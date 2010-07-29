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

#include <XmlRpc/XmlRpcMethodResponse.h>
#include <XmlRpc/XmlRpcCoder.h>
#include "common.h"
#include <NGObjWeb/WORequest.h>

@implementation WORequest(XmlRpcCoding)

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [super encodeWithXmlRpcCoder:_coder];
  [_coder encodeString:[self method] forKey:@"method"];
  [_coder encodeString:[self uri]    forKey:@"uri"];
}

- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  if ((self = [self initWithMethod:[_coder decodeStringForKey:@"method"]
                    uri:[_coder decodeStringForKey:@"uri"]
                    httpVersion:[_coder decodeStringForKey:@"http-version"]
                    headers:[_coder decodeStructForKey:@"headers"]
                    content:[_coder decodeBase64ForKey:@"content"]
                    userInfo:nil])) {
    NSArray      *cooks    = [_coder decodeArrayForKey:@"cookies"];
    NSEnumerator *cookEnum = [cooks objectEnumerator];
    WOCookie     *cook     = nil;

    while ((cook = [cookEnum nextObject])) {
      [self addCookie:cook];
    }
    return self;
  }
  return nil;
}

@end /* WORequest(XmlRpcCoding) */
