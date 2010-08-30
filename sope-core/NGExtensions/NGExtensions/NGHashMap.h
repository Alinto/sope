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

#ifndef __NGExtensions_NGHashMap_H__
#define __NGExtensions_NGHashMap_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSMapTable.h>

@class NSArray, NSDictionary;

@interface NGHashMap : NSObject < NSCopying, NSMutableCopying, NSCoding >
{
@protected
  NSMapTable *table;  
}

+ (id)hashMap;
+ (id)hashMapWithHashMap:(NGHashMap *)_hashMap;
+ (id)hashMapWithObjects:(NSArray *)_objects forKey:(id)_key;
+ (id)hashMapWithDictionary:(NSDictionary *)_dict;

- (id)init;
- (id)initWithCapacity:(NSUInteger)_size;
- (id)initWithObjects:(NSArray *)_objects forKey:(id)_key;
- (id)initWithHashMap:(NGHashMap *)_hashMap;
- (id)initWithDictionary:(NSDictionary *)_dictionary;

- (BOOL)isEqual:(id)anObject;
- (BOOL)isEqualToHashMap:(NGHashMap *)_other;

- (id)objectForKey:(id)_key;
- (NSArray *)objectsForKey:(id)_key;
- (id)objectAtIndex:(NSUInteger)_index forKey:(id)_key;

- (NSArray *)allKeys;
- (NSArray *)allObjects;

- (NSEnumerator *)keyEnumerator;
- (NSEnumerator *)objectEnumerator;
- (NSEnumerator *)objectEnumeratorForKey:(id)_key;

- (id)propertyList;
- (NSString *)description;
- (NSDictionary *)asDictionary;
- (NSDictionary *)asDictionaryWithArraysForValues;

- (NSUInteger)hash;
- (NSUInteger)count; // returns the number of keys
- (NSUInteger)countObjectsForKey:(id)_key;

@end

@interface NGMutableHashMap : NGHashMap
{
}

+ (id)hashMapWithCapacity:(NSUInteger)_numItems;

- (id)init;
 
- (void)insertObject:(id)_object atIndex:(NSUInteger)_index forKey:(id)_key;
- (void)insertObjects:(NSArray *)_object
  atIndex:(NSUInteger)_index forKey:(id)_key;
- (void)insertObjects:(id*)_objects count:(NSUInteger)_count
  atIndex:(NSUInteger)_index forKey:(id)_key;

- (void)addObject:(id)_object forKey:(id)_key;
- (void)addObjects:(NSArray *)_objects forKey:(id)_key;
- (void)addObjects:(id*)_objects count:(NSUInteger)_count
  forKey:(id)_key;

- (void)setObject:(id)_object forKey:(id)_key;
- (void)setObjects:(NSArray *)_objects forKey:(id)_key;

- (void)removeAllObjects;
- (void)removeAllObjects:(id)_object forKey:(id)_key;
- (void)removeAllObjectsForKey:(id)_key;
- (void)removeAllObjectsForKeys:(NSArray *)_keyArray;

@end

#endif /* __NGExtensions_NGHashMap_H__ */
