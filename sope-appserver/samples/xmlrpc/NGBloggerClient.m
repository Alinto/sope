/*
  Copyright (C) 2004 Helge Hess

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

#include "NGBloggerClient.h"
#include <NGXmlRpc/NGXmlRpcClient.h>
#include "common.h"

@implementation NGBloggerClient

- (id)initWithClient:(NGXmlRpcClient *)_client {
  if (_client == nil) {
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    self->xmlrpc   = [_client retain];
    self->appid    = @"NGBloggerClient";
    self->login    = @"NGBloggerClient";
    self->password = @"NGBloggerClient";
  }
  return self;
}

- (id)initWithURL:(id)_url {
  NGXmlRpcClient *client;
  
  client = [[NGXmlRpcClient alloc] initWithURL:_url];
  self = [self initWithClient:client];
  [client release];
  return self;
}

- (id)init {
  return [self initWithClient:nil];
}

- (void)dealloc {
  [self->appid    release];
  [self->login    release];
  [self->password release];
  [self->xmlrpc   release];
  [super dealloc];
}

/* accessors */

- (NGXmlRpcClient *)client {
  return self->xmlrpc;
}

- (void)setLogin:(NSString *)_login {
  ASSIGNCOPY(self->login, _login);
  [self->xmlrpc setUserName:self->login];
}
- (NSString *)login {
  return self->login;
}

- (void)setPassword:(NSString *)_value {
  ASSIGNCOPY(self->password, _value);
  [self->xmlrpc setPassword:_value];
}
- (NSString *)password {
  return self->password;
}

/* operations */

- (NSArray *)getUsersBlogs {
  return [self->xmlrpc call:@"blogger.getUsersBlogs",
	      self->appid, self->login, self->password, nil];
}

@end /* NGBloggerClient */
