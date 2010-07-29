/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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
#include <NGExtensions/NSString+Encoding.h>
#include "common.h"

@implementation NGMimeTextBodyGenerator

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (NSStringEncoding)_encodingFromContentType:(NGMimeType *)_type {
  NSStringEncoding encoding;
  NSString *charset;

  encoding = [NSString defaultCStringEncoding];
  if (_type != nil) {
    charset = [_type valueOfParameter: @"charset"];
    if ([charset length] > 0) {
      if ([charset isEqualToString: @"utf-8"])
	encoding = NSUTF8StringEncoding;
      else if ([charset isEqualToString: @"iso-8859-1"])
	encoding = NSISOLatin1StringEncoding;
      /* more should be handled here */
    }
  }
    
  return encoding;
}

- (NSData *)generateBodyOfPart:(id<NGMimePart>)_part
  additionalHeaders:(NGMutableHashMap *)_addHeaders
  delegate:(id)_delegate
{
  NSData *data;
  id     body;
  
  body = [_part body];
  data = nil;
  
  if ([body isKindOfClass:[NSString class]]) {
    NSString *charset = [[_part contentType] valueOfParameter:@"charset"];
    if ([charset isNotEmpty])
      data = [body dataUsingEncodingNamed:charset];
    
    if (data == nil) /* either no charset given or the charset failed */
      data = [body dataUsingEncoding:[NSString defaultCStringEncoding]];
  }
  else if ([body respondsToSelector:@selector(bytes)]) {
    /* an NSData, but why not check the class?!, we can't just cast it */
    data = body;
  }
  else if ([body respondsToSelector:@selector(dataUsingEncoding:)]) {
    /* hm, whats that?, NSString is covered before */
    NSStringEncoding encoding = 0;
    NSString *charset = [[_part contentType] valueOfParameter:@"charset"];
    
    if ([charset isNotEmpty]) {
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
      encoding = [NSString stringEncodingForEncodingNamed:charset];
#else
      encoding = [self _encodingFromContentType:[_part contentType]];
#endif
    }
    
    data = [body dataUsingEncoding:
		   (encoding != 0 ? encoding : NSISOLatin1StringEncoding)];
  }
  else if (body != nil) {
    [self errorWithFormat:@"unexpected part body %@: %@", [body class], body];
    return nil;
  }
  
  if (data == nil) {
    [self warnWithFormat:@"%s: generate empty body", __PRETTY_FUNCTION__];
    data = [NSData data];
  }
  return [self encodeData:data forPart:_part additionalHeaders:_addHeaders];
}

@end /* NGMimeTextBodyGenerator */
