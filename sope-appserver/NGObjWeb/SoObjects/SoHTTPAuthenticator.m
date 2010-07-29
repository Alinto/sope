/*
  Copyright (C) 2002-2007 SKYRIX Software AG
  Copyright (C) 2006-2007 Helge Hess

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

#include "SoHTTPAuthenticator.h"
#include "SoUser.h"
#include "SoPermissions.h"
#include "NSException+HTTP.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOContext.h>
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

#if APPLE_RUNTIME || NeXT_RUNTIME
@interface NSObject(Miss)
- (void)subclassResponsibility:(SEL)cmd;
@end
#endif

@implementation SoHTTPAuthenticator

+ (int)version {
  return 1;
}

/* HTTP basic authentication */

- (NSString *)authRealm {
  // DEPRECATED
  return [(WOApplication *)[WOApplication application] name];
}
- (NSString *)authRealmInContext:(WOContext *)_ctx {
  return [self authRealm];
}

/* check for roles */

- (BOOL)checkLogin:(NSString *)_login password:(NSString *)_pwd {
  [self subclassResponsibility:_cmd];
  return NO;
}

+ (NSArray *)parseCredentials:(NSString *)_creds {
  /*
    returns an array containing two items, user and password.
  */
  NSRange  rng;
  NSString *login, *pwd;
  NSString *k;
  
  /*
    Hack for Google authentication (we treat the auth just like regular
    HTTP authentication).
  */
  if ([_creds hasPrefix:@"GoogleLogin auth="])
    _creds = [_creds substringFromIndex:17];
  
  
  if (![_creds isNotEmpty]) {
    static NSArray *anon = nil;
    if (anon == nil)
      anon = [[NSArray alloc] initWithObjects:@"anonymous", @"", nil];
    return anon;
  }
  if ([_creds length] < 6) {
    [self logWithFormat:@"cannot handle authentication token: %@", _creds];
    return nil;
  }
  
  k = [[_creds substringToIndex:5] lowercaseString];
  if (![k hasPrefix:@"basic"]) {
    [self logWithFormat:@"tried unknown authentication method: %@", _creds];
    return nil;
  }
  
  /*
    Should be 'basic ' (basic + space), but lets be tolerant and allow an
    arbitary amount of leading spaces.
  */
  k = [[_creds substringFromIndex:5] stringByTrimmingLeadWhiteSpaces];
  k = [k stringByDecodingBase64];
  if (k == nil) return nil;

  rng = [k rangeOfString:@":"];
  if (rng.length <= 0) {
    [self logWithFormat:@"got malformed basic credentials!"];
    return nil;
  }
  login = [k substringToIndex:rng.location];
  pwd   = [k substringFromIndex:(rng.location + rng.length)];
  
  rng = [login rangeOfString:@"\\"];
  if (rng.length > 0) {
    [self debugWithFormat:@"splitting off domain in login: '%@'", login];
    login = [login substringFromIndex:(rng.location + rng.length)];
  }
  return [NSArray arrayWithObjects:login, pwd, nil];
}
- (NSArray *)parseCredentials:(NSString *)_creds {
  return [[self class] parseCredentials:_creds];
}

- (NSString *)checkCredentials:(NSString *)_creds {
  /* checks credentials, returnes login if successful */
  NSString *login, *pwd;
  NSArray  *creds;
  
  if (![(creds = [self parseCredentials:_creds]) isNotEmpty])
    return nil;
  
  login = [creds objectAtIndex:0];
  if ([login isEqualToString:@"anonymous"])
    return @"anonymous";
  
  pwd = [creds objectAtIndex:1];
  if (![self checkLogin:login password:pwd])
    return nil;
  
  return login;
}

- (NSString *)checkCredentialsInContext:(WOContext *)_ctx {
  WORequest *rq;
  NSString  *auth;
  
  rq = [_ctx request];
  if ((auth = [rq headerForKey:@"authorization"]) == nil) {
    /* no auth supplied */
    return @"anonymous";
  }
  return [self checkCredentials:auth];
}

- (NSArray *)rolesForLogin:(NSString *)_login {
  NSArray *uroles = nil;
  
  // could add manager of login=root
  
  uroles = [NSArray arrayWithObjects:
		      SoRole_Authenticated,
		      SoRole_Anonymous,
		    nil];
  return uroles;
}

- (SoUser *)userInContext:(WOContext *)_ctx {
  static SoUser *anonymous = nil;
  NSString  *login;
  NSArray   *uroles;
  
  if (anonymous == nil) {
    NSArray *ar = [NSArray arrayWithObject:SoRole_Anonymous];
    anonymous = [[SoUser alloc] initWithLogin:@"anonymous" roles:ar];
  }
  
  if ((login = [self checkCredentialsInContext:_ctx]) == nil)
    /* some error (otherwise result would have been anonymous */
    return nil;
  
  if ([login isEqualToString:@"anonymous"])
    return anonymous;
  
  uroles = [self rolesForLogin:login];
  return [[[SoUser alloc] initWithLogin:login roles:uroles] autorelease];
}

- (WOResponse *)unauthorized:(NSString *)_reason inContext:(WOContext *)_ctx {
  WOResponse *r;
  NSString *auth;

  if (![_reason isNotEmpty]) _reason = @"Unauthorized";
  
  auth = [NSString stringWithFormat:@"basic realm=\"%@\"", 
		   [self authRealmInContext:_ctx]];
  
  r = [_ctx response];
  [r setStatus:401 /* unauthorized */];
  [r setHeader:auth forKey:@"www-authenticate"];
  [r appendContentString:_reason];
  return r;
}

- (WOResponse *)preprocessCredentialsInContext:(WOContext *)_ctx {
  WOResponse *r;
  NSString *auth;
  NSString *k;
  NSString *user, *pwd;
  NSRange rng;

  if ((auth = [[_ctx request] headerForKey:@"authorization"]) == nil) {
    /* no authentication provided */
    static NSArray *anon = nil;
    if (anon == nil)
      anon = [[NSArray alloc] initWithObjects:SoRole_Anonymous, nil];
    
    [_ctx setObject:anon forKey:@"SoAuthenticatedRoles"];
    return nil;
  }
  /*
    Hack for Google authentication (we treat the auth just like regular
    HTTP authentication).
  */
  else if ([auth hasPrefix:@"GoogleLogin auth="])
    auth = [auth substringFromIndex:17];
  
  /* authentication provided, check whether it's valid */
  
  r = [_ctx response];
  if ([auth length] < 6) {
    [self logWithFormat:@"tried unknown authentication method: %@ (A)", auth];
    return [self unauthorized:@"unsupported authentication method"
                 inContext:_ctx];
  }
  k = [[auth substringToIndex:5] lowercaseString];
  if (![k hasPrefix:@"basic"]) {
    [self logWithFormat:@"tried unknown authentication method: %@ (B)", auth];
    return [self unauthorized:@"unsupported authentication method"
                 inContext:_ctx];
  }
  
  /*
    Should be 'basic ' (basic + space), but lets be tolerant and allow an
    arbitary amount of leading spaces.
  */
  k = [[auth substringFromIndex:5] stringByTrimmingLeadWhiteSpaces];
  if ((k = [k stringByDecodingBase64]) == nil) {
    [self logWithFormat:@"tried unknown authentication method: %@ (C)", auth];
    return [self unauthorized:@"unsupported authentication method"
                 inContext:_ctx];
  }

  rng = [k rangeOfString:@":"];
  if (rng.length <= 0) {
    [self logWithFormat:@"got malformed basic credentials (missing colon)!"];
    return [self unauthorized:@"malformed basic credentials!" inContext:_ctx];
  }
  
  user = [k substringToIndex:rng.location];
  pwd  = [k substringFromIndex:(rng.location + rng.length)];
  
  rng = [user rangeOfString:@"\\"];
  if (rng.length > 0) {
    [self debugWithFormat:@"splitting of domain in user: '%@'", user];
    user = [user substringFromIndex:(rng.location + rng.length)];
  }
  
  if (![user isNotEmpty]) {
    [self logWithFormat:@"got malformed basic credentials!"];
    return [self unauthorized:@"empty login in credentials?" inContext:_ctx];
  }
  if (![pwd isNotEmpty]) {
    [self logWithFormat:@"got empty password for user '%@'!", user];
    return [self unauthorized:@"empty passwords unsupported!" inContext:_ctx];
  }
  
  /* authenticate valid credentials */
  
  if (![self checkLogin:user password:pwd]) {
    [self logWithFormat:@"tried wrong password for user '%@'!", user];
    return [self unauthorized:nil inContext:_ctx];
  }
  
  //[self debugWithFormat:@"authenticated user '%@'", user];
  
  /* authentication succeeded */
  {
    static NSArray *auth = nil;
    if (auth == nil) {
      auth = [[NSArray alloc] initWithObjects:
				SoRole_Authenticated, SoRole_Anonymous, nil];
    }
    [_ctx setObject:auth forKey:@"SoAuthenticatedRoles"];
  }
  return nil;
}

/* render auth exceptions */

- (BOOL)renderException:(NSException *)_e inContext:(WOContext *)_ctx {
  if ([_e httpStatus] == 401) {
    WOResponse *r;
    NSString   *auth;
    
    r = [_ctx response];
    auth = [NSString stringWithFormat:@"basic realm=\"%@\"", 
		     [self authRealmInContext:_ctx]];
    [r setStatus:[_e httpStatus] /* unauthorized */];
    [r setHeader:auth forKey:@"www-authenticate"];
    return YES;
  }
  return NO;
}

@end /* SoHTTPAuthenticator */
