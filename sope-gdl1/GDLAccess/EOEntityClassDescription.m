/* 
   EOAttributeOrdering.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

// $Id: EOEntityClassDescription.m 1 2004-08-20 10:38:46Z znek $

#import "common.h"
#import "EOEntity.h"
#import "EOAttribute.h"
#import "EORelationship.h"
#import <EOControl/EOKeyValueCoding.h>
#import <EOControl/EOKeyGlobalID.h>

@interface EOClassDescription(ClassDesc)
/* TODO: check, whether this can be removed */
+ (NSClassDescription *)classDescriptionForEntityName:(NSString *)_entityName;
@end

@implementation EOEntityClassDescription

- (id)initWithEntity:(EOEntity *)_entity {
  self->entity = RETAIN(_entity);
  return self;
}

- (void)dealloc {
  RELEASE(self->entity);
  [super dealloc];
}

/* creating instances */

- (id)createInstanceWithEditingContext:(id)_ec
  globalID:(EOGlobalID *)_oid
  zone:(NSZone *)_zone
{
  Class eoClass;
  id eo;
  
  eoClass = NSClassFromString([self->entity className]);
  eo = [eoClass allocWithZone:_zone];
  
  if ([eo respondsToSelector:
          @selector(initWithEditingContext:classDescription:globalID:)])
    eo = [eo initWithEditingContext:_ec classDescription:self globalID:_oid];
  else
    eo = [eo init];

  return AUTORELEASE(eo);
}

/* accessors */

- (EOEntity *)entity {
  return self->entity;
}

/* model */

- (NSString *)entityName {
  return [self->entity name];
}

- (NSArray *)attributeKeys {
  NSArray      *attrs    = [self->entity attributes];
  unsigned int attrCount = [attrs count];
  id           keys[attrCount];
  unsigned int i;

  for (i = 0; i < attrCount; i++) {
    EOAttribute *attribute;

    attribute = [attrs objectAtIndex:i];
    keys[i] = [attribute name];
  }

  return [NSArray arrayWithObjects:keys count:attrCount];
}

- (NSArray *)toManyRelationshipKeys {
  NSArray      *relships = [self->entity relationships];
  unsigned int attrCount = [relships count];
  id           keys[attrCount];
  unsigned int i, j;

  for (i = 0, j = 0; i < attrCount; i++) {
    EORelationship *relship;

    relship = [relships objectAtIndex:i];
    if ([relship isToMany]) {
      keys[j] = [relship name];
    }
  }
  return [NSArray arrayWithObjects:keys count:j];
}

- (NSArray *)toOneRelationshipKeys {
  NSArray      *relships = [self->entity relationships];
  unsigned int attrCount = [relships count];
  id           keys[attrCount];
  unsigned int i, j;

  for (i = 0, j = 0; i < attrCount; i++) {
    EORelationship *relship;

    relship = [relships objectAtIndex:i];
    if (![relship isToMany]) {
      keys[j] = [relship name];
    }
  }
  return [NSArray arrayWithObjects:keys count:j];
}


- (NSClassDescription *)classDescriptionForDestinationKey:(NSString *)_key {
  /* TODO: is this used anywhere?, maybe remove? */
  EORelationship *relship;
  NSString       *targetEntityName;
  
  if ((relship = [self->entity relationshipNamed:_key]) == nil)
    return nil;
  
  if ([relship isToMany])
    return nil;
  
  targetEntityName = [[relship entity] name];
  
  return [EOClassDescription classDescriptionForEntityName:targetEntityName];
}

/* validation */

- (NSException *)validateObjectForSave:(id)_object {
  NSMutableArray *exceptions;
  NSArray        *attrs;
  unsigned int   count, i;

  exceptions = nil;
  
  /* validate attributes */
  
  attrs = [self->entity attributes];
  count = [attrs count];
  
  for (i = 0; i < count; i++) {
    EOAttribute *attribute;
    NSException *exception;
    id oldValue, newValue;
    
    attribute = [attrs objectAtIndex:i];
    oldValue  = [_object storedValueForKey:[attribute name]];
    newValue  = oldValue;
    
    if ((exception = [attribute validateValue:&newValue])) {
      /* validation failed */
      if (exceptions == nil) exceptions = [NSMutableArray array];
      [exceptions addObject:exception];
    }
    else if (oldValue != newValue) {
      /* apply new value to object (value was changed by val-method) */
      [_object takeStoredValue:newValue forKey:[attribute name]];
    }
  }

  /* validate relationships */

  attrs = [self->entity relationships];
  count = [attrs count];
  
  for (i = 0; i < count; i++) {
    EORelationship *relationship;
    NSException *exception;
    id oldValue, newValue;
    
    relationship = [attrs objectAtIndex:i];
    oldValue     = [_object storedValueForKey:[relationship name]];
    newValue     = oldValue;
    
    if ((exception = [relationship validateValue:&newValue])) {
      /* validation failed */
      if (exceptions == nil) exceptions = [NSMutableArray array];
      [exceptions addObject:exception];
    }
    else if (oldValue != newValue) {
      /* apply new value to object (value was changed by val-method) */
      [_object takeStoredValue:newValue forKey:[relationship name]];
    }
  }
  
  /* process exceptions */
  
  if ((count = [exceptions count]) == 0)
    return nil;

  if (count == 1)
    return [exceptions objectAtIndex:0];
  
  {
    NSException *master;
    NSMutableDictionary *ui;
    
    master = [exceptions objectAtIndex:0];
    ui = [[master userInfo] mutableCopy];
    if (ui == nil) ui = [[NSMutableDictionary alloc] init];
    [ui setObject:exceptions forKey:@"EOAdditionalExceptions"];
    
    master = [NSException exceptionWithName:[master name]
			  reason:[master reason]
			  userInfo:ui];
    [ui release]; ui = nil;
    return master;
  }
}

@end /* EOEntityClassDescription */
