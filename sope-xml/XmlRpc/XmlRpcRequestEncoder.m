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

#include "XmlRpcCoder.h"
#include "XmlRpcMethodCall.h"
#include "common.h"

@interface XmlRpcEncoder(PrivateMethodes)
- (void)_encodeObject:(id)_object;
- (void)_reset;
@end

@implementation XmlRpcRequestEncoder

- (void)encodeRootObject:(XmlRpcMethodCall *)_methodCall {
  NSEnumerator *paramEnum;
  id           param;

  if (_methodCall == nil) return;

  if (![_methodCall isKindOfClass:[XmlRpcMethodCall class]]) {
    NSLog(@"%s: Warning: rootObject MUST be a XmlRpcMethodCall\n "
          @"(rootObject=%@)",
          __PRETTY_FUNCTION__,
          _methodCall);
    return;
  }
  
  [self _reset];
  
  paramEnum = [[_methodCall parameters] objectEnumerator];
  
  [self->string appendString:@"<?xml version='1.0'?>\n"];
  [self->string appendString:@"<methodCall>\n"];

  [self->string appendString:@"<methodName>"];
  [self->string appendString:[_methodCall methodName]];
  [self->string appendString:@"</methodName>\n"];
  
  [self->string appendString:@"<params>\n"];
  
  while ((param = [paramEnum nextObject])) {
    [self->string appendString:@"<param>\n"];
    [self->string appendString:@"<value>\n"];

    [self _encodeObject:param];
    
    [self->string appendString:@"</value>\n"];
    [self->string appendString:@"</param>\n"];
  }

  [self->string appendString:@"</params>\n"];
  
  [self->string appendString:@"</methodCall>\n"];
}

@end /* XmlRpcRequestEncoder */
