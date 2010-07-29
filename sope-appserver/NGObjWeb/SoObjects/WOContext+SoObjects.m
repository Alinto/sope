/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "WOContext+SoObjects.h"
#include "SoObjectRequestHandler.h"
#include "SoObject.h"
#include "SoUser.h"
#include "SoSubContext.h"
#include "SoSecurityManager.h"
#include "SoHTTPAuthenticator.h"
#include <NGObjWeb/WOComponent.h>
#include "common.h"

@implementation WOContext(SoSecurityManager)

- (SoSecurityManager *)soSecurityManager {
  return [SoSecurityManager sharedSecurityManager];
}

@end /* WOContext(SoSecurityManager) */

@implementation WOContext(SoObjectRequestHandler)

static BOOL debugOn = NO;

- (void)setClientObject:(id)_object {
  if (debugOn) [self logWithFormat:@"set client: %@", _object];
  ASSIGN(self->clientObject, _object);
}
- (id)clientObject {
  return self->clientObject;
}

- (void)addObjectToTraversalStack:(id)_object {
  if (self->traversalStack == nil)
    self->traversalStack = [[NSMutableArray alloc] initWithCapacity:16];
  [self->traversalStack addObject:
	 (_object != nil ? _object : (id)[NSNull null])];
}

- (id)traversalRoot {
  unsigned count;
  if ((count = [self->traversalStack count]) == 0)
    return nil;
  return [self->traversalStack objectAtIndex:0];
}

- (NSArray *)objectTraversalStack {
  return self->traversalStack;
}

- (void)setRootURL:(NSString *)_url {
  ASSIGNCOPY(self->rootURL, _url);
}
- (NSString *)rootURL {
  return self->rootURL;
}

- (void)setObjectPermissionCache:(id)_cache {
  ASSIGN(self->objectPermissionCache, _cache);
}
- (id)objectPermissionCache {
  return self->objectPermissionCache;
}

- (void)setActiveUser:(id)_user {
  ASSIGN(self->activeUser, _user);
}
- (id)activeUser {
  if (self->activeUser == nil) {
    /* can only do that if a clientObject is already set */
    id client, auth;
    
    if ((client = [self clientObject]) != nil) {
      auth = [[self clientObject] authenticatorInContext:self];
      self->activeUser = [[auth userInContext:self] retain];
    
      if (self->activeUser == nil) {
	if (auth == nil) {
	  [self warnWithFormat:@"Got no authenticator from clientObject: %@",
	          [self clientObject]];
	}
	else
	  [self warnWithFormat:@"Got no user from authenticator: %@", auth];
      }
    }
  }
  return [self->activeUser isNotNull] ? self->activeUser : nil;
}

- (void)setObjectDispatcher:(id)_dispatcher {
  ASSIGN(self->objectDispatcher, _dispatcher);
}
- (id)objectDispatcher {
  return self->objectDispatcher;
}

- (void)setSoRequestType:(NSString *)_rqType {
  ASSIGNCOPY(self->soRequestType, _rqType);
}
- (NSString *)soRequestType {
  return self->soRequestType;
}

- (void)setSoRequestTraversalPath:(NSArray *)_path {
  // TODO: add ivar
  [self setObject:_path forKey:@"SoRequestTraversalPath"];
}
- (NSArray *)soRequestTraversalPath {
  return [self objectForKey:@"SoRequestTraversalPath"];
}

- (void)setPathInfo:(NSString *)_pi {
  ASSIGNCOPY(self->pathInfo, _pi);
}
- (NSString *)pathInfo {
  return self->pathInfo;
}

/* subcontexts */

- (SoSubContext *)createSubContext {
  return [[[SoSubContext alloc] initWithParentContext:self] autorelease];
}
- (WOContext *)parentContext {
  return nil;
}
- (WOContext *)rootContext {
  return self;
}

@end /* WOContext(SoObjectRequestHandler) */
