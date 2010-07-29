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

#include "SoClassRegistry.h"
#include "SoObjCClass.h"
#include "common.h"

@implementation SoClassRegistry

// TODO: register for bundle-did-load notification !!
static SoClassRegistry *registry = nil; // THREAD

+ (id)sharedClassRegistry {
  if (registry == nil)
    registry = [[SoClassRegistry alloc] init];
  return registry;
}
- (id)init {
  if ((self = [super init])) {
    self->objcToSoClass = [[NSMutableDictionary alloc] initWithCapacity:64];
    self->extToSoClass  = [[NSMutableDictionary alloc] initWithCapacity:32];
    self->nameToSoClass = [[NSMutableDictionary alloc] initWithCapacity:32];
  }
  return self;
}

- (void)dealloc {
  [self->extToSoClass  release];
  [self->nameToSoClass release];
  [self->objcToSoClass release];
  [super dealloc];
}

/* name registry */

- (SoClass *)soClassWithName:(NSString *)_name {
  Class clazz;
  
  if ([_name length] == 0) return nil;
  
  if ((clazz = NSClassFromString(_name)))
    return [self soClassForClass:clazz];
  
  return nil;
}

- (SoClass *)soClassForExtension:(NSString *)_ext {
  SoClass *soClass;
  
  if ((soClass = [self->extToSoClass objectForKey:_ext]) == nil)
    return nil;

  return soClass;
}
- (NSException *)registerSoClass:(SoClass *)_clazz forExtension:(NSString *)_e{
  SoClass *soClass;
  
  NSAssert(_clazz, @"invalid class parameter !");
  NSAssert(_e,     @"invalid file extension parameter !");
  
  if ((soClass = [self->extToSoClass objectForKey:_e])) {
    if (soClass == _clazz)
      /* already registered */
      return nil;
    
    [self debugWithFormat:
	    @"overriding existing registration for extension '%@': %@",
	    _e, soClass];
  }
  
  [self->extToSoClass setObject:_clazz forKey:_e];
  return nil;
}

- (SoClass *)soClassForExactName:(NSString *)_name {
  SoClass *soClass;
  
  if ((soClass = [self->nameToSoClass objectForKey:_name]) == nil)
    return nil;

  return soClass;
}
- (NSException *)registerSoClass:(SoClass *)_clazz forExactName:(NSString *)_n{
  SoClass *soClass;
  
  NSAssert(_clazz, @"invalid class parameter !");
  NSAssert(_n,     @"invalid file extension parameter !");
  
  if ((soClass = [self->nameToSoClass objectForKey:_n])) {
    if (soClass == _clazz)
      /* already registered */
      return nil;
    
    [self debugWithFormat:
	    @"overriding existing registration for name '%@': %@",
	    _n, soClass];
  }
  
  [self->nameToSoClass setObject:_clazz forKey:_n];
  return nil;
}

/* ObjC classes */

- (SoClass *)soClassForClass:(Class)_clazz {
  SoObjCClass *soClass;
  SoClass     *soSuper;
  
  if (_clazz == Nil)
    return nil;
  if ((soClass = [self->objcToSoClass objectForKey:_clazz]))
    return soClass;
  
  soSuper = [self soClassForClass:[_clazz superclass]];
  soClass = [[SoObjCClass alloc] initWithSoSuperClass:soSuper class:_clazz];
  
  if (soClass == nil) {
    [self debugWithFormat:@"could not create SoClass for class %@ !", _clazz];
    return nil;
  }
  [self->objcToSoClass setObject:soClass forKey:_clazz];
  [soClass rescanClass];
  [self debugWithFormat:@"mapped class %@ to SoClass %@", 
	  NSStringFromClass(_clazz), soClass];
  return [soClass autorelease];
}

@end /* SoClassRegistry */

@implementation SoClassRegistry(Logging)

- (NSString *)loggingPrefix {
  return @"[so-class-registry]";
}
- (BOOL)isDebuggingEnabled {
  static int debugOn = -1;
  if (debugOn == -1) {
    debugOn = [[NSUserDefaults standardUserDefaults]
		boolForKey:@"SoClassRegistryDebugEnabled"] ? 1 : 0;
  }
  return debugOn ? YES : NO;
}

@end /* SoClassRegistry(Logging) */
