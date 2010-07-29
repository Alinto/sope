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

#include "NGMimeBodyGenerator.h"
#include "NGMimePartGenerator.h"
#include "NGMimeMultipartBody.h"
#include "NGMimeJoinedData.h"
#include "NGMimeFileData.h"
#include "common.h"
#include <string.h>
#include <unistd.h>

@implementation NGMimeMultipartBodyGenerator

static Class NGMimeFileDataClass   = Nil;
static Class NGMimeJoinedDataClass = Nil;
static BOOL  debugOn = NO;

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  NGMimeFileDataClass   = [NGMimeFileData class];
  NGMimeJoinedDataClass = [NGMimeJoinedData class];
  
  debugOn = [ud boolForKey:@"NGMimeGeneratorDebugEnabled"];
  if (debugOn)
    NSLog(@"WARNING[%@]: NGMimeGeneratorDebugEnabled is enabled!", self);
}

+ (NSString *)boundaryPrefix {
  static NSString *BoundaryPrefix = nil;
  
  if (BoundaryPrefix == nil) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    BoundaryPrefix = 
      [[ud stringForKey:@"NGMime_MultipartBoundaryPrefix"] copy];
    if (BoundaryPrefix == nil)
      BoundaryPrefix = @"--=_=-_OpenGroupware_org_NGMime";
  }
  return BoundaryPrefix;
}

static inline BOOL _isBoundaryInArray(NGMimeMultipartBodyGenerator *self,
                                      NSString *_boundary,
                                      NSArray *_data)
{
  const unsigned char *boundary;
  unsigned int length;
  NSEnumerator *enumerator;
  NSData       *data;
  BOOL         wasFound;
  
  // TODO: do we need to treat the boundary as a CString?
  boundary   = (const unsigned char *)[_boundary cString];
  length     = [_boundary length];
  enumerator = [_data objectEnumerator];
  data       = nil;
  wasFound   = NO;
  
  while ((data = [enumerator nextObject]) != nil) {
    const unsigned char *bytes;
    unsigned int dataLen;
    unsigned     cnt;
    
    if ([data isKindOfClass:NGMimeFileDataClass] ||
        [data isKindOfClass:NGMimeJoinedDataClass])
      continue;
    
    bytes   = [data bytes];
    dataLen = [data length];
    cnt     = 0;
    
    if (dataLen < length)
      return NO;
      
    while ((cnt < dataLen) && ((dataLen - cnt) >= length)) {
      if (bytes[cnt + 2] != '-') { // can`t be a boundary
	cnt++;
	continue;
      }

      if (bytes[cnt] == '\n') {// LF*-
	if (bytes[cnt + 1] == '-') { // LF--
	  if (strncmp((char *)boundary, (char *)(bytes+cnt+3), length) == 0) {
	    wasFound = YES;
	    break;
	  }
	}
      }
      else if (bytes[cnt] == '\r') { //CR*-
	if (bytes[cnt + 1] == '-') { //CR--
	  if (strncmp((char *)boundary, (char *)(bytes+cnt+3), length) == 0) {
	    wasFound = YES;
	    break;
	  }
	}
	else if ((bytes[cnt + 1] == '\n') && (bytes[cnt + 3] == '-')) {
	  if (strncmp((char*)boundary, (char *)(bytes+cnt+4), length)==0) { // CRLF--
	    wasFound = YES;
	    break;
	  }
	}
      }
      cnt++;
    }
  }
  return wasFound;
}

- (NSString *)buildBoundaryForPart:(id<NGMimePart>)_part data:(NSArray *)_data
  additionalHeaders:(NGMutableHashMap *)_addHeaders 
{
  static   int       BoundaryUniqueCount = 0;
  NSString *boundary = nil;
  BOOL     isUnique  = NO;
  unsigned pid;
  
  if ((boundary = [[_part contentType] valueOfParameter:@"boundary"]))
    return boundary;
  
#if defined(__WIN32__)
  pid = GetCurrentProcessId();
#else
  pid = getpid();
#endif
  
  boundary = [NSString stringWithFormat:
                       @"--%@-%d-%f-%d------",
                       [NGMimeMultipartBodyGenerator boundaryPrefix],
                       pid, [[NSDate date] timeIntervalSince1970],
                       BoundaryUniqueCount++];
  while (!isUnique) {
    isUnique = _isBoundaryInArray(self, boundary, _data) ? NO : YES;
    if (!isUnique) {
      boundary = [NSString stringWithFormat:
                           @"--%@-%d-%f-%d-----",
                           [NGMimeMultipartBodyGenerator boundaryPrefix],
                           pid, [[NSDate date] timeIntervalSince1970],
                           BoundaryUniqueCount++];
    }
  }
  { // setting content-type with boundary
    NGMimeType *type = nil;

    type = [_part contentType];
    
    if (type == nil) {
      NSDictionary *d;

      d = [[NSDictionary alloc] initWithObjectsAndKeys:
				  boundary, @"boundary", nil];
      type = [NGMimeType mimeType:@"multipart" subType:@"mixed"
                         parameters:d];
      [d release];
    }
    else {
      NSMutableDictionary *dict = nil;
      
      dict = [NSMutableDictionary dictionaryWithDictionary:
                                    [type parametersAsDictionary]];
      [dict setObject:boundary forKey:@"boundary"];
      type = [NGMimeType mimeType:[type type] subType:[type subType]
                         parameters:dict];
    }
    [_addHeaders setObject:type forKey:@"content-type"];
  }
  return boundary;
}

- (NSData *)buildDataWithBoundary:(NSString *)_boundary
  partsData:(NSArray *)_parts
{
  NSEnumerator  *enumerator;
  NSData        *part;
  NSMutableData *data;

  data = (self->useMimeData)
    ? [[[NGMimeJoinedData alloc] init] autorelease]
    : [NSMutableData dataWithCapacity:4096];
  
  enumerator = [_parts objectEnumerator];
  while ((part = [enumerator nextObject])) {
    [data appendBytes:"--" length:2];
    [data appendBytes:[_boundary cString] length:[_boundary length]];
    [data appendBytes:"\r\n" length:2];
    [data appendData:part];
    [data appendBytes:"\r\n" length:2];
  }
  [data appendBytes:"--" length:2];
  [data appendBytes:[_boundary cString] length:[_boundary length]];
  [data appendBytes:"--\r\n" length:4];
  return data;
}

- (NSData *)generateBodyOfPart:(id<NGMimePart>)_part
  additionalHeaders:(NGMutableHashMap *)_addHeaders
  delegate:(id)_delegate
{
  // TODO: split up
  NGMimeMultipartBody *body       = nil;
  NSMutableData       *data       = nil;
  id                  tmp         = nil;
  NSArray             *parts      = nil;
  id<NGMimePart>      part        = nil;
  NSEnumerator        *enumerator = nil;
  NSString            *boundary   = nil;
  NSMutableArray      *partsData  = nil;
  NSAutoreleasePool   *pool;

  body = [_part body];

  if (body == nil)
    return [NSData data];

  pool = [[NSAutoreleasePool alloc] init];
  
  NSAssert1([body isKindOfClass:[NGMimeMultipartBody class]],
            @"NGMimeMultipartBodyGenerator expect a NGMimeMultipartBody "
            @"as body of part\n part: %@\n", _part);

  data = (self->useMimeData)
    ? [[[NGMimeJoinedData alloc] init] autorelease]
    : [NSMutableData dataWithCapacity:4096];

  if ([_delegate respondsToSelector:
                   @selector(multipartBodyGenerator:prefixForPart:)])
    tmp = [_delegate multipartBodyGenerator:self prefixForPart:_part];
  else 
    tmp = [self multipartBodyGenerator:self prefixForPart:_part
                mimeMultipart:body];
  if (tmp != nil) {
    NSAssert([tmp isKindOfClass:[NSString class]],
             @"prefix should be a NSString");
    [data appendBytes:[tmp cString] length:[tmp length]];
  }
  
  parts      = [body parts];
  enumerator = [parts objectEnumerator];
  partsData  = [[NSMutableArray alloc] initWithCapacity:4];

  while ((part = [enumerator nextObject]) != nil) {
    id<NGMimePartGenerator> gen = nil;
    NSData *data;
    
    if ([_delegate respondsToSelector:
                   @selector(multipartBodyGenerator:generatorForPart:)]) {
      gen = [_delegate multipartBodyGenerator:self generatorForPart:part];
    }
    else {
      gen = [self multipartBodyGenerator:self generatorForPart:part];
      [gen setDelegate:_delegate];
      [(id)gen setUseMimeData:self->useMimeData];
    }
    if (gen == nil) {
      [self logWithFormat:@"WARNING(%s): got no generator", 
	    __PRETTY_FUNCTION__];
      continue;
    }
    
    /* generate part */
    
    data = [gen generateMimeFromPart:part];
    if (data != nil) {
      if (debugOn) {
	[self debugWithFormat:
		@"multipart body generated %d bytes using %@ for part: %@",
	        [data length], gen, part];
      }
      [partsData addObject:data];
    }
    else if (debugOn) {
      [self debugWithFormat:
	      @"multipart body %@ did not generate content for part: %@",
	      gen, part];
    }
  }
  boundary = [self buildBoundaryForPart:_part data:partsData
                   additionalHeaders:_addHeaders];
  tmp      = [self buildDataWithBoundary:boundary partsData:partsData];

  if (tmp != nil) {
    [data appendData:tmp];
  }
  else {
    NSLog(@"WARNING(%s): couldn`t build multipart data", __PRETTY_FUNCTION__);
  }
  if ([_delegate respondsToSelector:
                   @selector(multipartBodyGenerator:suffixForPart:)])
    tmp = [_delegate multipartBodyGenerator:self suffixForPart:_part];
  else 
    tmp = [self multipartBodyGenerator:self suffixForPart:_part
                mimeMultipart:body];
  if (tmp != nil) {
    NSAssert([tmp isKindOfClass:[NSString class]],
             @"suffix should be a NSString");
    [data appendBytes:[tmp cString] length:[tmp length]];
  }
  [partsData release]; partsData = nil;
  [data retain];
  [pool release];
  return [data autorelease];
}

- (NSString *)multipartBodyGenerator:(NGMimeMultipartBodyGenerator *)_gen
  prefixForPart:(id<NGMimePart>)_part
  mimeMultipart:(NGMimeMultipartBody *)_body 
{
  return @""; // [_body prefix];
}

- (NSString *)multipartBodyGenerator:(NGMimeMultipartBodyGenerator *)_gen
  suffixForPart:(id<NGMimePart>)_part
  mimeMultipart:(NGMimeMultipartBody *)_body
{
  return @""; //[_body suffix];
}

- (id<NGMimePartGenerator>)multipartBodyGenerator:(NGMimeBodyGenerator *)_gen
  generatorForPart:(id<NGMimePart>)_part
{
  id gen;
  
  gen = [[NGMimePartGenerator alloc] init];
  [gen setUseMimeData:self->useMimeData];
  return [gen autorelease];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* NGMimeMultipartBodyGenerator */
