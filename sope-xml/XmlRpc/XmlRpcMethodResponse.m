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

#include "XmlRpcMethodResponse.h"
#include "XmlRpcCoder.h"
#include "common.h"

@interface XmlRpcMethodResponse(PrivateMethodes)
- (NSString *)_encodeXmlRpcMethodResponse;
@end

@implementation XmlRpcMethodResponse

- (id)initWithXmlRpcString:(NSString *)_string {
  XmlRpcDecoder        *coder;
  XmlRpcMethodResponse *baseResponse;
  
  if ([_string length] == 0) {
    [self release];
    return nil;
  }

  coder        = [[XmlRpcDecoder alloc] initForReadingWithString:_string];
  baseResponse = [coder decodeMethodResponse];
  [coder release];

  if (baseResponse == nil) {
    [self release];
    return nil;
  }
  
  self = [self initWithResult:[baseResponse result]];
  
  return self;
}
- (id)initWithXmlRpcData:(NSData *)_data {
  XmlRpcDecoder        *coder;
  XmlRpcMethodResponse *baseResponse;
  
  if ([_data length] == 0) {
    [self release];
    return nil;
  }

  coder        = [[XmlRpcDecoder alloc] initForReadingWithData:_data];
  baseResponse = [coder decodeMethodResponse];
  [coder release];

  if (baseResponse == nil) {
    [self release];
    return nil;
  }
  
  self = [self initWithResult:[baseResponse result]];
  
  return self;
}

- (id)initWithResult:(id)_result {
  if ((self = [super init])) {
    self->result = [_result retain];
  }
  return self;
}

- (void)dealloc {
  [self->result release];
  [super dealloc];
}

/* accessors */

- (void)setResult:(id)_result {
  [self->result autorelease];
  self->result = [_result retain];
}
- (id)result {
  return self->result;
}

- (NSString *)xmlRpcString {
  return [self _encodeXmlRpcMethodResponse];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (result)
    [ms appendFormat:@" %@", self->result];
  else
    [ms appendString:@" no result"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* XmlRpcMethodResponse */

@implementation XmlRpcMethodResponse(PrivateMethodes)

- (NSString *)_encodeXmlRpcMethodResponse {
  XmlRpcEncoder   *encoder = nil;
  NSMutableString *str     = nil;

  str = [NSMutableString stringWithCapacity:512];

  encoder = [[XmlRpcEncoder alloc] initForWritingWithMutableString:str];
  [encoder encodeMethodResponse:self];
  [encoder release];

  return str;
}

@end /* XmlRpcMethodResponse(PrivateMethodes) */
