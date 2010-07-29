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

#ifndef __NGExtensions_EOKeyMapDataSource_H__
#define __NGExtensions_EOKeyMapDataSource_H__

#import <EOControl/EODataSource.h>

/*
  EOKeyMapDataSource
  
  This class allows you to remap the keys of a source datasource on the fly. It
  fully supports fetch enumerators.
  
  The class description of the datasource describes what keys the resulting
  objects should have (note that the fetchspec isn't checked for validaty on
  that).
*/

@class NSException, NSEnumerator, NSArray, NSClassDescription;
@class NSMutableDictionary, NSDictionary;
@class EOFetchSpecification, EOGlobalID;

@interface EOKeyMapDataSource : EODataSource
{
  EOFetchSpecification *fspec;
  EODataSource         *source;
  NSClassDescription   *classDescription;
  NSArray *entityKeys;
  NSArray *mappedKeys;
  id      map;
}

- (id)initWithDataSource:(EODataSource *)_ds map:(id)_map;

/* accessors */

- (void)setSource:(EODataSource *)_source;
- (EODataSource *)source;
- (void)setFetchSpecification:(EOFetchSpecification *)_fetchSpec;
- (EOFetchSpecification *)fetchSpecification;

- (NSException *)lastException;

/* mappings (default implementations use the map) */

- (EOFetchSpecification *)mapFetchSpecification:(EOFetchSpecification *)_fs;

- (void)setClassDescriptionForObjects:(NSClassDescription *)_cd;
- (NSClassDescription *)classDescriptionForObjects;

- (id)mapCreatedObject:(id)_object;
- (id)mapObjectForUpdate:(id)_object;
- (id)mapObjectForInsert:(id)_object;
- (id)mapObjectForDelete:(id)_object;
- (id)mapFetchedObject:(id)_object;

- (id)mapFromSourceObject:(id)_object;
- (id)mapToSourceObject:(id)_object;

/* fetching */

- (Class)fetchEnumeratorClass;
- (NSEnumerator *)fetchEnumerator;
- (NSArray *)fetchObjects;

- (void)clear;

/* operations */

- (void)updateObject:(id)_obj;
- (void)insertObject:(id)_obj;
- (void)deleteObject:(id)_obj;
- (id)createObject;

@end

#import <Foundation/NSEnumerator.h>

@interface EOKeyMapDataSourceEnumerator : NSEnumerator
{
  EOKeyMapDataSource *ds;
  NSEnumerator       *source;
}

- (id)initWithKeyMapDataSource:(EOKeyMapDataSource *)_ds
  fetchEnumerator:(NSEnumerator *)_enum;

@end

@interface EOMappedObject : NSObject
{
  id         original;
  EOGlobalID *globalID;
  NSMutableDictionary *values;
  struct {
    BOOL didChange:1;
    int  reserved:31;
  } flags;
}

- (id)initWithObject:(id)_object values:(NSDictionary *)_values;

/* accessors */

- (id)mappedObject;
- (EOGlobalID *)globalID;

- (BOOL)isModified;
- (void)willChange;
- (void)applyChangesOnObject;

/* mimic dictionary */

- (void)setObject:(id)_obj forKey:(id)_key;
- (id)objectForKey:(id)_key;
- (void)removeObjectForKey:(id)_key;

- (NSEnumerator *)keyEnumerator;
- (NSEnumerator *)objectEnumerator;

/* KVC */

- (void)takeValue:(id)_value forKey:(NSString *)_key;
- (id)valueForKey:(NSString *)_key;

@end

#endif /* __NGExtensions_EOKeyMapDataSource_H__ */
