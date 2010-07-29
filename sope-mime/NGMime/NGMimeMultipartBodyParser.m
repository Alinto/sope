/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "NGMimeBodyParser.h"
#include "NGMimeBodyPartParser.h"
#include "NGMimeMultipartBody.h"
#include "common.h"
#include <string.h>

@implementation NGMimeMultipartBodyParser

static int MimeLogEnabled = -1;

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  MimeLogEnabled = [ud boolForKey:@"MimeLogEnabled"] ? 1 : 0;
}

// returns the postion of the '\r' that starts the boundary
static inline const char
*_findNextBoundary(const char *_from, unsigned _len,
                   const char *_boundary, unsigned _boundaryLen, BOOL _isFirst)
{
  register unsigned pos  = 0;
  register unsigned blen = _boundaryLen;

  if (_isFirst) {
    blen += 3; // -- + at least one EOL char at end of line
    if (_len < blen) return NULL;  // too short to contain boundary
    
    for (pos = 0; (pos < _len) && (_len - pos > blen); pos++) {
      if ((_from[pos] == '-') && (_from[pos + 1] == '-')) {
        if (strncmp(&(_from[pos + 2]), _boundary, _boundaryLen) == 0) {
          // found boundary;
          return _from + pos;
        }
      }
    }
  }
  else {
    blen += 4; // -- + at least two EOL chars at start and end of line
    if (_len < blen) return NULL; // too short to contain boundary

    /* detect:
         --boundary(--)?CR
         CR--boundary(--)?CR
         CRLF--boundary(--)?CRLF
         LF--boundary(--)?LF
    */
    
    for (pos = 0; (pos < _len) && ((_len - pos) > blen); pos++) {
      if (_from[pos] == '\n') { // check for LF--
        if ((_from[pos + 1] == '-') &&(_from[pos + 2] == '-')) {
          // found LF--
          if (strncmp(&(_from[pos + 3]), _boundary, _boundaryLen) == 0)
            // found LF--boundary
            return (_from + pos);
        }
      }
      else if (_from[pos] == '\r') { // check for CR.-?
        if ((_from[pos + 1] == '-') && (_from[pos + 2] == '-')) { // CHECK FOR CR--
          // found CR--
          if (strncmp(&(_from[pos + 3]), _boundary, _boundaryLen) == 0)
            // found LF--boundary
            return (_from + pos);
        }
        if ((_from[pos + 1] == '\n') && (_from[pos + 2] == '-')
            && (_from[pos + 3] == '-')) {
          // found CRLF--
          if ((_len - pos) <= blen) {
            // remaining part is too short for boundary starting with CRLF
            break;
          }
          
          if (strncmp(&(_from[pos + 4]), _boundary, _boundaryLen) == 0)
            // found LF--boundary
            return (_from + pos);
        }
      }
      else if ((_from[pos] == '-') && (_from[pos + 1] == '-')) {
        if (strncmp(&(_from[pos + 2]), _boundary, _boundaryLen) == 0) {
            // found --boundary
          return (_from + pos);
        }
      }
    }
  }
  return NULL;
}

static inline BOOL
_isEndBoundary(const char *_from, unsigned _len,
               const char *_boundary, unsigned _boundaryLen)
{
  // no buffer out-of-bounds check, may cause segfault
  
  if (_len < (_boundaryLen + 8)) // + 2x CRLF and 2x '--'
    return YES;

  while (*_from != '-') _from++; // search first '-'
  _from += 2; // skip '--'
  
  _from += _boundaryLen; // skip boundary;
  return ((_from[0] == '-') && (_from[1] == '-')) ? YES : NO;
}

static inline const char *
_skipBoundary(id self, const char *_from, unsigned _len, BOOL _first)
{
  register unsigned pos = 0;
  register unsigned char c = 0;

  if (_from == NULL) return NULL;

  if (_from[0] == '-') { // skip '--'
    c = 0; // EOL needs to be detected
  }
  else if (_from[1] == '-') { // skip CR-- or LF--
    c = _from[0];
    if ((c != '\n') && (c != '\r')) {
      if (MimeLogEnabled) 
        [self logWithFormat:@"WARNING(%s): invalid char before boundary '--'",
              __PRETTY_FUNCTION__];
    }
    pos = 3;
  }
  else if (_from[2] == '-') { // skip CRLF--
    c = _from[0];
    if (c != '\r') {
      if (MimeLogEnabled)
        [self logWithFormat:@"WARNING(%s): missing CR before boundary 'LF--'",
              __PRETTY_FUNCTION__];
    }
    c = _from[1];
    if (c != '\n') {
      if (MimeLogEnabled)
        [self logWithFormat:@"WARNING(%s): missing LF before boundary '--' (after"
              @"CR)", __PRETTY_FUNCTION__];
    }
    pos = 4;
  }
  else {
    if (MimeLogEnabled)
      [self logWithFormat:@"ERROR(%s): invalid parser state, skipping 4.",
            __PRETTY_FUNCTION__];
    pos = 4;
  }

  while (pos < _len) {
    register unsigned char fc = _from[pos];
    
    if (c == 0) { // EOL detect (on first line)
      if (fc == '\n') // LF
        break;

      if (fc == '\r') { // CR *
        if ((pos + 1) == _len) // CR EOF
          break;
        else if (_from[pos + 1] == '\n') { // CRLF
          pos++; // skip LF
          break;
        }
        else // CR
          break;
      }
    }
    else if (fc == c) // EOL char is known
      break;
    
    pos++;
  }

  if (pos < _len)
    pos++; // skip EOL char
  
  return &(_from[pos]); // return pointer to position after char
}

- (NSArray *)_parseBody:(NGMimeMultipartBody *)_body
  part:(id<NGMimePart>)_part data:(NSData *)_data
  boundary:(const char *)_boundary length:(unsigned)_boundaryLen
  delegate:(id)_delegate
{
  NSMutableArray    *result;
  NSAutoreleasePool *pool;
  const char *begin   = NULL;
  const char *end     = NULL;
  const char *buffer  = [_data bytes];
  unsigned   len      = [_data length];
  BOOL       isEOF    = NO;    

  NSCAssert(buffer,                @"got no buffer");
  NSCAssert(_boundary,             @"got no boundary");

  result = [NSMutableArray arrayWithCapacity:7];
  
  // find first boundary and store prefix
  
  begin = _findNextBoundary(buffer, len, _boundary, _boundaryLen, YES);
  
  if (begin == NULL) {
    if (MimeLogEnabled)
      [self logWithFormat:@"WARNING(%s): Found multipart with no 1st boundary",
            __PRETTY_FUNCTION__];
    [result addObject:_data];
    return result;
  }

  pool = [[NSAutoreleasePool alloc] init];
  
  {
    unsigned preLen = begin - buffer;
    
    if (preLen > 0) {
      if ([_delegate respondsToSelector:
                     @selector(multipartBodyParser:foundPrefix:inMultipart:)]) {
        [_delegate multipartBodyParser:self
                   foundPrefix:[NSData dataWithBytes:buffer length:preLen]
                   inMultipart:_part];
      }

      [_body setPrefix:[NSString stringWithCString:buffer length:preLen]];
    }
  }

  // skip first boundary
  
  begin = _skipBoundary(self, begin, len - (begin - buffer), YES);
  NSCAssert(begin, @"could not skip 1st boundary ..");

  // loop over multipart bodies and exit if end-boundary is found

  do {

    /* check for boundary denoting end of current part */
    
    end = _findNextBoundary(begin, len - (begin - buffer),
                            _boundary,_boundaryLen, NO);
    if (end == NULL) {
      NSRange subDataRange;
      NSData  *rawData = nil;

      if (MimeLogEnabled)
        [self logWithFormat:@"WARNING(%s): reached end of body without"
              @" end-boundary", __PRETTY_FUNCTION__];
      
      subDataRange.location = (begin - buffer);
      subDataRange.length   = ([_data length] + buffer - begin);
      rawData = [_data subdataWithRange:subDataRange];
      if (rawData)
        [result addObject:rawData];
      isEOF = YES;      
      break;
    }
    else {
      NSRange subDataRange;
      NSData *rawData = nil;
      
      NSCAssert(end - begin >= 0, @"invalid range ..");

      subDataRange.location = (begin - buffer);
      subDataRange.length   = (end - begin);

      rawData = [_data subdataWithRange:subDataRange];

      if (rawData) {
        [result addObject:rawData];
      }
      else {
        NSLog(@"WARNING(%s): could not create rawdata for "
              @" bodypart in multipart %@", __PRETTY_FUNCTION__,
              _part);
      }

      /* check whether last read boundary was an end boundary */

      if (_isEndBoundary(end, len - (end - buffer),
                         _boundary, _boundaryLen)) {
        isEOF = NO;
        break;        
      }
      
      /* skip non-end boundary */
    
      begin = _skipBoundary(self, end, len - (end - buffer), NO);
    }
  }
  while (begin);

  // skip end boundary and store suffix
  if (!isEOF) {
    if ((begin = _skipBoundary(self, end, len - (end - buffer), NO))) {   
      unsigned sufLen;

      sufLen = len - (begin - buffer);
      
      if (sufLen > 0) {
        if ([_delegate respondsToSelector: @selector(multipartBodyParser:
                                                     foundSuffix:
                                                     inMultipart:)])
            [_delegate multipartBodyParser:self
                       foundSuffix:[NSData dataWithBytes:begin length:sufLen]
                       inMultipart:_part];
        
        [_body setSuffix:[NSString stringWithCString:begin length:sufLen]];
      }
    }
  }
  
  /* result is not contained in this pool, so no need to retain ... */
  RELEASE(pool);

  return result;
}

static NSString *_searchBoundary(NGMimeMultipartBodyParser *self,
                                 NSData *_data) {
  const char *buffer = [_data bytes];
  int        length  = [_data length];  
  int        pos     = 0;
  BOOL       found   = NO;

  if (length < 3)
    return nil;

  if ((buffer[0] == '-') && (buffer[1] == '-')) {   // no prefix
    found = YES;
    pos = 2;
  }
  else {
    while (pos + 5 < length) {
      if (buffer[pos + 2] != '-') {
        // if third char is not a '-' it cannot be a boundary start
        pos++;
        continue;
      }
      
      if (buffer[pos] == '\n') { // check for LF--
        if (buffer[pos + 1] == '-') {
          // found LF--
          pos  += 3;
          found = YES;
          break;
        }
      }
      else if (buffer[pos] == '\r') { // check for CR.-?
        if ((buffer[pos + 1] == '-') ) { // CHECK FOR CR--
          // found CR--
          pos  += 3;
          found = YES;
          break;
        }
        if ((buffer[pos + 1] == '\n') && (buffer[pos + 3] == '-')) {
          // found CRLF--
          if ((length - pos) <= 4) {
            // remaining part is too short for boundary starting with CRLF
            break;
          }
          // found LF--boundary
          pos  += 4;
          found = YES;
          break;
        }
      }
      pos++;
    }
  }
  if (found) {
    int boundLength = 0;
    
    buffer += pos;
    
    while (((boundLength + pos) < length) &&
           (buffer[boundLength] != '\n')  &&
           (buffer[boundLength] != '\r')) {
      boundLength++;
    }
    if ((boundLength + pos) < length) {
      return [NSString stringWithCString:buffer length:boundLength]; 
    }
    else 
      return nil;
  }
  else 
    return nil;
}

- (id<NGMimePart>)parseBodyPartWithData:(NSData *)_rawData
  inMultipart:(id<NGMimePart>)_multipart
  parser:(NGMimePartParser *)_parser
{
  if (![_rawData length])
    return nil;

  return [_parser parsePartFromData:_rawData];
}

- (BOOL)parseBody:(NGMimeMultipartBody *)_body
  ofMultipart:(id<NGMimePart>)_part
  data:(NSData *)_data delegate:(id)_d
{
  NGMimeType *contentType  = nil;
  NSString   *boundary     = nil;
  NSArray    *rawBodyParts = nil;
  BOOL       foundError    = NO;
  NSData     *boundaryBytes;

  contentType = [_part contentType];
  boundary    = [contentType valueOfParameter:@"boundary"];
  
  if (boundary == nil)
    boundary = _searchBoundary(self, _data);
  
  *(&foundError) = NO;
  
  boundaryBytes = [boundary dataUsingEncoding:NSISOLatin1StringEncoding];
  *(&rawBodyParts) = [self _parseBody:_body part:_part data:_data
			   boundary:[boundaryBytes bytes]
			   length:[boundary length]
			   delegate:_d];

  if (rawBodyParts) {
    NGMimeBodyPartParser *bodyPartParser;
    unsigned i, count;
    BOOL     askDelegate = NO;

    *(&count)          = [rawBodyParts count];    
    *(&i)              = 0;
    *(&bodyPartParser) = nil;

    if ([_d respondsToSelector:
              @selector(multipartBodyParser:parserForEntity:inMultipart:)]) {
      *(&askDelegate) = YES;
    }

    for (i = 0; i < count; i++) {
      NSString     *reason  =
        @"ERROR: could not parse body part at index %i in multipart %@: %@";
      NGMimePartParser *parser;
      id               rawData;
      id               bodyPart;

      rawData      = [rawBodyParts objectAtIndex:i];      
      *(&parser)   = bodyPartParser;
      *(&bodyPart) = nil;

      if (askDelegate) {
        parser = [_d multipartBodyParser:self
                     parserForEntity:rawData
                     inMultipart:_part];
        [parser setDelegate:_d];
      }
      else if (bodyPartParser == nil) {
        bodyPartParser = [[NGMimeBodyPartParser alloc] init];
        [bodyPartParser setDelegate:_d];
        parser = bodyPartParser;
      }

      if (parser == nil) {
        if (rawData) {
	  NSData *d;
	  
	  /* ensure that we have a copy, not a range on the full data */
	  d = [[NSData alloc] initWithBytes:[rawData bytes] 
			      length:[rawData length]];
          [_body addBodyPart:d];
	  RELEASE(d);
	}
      }
      else {
        NS_DURING {
          if ([rawData length])
            bodyPart = [self parseBodyPartWithData:rawData
                             inMultipart:_part
                             parser:parser];
        }
        NS_HANDLER {
          NSLog(reason, i, _part, localException);
          foundError = YES;
        }
        NS_ENDHANDLER;
	
        if (bodyPart) {
          [_body addBodyPart:bodyPart];
        }

        parser = nil;
      }
    }
    
    RELEASE(bodyPartParser); bodyPartParser = nil;
  }
  return foundError;
}

- (BOOL)parseImmediatlyWithDelegate:(id)_delegate
  multipart:(id<NGMimePart>)_part data:(NSData *)_data
{
  if ([_delegate respondsToSelector:
          @selector(multipartBodyParser:immediatlyParseBodyOfMultipart:data:)]) {
    BOOL result;

    result = [_delegate multipartBodyParser:self
                        immediatlyParseBodyOfMultipart:_part
                        data:_data];
    return result;
  }
  else
    return YES;
}

- (id)parseBodyOfPart:(id<NGMimePart>)_part
  data:(NSData *)_data delegate:(id)_d
{
  NGMimeMultipartBody *body;
  NGMimeType *contentType;
  NSString   *boundary;
  unsigned   len;
  
  contentType = [_part contentType];
  boundary    = [contentType valueOfParameter:@"boundary"];
  len         = [_data length];
  
  if (len == 0)
    return nil;
  
  if (contentType == nil) {
    NSLog(@"ERROR [%s]: part %@ has no content type, cannot find out "
          @"the boundary !", __PRETTY_FUNCTION__, _part);
    return _data;
  }
  if (![contentType isCompositeType]) {
    NSLog(@"ERROR [%s]: content type %@ of part %@ is not composite !",
          __PRETTY_FUNCTION__, contentType, _part);
    return _data;
  }
  if (boundary == nil) {
    if (!(boundary = _searchBoundary(self, _data))) {
      NSLog(@"ERROR [%s]: no boundary parameter in content "
            @"type %@ of part %@ !",
            __PRETTY_FUNCTION__, contentType, _part);
      return _data;
    }
  }
  if ([boundary length] > 70) {
    if (MimeLogEnabled) 
      [self logWithFormat:@"WARNING(%s): got boundary longer than 70 chars "
            @"(not allowed by RFC) in type %@",
            __PRETTY_FUNCTION__, contentType];
  }
  
  if ([self parseImmediatlyWithDelegate:_d multipart:_part data:_data]) {
    body = [[NGMimeMultipartBody alloc] initWithPart:_part];
    body = AUTORELEASE(body);
    
    if (![self parseBody:body ofMultipart:_part data:_data delegate:_d])
      ; // error
  }
  else {
    body = [[NGMimeMultipartBody alloc]
                                 initWithPart:_part data:_data delegate:_d];
    body = AUTORELEASE(body);
  }
  
  return body;
}

@end /* NGMimeMultipartBodyParser */
