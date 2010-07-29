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

#include "NGHttpBodyParser.h"
#include "NGUrlFormCoder.h"
#include "common.h"

@implementation NGFormUrlBodyParser

- (id)parseBodyOfPart:(id<NGMimePart>)_part data:(NSData *)_data
  delegate:(id)_d
{
  const char *bytes;
  unsigned   len;
  id         body;

  [self debugWithFormat:@"parse part %@ data: %@", _part, _data];
  
  len   = [_data length];
  bytes = [_data bytes];
  
  /* cut off spaces at the end */
  while (len > 0) {
    if ((bytes[len - 1] == '\r') || (bytes[len - 1] == '\n'))
      len--;
    else
      break;
  }
  if (len == 0) return nil;
  
  body = NGDecodeUrlFormParameters((unsigned char *)bytes, len);
  return [body autorelease];
}

- (BOOL)isDebuggingEnabled {
  return NO;
}

@end /* NGFormUrlBodyParser */


@implementation NGHttpMultipartFormDataBodyParser

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (BOOL)parseImmediatlyWithDelegate:(id)_delegate
  multipart:(id<NGMimePart>)_part data:(NSData *)_data 
{
  return YES;
}

- (id)parseBodyOfPart:(id<NGMimePart>)_part data:(NSData *)_data
  delegate:(id)_d
{
  NGMimeMultipartBody *body;
  
  body = [super parseBodyOfPart:_part data:_data delegate:_d];
  
  if ([body isKindOfClass:[NGMimeMultipartBody class]]) {
    NGMutableHashMap *map;
    NSArray  *parts;
    unsigned i, count;

    parts = [body parts];
    count = [parts count];
    
    if (count == 0) // no form fields ..
      return nil;

    map = [NGMutableHashMap hashMapWithCapacity:count];
    for (i = 0; i < count; i++) {
      NGMimeContentDispositionHeaderField *disposition = nil;
      id<NGMimePart> bodyPart;
      
      bodyPart = [parts objectAtIndex:i];
      
      disposition =
        [[bodyPart valuesOfHeaderFieldWithName:@"content-disposition"]
                   nextObject];
      
      if (disposition) {
        NSString *name    = [disposition name];
        id       partBody = [bodyPart body];
        
        if (partBody)
          [map addObject:partBody forKey:name];
      }
      else
        NSLog(@"ERROR(%s): did not find content disposition in form part %@",
              __PRETTY_FUNCTION__, bodyPart);
    }
    NSLog(@"made map %@", map);
    return map;
  }
  else {
    NSLog(@"ERROR: form-data parser expected MultipartBody, got %@", body);
    body = nil;
  }
  return body;
}

@end /* NGHttpMultipartFormDataBodyParser */
