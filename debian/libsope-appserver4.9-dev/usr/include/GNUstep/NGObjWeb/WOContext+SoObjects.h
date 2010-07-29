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

#ifndef __SoObjects_WOContext_SoObjects_H__
#define __SoObjects_WOContext_SoObjects_H__

#include <NGObjWeb/WOContext.h>

/*
  WOContext(SoObjects)
  
  The WOContext is the central access point for SOPE too. It has several new
  variables representing publishing state like the client object or the
  traversal path. You also access global SOPE objects using the context, for
  example the security manager.
*/

@class NSArray;
@class SoSecurityManager, SoSubContext;

@interface WOContext(SoObjects)

/* security */

- (SoSecurityManager *)soSecurityManager;

/* traversal */

- (void)addObjectToTraversalStack:(id)_object;
- (NSArray *)objectTraversalStack;
- (id)traversalRoot;

- (void)setClientObject:(id)_object;
- (id)clientObject;

- (void)setObjectDispatcher:(id)_dispatcher;
- (id)objectDispatcher;

- (void)setSoRequestType:(NSString *)_rqType;
- (NSString *)soRequestType;
- (void)setSoRequestTraversalPath:(NSArray *)_path;
- (NSArray *)soRequestTraversalPath;

- (void)setPathInfo:(NSString *)_pi;
- (NSString *)pathInfo;

- (void)setRootURL:(NSString *)_url;
- (NSString *)rootURL;

- (void)setObjectPermissionCache:(id)_cache;
- (id)objectPermissionCache;

- (void)setActiveUser:(id)_user;
- (id)activeUser;

/* subcontexts */

- (SoSubContext *)createSubContext;
- (WOContext *)parentContext;
- (WOContext *)rootContext;

@end

/* all the following methods are convenience methods that access WOContext */

#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WODirectAction.h>

@interface WOComponent(SoObjects)
- (void)setClientObject:(id)_object;
- (id)clientObject;
@end

@interface WODirectAction(SoObjects)
- (id)clientObject;
@end

#endif /* __SoObjects_WOContext_SoObjects_H__ */
