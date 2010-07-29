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

#include "OFSResourceManager.h"
#include "OFSBaseObject.h"
#include <NGObjWeb/WOComponentDefinition.h>
#include "common.h"

@interface WOResourceManager(UsedPrivates)
- (WOComponentDefinition *)definitionForComponent:(id)_name
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages;
@end

@interface WOComponentDefinition(UsedPrivates)
- (void)setComponentClass:(Class)_clazz;
@end

@interface WOComponent(RM)
- (void)setResourceManager:(WOResourceManager *)_rm;
@end

@implementation OFSResourceManager

static BOOL debugOn = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn = [ud boolForKey:@"SoOFSResourceManagerDebugEnabled"];
}

- (id)initWithBaseObject:(id)_object inContext:(id)_ctx {
  if ((self = [super init])) {
    self->baseObject = _object;
    self->context    = _ctx;
    
    if (self->baseObject == nil) {
      [self release];
      return nil;
    }
    
    if (self->context == nil)
      [self debugWithFormat:@"WARNING: got not context !"];
  }
  return self;
}

- (void)dealloc {
  [super dealloc];
}

- (void)invalidate {
  self->baseObject = nil;
  self->context    = nil;
}

/* accessors */

- (id)context {
  if (self->context == nil)
    return [(WOApplication *)[WOApplication application] context];
  return self->context;
}

/* base object lookup */

- (BOOL)doesAcquireResources {
  return YES;
}

- (id)soObjectForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
{
  id resourceObject;
  
  if (debugOn) {
    [self debugWithFormat:@"lookup resource object named '%@' in %@",
            _name, self->baseObject];
  }
  
  if ([self doesAcquireResources]) {
    NSException *error = nil;
    id subctx;
    
    /* 
       Note: this will first look into the object traversal stack of the
             context which might be different to the base object!
	     e.g. its common to use the resource manager on the container
	     of the clientObject (baseObject==container) instead of the
	     object itself.
    */
    subctx = [[self context] createSubContext];
    resourceObject = [self->baseObject 
                          traverseKey:_name
                          inContext:subctx
                          error:&error
                          acquire:YES];
    if (error) {
      if (debugOn) {
	[self debugWithFormat:@"  name: %@", _name];
	[self debugWithFormat:@"  base: %@", self->baseObject];
	[self debugWithFormat:@"  ctx:  %@", subctx];
      }
      [self logWithFormat:@"ERROR: %@", error];
    }
  }
  else {
    resourceObject = [self->baseObject lookupName:_name 
                                       inContext:[self context]
                                       acquire:YES];
  }
  
  if (debugOn)
    [self debugWithFormat:@"  found: %@", resourceObject];
  return resourceObject;
}

/* components */

- (WOComponentDefinition *)definitionForComponent:(id)_name
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages
{
  WOComponentDefinition *cdef;
  NSRange               r;
  NSString              *name;
  Class                 cClass;

  cdef = [super definitionForComponent:_name
		inFramework:_framework
		languages:_languages];
  r = [_name rangeOfString:@"."];
  if (r.length > 0)
    name = [_name substringToIndex:r.location];
  else 
    name = _name;
  
  cClass = NSClassFromString(name);
  if (cClass == Nil)
    cClass = NSClassFromString(@"WOComponent");

  [cdef setComponentClass:cClass];
  return cdef;
}

/* resource manager methods */

- (NSString *)forcedComponentExtension {
  /* the content negotiation should select an extension for us ! */
  return nil;
}

- (NSString *)resourceNameForComponentNamed:(NSString *)_name {
  NSString *ext;
  
  if ((ext = [self forcedComponentExtension])) {
    if ([[_name pathExtension] length] == 0)
      _name = [_name stringByAppendingPathExtension:ext];
  }
  return _name;
}

- (NSString *)pathForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_fw
  languages:(NSArray *)_langs
{
  // TODO: add a cache
  id obj;
  
  obj = [self soObjectForResourceNamed:_name inFramework:_fw languages:_langs];
  if (obj == nil)
    [self debugWithFormat:@"found no resource object named '%@'", _name];
  else
    [self debugWithFormat:@"found resource object '%@': %@", _name, obj];
  
  return [obj storagePath];
}

- (NSString *)urlForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_fw
  languages:(NSArray *)_langs
  request:(WORequest *)_request
{
  // TODO: add a cache
  id obj;
  
  obj = [self soObjectForResourceNamed:_name inFramework:_fw languages:_langs];
  if (obj == nil)
    [self logWithFormat:@"found no object named '%@'", _name];
  
  return [obj baseURLInContext:[self context]];
}

- (id)pageWithName:(NSString *)_name languages:(NSArray *)_langs {
  WOComponent *p;
  
  p = [super pageWithName:_name languages:_langs];
  [p setResourceManager:self];
  return p;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->baseObject) 
    [ms appendFormat:@" base=%@", self->baseObject];
  if (self->context) 
    [ms appendFormat:@" ctx=0x%p", self->context];
  
  [ms appendString:@">"];
  return ms;
}

@end /* OFSResourceManager */
