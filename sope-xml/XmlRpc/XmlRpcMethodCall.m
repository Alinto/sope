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

#include <XmlRpc/XmlRpcMethodCall.h>
#include <XmlRpc/XmlRpcCoder.h>
#include "common.h"

@interface XmlRpcMethodCall(PrivateMethodes)
- (NSString *)_encodeXmlRpcMethodCall;
@end

@implementation XmlRpcMethodCall

- (id)initWithXmlRpcString:(NSString *)_string {
  XmlRpcDecoder    *coder;
  XmlRpcMethodCall *baseCall;
  
  if ([_string length] == 0) {
    [self release];
    return nil;
  }
  
  coder = [[XmlRpcDecoder alloc] initForReadingWithString:_string];
  baseCall = [coder decodeMethodCall];
  [coder release];

  if (baseCall == nil) {
    [self release];
    return nil;
  }
  
  self = [self initWithMethodName:[baseCall methodName]
               parameters:[baseCall parameters]];
  
  return self;
}
- (id)initWithXmlRpcData:(NSData *)_xmlRpcData {
  XmlRpcDecoder    *coder;
  XmlRpcMethodCall *baseCall;
  
  if ([_xmlRpcData length] == 0) {
    [self release];
    return nil;
  }
  
  coder = [[XmlRpcDecoder alloc] initForReadingWithData:_xmlRpcData];
  baseCall = [coder decodeMethodCall];
  [coder release];
  
  if (baseCall == nil) {
    [self release];
    return nil;
  }
  
  self = [self initWithMethodName:[baseCall methodName]
               parameters:[baseCall parameters]];
  
  return self;
}

- (id)initWithMethodName:(NSString *)_name parameters:(NSArray *)_params {
  if ((self = [super init])) {
    self->methodName = [_name copy];
    [self setParameters:_params];
  }
  return self;
}

- (void)dealloc {
  [self->methodName release];
  [self->parameters release];
  [super dealloc];
}

/* accessors */

- (void)setMethodName:(NSString *)_name {
  [self->methodName autorelease];
  self->methodName = [_name copy];
}
- (NSString *)methodName {
  return self->methodName;
}

- (void)setParameters:(NSArray *)_params {
  if (self->parameters != _params) {
    unsigned i, cc;
    id *objects;
    
    [self->parameters autorelease];
    
    /* 
       shallow copy parameters, it is implemented here 'by-hand', since 
       skyrix-xml is not dependend on EOControl
    */
    cc = [_params count];
    objects = calloc(cc + 1, sizeof(id));
    
    for (i = 0; i < cc; i++)
      objects[i] = [_params objectAtIndex:i];
    self->parameters = [[NSArray alloc] initWithObjects:objects count:cc];
    if (objects) free(objects);
  }
}
- (NSArray *)parameters {
  return self->parameters;
}

- (NSString *)xmlRpcString {
  return [self _encodeXmlRpcMethodCall];
}

/* description */

- (NSString *)description {
  NSMutableString *s;
  
  s = [NSMutableString stringWithFormat:@"<0x%p[%@]: ",
                         self, NSStringFromClass([self class])];
  [s appendFormat:@"method=%@", [self methodName]];
  [s appendFormat:@" #paras=%d", [self->parameters count]];
  [s appendString:@">"];
  return s;
}

@end /* XmlRpcMethodCall */


@implementation XmlRpcMethodCall(PrivateMethodes)

- (NSString *)_encodeXmlRpcMethodCall {
  NSMutableString *str;
  XmlRpcEncoder   *coder;

#if DEBUG
  NSAssert1(self->methodName, @"%s, methodName is not allowed to be nil!",
            __PRETTY_FUNCTION__);
#endif
  
  str   = [NSMutableString stringWithCapacity:512];
  coder = [[XmlRpcEncoder alloc] initForWritingWithMutableString:str];
  [coder encodeMethodCall:self];

  [coder release]; coder = nil;
  
  return str;
}

@end /* XmlRpcMethodCall(PrivateMethodes) */
