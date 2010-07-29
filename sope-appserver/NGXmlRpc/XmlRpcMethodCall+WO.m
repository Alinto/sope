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
#include <NGObjWeb/WORequest.h>
#include "common.h"

@implementation XmlRpcMethodCall(WO)

// TODO: not required anymore by NGXmlRpcClient, can be removed ?

- (id)initWithRequest:(WORequest *)_request {
  /* do not use -initWithXmlRpcString here !!! */
  return [self initWithXmlRpcData:[_request content]];
}

- (WORequest *)generateRequestWithUri:(NSString *)_uri {
  WORequest *request;
  
  request = [[WORequest alloc] initWithMethod:@"POST"
                               uri:_uri
                               httpVersion:@"HTTP/1.0"
                               headers:nil
                               content:nil
                               userInfo:nil];

  [request setHeader:@"text/xml" forKey:@"content-type"];
  [request setContentEncoding:NSUTF8StringEncoding];
  
  [request appendContentString:[self xmlRpcString]];
  
  return [request autorelease];
}

@end /* XmlRpcMethodCall(WO) */
