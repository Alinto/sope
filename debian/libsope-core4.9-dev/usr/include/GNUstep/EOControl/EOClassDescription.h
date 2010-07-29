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

#ifndef __EOControl_EOClassDescription_H__
#define __EOControl_EOClassDescription_H__

#import <Foundation/Foundation.h>
#include <EOControl/EOGlobalID.h>

@class NSException, NSString, NSFormatter;

@interface EOClassDescription : NSClassDescription

@end

@interface NSClassDescription(EOClassDescription)

/* model */

- (NSString *)entityName;
- (NSString *)inverseForRelationshipKey:(NSString *)_key;
- (NSClassDescription *)classDescriptionForDestinationKey:(NSString *)_key;

/* object initialization */

- (id)createInstanceWithEditingContext:(id)_ec
  globalID:(EOGlobalID *)_oid
  zone:(NSZone *)_zone;

- (void)awakeObject:(id)_object fromFetchInEditingContext:(id)_ec;
- (void)awakeObject:(id)_object fromInsertionInEditingContext:(id)_ec;

/* delete */

- (void)propagateDeleteForObject:(id)_object editingContext:(id)_ec;

/* entity names */

#if 0
// used by: EOGenericRecord.m
+ (NSClassDescription *)classDescriptionForEntityName:(NSString *)_entityName;
#endif

/* formatting */

- (NSFormatter *)defaultFormatterForKey:(NSString *)_key;
- (NSFormatter *)defaultFormatterForKeyPath:(NSString *)_keyPath;

@end

@interface NSClassDescription(EOValidation)

- (NSException *)validateObjectForDelete:(id)_object;
- (NSException *)validateObjectForSave:(id)_object;
- (NSException *)validateValue:(id *)_value forKey:(NSString *)_key;

@end

@interface NSObject(EOClassDescriptionInit)

/* object initialization */

- (id)initWithEditingContext:(id)_ec
  classDescription:(NSClassDescription *)_classDesc
  globalID:(EOGlobalID *)_oid;

- (void)awakeFromFetchInEditingContext:(id)_ec;
- (void)awakeFromInsertionInEditingContext:(id)_ec;

/* model */

- (NSString *)entityName;
- (NSString *)inverseForRelationshipKey:(NSString *)_key;
- (NSArray *)attributeKeys;
- (NSArray *)toManyRelationshipKeys;
- (NSArray *)toOneRelationshipKeys;

- (BOOL)isToManyKey:(NSString *)_key;
- (NSArray *)allPropertyKeys;

/* delete */

- (void)propagateDeleteWithEditingContext:(id)_ec;

@end

/* validation */

@interface NSObject(EOValidation)

- (NSException *)validateForDelete;
- (NSException *)validateForInsert;
- (NSException *)validateForUpdate;
- (NSException *)validateForSave;

@end

@interface NSException(EOValidation)

+ (NSException *)aggregateExceptionWithExceptions:(NSArray *)_exceptions;

@end

/* snapshots */

@interface NSObject(EOSnapshots)

- (NSDictionary *)snapshot;
- (void)updateFromSnapshot:(NSDictionary *)_snapshot;
- (NSDictionary *)changesFromSnapshot:(NSDictionary *)_snapshot;

@end

/* relationships */

@interface NSObject(EORelationshipManipulation)

- (void)addObject:(id)_o    toBothSidesOfRelationshipWithKey:(NSString *)_key;
- (void)removeObject:(id)_o fromBothSidesOfRelationshipWithKey:(NSString *)_key;

- (void)addObject:(id)_object    toPropertyWithKey:(NSString *)_key;
- (void)removeObject:(id)_object fromPropertyWithKey:(NSString *)_key;

@end

/* shallow array copying */

@interface NSArray(ShallowCopy)
- (id)shallowCopy;
@end

#endif /* __EOControl_EOClassDescription_H__ */
