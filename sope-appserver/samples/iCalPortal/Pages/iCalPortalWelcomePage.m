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

#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WODirectAction.h>

@interface iCalPortalWelcomePage : WOComponent
{
}

@end

@interface iCalPortalWelcomeAction : WODirectAction
@end

#include "iCalPortalUser.h"
#include "iCalPortalDatabase.h"
#include "common.h"

@implementation iCalPortalWelcomePage

- (void)dealloc {
  [super dealloc];
}

/* accessors */

/* actions */

- (BOOL)isSessionProtectedPage {
  return NO;
}

- (id)run {
  return self;
}
- (id)performPage {
  return [self run];
}

@end /* iCalPortalWelcomePage */

@implementation iCalPortalWelcomeAction

- (BOOL)redirectOnLogin {
  return NO;
}

- (id)loginAction {
  NSString           *login, *pwd;
  iCalPortalDatabase *db;
  iCalPortalUser     *user;
  
  db = [(id)[WOApplication application] database];
  
  login = [[self request] formValueForKey:@"user"];
  pwd   = [[self request] formValueForKey:@"pwd"];
  
  if (![db isLoginNameValid:login]) {
    [self logWithFormat:@"tried an invalid login: '%@'", login];
    return [self indexPage];
  }
  
  if ((user = [db userWithName:login password:pwd]) == nil) {
    [self logWithFormat:@"login failed: '%@'", login];
    return [self indexPage];
  }
  
  [self logWithFormat:@"user %@ is logged in.", login];
  [[self session] setObject:user forKey:@"user"];
  
  /* check language */
  {
    NSString *lang;
    
    if ((lang = [[self request] formValueForKey:@"language"])) {
      NSMutableArray *langs;

      if ([lang isEqualToString:@"en"])
	lang = @"English";
      else if ([lang isEqualToString:@"de"])
	lang = @"German";
      
      langs = [NSMutableArray arrayWithCapacity:16];
      [langs addObject:lang];
      [langs addObject:[[self session] languages]];
      [[self session] setLanguages:langs];
    }
  }
  
  /* deliver login result */
  
  if ([self redirectOnLogin]) {
    /* make a redirect on login (better for deployment) ... */
    WOResponse   *r;
    NSString     *homeURL;
    NSDictionary *qd;

    qd = [NSDictionary dictionaryWithObject:[[self session] sessionID]
		       forKey:WORequestValueSessionID];
    
    homeURL = [[[WOApplication application] context] 
		               directActionURLForActionNamed:@"home"
		               queryDictionary:qd];
    
    r = [WOResponse responseWithRequest:[self request]];
    [r setStatus:302];
    [r setHeader:homeURL forKey:@"location"];
    return r;
  }
  else {
    /* better for development */
    return [[self pageWithName:@"iCalPortalHomePage"] performPage];
  }
}

@end /* iCalPortalWelcomeAction */
