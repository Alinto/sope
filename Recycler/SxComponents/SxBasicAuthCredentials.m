/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "SxBasicAuthCredentials.h"
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@implementation SxBasicAuthCredentials

- (id)initWithRealm:(NSString *)_realm
  userName:(NSString *)_userName
  password:(NSString *)_pwd
{
  NSString *s;
  
  self->realm    = [_realm    copy];
  self->userName = [_userName copy];

  s = [NSString stringWithFormat:@"%@:%@", _userName, _pwd];
  s = [s stringByEncodingBase64];
  self->httpCred = [s copy];
  return self;
}
- (id)init {
  return [self initWithRealm:nil userName:nil password:nil];
}

- (void)dealloc {
  RELEASE(self->userName);
  RELEASE(self->realm);
  RELEASE(self->httpCred);
  [super dealloc];
}

/* basic auth info */

- (NSString *)realm {
  return self->realm;
}
- (void)setUserName:(NSString *)_username {
  ASSIGNCOPY(self->userName, _username);
}
- (NSString *)userName {
  return self->userName;
}

- (void)setHttpCred:(NSString *)_cred {
  ASSIGNCOPY(self->httpCred, _cred);
}

- (void)setCredentials:(NSString *)_username password:(NSString *)_password {
  [self setUserName:_username];
  [self setHttpCred:[[NSString stringWithFormat:@"%@:%@", _username, _password] 
        stringByEncodingBase64]];
}

/* support XML-RPC backend ... */

- (BOOL)usableWithHttpResponse:(WOResponse *)_response {
  NSString *authHeader;
  
  authHeader = [_response headerForKey:@"www-authenticate"];
  if ([authHeader length] == 0)
    return NO;
  
  if (self->httpCred == nil)
    /* no credentials set ... */
    return NO;
  
  /* check realm !!! */
  
  return YES;
}

- (void)applyOnRequest:(WORequest *)_request {
  NSAssert([self->httpCred length] > 0, @"no credentials set !");
  
  [_request setHeader:[@"basic " stringByAppendingString:self->httpCred]
            forKey:@"authorization"];
}

/* equality */

- (BOOL)isEqualToBasicCredentials:(SxBasicAuthCredentials *)_otherObj {
  if (![[_otherObj realm] isEqualToString:[self realm]])
    return NO;
  
  return [_otherObj->httpCred isEqualToString:self->httpCred];
}

- (BOOL)isEqual:(id)_otherObj {
  if (_otherObj == self)
    return YES;
  if ([_otherObj class] == [self class])
    return [self isEqualToBasicCredentials:_otherObj];
  return NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]: realm=%@ user=%@>",
                     self, NSStringFromClass([self class]),
                     [self realm], [self userName]];
}

@end /* SxBasicAuthCredentials */
