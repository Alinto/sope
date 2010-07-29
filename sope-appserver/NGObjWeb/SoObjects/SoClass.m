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

#include "SoClass.h"
#include "SoClassSecurityInfo.h"
#include "common.h"

#if APPLE_RUNTIME || NeXT_RUNTIME
@interface NSObject(Miss)
- (void)subclassResponsibility:(SEL)cmd;
@end
#endif

@implementation SoClass

static BOOL debugOn = NO;

- (id)initWithSoSuperClass:(SoClass *)_soClass {
  if ((self = [super init])) {
    self->soSuperClass = [_soClass retain];
    self->slots        = [[NSMutableDictionary alloc] init];
  }
  return self;
}
- (id)init {
  return [self initWithSoSuperClass:nil];
}

- (void)dealloc {
  [self->security     release];
  [self->slots        release];
  [self->soSuperClass release];
  [super dealloc];
}

/* hierachy */

- (SoClass *)soSuperClass {
  return self->soSuperClass;
}

/* keys (traverse hierarchy) */

- (BOOL)hasKey:(NSString *)_key inContext:(id)_ctx {
  if ([self valueForSlot:_key] != nil)
    return YES;
  
  return [self->soSuperClass hasKey:_key inContext:_ctx];
}

- (id)lookupKey:(NSString *)_key inContext:(id)_ctx {
  id value;
  
  if ((value = [self valueForSlot:_key]))
    return value;
  
  return [self->soSuperClass lookupKey:_key inContext:_ctx];
}

- (NSArray *)allKeys {
  SoClass *soClass;
  NSMutableSet *keys;
  
  keys = [NSMutableSet setWithCapacity:64];
  for (soClass = self; soClass != nil; soClass = [soClass soSuperClass])
    [keys addObjectsFromArray:[soClass slotNames]];
  return [keys allObjects];
}

/* slots (only works on the exact class) */

- (void)setValue:(id)_value forSlot:(NSString *)_key {
  if (debugOn)
    [self logWithFormat:@"set value for slot '%@': %@", _key, _value];

  if ([_key length] == 0) {
    [self logWithFormat:@"attempt to set value for invalid slot '%@'", _key];
    return;
  }
  [self->slots setObject:(_value != nil ? _value : (id)[NSNull null]) 
               forKey:_key];
}
- (id)valueForSlot:(NSString *)_key {
  id value;
  
  value = [self->slots objectForKey:_key];
  if (debugOn)
    [self logWithFormat:@"queried value for slot '%@': %@", _key, value];
  return value;
}
- (NSArray *)slotNames {
  return self->slots != nil
    ?  [self->slots allKeys] : (NSArray *)[NSArray array];
}

/* security */

- (SoClassSecurityInfo *)soClassSecurityInfo {
  if (self->security == nil)
    self->security = [[SoClassSecurityInfo alloc] initWithSoClass:self];
  return self->security;
}

- (NSException *)validateKey:(NSString *)_key inContext:(id)_ctx {
  /* 
     nil means: access fully granted 
     
     IMPORTANT: to properly support acquisition, this method must return
     nil on keys which should be acquired (since validateKey is called before
     the lookup is performed) !
  */
  NSString *r;
  
  r = [NSString stringWithFormat:@"tried to access private key %@", _key];
  return [NSException exceptionWithName:@"KeyDenied" reason:r userInfo:nil];
}

/* factory */

- (id)instantiateObject {
  [self subclassResponsibility:_cmd];
  return nil;
}

- (NSClassDescription *)soClassDescription {
  return nil;
}

- (NSString *)className {
  return nil;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* 
    This is required on OSX because the class is used as a dict-key in
    OFSFactoryRegistry.
  */
  return [self retain];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self,
        NSStringFromClass((Class)*(void**)self)];
  
  if (self->soSuperClass)
    [ms appendFormat:@" super=0x%p", self->soSuperClass];
  else
    [ms appendString:@" root"];
  
  if ([self->slots count] > 0) {
    [ms appendFormat:@" slots=%@", 
	  [[self->slots allKeys] componentsJoinedByString:@","]];
  }
  
  [ms appendString:@">"];
  return ms;
}

@end /* SoClass */
