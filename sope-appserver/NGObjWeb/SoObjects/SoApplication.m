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

#include "SoApplication.h"
#include "SoClassRegistry.h"
#include "SoControlPanel.h"
#include "SoObject.h"
#include "SoObjectRequestHandler.h"
#include "SoProductRegistry.h"
#include "SoSecurityManager.h"
#include "SoApplication.h"
#include "SoObject+SoDAV.h"
#include <NGObjWeb/WORequest.h>
#include "common.h"

@implementation SoApplication

static BOOL debugLookup = NO;

- (BOOL)loadProducts:(id)_spec  {
  if (_spec != nil) {
    // TODO: only load specified products
    [self logWithFormat:@"load products (not implemented): %@", _spec];
    return NO;
  }
  else
    [self->productRegistry loadAllProducts];
  
  return YES;
}

- (id)init {
  if ((self = [super init])) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    id tmp;
    
    debugLookup = [ud boolForKey:@"SoDebugKeyLookup"];
    
    /* setup global objects */
    
    self->securityManager = [[SoSecurityManager sharedSecurityManager] retain];
    self->classRegistry   = [[SoClassRegistry sharedClassRegistry] retain];
    self->productRegistry = [[SoProductRegistry sharedProductRegistry] retain];
    
    /* Object Publishing */
    tmp = [[SoObjectRequestHandler alloc] init];
    [self registerRequestHandler:tmp forKey:@"so"];
    [self registerRequestHandler:tmp forKey:@"dav"];
    [self registerRequestHandler:tmp forKey:@"RPC2"];
    [self setDefaultRequestHandler:tmp];
    [tmp release];
    
    /* load products (all if SoApplicationLoadProducts is not set) */
    if (![self loadProducts:[ud objectForKey:@"SoApplicationLoadProducts"]]) {
      [self logWithFormat:@"failed to load the products ..."];
      [self release];
      return nil;
    }
    
#if LIB_FOUNDATION_LIBRARY
    /* debugging */
    if ([[ud objectForKey:@"EnableDoubleReleaseCheck"] boolValue])
      [NSAutoreleasePool enableDoubleReleaseCheck:YES];
#endif
  }
  return self;
}

- (void)dealloc {
  [self->securityManager release];
  [self->classRegistry   release];
  [self->productRegistry release];
  [super dealloc];
}

/* accessors */

- (SoProductRegistry *)productRegistry {
  return self->productRegistry;
}
- (SoClassRegistry *)classRegistry {
  return self->classRegistry;
}
- (SoSecurityManager *)securityManager {
  return self->securityManager;
}

/* application as the SoObject root */

- (id)rootObjectInContext:(id)_ctx {
  return nil;
}

- (NSException *)validateName:(NSString *)_key inContext:(id)_ctx {
  id root;
  
  if ([self hasName:_key inContext:_ctx])
    return [super validateName:_key inContext:_ctx];
  
  root = [self rootObjectInContext:_ctx];
  return (root != self) 
    ? [root validateName:_key inContext:_ctx] 
    : [super validateName:_key inContext:_ctx];
}

- (BOOL)hasName:(NSString *)_key inContext:(id)_ctx {
  id root;
  
  if ([_key isEqualToString:@"ControlPanel"])
    return YES;
  
  if ([[self registeredRequestHandlerKeys] containsObject:_key])
    return YES;
  
  if ([super hasName:_key inContext:_ctx])
    return YES;
  
  root = [self rootObjectInContext:_ctx];
  if (root != self)
    return [root hasName:_key inContext:_ctx];
  
  return NO;
}

- (id)controlPanel:(NSString *)_name inContext:(id)_ctx {
  return [[[SoControlPanel alloc] init] autorelease];
}

- (BOOL)isApplicationNameLookup:(NSString *)_name inContext:(id)_ctx {
  static NSString *WOApplicationSuffix = nil;
  NSString *appName;

  appName = [[(WOContext *)_ctx request] applicationName];
  if ([_name isEqual:appName]) {
    if (debugLookup) [self logWithFormat:@"  matched appname: %@", appName];
    return YES;
  }

  if (WOApplicationSuffix == nil) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    WOApplicationSuffix = [[ud stringForKey:@"WOApplicationSuffix"] copy];
  }
  appName = [appName stringByAppendingString:WOApplicationSuffix];
  if ([_name isEqual:appName]) {
    if (debugLookup) [self logWithFormat:@"  matched appname: %@", appName];
    return YES;
  }
  
  return NO;
}

- (id)lookupName:(NSString *)_name inContext:(id)_ctx acquire:(BOOL)_flag {
  id v;
  
  if ([_name isEqualToString:@"ControlPanel"])
    return [self controlPanel:_name inContext:_ctx];
  
  if ([[self registeredRequestHandlerKeys] containsObject:_name]) {
    /* 
      need to check registeredRequestHandlerKeys because requestHandlerForKey:
      returns the default handler if the key could not be found ...
    */
    if ((v = [super requestHandlerForKey:_name]))
      return v;
  }
  
  if (debugLookup) [self logWithFormat:@"lookup name: %@", _name];
  
  if ((v = [super lookupName:_name inContext:_ctx acquire:NO]) == nil) {
    id root;
    
    root = [self rootObjectInContext:_ctx];
    if (debugLookup) [self logWithFormat:@"  lookup in root object: %@", v];
    
    if (root != self)
      v = [root lookupName:_name inContext:_ctx acquire:_flag];
    else if (debugLookup)
      [self logWithFormat:@"  root is application object"];
  }
  
  if (debugLookup) [self logWithFormat:@"  GOT: %@", v];
  
  /* 
     hack to allow "/myapp/folder/", it is a hack because it also allows
     /myapp/myapp/myapp/.../folder/ ...
  */
  if (v == nil && [self isApplicationNameLookup:_name inContext:_ctx]) {
    v = self;
    if (debugLookup) [self logWithFormat:@"  => rewrote value: %@", self];
  }
  
  return v;
}

- (NSArray *)toOneRelationshipKeys {
  NSMutableSet *ma;
  id root;
  
  ma = ((root = [super toOneRelationshipKeys]))
    ? [[NSMutableSet alloc] initWithArray:root]
    : [[NSMutableSet alloc] init];
  
  [ma addObjectsFromArray:[self registeredRequestHandlerKeys]];
  [ma addObject:@"ControlPanel"];
  
  root = [self rootObjectInContext:[self context]];
  if (root != nil && (root != self)) 
    [ma addObjectsFromArray:[root toOneRelationshipKeys]];
  
  root = [ma allObjects];
  [ma release];
  return root;
}

/* WebDAV support for root objects */

- (id)davCreateObject:(NSString *)_name
  properties:(NSDictionary *)_props
  inContext:(id)_ctx
{
  id root;

  if ((root = [self rootObjectInContext:_ctx]) == nil)
    return [super davCreateObject:_name properties:_props inContext:_ctx];
  
  return [root davCreateObject:_name properties:_props inContext:_ctx];
}

- (NSException *)davCreateCollection:(NSString *)_name inContext:(id)_ctx {
  id root;

  if ((root = [self rootObjectInContext:_ctx]) == nil)
    return [super davCreateCollection:_name inContext:_ctx];
  
  //[self debugWithFormat:@"let root '%@' create collection '%@'", root,_name];
  return [root davCreateCollection:_name inContext:_ctx];
}

@end /* SoApplication */
