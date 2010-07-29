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

#include <XmlRpc/XmlRpcCoder.h>
#include <NGExtensions/NGExtensions.h>
#include <NGObjWeb/WOMessage.h>
#include "common.h"

@implementation WOMessage(XmlRpcCoding)

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeString:[self httpVersion] forKey:@"http-version"];
  [_coder encodeStruct:[self headers]     forKey:@"headers"];
  [_coder encodeBase64:[self content]     forKey:@"content"];  
  [_coder encodeArray:[self cookies]      forKey:@"cookies"];
}

- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  if ((self = [super init])) {
    NSArray      *cooks    = [_coder decodeArrayForKey:@"cookies"];
    NSEnumerator *cookEnum = [cooks objectEnumerator];
    WOCookie     *cook     = nil;

    while ((cook = [cookEnum nextObject])) {
      [self addCookie:cook];
    }
    [self setHTTPVersion:[_coder decodeStringForKey:@"http-version"]];
    [self setHeaders:    [_coder decodeStructForKey:@"headers"]];
    [self setContent:    [_coder decodeBase64ForKey:@"content"]];

    return self;
  }
  return nil;
}

@end /* WOMessage(XmlRpcCoding) */
