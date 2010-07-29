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

#include "NGMimeMessageParser.h"
#include "NGMimeMessage.h"
#include "common.h"
#include <string.h>

@interface NGMimeMessageParserDelegate : NSObject
@end

@implementation NGMimeMessageParserDelegate

static Class NGMimeMessageParserClass = Nil; 

+ (void)initialize {
  if (NGMimeMessageParserClass == Nil)
    NGMimeMessageParserClass = [NGMimeMessageParser class];
}

- (id)parser:(NGMimePartParser *)_p parseHeaderField:(NSString *)_field
  data:(NSData *)_data
{
  NGMimeMessageParser *parser = nil;
  id v;

  if ([_p isKindOfClass:NGMimeMessageParserClass])
    return nil;
  
  parser = [[NGMimeMessageParserClass alloc] init];
  v = [parser valueOfHeaderField:_field data:_data];
  [parser release]; parser = nil;
  return v;
}

- (id<NGMimeBodyParser>)parser:(NGMimePartParser *)_parser
  bodyParserForPart:(id<NGMimePart>)_part
{
  id         ctype;
  NGMimeType *contentType;

  ctype = [_part contentType];
  
  contentType = ([ctype isKindOfClass:[NGMimeType class]])
    ? ctype
    : [NGMimeType mimeType:[ctype stringValue]];
  
  if ([[contentType type] isEqualToString:@"message"] &&
      [[contentType subType] isEqualToString:@"rfc822"]) {
    return [[[NGMimeRfc822BodyParser alloc] init] autorelease];
  }
  return nil;
}


@end /* NGMimeMessageParserDelegate */

@implementation NGMimeMessageParser

static Class NSStringClass = Nil;

+ (int)version {
  return 3;
}
+ (void)initialize {
  NSAssert2([super version] == 3,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  if (NSStringClass == Nil)
    NSStringClass = [NSString class];
}

- (id)init {
  if ((self = [super init])) {
    [self setDelegate:[NGMimeMessageParserDelegate new]];
  }
  return self;
}

/* factory */

- (id<NGMimePart>)producePartWithHeader:(NGHashMap *)_header {
  return [NGMimeMessage messageWithHeader:_header];
}

/* header field specifics */

- (id)valueOfHeaderField:(NSString *)_name data:(id)_data {
  // check data for 8-bit headerfields (RFC 2047 (MIME PART III))
  
  /* check whether we got passed a string ... */
  if ([_data isKindOfClass:NSStringClass]) {
    NSLog(@"%s: WARNING unexpected class for headerfield %@ (value %@)",
          __PRETTY_FUNCTION__, _name, _data);
    return [super valueOfHeaderField:_name data:_data];
  }
  _data = [_data decodeQuotedPrintableValueOfMIMEHeaderField:_name];
  return [super valueOfHeaderField:_name data:_data];
}

@end /* NGMimeMessageParser */



@implementation NGMimeRfc822BodyParser

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)parseBodyOfPart:(id<NGMimePart>)_part data:(NSData *)_data
  delegate:(id)_d
{
  id<NGMimePart> body;
  id             parser; // NGMimeMessageParser

  parser = [[NGMimeMessageParser alloc] init];
  body = [parser parsePartFromData:_data];
  [parser release]; parser = nil;
  
  return body;
}

@end /* NGMimeRfc822BodyParser */
