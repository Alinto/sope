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

@implementation NGMimeBodyParser

+ (int)version {
  return 2;
}

- (id)parseBodyOfPart:(id<NGMimePart>)_part
  data:(NSData *)_data
  delegate:(id)_d
{
  return _data;
}

@end /* NGMimeBodyParser */

@implementation NGMimeTextBodyParser

static int UseFoundationStringEncodingForMimeText = -1;

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  if (UseFoundationStringEncodingForMimeText == -1) {
    UseFoundationStringEncodingForMimeText =
      [ud boolForKey:@"UseFoundationStringEncodingForMimeText"]?1:0;
  }
}

- (id)parseBodyOfPart:(id<NGMimePart>)_part data:(NSData *)_data
  delegate:(id)_d
{
  NSString *charset;
  id       ctype, body;

  if (_data == nil) return nil;
  
  ctype = [_part contentType];
  if (!ctype
      && [_d respondsToSelector: @selector(parser:contentTypeOfPart:)])
    ctype = [_d parser: self contentTypeOfPart: _part];

  if (![ctype isKindOfClass:[NGMimeType class]])
    ctype = [NGMimeType mimeType:[ctype stringValue]];
  
  charset = [[ctype valueOfParameter:NGMimeParameterTextCharset]
                    lowercaseString];
  body     = nil;
  
  if (!UseFoundationStringEncodingForMimeText) {
    if (![_data length])
      return @"";

    if (![[charset lowercaseString] isEqualToString:@"us-ascii"] &&
        [charset length]) {
      body = [NSString stringWithData:_data usingEncodingNamed:charset];
    }
  }
  if (!body) {
    NSStringEncoding encoding;
    
    encoding = [NGMimeType stringEncodingForCharset:charset];
    
    // If we nave no encoding here, let's not simply return nil.
    // We SHOULD try at least UTF-8 and after, Latin1.
    if (!encoding)
      encoding = NSUTF8StringEncoding;
    
    body = [[[NSString alloc]
	      initWithData:_data
                       encoding:encoding] autorelease];

    if (!body)
     body = [[[NSString alloc] initWithData:_data
			       encoding:NSISOLatin1StringEncoding]
	      autorelease];
  }
  return body;
}

@end /* NGMimeTextBodyParser */

