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

#ifndef __NGObjWeb_WODisplayGroup_H__
#define __NGObjWeb_WODisplayGroup_H__

#import <Foundation/NSObject.h>

@class NSDictionary, NSArray, NSNotification, NSMutableDictionary;
@class EODataSource, EOQualifier;

@interface WODisplayGroup : NSObject < NSCoding >
{
  id           delegate;               /* non-retained ! */
  EODataSource *dataSource;
  NSArray      *sortOrderings;
  NSDictionary *insertedObjectDefaults;
  unsigned     numberOfObjectsPerBatch;
  NSArray      *selectionIndexes;
  NSArray      *objects;
  NSArray      *displayObjects;
  EOQualifier  *qualifier;
  NSString     *defaultStringMatchFormat;
  NSString     *defaultStringMatchOperator;
  unsigned     currentBatchIndex;

  NSMutableDictionary *_queryBindings;
  NSMutableDictionary *_queryMatch;
  NSMutableDictionary *_queryMin;
  NSMutableDictionary *_queryMax;
  NSMutableDictionary *_queryOperator;
  
  struct {
    BOOL fetchesOnLoad:1;
    BOOL selectFirstAfterFetch:1;
    BOOL validatesChangesImmediatly:1;
    BOOL inQueryMode:1;
  } flags;
}


/* accessors */

- (void)setDelegate:(id)_delegate;
- (id)delegate;

- (void)setDataSource:(EODataSource *)_ds;
- (EODataSource *)dataSource;

- (void)setSortOrderings:(NSArray *)_orderings;
- (NSArray *)sortOrderings;

- (void)setFetchesOnLoad:(BOOL)_flag;
- (BOOL)fetchesOnLoad;

- (void)setInsertedObjectDefaultValues:(NSDictionary *)_values;
- (NSDictionary *)insertedObjectDefaultValues;

- (void)setNumberOfObjectsPerBatch:(unsigned)_count;
- (unsigned)numberOfObjectsPerBatch;

- (void)setSelectsFirstObjectAfterFetch:(BOOL)_flag;
- (BOOL)selectsFirstObjectAfterFetch;

- (void)setValidatesChangesImmediatly:(BOOL)_flag;
- (BOOL)validatesChangesImmediatly;

/* display */

- (void)redisplay;

/* batches */

- (BOOL)hasMultipleBatches;
- (unsigned)batchCount;
- (void)setCurrentBatchIndex:(unsigned)_currentBatchIndex;
- (unsigned)currentBatchIndex;
- (unsigned)indexOfFirstDisplayedObject;
- (unsigned)indexOfLastDisplayedObject;
- (id)displayNextBatch;
- (id)displayPreviousBatch;
- (id)displayBatchContainingSelectedObject;

/* selection */

- (BOOL)setSelectionIndexes:(NSArray *)_selection;
- (NSArray *)selectionIndexes;
- (BOOL)clearSelection;

- (id)selectNext;
- (id)selectPrevious;

- (void)setSelectedObject:(id)_obj;
- (id)selectedObject;
- (void)setSelectedObjects:(NSArray *)_objs;
- (NSArray *)selectedObjects;

- (BOOL)selectObject:(id)_obj;
- (BOOL)selectObjectsIdenticalTo:(NSArray *)_objs;
- (BOOL)selectObjectsIdenticalTo:(NSArray *)_objs
  selectFirstOnNoMatch:(BOOL)_flag;

/* objects */

- (void)setObjectArray:(NSArray *)_objects;
- (NSArray *)allObjects;
- (NSArray *)displayedObjects;

- (id)fetch;
- (void)updateDisplayedObjects;

/* query */

- (void)setInQueryMode:(BOOL)_flag;
- (BOOL)inQueryMode;

- (EOQualifier *)qualifierFromQueryValues;
- (NSMutableDictionary *)queryBindings;
- (NSMutableDictionary *)queryMatch;
- (NSMutableDictionary *)queryMin;
- (NSMutableDictionary *)queryMax;
- (NSMutableDictionary *)queryOperator;

- (void)setDefaultStringMatchFormat:(NSString *)_tmp;
- (NSString *)defaultStringMatchFormat;
- (void)setDefaultStringMatchOperator:(NSString *)_tmp;
- (NSString *)defaultStringMatchOperator;
+ (NSString *)globalDefaultStringMatchFormat;
+ (NSString *)globalDefaultStringMatchOperator;

/* qualifiers */

- (void)setQualifier:(EOQualifier *)_q;
- (EOQualifier *)qualifier;

- (NSArray *)allQualifierOperators;
- (NSArray *)stringQualifierOperators;
- (NSArray *)relationalQualifierOperators;

- (void)qualifyDisplayGroup;
- (void)qualifyDataSource;

/* object creation */

- (id)insert;
- (id)insertObjectAtIndex:(unsigned)_idx;
- (void)insertObject:(id)_object atIndex:(unsigned)_idx;

/* object deletion */

- (id)delete;
- (BOOL)deleteSelection;
- (BOOL)deleteObjectAtIndex:(unsigned)_idx;

@end


@interface NSObject(WODisplayGroupDelegate)

- (void)displayGroup:(WODisplayGroup *)_dg
  createObjectFailedForDataSource:(EODataSource *)_ds;

- (BOOL)displayGroupShouldFetch:(WODisplayGroup *)_dg;
- (void)displayGroup:(WODisplayGroup *)_dg didFetchObjects:(NSArray *)_objects;

- (BOOL)displayGroup:(WODisplayGroup *)_dg shouldInsertObject:(id)_object
  atIndex:(unsigned int)_idx;
- (void)displayGroup:(WODisplayGroup *)_dg didInsertObject:(id)_object;

- (BOOL)displayGroup:(WODisplayGroup *)_dg shouldDeleteObject:(id)_object;
- (void)displayGroup:(WODisplayGroup *)_dg didDeleteObject:(id)_object;

- (void)displayGroup:(WODisplayGroup *)_dg
  didSetValue:(id)_value forObject:(id)_object key:(NSString *)_key;

- (void)displayGroupDidChangeDataSource:(WODisplayGroup *)_dg;
- (BOOL)displayGroup:(WODisplayGroup *)_dg
  shouldRedisplayForEditingContextChangeNotification:(NSNotification *)_not;

- (BOOL)displayGroup:(WODisplayGroup *)_dg
  shouldChangeSelectionToIndexes:(NSArray *)_idxs;
- (void)displayGroupDidChangeSelectedObjects:(WODisplayGroup *)_dg;
- (void)displayGroupDidChangeSelection:(WODisplayGroup *)_dg;

- (NSArray *)displayGroup:(WODisplayGroup *)_dg
  displayArrayForObjects:(NSArray *)_objects;

@end

#endif /* __NGObjWeb_WODisplayGroup_H__ */
