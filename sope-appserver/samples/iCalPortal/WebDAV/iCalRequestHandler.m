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

#include "iCalRequestHandler.h"
#include "iCalPortalUser.h"
#include "iCalPortalDatabase.h"

#include "iCalAction.h"
#include "iCalPublishAction.h"
#include "iCalDeleteAction.h"
#include "iCalGetAction.h"
#include "iCalLockAction.h"
#include "iCalOptionsAction.h"

#include "common.h"

@implementation iCalRequestHandler

+ (int)version {
  return [super version] + 0 /* 2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}


/*
  The request handler part of an ical action URI looks like this:

    user-login/calendar-name
*/

- (BOOL)restoreSessionUsingIDs {
  return NO;
}
- (BOOL)autocreateSessionForRequest:(WORequest *)_request {
  return NO;
}
- (BOOL)requiresSessionForRequest:(WORequest *)_request {
  return NO;
}

- (WOResponse *)handleRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
  session:(WOSession *)session
  application:(WOApplication *)app
{
  iCalAction *action;
  NSString   *userAgent;
  NSString   *m;
  id         creds;
  
  userAgent = [_request headerForKey:@"user-agent"];
  m = [[_request method] uppercaseString];

  if ([m isEqualToString:@"GET"])
    action = [[iCalGetAction alloc] initWithContext:_ctx];
  else if ([m isEqualToString:@"PUT"])
    action = [[iCalPublishAction alloc] initWithContext:_ctx];
  else if ([m isEqualToString:@"POST"])
    action = [[iCalPublishAction alloc] initWithContext:_ctx];
  else if ([m isEqualToString:@"DELETE"])
    action = [[iCalDeleteAction alloc] initWithContext:_ctx];
  else if ([m isEqualToString:@"LOCK"])
    action = [[iCalLockAction alloc] initWithContext:_ctx];
  else if ([m isEqualToString:@"OPTIONS"])
    action = [[iCalOptionsAction alloc] initWithContext:_ctx];
  
  else if ([m isEqualToString:@"MKCOL"]) {
    action = [[iCalFakeAction alloc] initWithContext:_ctx 
				     code:405 /* method not allowed */];
  }
  else if ([m isEqualToString:@"PROPFIND"]) {
    [self debugWithFormat:@"PROPFIND:\n%@\n--------",
	    [_request contentAsString]];
    action = [[iCalFakeAction alloc] initWithContext:_ctx 
				     code:200 /* method not allowed */];
  }
  
  else {
    [self logWithFormat:@"cannot handle HTTP method: '%@'", m];
    return nil;
  }
  
  action = [action autorelease];
  if ((creds = [_request headerForKey:@"authorization"]) == nil)
    return [action missingAuthResponse];
  
  return [action run];
}

/* logging */

- (NSString *)loggingPrefix {
  return @"[ical-handler]";
}

- (BOOL)isDebuggingEnabled {
  return YES;
}

@end /* iCalRequestHandler */
