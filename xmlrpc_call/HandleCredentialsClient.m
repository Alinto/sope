/*
  Copyright (C) 2004-2005 Helge Hess

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

#include "HandleCredentialsClient.h"
#include <NGObjWeb/WOResponse.h>
#include "common.h"
#include <string.h>
#include <unistd.h>

@interface NGXmlRpcClient(CallFailed)
- (id)callFailed:(WOResponse *)_response;
@end /* NGXmlRpcClient */

@implementation HandleCredentialsClient

- (void)dealloc {
  [self->defLogin    release];
  [self->defPassword release];
  [super dealloc];
}

/* accessors */

- (void)setDefLogin:(NSString *)_login {
  ASSIGNCOPY(self->defLogin, _login);
}
- (void)setDefPassword:(NSString *)_pwd {
  ASSIGNCOPY(self->defPassword, _pwd);
}

/* prompting */

- (NSString *)prompt:(NSString *)_prompt {
  NSString *login;
  char clogin[256];
  
  fprintf(stderr, "%s", [_prompt cString]);
  fflush(stderr);
  fgets(clogin, 200, stdin);
  clogin[strlen(clogin) - 1] = '\0';
  login = [NSString stringWithCString:clogin];
  return login;
}

- (NSString *)promptPassword:(NSString *)_prompt {
  NSString *pwd;
  char     *cpwd;

  cpwd = getpass("password: ");
  pwd = [NSString stringWithCString:cpwd];
  return pwd;
}

- (id)callFailed:(WOResponse *)_response {
  if ([_response status] == 401) {
    NSString *wwwauth;
    NSString *user;
    NSString *pass;
    
    wwwauth = [_response headerForKey:@"www-authenticate"];
    if ([[wwwauth lowercaseString] hasPrefix:@"digest"])
      [self logWithFormat:@"Digest authentication:\n'%@'", wwwauth];

    // TODO: test credentials of URL
    
    if (self->defLogin) {
      user = [self->defLogin autorelease];
      self->defLogin = nil;
    }
    else
      user = [self prompt:@"login:    "];
    
    if (self->defPassword) {
      pass = [self->defPassword autorelease];
      self->defPassword = nil;
    }
    else
      pass = [self promptPassword:@"password: "];
    
    [self setUserName:user];
    [self setPassword:pass];
    
    /* this "should" return some kind of "need-pwd" object ... */
    return nil;
  }
  else {
    return [super callFailed:_response];
  }
}

@end /* HandleCredentialsClient */
