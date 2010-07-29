/* 
   NSMapTable.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSMapTable_h__
#define __NSMapTable_h__

#include <Foundation/NSObject.h>

@class NSArray;

struct _NSMapTable;

struct _NSMapNode {
    void *key;
    void *value;
    struct _NSMapNode *next;
};

typedef struct _NSMapTableKeyCallBacks {
    unsigned (*hash)(struct _NSMapTable *table, const void *anObject);
    BOOL (*isEqual)(struct _NSMapTable *table, const void *anObject1, 
	    const void *anObject2);
    void (*retain)(struct _NSMapTable *table, const void *anObject);
    void (*release)(struct _NSMapTable *table, void *anObject);
    NSString  *(*describe)(struct _NSMapTable *table, const void *anObject);
    const void *notAKeyMarker;
} NSMapTableKeyCallBacks;

typedef struct _NSMapTableValueCallBacks {
    void (*retain)(struct _NSMapTable *table, const void *anObject);
    void (*release)(struct _NSMapTable *table, void *anObject);
    NSString  *(*describe)(struct _NSMapTable *table, const void *anObject);
} NSMapTableValueCallBacks;

typedef struct _NSMapTable {
    struct _NSMapNode	**nodes;
    unsigned int    	hashSize;
    unsigned int	itemsCount;
    NSMapTableKeyCallBacks keyCallbacks;
    NSMapTableValueCallBacks valueCallbacks;
    NSZone		*zone;
    BOOL		keysInvisible;
    BOOL		valuesInvisible;
} NSMapTable;

typedef struct NSMapEnumerator {
    struct _NSMapTable	*table;
    struct _NSMapNode	*node;
    int			bucket;
} NSMapEnumerator;

#define NSNotAnIntMapKey MAXINT
#define NSNotAPointerMapKey ((long)1)

/* Predefined callback sets */
LF_EXPORT const NSMapTableKeyCallBacks   NSIntMapKeyCallBacks; 
LF_EXPORT const NSMapTableValueCallBacks NSIntMapValueCallBacks; 
LF_EXPORT const NSMapTableKeyCallBacks   NSNonOwnedPointerMapKeyCallBacks; 
LF_EXPORT const NSMapTableKeyCallBacks   NSNonOwnedCStringMapKeyCallBacks; 
LF_EXPORT const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks;
LF_EXPORT const NSMapTableKeyCallBacks   NSNonOwnedPointerOrNullMapKeyCallBacks; 
LF_EXPORT const NSMapTableKeyCallBacks   NSNonRetainedObjectMapKeyCallBacks; 
LF_EXPORT const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks; 
LF_EXPORT const NSMapTableKeyCallBacks   NSObjectMapKeyCallBacks; 
LF_EXPORT const NSMapTableValueCallBacks NSObjectMapValueCallBacks; 
LF_EXPORT const NSMapTableKeyCallBacks   NSOwnedPointerMapKeyCallBacks; 
LF_EXPORT const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks; 

/* Map Table Functions */

/* Create a Table */
NSMapTable *NSCreateMapTable(NSMapTableKeyCallBacks keyCallBacks, 
	NSMapTableValueCallBacks valueCallBacks,
	unsigned capacity);
NSMapTable *NSCreateMapTableWithZone(NSMapTableKeyCallBacks keyCallBacks, 
	NSMapTableValueCallBacks valueCallBacks,
	unsigned capacity,
	NSZone *zone);

NSMapTable* NSCreateMapTableInvisibleKeysOrValues (
   NSMapTableKeyCallBacks keyCallBacks,
   NSMapTableValueCallBacks valueCallBacks,
   unsigned capacity,
   BOOL keysInvisible,
   BOOL valuesInvisible);

NSMapTable *NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone);

/* Free a Table */
void NSFreeMapTable(NSMapTable *table);
void NSResetMapTable(NSMapTable *table);

/* Compare Two Tables */
BOOL NSCompareMapTables(NSMapTable *table1, NSMapTable *table2);

/* Get the Number of Items */
unsigned NSCountMapTable(NSMapTable *table);

/* Retrieve Items */
BOOL NSMapMember(NSMapTable *table, const void *key, 
	void **originalKey,
	void **value);
void *NSMapGet(NSMapTable *table, const void *key);
NSMapEnumerator NSEnumerateMapTable(NSMapTable *table);
BOOL NSNextMapEnumeratorPair(NSMapEnumerator *enumerator, 
	void **key,
	void **value);
NSArray *NSAllMapTableKeys(NSMapTable *table);
NSArray *NSAllMapTableValues(NSMapTable *table);

/* Add or Remove an Item */
void NSMapInsert(NSMapTable *table, const void *key, const void *value);
void *NSMapInsertIfAbsent(NSMapTable *table,
	const void *key,
	const void *value);
void NSMapInsertKnownAbsent(NSMapTable *table,
	const void *key, 
	const void *value);
void NSMapRemove(NSMapTable *table, const void *key);
NSString *NSStringFromMapTable(NSMapTable *table);

#endif /* __NSMapTable_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
