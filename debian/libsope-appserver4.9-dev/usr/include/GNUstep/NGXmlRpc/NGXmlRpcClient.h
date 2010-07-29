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

#ifndef __NGXmlRpcClient_H__
#define __NGXmlRpcClient_H__

#import <Foundation/NSObject.h>

/*
  NGXmlRpcClient
  
  This class is a raw XML-RPC client based on WOHTTPConnection. To see how
  it works, take a look at the xmlrpc_call.m tool included in SOPE 4.5.

  XML-RPC over Unix domain sockets. NGXmlRpcClient (will) support XML-RPC over
  a Unix domain socket, as used in the ximian_xmlrpclib.py. The transport
  protocol used is "$body$\r\n\r\n".
  
  Usage:
    NGXmlRpcClient *server;
    
    server =
      [[NGXmlRpcClient alloc] initWithURL:@"http://betty.userland.com/RPC2"];
    
    NSLog(@"result: %@", [server call:@"state.getByNumber", @"42", nil]);
*/

@class NSArray, NSString, NSURL, NSDictionary;
@class WOHTTPConnection;

@interface NGXmlRpcClient : NSObject
{
  /* performing HTTP requests */
  WOHTTPConnection *httpConnection;
  NSString         *userName;
  NSString         *password;
  NSString         *uri;
  NSDictionary     *additionalHeaders;
  
  /* performing RAW requests */
  id address;
  
  /* some transactional state is required for digest authentication */
  id digestInfo;
  
  // TODO: add timeout parameters
}

- (id)initWithURL:(id)_url;
- (id)initWithURL:(id)_url login:(NSString *)_login password:(NSString *)_pwd;

- (id)initWithRawAddress:(id)_address;

/* accessors */

- (void)setUserName:(NSString *)_userName;
- (NSString *)userName;
- (NSString *)login;

- (void)setPassword:(NSString *)_password;
- (NSString *)password;

- (void)setUri:(NSString *)_uri;
- (NSString *)uri;

- (void)setAdditionalHeaders:(NSDictionary *)_headers;
- (NSDictionary *)additionalHeaders;

/* invoking methods */

- (id)invoke:(NSString *)_methodName params:(id)first,...;

- (id)invokeMethodNamed:(NSString *)_methodName;
- (id)invokeMethodNamed:(NSString *)_methodName withParameter:(id)_param;
- (id)invokeMethodNamed:(NSString *)_methodName parameters:(NSArray *)_params;

/*
  terminate parameter list with nil, eg:

    [rpc call:@"state.getByNumber", @"42", nil];
*/
- (id)call:(NSString *)_methodName,...;

@end

#endif /* __NGXmlRpcClient_H__ */
