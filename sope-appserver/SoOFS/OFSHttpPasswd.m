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

#include "OFSHttpPasswd.h"
#include <SoObjects/SoHTTPAuthenticator.h>
#include "common.h"

#if defined (__APPLE__) || defined(__FreeBSD__)
#  include <unistd.h>
#else
#  if defined(__OpenBSD__)
#    include <des.h>
#  else
#    include <crypt.h>
#  endif
#endif

/*
  Note: a user-folder is different to an authenticator (though a user
  folder can be a authenticator itself) ! A user-folder manages the whole
  user-database while an authenticator decodes HTTP authentication info,
  checks a password against a user and retrieves only authentication related
  information on a user.
  
  So: a user-folder is strongly related to an authenticator, but isn't
  usually the actual authenticator object (which usually inherits from
  SoHTTPAuthenticator).
*/

// TODO: implement ...

@interface OFSHttpPasswdAuthenticator : SoHTTPAuthenticator
{
  OFSHttpPasswd *passwd; /* non-retained */
}

- (id)initWithObject:(id)_obj;
- (void)detach;

@end

@implementation OFSHttpPasswd

static BOOL    debugOn     = NO;
static NSArray *plainRoles = nil;
static NSArray *rootRoles  = nil;

+ (void)initialize {
  if (plainRoles == nil) {
    plainRoles = [[NSArray alloc] initWithObjects:
		      SoRole_Authenticated, SoRole_Anonymous, nil];
  }
  if (rootRoles == nil) {
    rootRoles = [[NSArray alloc] initWithObjects:
				   SoRole_Manager, SoRole_Authenticated, 
				   SoRole_Anonymous, nil];
  }
}

- (void)dealloc {
  [self->content release];
  [self->authenticator detach];
  [self->authenticator release];
  [super dealloc];
}

- (id)authenticatorInContext:(id)_ctx {
  if (self->authenticator == nil) {
    self->authenticator = 
      [[OFSHttpPasswdAuthenticator alloc] initWithObject:self];
  }
  return self->authenticator;
}

/* loading htpasswd */

- (NSException *)primaryLoad {
  NSMutableDictionary *md;
  NSString *s;
  NSArray  *lines;
  unsigned i, count;

  [self->content release]; self->content = nil;
  
  s = [self contentAsString];
  lines = [s componentsSeparatedByString:@"\n"];
  count = [lines count];
  md = [NSMutableDictionary dictionaryWithCapacity:(count + 1)];
  
  for (i = 0; i < count; i++) {
    NSString *s;
    NSRange  r;
    NSString *login, *pwd;
    
    s = [lines objectAtIndex:i];
    r = [s rangeOfString:@":"];
    if (r.length == 0) continue;
    
    login = [s substringToIndex:r.location];
    pwd   = [s substringFromIndex:(r.location + r.length)];
    
    [md setObject:pwd forKey:login];
  }
  self->content = [md copy];
  return nil;
}

- (NSString *)cryptedPasswordForLogin:(NSString *)_login {
  NSException *error;
  
  if ([_login length] < 1)
    return nil;
  if (self->content)
    return [self->content objectForKey:_login];
  
  if ((error = [self primaryLoad]))
    return nil;
  
  return [self->content objectForKey:_login];
}

/* authenticator implementation */

- (BOOL)checkLogin:(NSString *)_login password:(NSString *)_pwd {
  NSString *cryptedPwd;
  NSString *cpo;
  const char *cp;
  
  if (debugOn)
    [self debugWithFormat:@"check '%@' against pwd ...", _login];
  
  if ((cryptedPwd = [self cryptedPasswordForLogin:_login]) == nil) {
    [self debugWithFormat:@"  user '%@' not available in htpasswd", _login];
    return NO;
  }
  
  if (debugOn)
    [self debugWithFormat:@"  check crypted pwd of user '%@' ...", _login];
  
  // salt is user-pwd itself (crypt(pwd, cryptedpwd))
  cp = crypt([_pwd cString], [cryptedPwd cString]);
  cpo = cp ? [NSString stringWithCString:cp] : nil;
  
  return [cryptedPwd isEqualToString:cpo];
}

- (NSString *)authRealm {
  return [(WOApplication *)[WOApplication application] name];
}

- (BOOL)isRootLogin:(NSString *)_login {
  return [_login isEqualToString:@"root"];
}
- (NSArray *)rolesForLogin:(NSString *)_login {
  return [self isRootLogin:_login] ? rootRoles : plainRoles;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* OFSHttpPasswd */

@implementation OFSHttpPasswdAuthenticator

- (id)initWithObject:(id)_obj {
  NSAssert(_obj, @"missing htpasswd user folder in argument ...");
  if ((self = [super init])) {
    self->passwd = _obj;
  }
  return self;
}
- (id)init {
  return [self initWithObject:nil];
}

- (void)detach {
  self->passwd = nil;
}

/* implement using folder itself ... */

- (BOOL)checkLogin:(NSString *)_login password:(NSString *)_pwd {
  return [self->passwd checkLogin:_login password:_pwd];
}

- (NSString *)authRealm {
  return [self->passwd authRealm];
}

- (NSArray *)rolesForLogin:(NSString *)_login {
  return [self->passwd rolesForLogin:_login];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* OFSHttpPasswdAuthenticator */
