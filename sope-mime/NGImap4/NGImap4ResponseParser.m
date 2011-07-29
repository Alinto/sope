/*
  Copyright (C) 2000-2007 SKYRIX Software AG

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

#include "NGImap4ResponseParser.h"
#include "NGImap4Support.h"
#include "NGImap4Envelope.h"
#include "NGImap4EnvelopeAddress.h"
#include "imCommon.h"

// TODO(hh): code is now prepared for last-exception, but currently it just
//           raises and may leak the exception object

@interface NGImap4ResponseParser(ParsingPrivates)
- (BOOL)_parseNumberUntaggedResponse:(NGMutableHashMap *)result_;
- (NSDictionary *)_parseBodyContent;
- (NSData *) _parseBodyHeaderFields;

- (NSData *)_parseData;

- (BOOL)_parseQuotaResponseIntoHashMap:(NGMutableHashMap *)result_;
- (void)_parseContinuationResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseListOrLSubResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseCapabilityResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseNamespaceResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseSearchResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseSortResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseQuotaRootResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseStatusResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseThreadResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseVanishedResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseByeUntaggedResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseACLResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseMyRightsResponseIntoHashMap:(NGMutableHashMap *)result_;
- (BOOL)_parseListRightsResponseIntoHashMap:(NGMutableHashMap *)result_;

- (NSArray *)_parseThread;

@end

@implementation NGImap4ResponseParser

#define __la(__SELF__, __PEEKPOS) \
  ((__SELF__->la == NULL) \
    ? [__SELF__->buffer la:__PEEKPOS]\
    : __SELF__->la(__SELF__->buffer, @selector(la:), __PEEKPOS))

static __inline__ int _la(NGImap4ResponseParser *self, unsigned _laCnt) {
  register unsigned char c = __la(self, _laCnt);
  return (c == '\r')
    ? _la(self, _laCnt + 1)
    : c;
}
static __inline__ BOOL _matchesString(NGImap4ResponseParser *self, 
				      const char *s)
{
  register unsigned int  i;
  
  for (i = 0; s[i] != '\0'; i++) {
    if (_la(self, i) != s[i])
      return NO;
  }
  return YES;
}

static NSDictionary *_parseBody(NGImap4ResponseParser *self,
				BOOL isBodyStructure);
static NSDictionary *_parseSingleBody(NGImap4ResponseParser *self,
				      BOOL isBodyStructure);
static NSDictionary *_parseMultipartBody(NGImap4ResponseParser *self,
					 BOOL isBodyStructure);

static NSArray *_parseLanguages();

static NSString *_parseBodyString(NGImap4ResponseParser *self,
                                  BOOL _convertString);
static NSString *_parseBodyDecodeString(NGImap4ResponseParser *self,
                                        BOOL _convertString,
                                        BOOL _decode);
static NSDictionary *_parseBodyParameterList(NGImap4ResponseParser *self);
static NSDictionary *_parseContentDisposition(NGImap4ResponseParser *self);
static NSArray *_parseAddressStructure(NGImap4ResponseParser *self);
static NSArray *_parseParenthesizedAddressList(NGImap4ResponseParser *self);
static int _parseTaggedResponse(NGImap4ResponseParser *self,
                                NGMutableHashMap *result_);
static void _parseUntaggedResponse(NGImap4ResponseParser *self,
                                   NGMutableHashMap *result_);
static NSArray *_parseFlagArray(NGImap4ResponseParser *self);
static BOOL _parseFlagsUntaggedResponse(NGImap4ResponseParser *self,
                                        NGMutableHashMap *result_);
static BOOL _parseOkUntaggedResponse(NGImap4ResponseParser *self,
                                     NGMutableHashMap *result_);
static BOOL _parseBadUntaggedResponse(NGImap4ResponseParser *self,
                                      NGMutableHashMap *result_);
static BOOL _parseNoUntaggedResponse(NGImap4ResponseParser *self,
                                     NGMutableHashMap *result_);
static NSNumber *_parseUnsigned(NGImap4ResponseParser *self);
static NSString *_parseUntil(NGImap4ResponseParser *self, char _c);
static NSString *_parseUntil2(NGImap4ResponseParser *self, char _c1, char _c2);
static BOOL _endsWithCQuote(NSString *_string);

static __inline__ NSException *_consumeIfMatch
  (NGImap4ResponseParser *self, unsigned char _m);
static __inline__ void _consume(NGImap4ResponseParser *self, unsigned _cnt);

static void _parseSieveRespone(NGImap4ResponseParser *self,
                               NGMutableHashMap *result_);
static BOOL _parseGreetingsSieveResponse(NGImap4ResponseParser *self,
                                         NGMutableHashMap *result_);
static BOOL _parseDataSieveResponse(NGImap4ResponseParser *self,
                                    NGMutableHashMap *result_);
static BOOL _parseOkSieveResponse(NGImap4ResponseParser *self,
                                  NGMutableHashMap *result_);
static BOOL _parseNoSieveResponse(NGImap4ResponseParser *self,
                                  NGMutableHashMap *result_);
static NSString *_parseContentSieveResponse(NGImap4ResponseParser *self);
static NSString *_parseStringSieveResponse(NGImap4ResponseParser *self);

static unsigned int     LaSize              = 4097;
static unsigned         UseMemoryMappedData = 0;
static unsigned         Imap4MMDataBoundary = 0;
static BOOL             debugOn             = NO;
static BOOL             debugDataOn         = NO;
static NSStringEncoding encoding;
static Class            StrClass  = Nil;
static Class            NumClass  = Nil;
static Class            DataClass = Nil;
static NSStringEncoding defCStringEncoding;
static NSNumber         *YesNum = nil;
static NSNumber         *NoNum  = nil;
static NSNull           *null   = nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;

  null = [[NSNull null] retain];
  
  encoding = [NGMimePartParser defaultHeaderFieldEncoding];
  defCStringEncoding = [NSString defaultCStringEncoding];
  
  debugOn             = [ud boolForKey:@"ImapDebugEnabled"];
  debugDataOn         = [ud boolForKey:@"ImapDebugDataEnabled"];
  UseMemoryMappedData = [ud boolForKey:@"NoMemoryMappedDataForImapBlobs"]?0:1;
  Imap4MMDataBoundary = [ud integerForKey:@"Imap4MMDataBoundary"];
  
  if (Imap4MMDataBoundary < 10)
    /* Note: this should be larger than a usual header size! */
    Imap4MMDataBoundary = 2 * LaSize;
  
  StrClass  = [NSString class];
  NumClass  = [NSNumber class];
  DataClass = [NSData class];
  YesNum    = [[NumClass numberWithBool:YES] retain];
  NoNum     = [[NumClass numberWithBool:NO]  retain];
}

+ (id)parserWithStream:(id<NGActiveSocket>)_stream {
  NGImap4ResponseParser *parser;

  parser = [NGImap4ResponseParser alloc]; /* seperate line to keep gcc happy */
  return [[parser initWithStream:_stream] autorelease];
}

- (id)initWithStream:(id<NGActiveSocket>)_stream {
  // designated initializer
  if (_stream == nil) {
    [self logWithFormat:@"%s: got no stream ...", __PRETTY_FUNCTION__];
    [self release];
    return nil;
  }
  
  if ((self = [super init])) {
    id s;
    
    s = [(NGBufferedStream *)[NGBufferedStream alloc] initWithSource:_stream];
    self->buffer = [NGByteBuffer alloc];
    self->buffer = [self->buffer initWithSource:s la:LaSize];
    [s release];
    
    if ([self->buffer respondsToSelector:@selector(methodForSelector:)])
      self->la = (int(*)(id, SEL, unsigned))
        [self->buffer methodForSelector:@selector(la:)];
    
    self->debug = debugOn;
  }
  return self;
}

- (id)init {
  [self release];
  [NSException raise:@"InvalidUseOfMethodException"
	       format:
		 @"calling -init on the NGImap4ResponseParser is not allowed"];
  return nil;
}

- (void)dealloc {
  [self->buffer release];
  if (self->debug)
    [self->serverResponseDebug release];
  [super dealloc];
}

/* exception handling */

- (void)setLastException:(NSException *)_exc {
  // TODO: support last exception
  [_exc raise];
}

/*
** Parse Sieve Responses
*/

- (NGHashMap *)parseSieveResponse {
  NGMutableHashMap *result;

  if (self->debug) {
    if (self->serverResponseDebug != nil)
      [self->serverResponseDebug release];
    self->serverResponseDebug = [[NSMutableString alloc] initWithCapacity:512];
  }
  result = [NGMutableHashMap hashMapWithCapacity:64];

  if (_la(self,0) == -1) {
    [self setLastException:[self->buffer lastException]];
    return nil;
  }
  
  _parseSieveRespone(self, result);
  return result;
}

- (NGHashMap *)parseResponseForTagId:(int)_tag exception:(NSException **)ex_ {
  /* parse a response from the server, _tag!=-1 parse until tagged response */
  // TODO: is NGHashMap really necessary here?
  BOOL             endOfCommand;
  NGMutableHashMap *result;
  
  if (ex_) *ex_ = nil;
  
  if (self->debug) {
    [self->serverResponseDebug release]; self->serverResponseDebug = nil;
    self->serverResponseDebug = [[NSMutableString alloc] initWithCapacity:512];
  }
  
  result = [NGMutableHashMap hashMapWithCapacity:64];
  for (endOfCommand = NO; !endOfCommand; ) {
    unsigned char l0;
    
    l0 = _la(self, 0);
    
    if (l0 == '*') { /* those starting with '* ' */
      _parseUntaggedResponse(self, result);
      if ([result objectForKey:@"bye"]) {
        endOfCommand = YES;
      }
      else {
        if (_tag == -1) {
          if ([result objectForKey:@"ok"] != nil)
            endOfCommand = YES;
        }
      }
    }
    else if (l0 == '+') { /* starting with a '+'? */
      [self _parseContinuationResponseIntoHashMap:result];
      endOfCommand = YES;
    }
    else if (isdigit(l0)) {
      /* those starting with a number '24 ', eg '24 OK Completed' */
      endOfCommand = (_parseTaggedResponse(self, result) == _tag);
    }
    else if (l0 == (unsigned char) -1) {
      if (ex_) {
        *ex_ = [self->buffer lastException];
        if (!*ex_)
          *ex_
            = [NSException exceptionWithName:@"UnexpectedEndOfStream"
                                      reason:(@"the parsed stream ended"
                                              @" unexpectedly")
                                    userInfo:nil];
      } else {
        [self setLastException: [self->buffer lastException]];
      }
      endOfCommand = YES;
      result = nil;
    }
  }
  return result;
}
- (NGHashMap *)parseResponseForTagId:(int)_tag {
  // DEPRECATED
  NSException *e = nil;
  NGHashMap   *hm;

  hm = [self parseResponseForTagId:_tag exception:&e];
  if (e) {
    [self setLastException:e];
    return nil;
  }
  return hm;
}

static void _parseSieveRespone(NGImap4ResponseParser *self,
                               NGMutableHashMap *result_)
{
  if (_parseGreetingsSieveResponse(self, result_)) 
    return;
  if (_parseDataSieveResponse(self, result_))    // la: 1
    return;
  if (_parseOkSieveResponse(self, result_))     // la: 2
    return; 
  if (_parseNoSieveResponse(self, result_))     // la: 2
    return;
}

- (NSData *)_parseDataToFile:(unsigned)_size {
  // TODO: move to own method
  // TODO: do not use NGFileStream but just fopen/fwrite
  static NSProcessInfo *Pi = nil;
  NGFileStream  *stream;
  NSData        *result;
  unsigned char buf[LaSize + 2];
  unsigned char tmpBuf[LaSize + 2];
  unsigned      wasRead = 0;
  NSString      *path;
  signed char   lastChar; // must be signed
      
  if (debugDataOn) [self logWithFormat:@"  using memory mapped data  ..."];
      
  if (Pi == nil)
    Pi = [[NSProcessInfo processInfo] retain];

  path   = [Pi temporaryFileName];
  stream = [NGFileStream alloc]; /* extra line to keep gcc happy */
  stream = [stream initWithPath:path];

  if (![stream openInMode:NGFileWriteOnly]) {
    NSException *e;

    e = [[NGImap4ParserException alloc]
	  initWithFormat:@"Could not open temporary file %@", path];
    [self setLastException:[e autorelease]];
    return nil;
  }
      
  lastChar = -1;
  while (wasRead < _size) {
    unsigned readCnt, bufCnt, tmpSize, cnt, tmpBufCnt;

    bufCnt = 0;
        
    if (lastChar != -1) {
      buf[bufCnt++] = lastChar;
      lastChar = -1;
    }
        
    [self->buffer la:(_size - wasRead <  LaSize) 
	 ? (_size - wasRead)
	 : LaSize];
        
    readCnt = [self->buffer readBytes:buf+bufCnt count:_size - wasRead];
        
    wasRead+=readCnt;
    bufCnt +=readCnt;

    tmpSize   = bufCnt - 1;
    cnt       = 0;
    tmpBufCnt = 0;
        
    while (cnt < tmpSize) {
      if ((buf[cnt] == '\r') && (buf[cnt+1] == '\n')) {
	cnt++;
      }
      tmpBuf[tmpBufCnt++] = buf[cnt++];
    }
    if (cnt < bufCnt) {
      lastChar = buf[cnt];
    }
    [stream writeBytes:tmpBuf count:tmpBufCnt];
  }
  if (lastChar != -1)
    [stream writeBytes:&lastChar count:1];
  
  [stream close];
  [stream release]; stream = nil;
  result = [DataClass dataWithContentsOfMappedFile:path];
  [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];

  return result;
}
- (NSData *)_parseDataIntoRAM:(unsigned)_size {
  /* parses data into a RAM buffer (NSData) */
  unsigned char *buf = NULL;
  unsigned char *tmpBuf;
  unsigned      wasRead   = 0;
  unsigned      cnt, tmpBufCnt, tmpSize;
  NSData        *result;
          
  buf = calloc(_size + 10, sizeof(char));
    
  while (wasRead < _size) {
    [self->buffer la:(_size - wasRead <  LaSize) ? (_size - wasRead) : LaSize];
            
    wasRead += [self->buffer readBytes:(buf + wasRead) count:(_size-wasRead)];
  }
  
  /* normalize response  \r\n -> \n */
	
  tmpBuf    = calloc(_size + 10, sizeof(char));
  cnt       = 0;
  tmpBufCnt = 0;
  tmpSize   = _size == 0 ? 0 : _size - 1;
  while (tmpBufCnt < tmpSize && cnt < _size) {
    if ((buf[cnt] == '\r') && (buf[cnt + 1] == '\n'))
      cnt++; /* skip \r */
      
    tmpBuf[tmpBufCnt] = buf[cnt];
    tmpBufCnt++;
    cnt++;
  }
  if (cnt < _size) {
    tmpBuf[tmpBufCnt] = buf[cnt];
    tmpBufCnt++;
    cnt++;
  }
    
  result = [DataClass dataWithBytesNoCopy:tmpBuf length:tmpBufCnt];
    
  if (buf != NULL) free(buf); buf = NULL;
  return result;
}
- (NSData *)_parseData {
  /*
    parses:
      { <uint> } \n
  */
  // TODO: split up method
  NSData   *result;
  unsigned size;
  NSNumber *sizeNum;

  if (_la(self, 0) != '{')
    return nil;
  
  if (debugDataOn) [self logWithFormat:@"parse data ..."];

  /* got header */
  result = nil;  
  
  _consume(self, 1); // '{'
  if ((sizeNum = _parseUnsigned(self)) == nil) {
    NSException *e;

    e = [[NGImap4ParserException alloc] 
	    initWithFormat:@"expect a number between {}"];
    [self setLastException:[e autorelease]];
    return nil;
  }
  if (debugDataOn) [self logWithFormat:@"  parse data, size: %@", sizeNum];
  _consumeIfMatch(self, '}');
  _consumeIfMatch(self, '\n');
  
  if ((size = [sizeNum intValue]) == 0) {
    [self logWithFormat:@"ERROR(%s): got content size '0'!", 
            __PRETTY_FUNCTION__];
    return nil;
  }
  
  if (UseMemoryMappedData && (size > Imap4MMDataBoundary))
    return [self _parseDataToFile:size];
  
  return [self _parseDataIntoRAM:size];
}

/*
  Similair to _parseData but used to parse something like this :

  BODY[HEADER.FIELDS (X-PRIORITY)] {17}
  X-Priority: 1

  )

  Headers are returned as data, as is.
*/
- (NSData *) _parseBodyHeaderFields
{ 
  NSData   *result;
  unsigned size;
  NSNumber *sizeNum;

  /* we skip until we're ready to parse {length} */
  _parseUntil(self, '{');
  
  result = nil;  

  if ((sizeNum = _parseUnsigned(self)) == nil) {
    NSException *e;

    e = [[NGImap4ParserException alloc] 
	    initWithFormat:@"expect a number between {}"];
    [self setLastException:[e autorelease]];
    return nil;
  }
  _consumeIfMatch(self, '}');
  _consumeIfMatch(self, '\n');
  
  if ((size = [sizeNum intValue]) == 0) {
    [self logWithFormat:@"ERROR(%s): got content size '0'!", 
            __PRETTY_FUNCTION__];
    return nil;
  }
  
  if (UseMemoryMappedData && (size > Imap4MMDataBoundary))
    return [self _parseDataToFile:size];
  
  return [self _parseDataIntoRAM:size];
}

static int _parseTaggedResponse(NGImap4ResponseParser *self,
                                NGMutableHashMap *result_) 
{
  NSDictionary *d;
  NSNumber *tag  = nil;
  NSString *res  = nil;
  NSString *desc = nil;
  NSString *flag = nil;
  
  if ((tag  = _parseUnsigned(self)) == nil) {
    NSException *e;
    
    if (self->debug) {
      e = [[NGImap4ParserException alloc]
	    initWithFormat:@"expect a number at begin of tagged response <%@>",
	    self->serverResponseDebug];
    }
    else {
      e = [[NGImap4ParserException alloc]
	    initWithFormat:@"expect a number at begin of tagged response"];
    }
    e = [e autorelease];
    [self setLastException:e];
    return -1;
  }
  
  _consumeIfMatch(self, ' ');
  res  = [_parseUntil(self, ' ') lowercaseString];
  if (_la(self, 0) == '[') { /* Found flag like [READ-ONLY] */
    _consume(self, 1);
    flag = _parseUntil(self, ']');
  }
  desc = _parseUntil(self, '\n');
  /*
    ATTENTION: if no flag was set, flag == nil, in this case all key-value 
               pairs after flag will be ignored
  */
  d = [[NSDictionary alloc] initWithObjectsAndKeys:
			      tag,  @"tagId",
			      res,  @"result",
			      desc, @"description",
			      flag, @"flag", nil];
  [result_ addObject:d forKey:@"ResponseResult"];
  [d release];
  return [tag intValue];
}

static void _parseUntaggedResponse(NGImap4ResponseParser *self,
                                   NGMutableHashMap *result_) 
{
  // TODO: is it really required by IMAP4 that responses are uppercase?
  // TODO: apparently this code *breaks* with lowercase detection on!
  unsigned char l0, l1 = 0;
  _consumeIfMatch(self, '*');
  _consumeIfMatch(self, ' ');
  
  l0 = _la(self, 0);
  switch (l0) {
  case 'A':
    if ([self _parseACLResponseIntoHashMap:result_])
      return;
    break;
    
  case 'B':
    l1 = _la(self, 1);
    if (l1 == 'A' && _parseBadUntaggedResponse(self, result_))    // la: 3
      return;
    if (l1 == 'Y' && [self _parseByeUntaggedResponseIntoHashMap:result_]) // 3
      return;
    break;

  case 'C':
    if ([self _parseCapabilityResponseIntoHashMap:result_])       // la: 10
      return;
    break;
    
  case 'F':
    if (_parseFlagsUntaggedResponse(self, result_))  // la: 5
      return;
    break;
    
  case 'L':
    if (_matchesString(self, "LISTRIGHTS")) {
      if ([self _parseListRightsResponseIntoHashMap:result_])
	return;
    }
    if ([self _parseListOrLSubResponseIntoHashMap:result_])       // la: 4
      return;
    break;

  case 'M':
    if ([self _parseMyRightsResponseIntoHashMap:result_])
      return;
    break;

  case 'N':
    if (_matchesString(self, "NAMESPACE")) {
      if ([self _parseNamespaceResponseIntoHashMap:result_])
	return;
    }
    if (_parseNoUntaggedResponse(self, result_))     // la: 2
      return;
    break;

  case 'O':
    if (_parseOkUntaggedResponse(self, result_))     // la: 2
      /* eg "* OK Completed" */
      return;
    break;

  case 'R':
    break;

  case 'S':
    switch (_la(self, 1)) {
    case 'O': // SORT
      if ([self _parseSortResponseIntoHashMap:result_])   // la: 4
	return;
      break;
    case 'E': // SEARCH
      if ([self _parseSearchResponseIntoHashMap:result_]) // la: 5
	return;
      break;
    case 'T': // STATUS
      if ([self _parseStatusResponseIntoHashMap:result_]) // la: 6
	/* eg "* STATUS INBOX (MESSAGES 0 RECENT 0 UNSEEN 0)" */
	return;
      break;
    }
    break;

  case 'T':
    if ([self _parseThreadResponseIntoHashMap:result_])    // la: 6
      return;
    break;
    
  case 'V':
    if ([self _parseVanishedResponseIntoHashMap:result_])    // la: 6
      return;
    break;
    
  case 'Q':
    if ([self _parseQuotaResponseIntoHashMap:result_])     // la: 6
      return;
    if ([self _parseQuotaRootResponseIntoHashMap:result_]) // la: 10
      return;
    break;

  case '0': case '1': case '2': case '3': case '4':
  case '5': case '6': case '7': case '8': case '9':
    if ([self _parseNumberUntaggedResponse:result_]) // la: 5
      /* eg "* 928 FETCH ..." */
      return;
    break;
  }
  
  // TODO: what if none matches?
  [self logWithFormat:@"%s: no matching tag specifier?", __PRETTY_FUNCTION__];
  [self logWithFormat:@"  line: '%@'", _parseUntil(self, '\n')];
}

- (void)_parseContinuationResponseIntoHashMap:(NGMutableHashMap *)result_ {
  _consumeIfMatch(self, '+');
  _consumeIfMatch(self, ' ');
  
  [result_ addObject:YesNum forKey:@"ContinuationResponse"];
  [result_ addObject:_parseUntil(self, '\n') forKey:@"description"];
}

static inline void
_purifyQuotedString(NSMutableString *quotedString) {
  unichar *currentChar, *qString, *maxC, *startC;
  unsigned int max, questionMarks;
  BOOL possiblyQuoted, skipSpaces;
  NSMutableString *newString;

  newString = [NSMutableString string];

  max = [quotedString length];
  qString = malloc (sizeof (unichar) * max);
  [quotedString getCharacters: qString];
  currentChar = qString;
  startC = qString;
  maxC = qString + max;

  possiblyQuoted = NO;
  skipSpaces = NO;

  questionMarks = 0;

  while (currentChar < maxC) {
    if (possiblyQuoted) {
      if (questionMarks == 2) {
	if ((*currentChar == 'Q' || *currentChar == 'q'
	     || *currentChar == 'B' || *currentChar == 'b')
	    && ((currentChar + 1) < maxC
		&& (*(currentChar + 1) == '?'))) {
	  currentChar++;
	  questionMarks = 3;
	}
	else {
	  possiblyQuoted = NO;
	}
      }
      else if (questionMarks == 4) {
	if (*currentChar == '=') {
	  skipSpaces = YES;
	  possiblyQuoted = NO;
 	  currentChar++;
	  [newString appendString: [NSString stringWithCharacters: startC
					     length: (currentChar - startC)]];
	  startC = currentChar;
	}
	else {
	  possiblyQuoted = NO;
	}
      }
      else {
	if (*currentChar == '?') {
	  questionMarks++;
	}
	else if (*currentChar == ' ' && questionMarks != 3) {
	  possiblyQuoted = NO;
	}
      }
    }
    else if (*currentChar == '='
	     && ((currentChar + 1) < maxC
		 && (*(currentChar + 1) == '?'))) {
      [newString appendString: [NSString stringWithCharacters: startC
 					 length: (currentChar - startC)]];
      startC = currentChar;
      possiblyQuoted = YES;
      skipSpaces = NO;
      currentChar++;
      questionMarks = 1;
    }

    if (skipSpaces) {
      /* This part is about skipping the spaces separating two encoded chunks,
         which occurs when the chunks are on different lines. However we
         cannot ignore them if the next chunk is not encoded. Basically, we
         can deduce a case from the other by the fact that it makes no sense
         per se to have a space separating two encoded chunks. */
      startC = currentChar;
      while (currentChar < maxC
             && (*currentChar == ' ' || *currentChar == '\t'))
	currentChar++;
      if (currentChar != startC) {
        if (currentChar < maxC && *currentChar != '=')
          [newString appendString: [NSString stringWithCharacters: startC
                                             length: (currentChar - startC)]];
        startC = currentChar;
      }
      else
        currentChar++;

      skipSpaces = NO;
    }
    else
      currentChar++;
  }

  if (startC < maxC)
    [newString appendString: [NSString stringWithCharacters: startC
				       length: (currentChar - startC)]];

  [quotedString setString: newString];
  free (qString);
}

- (NSString *)_parseQuotedString {
  NSMutableString *quotedString;
  NSString *tmpString;
  BOOL stop;

  /* parse a quoted string, eg '"' */
  if (_la(self, 0) == '"') {
    _consume(self, 1);
    quotedString = [NSMutableString string];
    stop = NO;
    while (!stop) {
      tmpString = _parseUntil(self, '"');
      [quotedString appendString: tmpString];
      if(_endsWithCQuote(tmpString)) {
	[quotedString deleteSuffix: @"\\"];
	[quotedString appendString: @"\""];
      }
      else {
	stop = YES;
      }
    }
  }
  else {
    quotedString = nil;
  }

  _purifyQuotedString(quotedString);

  return quotedString;
}

- (NSString *)_parseQuotedStringOrNIL {
  unsigned char c0;
  
  if ((c0 = _la(self, 0)) == '"')
    return [self _parseQuotedString];
  
  if (c0 == '{') {
    /* a size indicator, eg '{112}\nkasdjfkja sdj fhj hasdfj hjasdf' */
    NSData   *data;
    NSString *s;
    
    if ((data = [self _parseData]) == nil)
      return nil;
    if (![data isNotEmpty])
      return @"";
    
    s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (s == nil)
      s = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if (s == nil) {
      [self logWithFormat:
	      @"ERROR(%s): could not convert data (%d bytes) into string.",
	      __PRETTY_FUNCTION__, [data length]];
      return @"[ERROR: NGImap4 could not parse IMAP4 data string]";
    }
    return [s autorelease];
  }
  
  if (c0 == 'N' && _matchesString(self, "NIL")) {
    _consume(self, 3);
    return (id)null;
  }
  return nil;
}
- (id)_parseQuotedStringOrDataOrNIL {
  if (_la(self, 0) == '"')
    return [self _parseQuotedString];
  if (_la(self, 0) == '{')
    return [self _parseData];
  
  if (_matchesString(self, "NIL")) {
    _consume(self, 3);
    return null;
  }
  return nil;
}
- (void)_consumeOptionalSpace {
  if (_la(self, 0) == ' ') _consume(self, 1);
}

- (BOOL)_parseListOrLSubResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSArray  *flags = nil;
  NSString *delim = nil;
  NSString *name  = nil;
  NSDictionary *d;
  
  if (!_matchesString(self, "LIST ") && !_matchesString(self, "LSUB "))
    return NO;
  
  _consume(self, 5); /* consume 'LIST ' or 'LSUB ' */
  flags = _parseFlagArray(self);
  _consumeIfMatch(self, ' ');
  
  if (_la(self, 0) == '"') {
    delim = [self _parseQuotedString];
    _consumeIfMatch(self, ' ');
  }
  else {
    _parseUntil(self, ' ');
    delim = nil;
  }
  if (_la(self, 0) == '"') {
    name = [self _parseQuotedString];
    _parseUntil(self, '\n');
  }
  else if (_la(self, 0) == '{') {
    name = [self _parseQuotedStringOrNIL];
    _parseUntil(self, '\n');
  }
  else
    name = _parseUntil(self, '\n');
  
  d = [[NSDictionary alloc] initWithObjectsAndKeys:
			      name,  @"folderName",
			      flags, @"flags",
			      delim, @"delimiter", nil];
  [result_ addObject:d forKey:@"list"];
  [d release];
  return YES;
}

- (BOOL)_parseCapabilityResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSString *caps;
  NSEnumerator   *enumerator;
  id             obj;
  NSMutableArray *array;
  NSArray        *tmp;
  
  if (!_matchesString(self, "CAPABILITY "))
    return NO;

  caps = _parseUntil(self, '\n');

  array = [[NSMutableArray alloc] initWithCapacity:16];

  enumerator = [[caps componentsSeparatedByString:@" "] objectEnumerator];
  while ((obj = [enumerator nextObject]) != nil)
    [array addObject:[obj lowercaseString]];
  
  tmp = [array copy];
  [result_ addObject:tmp forKey:@"capability"];
  
  [array release]; array = nil;
  [tmp   release]; tmp   = nil;
  return YES;
}

/* support for NAMESPACE extension - RFC2342 */

- (NSDictionary *)_parseNamespacePart {
  NSDictionary *namespacePart;
  NSString *prefix, *key, *delimiter;
  NSMutableDictionary *parameters;
  NSMutableArray *values;

  _consume(self, 1);                             /* ( */
  prefix = [self _parseQuotedStringOrNIL];       /* "prefix" */ 
  _consume(self, 1);                             /* <sp> */
  delimiter = [self _parseQuotedStringOrNIL];    /* "delimiter" */
  parameters = [NSMutableDictionary dictionary];
  while (_la(self, 0) == ' ') {
    _consume(self, 1);                           /* <sp> */
    key = [self _parseQuotedString];
    _consume(self, 1);                           /* <sp> */
    values = [NSMutableArray new];
    while (_la(self, 0) != ')') {
      _consume(self, 1);                         /* ( or <sp> */
      [values addObject: [self _parseQuotedString]];
    }
    _consume(self, 1);                           /* ) */
    [parameters setObject: values forKey: key];
    [values release];
  }
  _consume(self, 1);                             /* ) */

  namespacePart = [NSDictionary dictionaryWithObjectsAndKeys:
                                  prefix, @"prefix",
                                delimiter, @"delimiter",
                                parameters, @"parameters",
                                nil];

  return namespacePart;
}

- (NSArray *)_parseNamespace {
  NSMutableArray *namespace;

  namespace = [[NSMutableArray alloc] initWithCapacity: 3];
  if (_la(self, 0) == 'N') {
    namespace = nil;
    _consume(self, 3);
  } else {
    _consume(self, 1); /* ( */
    while (_la(self, 0) == '(') {
      [namespace addObject: [self _parseNamespacePart]];
    }
    _consume(self, 1); /* ) */
  }

  return namespace;
}

- (BOOL)_parseNamespaceResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSArray *namespace;

  if (!_matchesString(self, "NAMESPACE "))
    return NO;

  _parseUntil(self, ' ');

  namespace = [self _parseNamespace];
  if (namespace)
    [result_ addObject:namespace forKey:@"personal"];
  _consume(self, 1);
  namespace = [self _parseNamespace];
  if (namespace)
    [result_ addObject:namespace forKey:@"other users"];
  _consume(self, 1);
  namespace = [self _parseNamespace];
  if (namespace)
    [result_ addObject:namespace forKey:@"shared"];
  _consume(self, 1); /* \n */

  return YES;
}

- (BOOL)_parseACLResponseIntoHashMap:(NGMutableHashMap *)result_ {
  /*
    21 GETACL INBOX
    * ACL INBOX test.et.di.cete-lyon lrswipcda helge lrwip "a group" lrs fred ""
  */
  NSString       *uid;
  NSString       *userRights;
  NSString       *mailbox;
  NSMutableArray *uids;
  NSMutableArray *rights;
  NSDictionary   *result;
  
  if (!_matchesString(self, "ACL "))
    return NO;
  _consume(self, 4);
  
  if ((mailbox = _parseBodyString(self, YES)) != nil)
    [result_ setObject:mailbox forKey:@"mailbox"];
  _consumeIfMatch(self, ' ');
  
  uids   = [[NSMutableArray alloc] initWithCapacity:8];
  rights = [[NSMutableArray alloc] initWithCapacity:8];
  
  while (_la(self, 0) != '\n') {
    if (_la(self, 0) == '"') {
      uid = [self _parseQuotedString];
      _consumeIfMatch(self, ' ');
    }
    else
      uid = _parseUntil(self, ' ' );

    if (_la(self, 0) == '"')
      userRights = [self _parseQuotedString];
    else
      userRights = _parseUntil2(self, ' ', '\n');
    [self _consumeOptionalSpace];

    [uids addObject:uid];
    [rights addObject:userRights];
  }
  _consume(self,1);
  
  result = [[NSDictionary alloc] initWithObjects:rights forKeys:uids];
  [result_ addObject:result forKey:@"acl"];
  
  [uids   release]; uids   = nil;
  [rights release]; rights = nil;
  [result release]; result = nil;
  return YES;
}

- (BOOL)_parseMyRightsResponseIntoHashMap:(NGMutableHashMap *)result_ {
  /*
    Raw Sample (Cyrus):
      18 myrights INBOX
      * MYRIGHTS INBOX lrswipcda
      18 OK Completed
  */
  NSString *rights;
  id obj;
  
  if (!_matchesString(self, "MYRIGHTS "))
    return NO;
  _consume(self, 9);
  
  if ((obj = _parseBodyString(self, YES)) != nil)
    [result_ setObject:obj forKey:@"mailbox"];
  _consumeIfMatch(self, ' ');
  
  rights = _parseUntil(self, '\n');
  [result_ setObject:rights forKey:@"myrights"];
  return YES;
}

- (BOOL)_parseListRightsResponseIntoHashMap:(NGMutableHashMap *)result_ {
  /*
    Raw Sample (Cyrus):
      22 LISTRIGHTS INBOX helge
      * LISTRIGHTS INBOX helge "" l r s w i p c d a 0 1 2 3 4 5 6 7 8 9
      22 OK Completed
 */
  NSString *rights;
  id obj;
  
  if (!_matchesString(self, "LISTRIGHTS "))
    return NO;
  _consume(self, 11);
  
  if ((obj = _parseBodyString(self, YES)) != nil)
    [result_ setObject:obj forKey:@"mailbox"];
  _consumeIfMatch(self, ' ');

  if ((obj = _parseBodyString(self, YES)) != nil)
    [result_ setObject:obj forKey:@"uid"];
  _consumeIfMatch(self, ' ');
  
  if ((obj = _parseUntil(self, ' ')) != nil) {
    if ([obj isEqual:@"\"\""])
      obj = @"";
    [result_ setObject:obj forKey:@"requiredRights"];
  }
  
  rights = _parseUntil(self, '\n');
  [result_ setObject:[rights componentsSeparatedByString:@" "]
	   forKey:@"listrights"];
  return YES;
}

- (BOOL)_parseSearchResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSMutableArray *msn = nil;
  NSNumber *n;

  if (!_matchesString(self, "SEARCH"))
    return NO;

  _consume(self, 6);

  msn = [NSMutableArray arrayWithCapacity:128];

  while (_la(self, 0) == ' ') {
      _consume(self, 1);
      n = _parseUnsigned(self);
      if (n)
	[msn addObject:n];
  }
  _parseUntil(self, '\n');
  [result_ addObject:msn forKey:@"search"];
  return YES;
}

- (BOOL)_parseSortResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSMutableArray *msn = nil;
  
  if (!_matchesString(self, "SORT"))
    return NO;
  
  _consume(self, 4);

  msn = [NSMutableArray arrayWithCapacity:128];

  while (_la(self, 0) == ' ') {
    _consume(self, 1);
    if (_la(self, 0) == '(') {
      _consume(self, 1);
      if (!_matchesString(self, "MODSEQ "))
        return NO;
      _consume(self, 7);
      [result_ addObject:_parseUnsigned(self) forKey:@"modseq"];
      _consume(self, 1); /* final ')' */
    }
    else
      [msn addObject:_parseUnsigned(self)];
  }
  _parseUntil(self, '\n');
  [result_ addObject:msn forKey:@"sort"];
  return YES;
}

- (BOOL)_parseQuotaResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSString            *qRoot;
  NSMutableDictionary *parse;
  NSMutableDictionary *quota;

  if (!_matchesString(self, "QUOTA "))
    return NO;

  _consume(self, 6);

  quota = [result_ objectForKey:@"quota"];
  
  if (quota == nil) {
      quota = [NSMutableDictionary dictionaryWithCapacity:2];
      [result_ setObject:quota forKey:@"quota"];
  }
    
  parse = [NSMutableDictionary dictionaryWithCapacity:3];
  qRoot = _parseUntil2(self, ' ', '\n');

  if (_la(self, 0) == ' ') {
      _consume(self, 1);

      if (_la(self, 0) == '(') {
        _consume(self,1);
        if (_la(self, 0) == ')') { /* empty quota response */
          _consume(self,1);
        }
        else {
          NSString *key;

          key = _parseUntil(self, ' ');
          key = [key lowercaseString];
          if ([key isEqualToString:@"storage"]) {
            NSString *used, *max;

            used = _parseUntil(self, ' ');
            max  = _parseUntil(self, ')');

            [parse setObject:used forKey:@"usedSpace"];
            [parse setObject:max  forKey:@"maxQuota"];
          }
          else {
            NSString *v;

            v = _parseUntil(self, ')');

            [parse setObject:v forKey:@"resource"];
          }
        }
      }
      [quota setObject:parse forKey:qRoot];
  }
  _parseUntil(self, '\n');
    
  return YES;
}

- (BOOL)_parseQuotaRootResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSString *folderName, *folderRoot;
  NSMutableDictionary *dict;
  
  if (!_matchesString(self, "QUOTAROOT "))
    return NO;

  _consume(self, 10);

  dict = [result_ objectForKey:@"quotaRoot"];

  if (!dict) {
    dict = [NSMutableDictionary dictionaryWithCapacity:2];
    [result_ setObject:dict forKey:@"quotaRoot"];
  }
  if (_la(self, 0) == '"') {
    _consume(self , 1);
    folderName = _parseUntil(self, '"');
  }
  else {
    folderName = _parseUntil2(self, '\n', ' ');
  }
  if (_la(self, 0) == ' ') {
    _consume(self, 1);
    folderRoot = _parseUntil(self, '\n');
  }
  else {
    _consume(self, 1);
    folderRoot = nil;
  }
  if ([folderName isNotEmpty] && [folderRoot isNotEmpty])
    [dict setObject:folderRoot forKey:folderName];
  
  return YES;
}

- (NSArray *)_parseThread {
  NSMutableArray *array;
  NSNumber       *msg;
    
  array = [NSMutableArray arrayWithCapacity:64];

  if (_la(self, 0) == '(')
    _consume(self, 1);
  
  while (1) {
    if (_la(self, 0) == '(') {
      NSArray *a;
      
      a = [self _parseThread];
      if (a != nil) [array addObject:a];
    }
    else if ((msg = _parseUnsigned(self))) {
      [array addObject:msg];
    }
    else {
      return nil;
    }
    if (_la(self, 0) == ')')
      break;
    else if (_la(self, 0) == ' ')
      _consume(self, 1);
  }
  _consumeIfMatch(self, ')');
  return array;
}


- (BOOL)_parseThreadResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSMutableArray *msn;

  if (!_matchesString(self, "THREAD"))
    return NO;
  
  _consume(self, 6);

  if (_la(self, 0) == ' ') {
    _consume(self, 1);
  }
  
  msn = [NSMutableArray arrayWithCapacity:64];
  
  while ((_la(self, 0) == '(')) {
    NSArray *array;
    
    if ((array = [self _parseThread]) != nil)
      [msn addObject:array];
  }
  _parseUntil(self, '\n');
  [result_ addObject:msn forKey:@"thread"];
  return YES;
}

- (BOOL)_parseVanishedResponseIntoHashMap:(NGMutableHashMap *)result_ {
  // VANISHED (EARLIER) 1:53,55:56,58:113,115,120,126,128'
  NSMutableArray *uids;
  NSNumber *uid;
  NSUInteger count, max;

  if (!_matchesString(self, "VANISHED"))
    return NO;
  
  _consume(self, 8);

  if (_la(self, 0) == ' ') {
    _consume(self, 1);
  }

  if (_la(self, 0) == '(') {
    _consume(self, 1);
    if (!_matchesString(self, "EARLIER"))
      return NO;
    _consume(self, 7); /* EARLIER */
    _consumeIfMatch(self, ')');
    if (_la(self, 0) == ' ') {
      _consume(self, 1);
    }
  }

  uids = [NSMutableArray new];
  
  while ((_la(self, 0) != '\n')) {
    uid = _parseUnsigned(self);
    [uids addObject:uid];
    if (_la(self, 0) == ':') {
      _consume(self, 1);
      count = [uid unsignedIntValue] + 1;
      uid = _parseUnsigned(self);
      max = [uid unsignedIntValue];
      while (count < max) {
        [uids addObject: [NSNumber numberWithUnsignedInt: count]];
        count++;
      }
      [uids addObject: uid];
    }
    if (_la(self, 0) == ',') {
      _consume(self, 1);
    }
  }
  _consume(self, 1);
  [result_ addObject:uids forKey:@"vanished"];
  [uids release];

  return YES;
}

- (BOOL)_parseStatusResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSString            *name  = nil;
  NSMutableDictionary *flags = nil;
  NSDictionary *d;
    
  if (!_matchesString(self, "STATUS "))
    return NO;

  _consume(self, 7);

  if (_la(self, 0) == '"') {
    name = [self _parseQuotedString];
//     _consume(self, 1);
//     name = _parseUntil(self, '"');
    _consumeIfMatch(self, ' ');
  }
  else if (_la(self, 0) == '{') {
    name = [self _parseQuotedStringOrNIL];
    _consumeIfMatch(self, ' ');
  }
  else {
    name = _parseUntil(self, ' ');
  }
  _consumeIfMatch(self, '(');
  flags = [NSMutableDictionary dictionaryWithCapacity:8];
    
  while (_la(self, 0) != ')') {
    NSString *key   = _parseUntil(self, ' ');
    id       value = _parseUntil2(self, ' ', ')');

    if (_la(self, 0) == ' ')
      _consume(self, 1);
      
    [flags setObject:[NumClass numberWithInt:[value intValue]]
	   forKey:[key lowercaseString]];
  }
  _consumeIfMatch(self, ')');
  _parseUntil(self, '\n');
  
  d = [[NSDictionary alloc] initWithObjectsAndKeys:
			      name,  @"folderName",
			      flags, @"flags", nil];
  [result_ addObject:d forKey:@"status"];
  [d release];
  return YES;
}

- (BOOL)_parseByeUntaggedResponseIntoHashMap:(NGMutableHashMap *)result_ {
  NSString *reason;
  
  if (!_matchesString(self, "BYE "))
    return NO;

  _consume(self, 4);
  reason = _parseUntil(self, '\n');
  [result_ addObject:reason forKey:@"bye"];
  return YES;
}

- (id)_decodeQP:(id)_string headerField:(NSString *)_field {
  if (![_string isNotNull])
    return _string;
  
  if ([_string isKindOfClass:DataClass])
    return [_string decodeQuotedPrintableValueOfMIMEHeaderField:_field];
  
  if ([_string isKindOfClass:StrClass]) {
    if ([_string length] <= 6 /* minimum size */)
      return _string;
    
    if ([_string rangeOfString:@"=?"].length > 0) {
      NSData *data;
      
      if (debugOn)
	[self debugWithFormat:@"WARNING: string with quoted printable info!"];
      
      // TODO: this is really expensive ...
      data = [_string dataUsingEncoding:NSUTF8StringEncoding];
      if (data != nil) {
	NSData *qpData;
	
	qpData = [data decodeQuotedPrintableValueOfMIMEHeaderField:_field];
	if (qpData != data) return qpData;
      }
    }
    return _string;
  }
  
  return _string;
}

- (NGImap4EnvelopeAddress *)_parseEnvelopeAddressStructure {
  /* 
     Note: returns retained object!
     
     Order:
       personal name
       SMTP@at-domain-list(source route)
       mailbox name
       hostname
     eg: 
       ("Helge Hess" NIL "helge.hess" "opengroupware.org")
  */
  NGImap4EnvelopeAddress *address;
  NSString *pname, *route, *mailbox, *host;
  
  if (_la(self, 0) != '(') {
    if (_matchesString(self, "NIL")) {
      _consume(self, 3);
      return (id)[null retain];
    }
    return nil;
  }
  _consume(self, 1); // '('

  /* parse personal name, can be with quoted printable encoding! */
  
  pname = [self _parseQuotedStringOrNIL];
  if ([pname isNotNull]) // TODO: headerField 'subject'?? explain!
    pname = [self _decodeQP:pname headerField:@"subject"];
  [self _consumeOptionalSpace];
  
  // TODO: I think those forbid QP encoding?
  route   = [self _parseQuotedStringOrNIL]; [self _consumeOptionalSpace];
  mailbox = [self _parseQuotedStringOrNIL]; [self _consumeOptionalSpace];
  host    = [self _parseQuotedStringOrNIL]; [self _consumeOptionalSpace];

  if (_la(self, 0) != ')') {
    [self logWithFormat:@"WARNING: IMAP4 envelope "
	    @"address not properly closed (c0=%c,c1=%c): %@",
	    _la(self, 0), _la(self, 1), self->serverResponseDebug];
  }
  else
    _consume(self, 1);
  
  address = [[NGImap4EnvelopeAddress alloc] initWithPersonalName:pname
					    sourceRoute:route mailbox:mailbox
					    host:host];

  return address;
}

- (NSArray *)_parseEnvelopeAddressStructures {
  /*
    Parses an array of envelopes, most common:
      ((NIL NIL "users-admin" "opengroupware.org"))
    (just one envelope in the array)
  */
  NSMutableArray *ma;
  
  if (_la(self, 0) != '(') {
    if (_matchesString(self, "NIL")) {
      _consume(self, 3);
      return (id)[null retain];
    }
    return nil;
  }
  _consume(self, 1); // '('
  
  ma = nil;
  while (_la(self, 0) != ')') {
    NGImap4EnvelopeAddress *address;
    
    if ((address = [self _parseEnvelopeAddressStructure]) == nil) {
      _consume(self, 1);
      continue; // TODO: should we stop parsing?
    }
    if (![address isNotNull])
      continue;
    
    if (ma == nil) ma = [NSMutableArray arrayWithCapacity:4];
    [ma addObject:address];
    [address release]; /* the parse returns a retained object! */
  }
  
  if (_la(self, 0) != ')') {
    [self logWithFormat:
	    @"WARNING: IMAP4 envelope address not properly closed!"];
  }
  else
    _consume(self, 1);
  return ma;
}

- (id)_parseEnvelope {
  /*
    http://www.hunnysoft.com/rfc/rfc3501.html
	  
    envelope = "(" env-date SP env-subject SP env-from SP env-sender SP
	           env-reply-to SP env-to SP env-cc SP env-bcc SP
		   env-in-reply-to SP env-message-id ")" 
		   
    * 1189 FETCH (UID 1189 ENVELOPE 
       ("Tue, 22 Jun 2004 08:42:01 -0500" "" 
        (("Jeff Glaspie" NIL "jeff" "glaspie.org")) 
        (("Jeff Glaspie" NIL "jeff" "glaspie.org")) 
        (("Jeff Glaspie" NIL "jeff" "glaspie.org")) 
        ((NIL NIL "helge.hess" "opengroupware.org")) 
        NIL NIL NIL 
        "<20040622134354.F11133CEB14@mail.opengroupware.org>"
       )
      )
  */
  static NGMimeRFC822DateHeaderFieldParser *dateParser = nil;
  NGImap4Envelope *env;
  NSString        *dateStr;
  id tmp;
  
  if (dateParser == nil)
    dateParser = [[NGMimeRFC822DateHeaderFieldParser alloc] init];
  
  if (_la(self, 0) != '(')
    return nil;
  _consume(self, 1);
  
  env = [[[NGImap4Envelope alloc] init] autorelease];
  
  /* parse date */
  
  dateStr = [self _parseQuotedStringOrNIL]; 
  [self _consumeOptionalSpace];
  if ([dateStr isNotNull])
    env->date = [[dateParser parseValue:dateStr ofHeaderField:nil] retain];
  
  /* parse subject */
  
  if ((tmp = [self _parseQuotedStringOrDataOrNIL]) != nil) {
    // TODO: that one is an issue, the client does know the requested charset
    //       but doesn't pass it down to the parser? Requiring the client to
    //       deal with NSData's is a bit overkill?
    env->subject = [tmp isNotNull] 
      ? [[self _decodeQP:tmp headerField:@"subject"] copy]
      : nil;
    [self _consumeOptionalSpace];
  }
  else {
    [self logWithFormat:@"ERROR(%s): failed on subject(%c): %@",
	  __PRETTY_FUNCTION__, _la(self, 0), self->serverResponseDebug];
    return nil;
  }
  
  /* parse addresses */
  
  if ((tmp = [self _parseEnvelopeAddressStructures]) != nil) {
    env->from = [tmp isNotNull] ? [tmp copy] : nil;
    [self _consumeOptionalSpace];
  }
  else {
    [self logWithFormat:@"ERROR(%s): failed on from.", __PRETTY_FUNCTION__];
    return nil;
  }
  if ((tmp = [self _parseEnvelopeAddressStructures]) != nil) {
    env->sender = [tmp isNotNull] ? [[tmp lastObject] copy] : nil;
    [self _consumeOptionalSpace];
  }
  else {
    [self logWithFormat:@"ERROR(%s): failed on sender.", __PRETTY_FUNCTION__];
    return nil;
  }
  if ((tmp = [self _parseEnvelopeAddressStructures]) != nil) {
    env->replyTo = [tmp isNotNull] ? [tmp copy] : nil;
    [self _consumeOptionalSpace];
  }
  
  if ((tmp = [self _parseEnvelopeAddressStructures]) != nil) {
    env->to = [tmp isNotNull] ? [tmp copy] : nil;
    [self _consumeOptionalSpace];
  }
  if ((tmp = [self _parseEnvelopeAddressStructures]) != nil) {
    env->cc = [tmp isNotNull] ? [tmp copy] : nil;
    [self _consumeOptionalSpace];
  }
  if ((tmp = [self _parseEnvelopeAddressStructures]) != nil) {
    env->bcc = [tmp isNotNull] ? [tmp copy] : nil;
    [self _consumeOptionalSpace];
  }

  if ((tmp = [self _parseQuotedStringOrNIL])) {
    env->inReplyTo = [tmp isNotNull] ? [tmp copy] : nil;
    [self _consumeOptionalSpace];
  }
  if ((tmp = [self _parseQuotedStringOrNIL])) {
    env->msgId = [tmp isNotNull] ? [tmp copy] : nil;
    [self _consumeOptionalSpace];
  }
  
  if (_la(self, 0) != ')') {
    [self logWithFormat:@"WARNING: IMAP4 envelope not properly closed"
	    @" (c0=%c,c1=%c): %@",
	    _la(self, 0), _la(self, 1), self->serverResponseDebug];
  }
  else
    _consume(self, 1);
  
  return env;
}

- (BOOL)_parseNumberUntaggedResponse:(NGMutableHashMap *)result_ {
  NSMutableDictionary *fetch;
  NSNumber *number;
  NSString *key    = nil;

  if ((number = _parseUnsigned(self)) == nil)
    return NO;
  
  _consumeIfMatch(self, ' ');

  if (!_matchesString(self, "FETCH ")) {
    /* got a number request from select like  exists or recent */
    key = _parseUntil(self, '\n');
    [result_ addObject:number forKey:[key lowercaseString]];
    return YES;
  }
  
  /* eg: "FETCH (FLAGS (\Seen) UID 5 RFC822.HEADER {2903}" */
  fetch = [[NSMutableDictionary alloc] initWithCapacity:10];
    
  _consume(self, 6); /* "FETCH " */
  _consumeIfMatch(self, '(');
  while (_la(self, 0) != ')') { /* until closing parent */
    NSString *key;
      
    key = [_parseUntil(self, ' ') lowercaseString];
#if 0
    [self logWithFormat:@"PARSE KEY: %@", key];
#endif
    if ([key hasPrefix:@"body[header.fields"]) {
      NSData *content;
        
      if ((content = [self _parseBodyHeaderFields]) != nil)
	[fetch setObject:content forKey:key];
      else
	[self logWithFormat:@"ERROR: got no body content for key: '%@'",key];
    } 
    else if ([key hasPrefix:@"body["]) {
      NSDictionary *content;
        
      if ((content = [self _parseBodyContent]) != nil)
	[fetch setObject:content forKey:key];
      else
	[self logWithFormat:@"ERROR: got no body content for key: '%@'",key];
    }
    else if ([key isEqualToString:@"body"]) {
      [fetch setObject:_parseBody(self, NO) forKey:key];
    }
    else if ([key isEqualToString:@"bodystructure"]) {
      [fetch setObject:_parseBody(self, YES) forKey:key];
    }
    else if ([key isEqualToString:@"flags"]) {
      [fetch setObject:_parseFlagArray(self) forKey:key];
    }
    else if ([key isEqualToString:@"uid"]) {
      [fetch setObject:_parseUnsigned(self) forKey:key];
    }
    else if ([key isEqualToString:@"modseq"]) {
      _consumeIfMatch(self, '(');
      [fetch setObject:_parseUnsigned(self) forKey:key];
      _consumeIfMatch(self, ')');
    }
    else if ([key isEqualToString:@"rfc822.size"]) {
      [fetch setObject:_parseUnsigned(self) forKey:key];
    }
    else if ([key hasPrefix:@"rfc822"]) {
      NSData *data;
      
      if (_la(self, 0) == '"') {
	NSString *str;
	_consume(self,1);

	str = _parseUntil(self, '"');
	data = [str dataUsingEncoding:defCStringEncoding];
      }
      else 
	data = [self _parseData];

      if (data != nil) [fetch setObject:data forKey:key];
    }
    else if ([key isEqualToString:@"envelope"]) {
      id envelope;

      if ((envelope = [self _parseEnvelope]) != nil)
	[fetch setObject:envelope forKey:key];
      else
	[self logWithFormat:@"ERROR: could not parse envelope!"];
    }
//     else if ([key isEqualToString:@"bodystructure"]) {
//       // TODO: implement!
//       NSException *e;
      
//       e = [[NGImap4ParserException alloc] 
// 	    initWithFormat:@"bodystructure fetch result not yet supported!"];
//       [self setLastException:[e autorelease]];
//       return NO;
//     }
    else if ([key isEqualToString:@"internaldate"]) {
      // TODO: implement!
      NSException *e;
      
      e = [[NGImap4ParserException alloc] 
	    initWithFormat:@"INTERNALDATE fetch result not yet supported!"];
      [self setLastException:[e autorelease]];
      return NO;
    }
    else {
      NSException *e;
	
      e = [[NGImap4ParserException alloc] initWithFormat:
					    @"unsupported fetch key: %@", 
					  key];
      [self setLastException:[e autorelease]];
      return NO;
    }
    
    if (_la(self, 0) == ' ')
      _consume(self, 1);
  }
  if (fetch != nil) {
    [fetch setObject:number  forKey:@"msn"];
    [result_ addObject:fetch forKey:@"fetch"];
    _consume(self, 1); /* consume ')' */
    _consumeIfMatch(self, '\n');
  }
  else { /* no correct fetch line */
    _parseUntil(self, '\n');
  }
    
  [fetch release]; fetch = nil;
  return YES;
  }

static BOOL _parseGreetingsSieveResponse(NGImap4ResponseParser *self,
                                         NGMutableHashMap *result_) 
{
  BOOL isOK;
  
  while (!(isOK = _parseOkSieveResponse(self, result_))) {
    NSString *key, *value;

    if (!(key = _parseStringSieveResponse(self))) {
      break;
    }
    if (_la(self, 0) == ' ') {
      _consume(self, 1);

      if (!(value = _parseStringSieveResponse(self))) {
        break;
      }
    }
    else {
      value = @"";
    }
    _parseUntil(self, '\n');
    [result_ addObject:value forKey:[key lowercaseString]];
  }

  return isOK;
}

static BOOL _parseDataSieveResponse(NGImap4ResponseParser *self,
				    NGMutableHashMap *result_) 
{
  NSString *str;
  NSData   *data;

  if ((data = [self _parseData]) == nil)
    return NO;
  
  str = [[StrClass alloc] initWithData:data encoding:NSUTF8StringEncoding];
  [result_ setObject:str forKey:@"data"];
  [str release]; str = nil;

  _parseUntil(self, '\n');

  return YES;
}

static BOOL _parseOkSieveResponse(NGImap4ResponseParser *self,
                                  NGMutableHashMap *result_) 
{
  if (!((_la(self, 0) == 'O') && (_la(self, 1) == 'K')))
    return NO;
    
  _consume(self, 2);

  if (_la(self, 0) == ' ') {
      NSString *reason;

      if ((reason = _parseContentSieveResponse(self)))
        [result_ addObject:reason forKey:@"reason"];
  }
  _parseUntil(self, '\n');

  [result_ addObject:YesNum forKey:@"ok"];
  return YES;
}

static BOOL _parseNoSieveResponse(NGImap4ResponseParser *self,
                                  NGMutableHashMap *result_) 
{
  NSString *data;
  
  if (!((_la(self, 0)=='N') && (_la(self, 1)=='O') && (_la(self, 2)==' ')))
    return NO;

  _consume(self, 3);

  data = _parseContentSieveResponse(self);

  [result_ addObject:NoNum forKey:@"ok"];
  if (data) [result_ addObject:data forKey:@"reason"];

  _parseUntil(self, '\n');

  return YES;
}

static NSString *_parseContentSieveResponse(NGImap4ResponseParser *self) {
  NSString *str;
  NSData *data;
  
  if ((str = _parseStringSieveResponse(self)))
    return str;
  
  if ((data = [self _parseData]) == nil)
    return nil;
  
  return [[[StrClass alloc] initWithData:data encoding:NSUTF8StringEncoding]
                          autorelease];
}

static NSString *_parseStringSieveResponse(NGImap4ResponseParser *self) {
  if (_la(self, 0) != '"')
    return nil;
  
  _consume(self, 1);
  return _parseUntil(self, '"');
}

static NSString *_parseBodyDecodeString(NGImap4ResponseParser *self,
                                        BOOL _convertString,
                                        BOOL _decode)
{
  NSString *str;
  
  if (_la(self, 0) == '"') {
    // TODO: can the " be escaped somehow?
    _consume(self, 1);
    str = _parseUntil(self, '"');
  }
  else if (_la(self, 0) == '{') {
    NSData *data;
    
    if (debugDataOn) [self logWithFormat:@"parse body decode string"];
    data = [self _parseData];

    if (_decode)
      data = [data decodeQuotedPrintableValueOfMIMEHeaderField:nil];
    
    if ([data isKindOfClass: [NSString class]])
      return (NSString *) data;
    else
      {
	NSString *s;
	
	// Let's try with the supplied encoding. If it doesn't work,
	// we'll then try UTF-8 or fallback to ISO-8859-1
	s = [[StrClass alloc] initWithData:data encoding:encoding];

	if (!s && encoding != NSUTF8StringEncoding)
	  s = [[StrClass alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	if (!s)
	  s = [[StrClass alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
	
	return [s autorelease];
      }
  }
  else {
    str = _parseUntil2(self, ' ', ')');
  }
  if (_convertString) {
    if ([[str lowercaseString] isEqualToString:@"nil"])
      str = @"";
  }
  if (_decode) {
    id  d;
    
    d = [str dataUsingEncoding:defCStringEncoding];
    d = [d decodeQuotedPrintableValueOfMIMEHeaderField:nil];
    
    if ([d isKindOfClass:StrClass])
      str = d;
    else {
      str = [[[StrClass alloc] initWithData:d encoding:encoding]
	                       autorelease];
    }
  }
  return str;
}

static NSString *_parseBodyString(NGImap4ResponseParser *self,
                                  BOOL _convertString)
{
  return _parseBodyDecodeString(self, _convertString, NO /* no decode */);
}

static NSArray *_parseLanguages(NGImap4ResponseParser *self) {
  NSMutableArray *languages;
  NSString *language;

  languages = [NSMutableArray array];
  if (_la(self, 0) == '(') {
    while (_la(self, 0) != ')') {
      _consume(self,1);
      language = _parseBodyString(self, YES);
      if ([language length])
	[languages addObject: language];
    }
    _consume(self,1);
  }
  else {
    language = _parseBodyString(self, YES);
    if ([language length])
      [languages addObject: language];
  }

  return languages;
}

static NSDictionary *_parseBodyParameterList(NGImap4ResponseParser *self)
{
  NSMutableDictionary *list;

  if (_la(self, 0) == '(') {
    _consume(self, 1);

    list = [NSMutableDictionary dictionaryWithCapacity:4];
  
    while (_la(self,0) != ')') {
      NSString *key, *value;

      if (_la(self, 0) == ' ')
        _consume(self, 1);
      
      key = _parseBodyString(self, YES);
      _consumeIfMatch(self, ' ');
      value = _parseBodyDecodeString(self, YES, YES);

      if (value) [list setObject:value forKey:[key lowercaseString]];
    }
    _consumeIfMatch(self, ')');
  }
  else {
    NSString *str;
    str = _parseBodyString(self, YES);

    if ([str isNotEmpty])
      NSLog(@"%s: got unexpected string %@", __PRETTY_FUNCTION__, str);
    
    list = (id)[NSDictionary dictionary];
  }
  return list;
}

static NSDictionary *_parseContentDisposition(NGImap4ResponseParser *self)
{
  NSMutableDictionary *disposition;
  NSString *type;

  disposition = [NSMutableDictionary dictionary];

  if (_la(self, 0) == '(') {
    _consume(self, 1);
    type = _parseBodyString(self, YES);
    [disposition setObject: type forKey: @"type"];
    if (_la(self, 0) != ')') {
      _consume(self, 1);
      [disposition setObject: _parseBodyParameterList(self)
		   forKey: @"parameterList"];
    }
    _consume(self, 1);
  }
  else
    _parseBodyString(self, YES);

  return disposition;
}

static NSArray *_parseAddressStructure(NGImap4ResponseParser *self) {
  NSString *personalName, *sourceRoute, *mailboxName, *hostName;
  
  _consumeIfMatch(self, '(');
  personalName = _parseBodyString(self, YES);
  _consumeIfMatch(self, ' ');
  sourceRoute = _parseBodyString(self, YES);
  _consumeIfMatch(self, ' ');
  mailboxName = _parseBodyString(self, YES);
  _consumeIfMatch(self, ' ');
  hostName = _parseBodyString(self, YES);
  _consumeIfMatch(self, ')');
  return [NSDictionary dictionaryWithObjectsAndKeys:
                       personalName, @"personalName",
                       sourceRoute,  @"sourceRoute",
                       mailboxName,  @"mailboxName",
                       hostName,     @"hostName", nil];
}

static NSArray *_parseParenthesizedAddressList(NGImap4ResponseParser *self) {
  NSMutableArray *result;
  result = [NSMutableArray arrayWithCapacity:8];

  if (_la(self, 0) == '(') {
    _consume(self, 1);
    while (_la(self, 0) != ')') {
      [result addObject:_parseAddressStructure(self)];
    }
    _consume(self, 1);
  }
  else {
    NSString *str;
    str = _parseBodyString(self, YES);

    if ([str isNotEmpty])
      NSLog(@"%s: got unexpected string %@", __PRETTY_FUNCTION__, str);
    
    result = (id)[NSArray array];
  }
  return result;
}

static NSDictionary *_parseSingleBody(NGImap4ResponseParser *self,
				      BOOL isBodyStructure) {
  NSString            *type, *subtype, *bodyId, *description,
		      *result, *encoding, *bodysize;
  NSDictionary        *parameterList;
  NSMutableDictionary *dict;
  NSArray	      *languages;

  type = [_parseBodyString(self, YES) lowercaseString];
  _consumeIfMatch(self, ' ');
  subtype = [_parseBodyString(self, YES) lowercaseString];
  _consumeIfMatch(self, ' ');
  parameterList = _parseBodyParameterList(self);
  _consumeIfMatch(self, ' ');
  bodyId = _parseBodyString(self, YES);
  _consumeIfMatch(self, ' ');
  description = _parseBodyString(self, YES);
  _consumeIfMatch(self, ' ');
  encoding = _parseBodyString(self, YES);
  _consumeIfMatch(self, ' ');
  bodysize = _parseBodyString(self, YES);

  dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              type, @"type",
                              subtype, @"subtype",
                              parameterList, @"parameterList",
                              bodyId,        @"bodyId",
                              description,   @"description",
                              encoding,      @"encoding",
                              bodysize,      @"size", nil];
  
  if ([type isEqualToString:@"text"]) {
    _consumeIfMatch(self, ' ');
    [dict setObject:_parseBodyString(self, YES) forKey:@"lines"];
  }
  else if ([type isEqualToString:@"message"]
	   && [subtype isEqualToString:@"rfc822"]) {
    if (_la(self, 0) != ')') {
      _consumeIfMatch(self, ' ');
      _consumeIfMatch(self, '(');
      result = _parseBodyString(self, YES);
      if (result == nil) result = @"";
      [dict setObject:result forKey:@"date"];
      _consumeIfMatch(self, ' ');
      result = _parseBodyString(self, YES);
      if (result == nil) result = @"";
      [dict setObject:result forKey:@"subject"];
      _consumeIfMatch(self, ' ');
      [dict setObject:_parseParenthesizedAddressList(self) forKey:@"from"];
      if (_la(self, 0) == ' ')
        _consume(self, 1);
      [dict setObject:_parseParenthesizedAddressList(self) forKey:@"sender"];
      if (_la(self, 0) == ' ')
        _consume(self, 1);
      [dict setObject:_parseParenthesizedAddressList(self)
            forKey:@"reply-to"];
      if (_la(self, 0) == ' ')
        _consume(self, 1);
      [dict setObject:_parseParenthesizedAddressList(self) forKey:@"to"];
      if (_la(self, 0) == ' ')
        _consume(self, 1);
      [dict setObject:_parseParenthesizedAddressList(self) forKey:@"cc"];
      if (_la(self, 0) == ' ')
        _consume(self, 1);
      [dict setObject:_parseParenthesizedAddressList(self) forKey:@"bcc"];
      if (_la(self, 0) == ' ')
        _consume(self, 1);
      result = _parseBodyString(self, YES);
      if (result == nil) result = @"";
      [dict setObject:result forKey:@"in-reply-to"];
      if (_la(self, 0) == ' ')
        _consume(self, 1);
      result = _parseBodyString(self, YES);
      if (result == nil) result = @"";
      [dict setObject:result forKey:@"messageId"];
      _consumeIfMatch(self, ')');
      if (_la(self, 0) == ' ')
        _consume(self, 1);
      [dict setObject:_parseBody(self, isBodyStructure) forKey:@"body"];
      if (_la(self, 0) == ' ')
        _consume(self, 1);
      result = _parseBodyString(self, YES);
      if (result == nil) result = @"";
      [dict setObject:result forKey:@"bodyLines"];
    }
  }

  if (isBodyStructure) {
    if (_la(self, 0) != ')') {
      _consume(self,1);
      [dict setObject: _parseBodyString(self, YES)
	    forKey: @"md5"];
      if (_la(self, 0) != ')') {
	_consume(self,1);
	[dict setObject: _parseContentDisposition(self)
	      forKey: @"disposition"];
	if (_la(self, 0) != ')') {
	  _consume(self,1);
	  languages = _parseLanguages(self);
	  if ([languages count])
	    [dict setObject: languages forKey: @"languages"];
	  if (_la(self, 0) != ')') {
	    _consume(self,1);
	    [dict setObject: _parseBodyString(self, YES)
		  forKey: @"location"];
	  };
	};
      };
    };
  }

  return dict;
}

static NSDictionary *_parseMultipartBody(NGImap4ResponseParser *self,
					 BOOL isBodyStructure) {
  NSMutableArray *parts;
  NSArray	 *languages;
  NSString       *kind;
  NSMutableDictionary *dict;

  parts = [NSMutableArray arrayWithCapacity:4];

  while (_la(self, 0) == '(') {
    [parts addObject:_parseBody(self, isBodyStructure)];
  }
  _consumeIfMatch(self, ' ');
  kind = _parseBodyString(self, YES);
  dict = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				parts,        @"parts",
			      @"multipart", @"type",
			      kind        , @"subtype", nil];
  if (isBodyStructure) {
    if (_la(self, 0) != ')') {
      _consume(self,1);
      [dict setObject: _parseBodyParameterList(self)
	    forKey: @"parameterList"];
      if (_la(self, 0) != ')') {
	_consume(self,1);
	[dict setObject: _parseContentDisposition(self)
	      forKey: @"disposition"];
	if (_la(self, 0) != ')') {
	  _consume(self,1);
	  languages = _parseLanguages(self);
	  if ([languages count])
	    [dict setObject: languages forKey: @"languages"];
	  if (_la(self, 0) != ')') {
	    _consume(self,1);
	    [dict setObject: _parseBodyString(self, YES)
		  forKey: @"location"];
	  };
	};
      };
    };
  }

  return dict;
}

static NSDictionary *_parseBody(NGImap4ResponseParser *self, BOOL isBodyStructure) {
  NSDictionary *result;

  _consumeIfMatch(self, '(');

  if (_la(self, 0) == '(') {
    result = _parseMultipartBody(self, isBodyStructure);
  }
  else {
    result = _parseSingleBody(self, isBodyStructure);
  }
  if (_la(self,0) != ')') {
    NSString *str;

    str = _parseUntil(self, ')');
    NSLog(@"%s: got noparsed content %@", __PRETTY_FUNCTION__,
          str);
  }
  else 
    _consume(self, 1);

  return result;
}

- (NSDictionary *)_parseBodyContent {
  NSData *data;
  
  if (_la(self, 0) == '"') {
    NSString *str;
    _consume(self,1);
    
    str = _parseUntil(self, '"');
    data = [str dataUsingEncoding:defCStringEncoding];
  }
  else 
    data = [self _parseData];
  
  if (data == nil) {
    [self logWithFormat:@"ERROR(%s): got no data.", __PRETTY_FUNCTION__];
    return nil;
  }
  return [NSDictionary dictionaryWithObject:data forKey:@"data"];
}


static NSArray *_parseFlagArray(NGImap4ResponseParser *self) {
  NSString *flags;
  
  _consumeIfMatch(self, '(');
  
  flags = _parseUntil(self, ')');
  if (![flags isNotEmpty]) {
    static NSArray *emptyArray = nil;
    if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
    return emptyArray;
  }
  else
    return [[flags lowercaseString] componentsSeparatedByString:@" "];
}

static BOOL _parseFlagsUntaggedResponse(NGImap4ResponseParser *self,
                                        NGMutableHashMap *result_) {
  if ((_la(self, 0) == 'F')
      && (_la(self, 1) == 'L')
      && (_la(self, 2) == 'A')
      && (_la(self, 3) == 'G')
      && (_la(self, 4) == 'S')      
      && (_la(self, 5) == ' ')) {
    _consume(self, 6);
    [result_ addObject:_parseFlagArray(self) forKey:@"flags"];
    _consumeIfMatch(self, '\n');
    return YES;
  }
  return NO;
}

static BOOL _parseBadUntaggedResponse(NGImap4ResponseParser *self,
                                     NGMutableHashMap *result_) 
{
  if (!((_la(self, 0)=='B') && (_la(self, 1)=='A') && (_la(self, 2)=='D')      
	&& (_la(self, 3) == ' ')))
    return NO;

  _consume(self, 4);
  [result_ addObject:_parseUntil(self, '\n') forKey:@"bad"];
  return YES;
}

static BOOL _parseNoOrOkArguments(NGImap4ResponseParser *self,
                                  NGMutableHashMap *result_, NSString *_key) 
{
  NSString *obj;

  obj = nil;
  
  if (_la(self, 0) == '[') {
    NSString *key;
      
    _consume(self, 1);
    key = _parseUntil2(self, ']', ' ');

    /* possible kinds of untagged OK responses are either
     * OK [ALERT] System shutdown in 10 minutes
     or               
     * OK [UNSEEN 14]
     or
     * OK [PERMANENTFLAGS (\Answered \Flagged \Draft \Deleted \Seen \*)]
     */
    if (_la(self, 0) == ']') {

      _consume(self, 1);
      if (_la(self, 0) == ' ') {
        id value;
        
        _consume(self, 1);
        value = _parseUntil(self, '\n');
        if ([value isNotEmpty]) {
          obj = [[NSDictionary alloc] 
		  initWithObjects:&value forKeys:&key count:1];
	}
        else
          obj = [key retain];
      }
      else {
        obj = [key retain];
        _parseUntil(self, '\n');
      }
    }
    else { /* _la(self, 0) should be ' ' */
      id value;

      value = nil;
      
      _consume(self, 1);
      if (_la(self, 0) == '(') {
        value = _parseFlagArray(self);
        _consume(self, 1); /* consume ']' */
      }
      else {
        value = _parseUntil(self, ']');
      }
      {
        id tmp;

        tmp = _parseUntil(self, '\n');
        
        obj = [[NSDictionary alloc] initWithObjectsAndKeys:
                            value, key,
                            tmp,   @"comment", nil];
      }
    }
  }
  else
    obj = [_parseUntil(self, '\n') retain];

  [result_ addObject:obj forKey:_key];
  [obj release];
  return YES;
}


static BOOL _parseNoUntaggedResponse(NGImap4ResponseParser *self,
                                     NGMutableHashMap *result_) 
{
  if (!((_la(self, 0)=='N') && (_la(self, 1)=='O') && (_la(self, 2)==' ')))
    return NO;

  _consume(self, 3);
  return _parseNoOrOkArguments(self, result_, @"no");
}

static BOOL _parseOkUntaggedResponse(NGImap4ResponseParser *self,
                                     NGMutableHashMap *result_) 
{
  if (!((_la(self, 0)=='O') && (_la(self, 1)=='K') && (_la(self, 2)==' ')))
    return NO;
  
  _consume(self, 3);
  return _parseNoOrOkArguments(self, result_, @"ok");
}

static NSNumber *_parseUnsigned(NGImap4ResponseParser *self) {
  unsigned      n;
  unsigned char c;
  BOOL     isNumber;

  isNumber = NO;  
  n        = 0;  
  c        = _la(self, 0);
  
  while ((c >= '0') && (c <= '9')) {
    _consume(self, 1);
    isNumber = YES;
    n        = 10 * n + (c - 48);
    c        = _la(self, 0);
  }
  if (!isNumber)
    return nil;
  
  return [NumClass numberWithUnsignedInt:n];
}

static NSString *_parseUntil(NGImap4ResponseParser *self, char _c) {
  /*
    Note: this function consumes the stop char (_c)!
    normalize \r\n constructions
  */
  // TODO: optimize!
  char            buf[1024], c;
  NSMutableString *str;
  unsigned        cnt;

  cnt = 0;
  str = nil;  
  while ((c = _la(self, 0)) != _c) {
    if (c == '\\') {
      _consume(self, 1);
      c = _la(self, 0);
    }
    buf[cnt] = c;
    _consume(self, 1);
    cnt++;
    if (cnt == 1024) {
      if (str == nil) {
        str = (NSMutableString *)
          [NSMutableString stringWithCString:buf length:1024];
      }
      else {
        NSString *s;
        
        s = [(NSString *)[StrClass alloc] initWithCString:buf length:1024];
        [str appendString:s];
        [s release];
      }
      cnt = 0;
    }
  }
  _consume(self,1); /* consume known stop char */
  if (_c == '\n' && cnt > 0) {
    if (buf[cnt-1] == '\r')
      cnt--;
  }
  
  if (str == nil)
    return [StrClass stringWithCString:buf length:cnt];
  else {
    NSString *s, *s2;
    
    s = [(NSString *)[StrClass alloc] initWithCString:buf length:cnt];
    s2 = [str stringByAppendingString:s];
    [s release];
    return s2;
  }
}

static NSString *_parseUntil2(NGImap4ResponseParser *self, char _c1, char _c2){
  /* _parseUntil2(self, char, char) doesn`t consume the stop-chars */
  char            buf[1024], c;
  NSMutableString *str;
  unsigned        cnt;

  cnt = 0;
  c   = _la(self, 0);
  str = nil;
  
  while ((c != _c1) && (c != _c2)) {
    buf[cnt] = c;
    _consume(self, 1);
    cnt++;
    if (cnt == 1024) {
      if (str == nil)
        str = (NSMutableString *)
                 [NSMutableString stringWithCString:buf length:1024];
      else {
        NSString *s;
	
        s = [(NSString *)[StrClass alloc] initWithCString:buf length:1024];
        [str appendString:s];
        [s release];
      }
      
      cnt = 0;
    }
    c = _la(self, 0);    
  }

  if (str == nil)
    return [StrClass stringWithCString:buf length:cnt];
  
  {
    NSString *s, *s2;
    
    s = [(NSString *)[StrClass alloc] initWithCString:buf length:cnt];
    s2 = [str stringByAppendingString:s];
    [s release];
    return s2;
  }
}

static BOOL _endsWithCQuote(NSString *_string){
  unsigned int quoteSlashes;
  int pos;

  quoteSlashes = 0;
  pos = [_string length] - 1;
  while (pos > -1
	 && [_string characterAtIndex: pos] == '\\') {
    quoteSlashes++;
    pos--;
  }

  return ((quoteSlashes % 2) == 1);
}

- (NSException *)exceptionForFailedMatch:(unsigned char)_match
  got:(unsigned char)_avail
{
  NSException *e;
  
  e = [NGImap4ParserException alloc];
  if (self->debug) {
    e = [e initWithFormat:@"unexpected char <%c> expected <%c> <%@>",
	   _avail, _match, self->serverResponseDebug];
  }
  else {
    e = [e initWithFormat:@"unexpected char <%c> expected <%c>",
	     _avail, _match];
  }
  return [e autorelease];
}

static __inline__ NSException *_consumeIfMatch(NGImap4ResponseParser *self, 
					       unsigned char _match) 
{
  NSException *e;
  
  if (_la(self,0) == _match) {
    _consume(self, 1);
    return nil;
  }
  
  e = [self exceptionForFailedMatch:_match got:_la(self, 0)];
  [self setLastException:e];
  return e;
}

static __inline__ void _consume(NGImap4ResponseParser *self, unsigned _cnt) {
  /* Normalize end of line */

  if (_cnt == 0)
    return;
  
  _cnt +=  (__la(self, _cnt - 1) == '\r') ? 1 : 0;
  
  if (self->debug) {
    unsigned cnt;
    
    for (cnt = 0; cnt < _cnt; cnt++) {
      NSString *s;
      unichar c = _la(self, cnt);
      
      if (c == '\r')
	continue;
        
      s = [[StrClass alloc] initWithCharacters:&c length:1];
      [self->serverResponseDebug appendString:s];
      [s release];
      
      if (c == '\n') {
	if ([self->serverResponseDebug lengthOfBytesUsingEncoding:NSISOLatin1StringEncoding] > 2) {
            fprintf(stderr, "S[%p]: %s", self,
                    [self->serverResponseDebug cStringUsingEncoding:NSISOLatin1StringEncoding]);
          }
          [self->serverResponseDebug release];
          self->serverResponseDebug = 
            [[NSMutableString alloc] initWithCapacity:512];
      }
    }
  }
  [self->buffer consume:_cnt];
}

@end /* NGImap4ResponseParser */
