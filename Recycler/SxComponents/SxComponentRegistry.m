/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "SxComponentRegistry.h"
#include "SxComponent.h"
#include "common.h"

@implementation SxComponentRegistry

static SxComponentRegistry *defreg = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    NSDictionary *defs;
    didInit = YES;

    defs = [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSArray arrayWithObject:@"SxXmlRpcRegBackend"],
                         @"SxComponentRegistryBackends",
                         [NSNumber numberWithInt:3],
                         @"SxComponentRetriesOnError",
                         [NSNumber numberWithInt:5],
                         @"SxComponentRetryTime",
                         nil];
    [[NSUserDefaults standardUserDefaults] registerDefaults:defs];
  }
}
+ (NSArray *)defaultRegistryBackends {
  return [[NSUserDefaults standardUserDefaults]
                          arrayForKey:@"SxComponentRegistryBackends"];
}

+ (id)defaultComponentRegistry {
  if (defreg == nil) {
    // THREAD
    defreg = [[SxComponentRegistry alloc] init];
  }
  return defreg;
}

- (id)initWithBackends:(NSArray *)_backends { /* designated initializer */
  self->credentials = [[NSMutableArray alloc] initWithCapacity:4];
  self->backends    = [_backends shallowCopy];
  self->listMethodsCache = [[NSMutableDictionary alloc] initWithCapacity:64];
  self->methodSignatureCache =
    [[NSMutableDictionary alloc] initWithCapacity:256];
  return self;
}

- (id)initWithBackendClassNames:(NSArray *)_beClasses {
  NSEnumerator   *e;
  NSString       *beClassName;
  NSMutableArray *bes;
  
  /* load backends */

  bes = [NSMutableArray arrayWithCapacity:[_beClasses count]];
  e   = [_beClasses objectEnumerator];
  while ((beClassName = [e nextObject])) {
    Class beClass;
    id be;
    
    if ((beClass = NSClassFromString(beClassName)) == Nil) {
      [self logWithFormat:@"did not find backend class '%@'", beClassName];
      continue;
    }
    
    if ((be = [[beClass alloc] init])) {
      [bes addObject:be];
      RELEASE(be);
    }
    else {
      [self logWithFormat:@"backend of class %@ wasn't initialized ...",
              NSStringFromClass(beClass)];
    }
  }
  
  return [self initWithBackends:bes];
}
- (id)init {
  return [self initWithBackendClassNames:
                 [[self class] defaultRegistryBackends]];
}

- (void)dealloc {
  RELEASE(self->methodSignatureCache);
  RELEASE(self->listMethodsCache);
  RELEASE(self->backends);
  RELEASE(self->credentials);
  
  if (self->lookupCache) {
    NSFreeMapTable(self->lookupCache);
    self->lookupCache = NULL;
  }
  [super dealloc];
}

/* callbacks */

- (void)_componentWillDealloc:(SxComponent *)_c {
  if (self->lookupCache)
    NSMapRemove(self->lookupCache, [_c componentName]);
}

- (void)_removeComponentFromLookupCache:(NSString *)_cname {
  if (self->lookupCache)
    NSMapRemove(self->lookupCache, _cname);
}

/* getting components */

- (id<NSObject,SxComponent>)getComponent:(NSString *)_namespace {
  NSAutoreleasePool *pool;
  SxComponent *c;
  NSEnumerator *e;
  id           backend;
  
  if (self->lookupCache == NULL) {
    self->lookupCache = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                         NSNonRetainedObjectMapValueCallBacks,
                                         64);
  }
  
  if ((c = NSMapGet(self->lookupCache, _namespace))) {
    return c;
  }
  
  pool = [[NSAutoreleasePool alloc] init];

  e = [self->backends objectEnumerator];

  while((backend = [e nextObject])) {
    if ([backend registry:self canHandleNamespace:_namespace]) {
      c = [backend registry:self getComponent:_namespace];
      break;
    }
  }

  if (c) NSMapInsert(self->lookupCache, [c componentName], c);
  
  RETAIN(c);
  RELEASE(pool);

  return AUTORELEASE(c);
}

/* returns the names of the available components */

- (NSArray *)listComponents:(NSString *)_path {
  NSMutableArray *results;
  NSEnumerator *e;
  id backend;
  
  results = nil;
  e = [self->backends objectEnumerator];
  while ((backend = [e nextObject])) {
    NSArray *r;
    
    if ((r = [backend registry:self listComponents:_path])) {
      if (results == nil)
        results = [NSMutableArray arrayWithCapacity:128];
      [results addObjectsFromArray:r];
    }
  }
  return results;
}
- (NSArray *)listComponents {
  return [self listComponents:nil];
}

- (NSArray *)listMethods:(NSString *)_component {
  NSEnumerator *e;
  id           backend;
  NSArray      *result;

  if ([_component length] == 0)
    return nil;

  /* check cache */
  if ((result = [self->listMethodsCache objectForKey:_component]))
    return AUTORELEASE(RETAIN(result));

  /* let backends make reflection */
  e = [self->backends objectEnumerator];
  while((backend = [e nextObject])) {
    if ([backend registry:self canHandleNamespace:_component]) {
      result = [backend registry:self listMethods:_component];
      break;
    }
  }

  /* store in cache */
  if (result)
    [self->listMethodsCache setObject:result forKey:_component];
  
  return result;
}

- (NSArray *)methodSignature:(NSString *)_component method:(NSString *)_name {
  NSEnumerator *e;
  id           backend;
  NSString     *key;
  NSArray      *result;

  /* check cache */
  key = [NSString stringWithFormat:@"%@\n%@", _name, _component];
  if ((result = [self->methodSignatureCache objectForKey:key]))
    return AUTORELEASE(RETAIN(result));

  /* perform operation */
  e = [self->backends objectEnumerator];
  while((backend = [e nextObject])) {
    if ([backend registry:self canHandleNamespace:_component]) {
      result = [backend registry:self methodSignature:_component method:_name];
      break;
    }
  }

  /* store in cache */
  if (result)
    [self->methodSignatureCache setObject:result forKey:key];
  
  return result;
}

- (NSString *)methodHelp:(NSString *)_component method:(NSString *)_name {
  NSEnumerator *e;
  id           backend;

  e = [self->backends objectEnumerator];
  
  while((backend = [e nextObject])) {
    if ([backend registry:self canHandleNamespace:_component]) {
      return [backend registry:self methodHelp:_component method:_name];
    }
  }
  return nil;
}

/* component registration */

- (BOOL)registerComponent:(SxComponent *)_component {
  if (_component == nil) return YES;
  return NO;
}
- (BOOL)unregisterComponent:(SxComponent *)_component {
  if (_component == nil) return YES;
  return NO;
}

/* caching */

- (SxComponent *)getCachedComponent:(NSString *)_namespace {
  if (self->lookupCache == NULL) return nil;
  return NSMapGet(self->lookupCache, _namespace);
}
- (void)flush {
  if (self->lookupCache)
    NSResetMapTable(self->lookupCache);
  
  [self->listMethodsCache     removeAllObjects];
  [self->methodSignatureCache removeAllObjects];
}

/* component retries on error (failover) */

- (NSUserDefaults *)userDefaults {
  return [NSUserDefaults standardUserDefaults];
}

- (int)componentRetryCountOnError {
  return [[[self userDefaults]
                 valueForKey:@"SxComponentRetriesOnError"]
                 intValue];
}

- (int)componentRetryTime {
  return [[[self userDefaults]
                 valueForKey:@"SxComponentRetryTime"]
                 intValue];
}

/* credentials */

- (NSArray *)credentials {
  return self->credentials;
}

- (void)addCredentials:(id)_creds {
  if (_creds == nil) {
    [self logWithFormat:@"warning: passed <nil> to -addCredentials: ..."];
    return;
  }

  [self->credentials addObject:_creds];
}
- (void)removeCredentials:(id)_creds {
  [self->credentials removeObject:_creds];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:self->backends];
}
- (id)initWithCoder:(NSCoder *)_coder {
  self->credentials = [[NSMutableArray alloc] initWithCapacity:4];
  self->backends = [[_coder decodeObject] retain];
  return self;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<0x%p[%@]: backends=%@>",
                     self, NSStringFromClass([self class]),
                     self->backends];
}

@end /* SxComponentRegistry */
