/*
  Copyright (C) 2006 Helge Hess

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

#ifndef __SoObjects_SoCookieAuthenticator_H__
#define __SoObjects_SoCookieAuthenticator_H__

#import <Foundation/NSObject.h>

/*
  SoCookieAuthenticator

  SoCookieAuthenticator is an abstract base class for Cookie based
  authentication. That is, it uses a Cookie to store the credentials
  or a token of a session.
  In the simplest case you only need to override -checkLogin:password:
  to ensure login/password combinations.
  
  NOTE: work in progress.
  
  TODO: we also need a WOSessionAuthenticator which assumes that the
        existance of a session implies a successful authentication?
*/

@class NSString, NSException, NSArray;
@class WOContext, WOResponse, WOCookie;
@class SoUser;

@interface SoCookieAuthenticator : NSObject
{
}

/* password checker (override in subclasses !) */

- (BOOL)checkLogin:(NSString *)_login password:(NSString *)_pwd;

/* Cookie authentication */

- (NSString *)cookieNameInContext:(WOContext *)_ctx;
- (WOResponse *)preprocessCredentialsInContext:(WOContext *)_ctx;

- (NSString *)checkCredentialsInContext:(WOContext *)_ctx;
- (NSArray *)parseCredentials:(NSString *)_creds;

/* user management */

- (SoUser *)userInContext:(WOContext *)_ctx;
- (NSArray *)rolesForLogin:(NSString *)_login;

/* render auth exceptions of SoSecurityManager */

- (BOOL)renderException:(NSException *)_e inContext:(WOContext *)_ctx;

@end

#endif /* __SoObjects_SoCookieAuthenticator_H__ */
