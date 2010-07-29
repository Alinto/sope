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

#include "EOClassDescription.h"
#include "EOKeyValueCoding.h"
#include "EONull.h"
#include "common.h"

@implementation NSClassDescription(EOClassDescription)

/* model */

- (NSString *)entityName {
  return nil;
}
- (NSString *)inverseForRelationshipKey:(NSString *)_key {
  return nil;
}

- (NSClassDescription *)classDescriptionForDestinationKey:(NSString *)_key {
  return nil;
}

/* object initialization */

- (id)createInstanceWithEditingContext:(id)_ec
  globalID:(EOGlobalID *)_oid
  zone:(NSZone *)_zone
{
  return nil;
}

- (void)awakeObject:(id)_object
  fromFetchInEditingContext:(id)_ec
{
}
- (void)awakeObject:(id)_object
  fromInsertionInEditingContext:(id)_ec
{
}

/* formatting */

- (NSFormatter *)defaultFormatterForKey:(NSString *)_key {
  return nil;
}
- (NSFormatter *)defaultFormatterForKeyPath:(NSString *)_keyPath {
  return nil;
}

/* delete */

- (void)propagateDeleteForObject:(id)_object editingContext:(id)_ec {
}

@end /* NSClassDescription(EOClassDescription) */

@implementation EOClassDescription

// THREAD
static NSMapTable *entityToDesc = NULL;
static NSMapTable *classToDesc  = NULL;

+ (void)initialize {
  if (entityToDesc == NULL) {
    entityToDesc = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                    NSObjectMapValueCallBacks,
                                    32);
  }
  if (classToDesc == NULL) {
    classToDesc = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                   NSObjectMapValueCallBacks,
                                   32);
  }
}

+ (NSClassDescription *)classDescriptionForClass:(Class)_class
{
  EOClassDescription *d;

#if DEBUG
  NSAssert(_class != [EOGlobalID class],
           @"classDescriptionForClass:EOGlobalID ???");
#endif
  
  if ((d = NSMapGet(classToDesc, _class)))
    return d;
  
  [[NSNotificationCenter defaultCenter]
                         postNotificationName:
                           @"EOClassDescriptionNeededForClass"
                         object:_class];
  
  return NSMapGet(classToDesc, _class);
}

+ (NSClassDescription *)classDescriptionForEntityName:(NSString *)_entityName {
  NSClassDescription *d;
  
  if ((d = NSMapGet(entityToDesc, _entityName)))
    return d;

  [[NSNotificationCenter defaultCenter]
                         postNotificationName:
                           @"EOClassDescriptionNeededForEntityName"
                         object:_entityName];
  
  return NSMapGet(entityToDesc, _entityName);
}

+ (void)invalidateClassDescriptionCache {
  NSResetMapTable(entityToDesc);
  NSResetMapTable(classToDesc);
}

+ (void)registerClassDescription:(NSClassDescription *)_clazzDesc
  forClass:(Class)_class
{
  NSString *entityName;
  
  if (_clazzDesc == nil)
    return;
  
  if (_class)
    NSMapInsert(classToDesc,  _class, _clazzDesc);
  
  if ((entityName = [_clazzDesc entityName]))
    NSMapInsert(entityToDesc, entityName, _clazzDesc);
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: entity=%@>",
                     NSStringFromClass([self class]), self,
                     [self entityName]];
}

@end /* EOClassDescription */

@implementation NSObject(EOClassDescription)

- (NSClassDescription *)classDescriptionForDestinationKey:(NSString *)_key {
  return [[self classDescription] classDescriptionForDestinationKey:_key];
}

/* object initialization */

- (id)initWithEditingContext:(id)_ec
  classDescription:(NSClassDescription *)_classDesc
  globalID:(EOGlobalID *)_oid
{
  return [self init];
}

- (void)awakeFromFetchInEditingContext:(id)_ec {
  [[self classDescription]
         awakeObject:self fromFetchInEditingContext:_ec];
}
- (void)awakeFromInsertionInEditingContext:(id)_ec {
  [[self classDescription]
         awakeObject:self fromInsertionInEditingContext:_ec];
}

/* model */

- (NSString *)entityName {
  return [[self classDescription] entityName];
}
- (NSString *)inverseForRelationshipKey:(NSString *)_key {
  return [[self classDescription] inverseForRelationshipKey:_key];
}
- (NSArray *)attributeKeys {
  return [[self classDescription] attributeKeys];
}

- (BOOL)isToManyKey:(NSString *)_key {
  return [[self toManyRelationshipKeys] containsObject:_key];
}
- (NSArray *)allPropertyKeys {
  NSArray *attrs;

  attrs = [self attributeKeys];
  attrs = attrs
    ? [attrs arrayByAddingObjectsFromArray:[self toOneRelationshipKeys]]
    : [self toOneRelationshipKeys];
  attrs = attrs
    ? [attrs arrayByAddingObjectsFromArray:[self toManyRelationshipKeys]]
    : [self toManyRelationshipKeys];

  return attrs;
}

/* delete */

- (void)propagateDeleteWithEditingContext:(id)_ec {
  [[self classDescription] propagateDeleteForObject:self editingContext:_ec];
}

@end /* NSObject(EOClassDescription) */

@implementation NSException(EOValidation)

+ (NSException *)aggregateExceptionWithExceptions:(NSArray *)_exceptions {
  NSException *e;

  e = [[self alloc] initWithName:@"EOAggregateException"
                    reason:@"several exceptions occured"
                    userInfo:
                      [NSDictionary dictionaryWithObject:_exceptions
                                    forKey:@"exceptions"]];
  return [e autorelease];
}

@end /* NSException(EOValidation) */

/* snapshots */

@implementation NSObject(EOSnapshots)

- (NSDictionary *)snapshot {
  static NSNull *null = nil;
  NSMutableDictionary *d;
  NSDictionary *r;
  NSEnumerator *e;
  NSString *key;

  if (null == nil) null = [NSNull null];
  
  d = [[NSMutableDictionary alloc] initWithCapacity:64];
  
  e = [[self attributeKeys] objectEnumerator];
  while ((key = [e nextObject])) {
    id value;

    value = [self valueForKey:key];
    value = (value == nil) ? (id)[null retain] : (id)[value copy];
    [d setObject:value forKey:key];
    [value release]; value = nil;
  }
  
  e = [[self toOneRelationshipKeys] objectEnumerator];
  while ((key = [e nextObject])) {
    id value;

    value = [self valueForKey:key];
    if (value == nil) value = [NSNull null];

    [d setObject:value forKey:key];
  }
  
  e = [[self toManyRelationshipKeys] objectEnumerator];
  while ((key = [e nextObject])) {
    id value;

    value = [self valueForKey:key];
    if (value == nil) {
      value = [[NSNull null] retain];
    }
    else {
      value = [value shallowCopy];
    }
    [d setObject:value forKey:key];
    [value release]; value = nil;
  }
  
  r = [d copy];
  [d release]; d = nil;
  return [r autorelease];
}

- (void)updateFromSnapshot:(NSDictionary *)_snapshot {
  [self takeValuesFromDictionary:_snapshot];
}

- (NSDictionary *)changesFromSnapshot:(NSDictionary *)_snapshot {
  /* not really correct, need to work on relationships */
  static NSNull *null = nil;
  NSMutableDictionary *diff;
  NSEnumerator *props;
  NSString     *key;
  
  if (null == nil) null = [NSNull null];
  
  diff = [NSMutableDictionary dictionaryWithCapacity:32];
  
  props = [[self allPropertyKeys] objectEnumerator];
  while ((key = [props nextObject])) {
    id value;
    id svalue;
    
    value  = [self valueForKey:key];
    svalue = [_snapshot objectForKey:key];
    if (value  == nil) value  = null;
    if (svalue == nil) svalue = null;

    if (svalue != value) {
      /* difference */
      if ([self isToManyKey:key]) {
        id adiff[2];

        adiff[0] = [NSArray array];
        adiff[1] = [NSArray array];

        /* to be completed: calc real diff */
        
        [diff setObject:[NSArray arrayWithObjects:adiff count:2] forKey:key];
      }
      else
        [diff setObject:value forKey:key];
    }
  }
  
  return diff;
}

- (void)reapplyChangesFromDictionary:(NSDictionary *)_changes {
  /* not really correct, need to work on relationships */
  NSEnumerator *keys;
  NSString *key;

  keys = [_changes keyEnumerator];
  while ((key = [keys nextObject])) {
    id value;
    
    value = [_changes objectForKey:key];

    if ([self isToManyKey:key]) {
      NSArray        *added;
      NSArray        *deleted;
      NSMutableArray *current;

      added   = [value objectAtIndex:0];
      deleted = [value objectAtIndex:1];
      current = [[self valueForKey:key] mutableCopy];
      
      if (added)   [current addObjectsFromArray:added];
      if (deleted) [current removeObjectsInArray:deleted];
      
      [current release]; current = nil;
    }
    else
      [self takeValue:value forKey:key];
    
    [self takeValuesFromDictionary:_changes];
  }
}

@end /* NSObject(EOSnapshots) */

/* relationships */

@implementation NSObject(EORelationshipManipulation)

- (void)addObject:(id)_o toBothSidesOfRelationshipWithKey:(NSString *)_key {
  NSString *revKey;
  BOOL     isToMany;
  
  revKey = [self inverseForRelationshipKey:_key];
  isToMany = [self isToManyKey:_key];
  
  self = [[self retain] autorelease];
  _o   = [[_o retain] autorelease];
  
  if (isToMany) {
    /* watch out, likely to be buggy ! */
    [self addObject:_o toPropertyWithKey:_key];
  }
  else
    [self takeValue:_o forKey:_key];

  if (revKey) {
    /* add to the reverse object */
    BOOL revIsToMany;

    revIsToMany = [_o isToManyKey:revKey];
    
    if (revIsToMany)
      [_o addObject:self toPropertyWithKey:revKey];
    else
      [_o takeValue:self forKey:revKey];
  }
}
- (void)removeObject:(id)_o fromBothSidesOfRelationshipWithKey:(NSString *)_key {
  NSString *revKey;
  BOOL isToMany;

  revKey   = [self inverseForRelationshipKey:_key];
  isToMany = [self isToManyKey:_key];
  
  self = [[self retain] autorelease];
  _o   = [[_o   retain] autorelease];

  /* remove from this object */
  
  if (isToMany)
    [self removeObject:_o fromPropertyWithKey:_key];
  else
    [self takeValue:nil forKey:_key];
  
  if (revKey) {
    /* remove from reverse object */
    BOOL revIsToMany;

    revIsToMany = [_o isToManyKey:revKey];
    
    if (revIsToMany)
      [_o removeObject:self fromPropertyWithKey:revKey];
    else
      [_o takeValue:nil forKey:revKey];
  }
}

- (void)addObject:(id)_object toPropertyWithKey:(NSString *)_key {
  NSString *selname;
  SEL      sel;

  selname = [@"addTo" stringByAppendingString:[_key capitalizedString]];
  sel = NSSelectorFromString(selname);

  if ([self respondsToSelector:sel])
    [self performSelector:sel withObject:_object];
  else {
    id v;

    v = [self valueForKey:_key];

    if ([self isToManyKey:_key]) {
      /* to-many relationship */
      if (v == nil) {
        [self takeValue:[NSArray arrayWithObject:_object] forKey:_key];
      }
      else if (![v containsObject:_object]) {
        if ([v respondsToSelector:@selector(addObject:)])
          [v addObject:_object];
        else {
          v = [v arrayByAddingObject:_object];
          [self takeValue:v forKey:_key];
        }
      }
    }
    else {
      /* to-one relationship */
      if (v != _object)
        [self takeValue:v forKey:_key];
    }
  }
}
- (void)removeObject:(id)_object fromPropertyWithKey:(NSString *)_key {
  NSString *selname;
  SEL      sel;

  selname = [@"removeFrom" stringByAppendingString:[_key capitalizedString]];
  sel = NSSelectorFromString(selname);
  
  if ([self respondsToSelector:sel])
    [self performSelector:sel withObject:_object];
  else {
    id v;

    v = [self valueForKey:_key];
    
    if ([self isToManyKey:_key]) {
      /* to-many relationship */
      if (v == nil) {
        /* do nothing */
      }
      else if (![v containsObject:_object]) {
        if ([v respondsToSelector:@selector(addObject:)])
          [v removeObject:_object];
        else {
          v = [v mutableCopy];
          [v removeObject:_object];
          [self takeValue:v forKey:_key];
          [v release]; v = nil;
        }
      }
    }
    else {
      /* to-one relationship */
      [self takeValue:nil forKey:_key];
    }
  }
}

@end /* NSObject(EORelationshipManipulation) */

/* shallow array copying */

@implementation NSArray(ShallowCopy)

- (id)shallowCopy {
  NSArray *a;
  unsigned i, cc;
  id *objects;

  cc = [self count];
  objects = calloc(cc + 1, sizeof(id));
  
  for (i = 0; i < cc; i++)
    objects[i] = [self objectAtIndex:i];

  a = [[NSArray alloc] initWithObjects:objects count:cc];
  
  if (objects) free(objects);
  
  return a;
}

@end /* NSArray(ShallowCopy) */
