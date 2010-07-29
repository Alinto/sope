/*
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

#include "SoCookieAuthenticator.h"
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

// TODO: do we have 'anonymous' in such a scenario???
// TODO: we want to redirect to a login panel and include the root URL
//       using a query path

@implementation SoCookieAuthenticator

static NSString *prefix = @"0xHIGHFLYx";

+ (int)version {
  return 1;
}

/* HTTP basic authentication */

- (NSString *)cookieNameInContext:(WOContext *)_ctx {
  return [prefix stringByAppendingString:[[_ctx application] name]];
}

/* check for roles */

- (BOOL)checkLogin:(NSString *)_login password:(NSString *)_pwd {
  [self subclassResponsibility:_cmd];
  return NO;
}

- (NSArray *)parseCredentials:(NSString *)_creds {
  if (![_creds isNotEmpty])
    return nil;
  
  /* per default we just reuse HTTP basic credentials! */
  return [SoHTTPAuthenticator parseCredentials:_creds];
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
  
  auth = [rq cookieValueForKey:[self cookieNameInContext:_ctx]];
  if (![auth isNotEmpty]) {
    /* no auth supplied */
    return @"anonymous";
  }
  return [self checkCredentials:auth];
}

- (NSArray *)rolesForLogin:(NSString *)_login {
  // TODO: I suppose this should be overridden?
  NSArray *uroles;
  
  // could add manager of login=root
  
  uroles = [NSArray arrayWithObjects:
		      SoRole_Authenticated,
		      SoRole_Anonymous,
		    nil];
  return uroles;
}

- (SoUser *)userWithLogin:(NSString *)_login andRoles:(NSArray *)_roles
  inContext:(WOContext *)_ctx
{
  /* the actual factory method */
  return [[[SoUser alloc] initWithLogin:_login roles:_roles] autorelease];
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
  return [self userWithLogin:login andRoles:uroles inContext:_ctx];
}

/* auth fail handling */

- (void)setupAuthFailResponse:(WOResponse *)_response
  withReason:(NSString *)_reason inContext:(WOContext *)_ctx
{
  [_response appendContentString:@"TODO: render login page ..."];
}

- (WOResponse *)unauthorized:(NSString *)_reason inContext:(WOContext *)_ctx {
  WOResponse *r;
  
  if (![_reason isNotEmpty]) _reason = @"Unauthorized";
  
  r = [_ctx response];
  [self setupAuthFailResponse:r withReason:_reason inContext:_ctx];
  return r;
}

- (BOOL)renderException:(NSException *)_e inContext:(WOContext *)_ctx {
  /* 
     TODO: this can be called for content which is not accessible to the
           user? (but the user is otherwise perfectly ok?)
	   Should not: in this case we should get a 404?
  */
  if ([_e httpStatus] != 401)
    return NO;
  
  [self setupAuthFailResponse:[_ctx response]
	withReason:[_e reason] inContext:_ctx];
  return YES;
}

/* request preprocessing */

- (WOResponse *)preprocessCredentialsInContext:(WOContext *)_ctx {
  /*
    This is called by SoObjectRequestHandler prior doing any significant
    processing to allow the authenticator to reject invalid requests.
  */
  WOResponse *r;
  NSString *auth;
  NSString *k;
  NSString *user, *pwd;
  NSRange rng;
  
  auth = [[_ctx request] cookieValueForKey:[self cookieNameInContext:_ctx]];
  if (![auth isNotEmpty]) {
    /* no authentication provided */
    static NSArray *anon = nil;
    if (anon == nil)
      anon = [[NSArray alloc] initWithObjects:SoRole_Anonymous, nil];
    
    [_ctx setObject:anon forKey:@"SoAuthenticatedRoles"];
    return nil;
  }
  
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
  
  /*
    Authentication succeeded. Put authenticated roles into the context.
  */
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

@end /* SoCookieAuthenticator */
