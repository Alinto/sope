/* 
   NSHashTable.h

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

#ifndef __NSHashTable_h__
#define __NSHashTable_h__

#include <Foundation/NSObject.h>

@class NSArray;

struct _NSHashTable;

typedef struct _NSHashTableCallBacks {
    unsigned (*hash)(struct _NSHashTable *table, const void *anObject);
    BOOL (*isEqual)(struct _NSHashTable *table, 
	    const void *anObject1, const void *anObject2);
    void (*retain)(struct _NSHashTable *table, const void *anObject);
    void (*release)(struct _NSHashTable *table, void *anObject);
    NSString  *(*describe)(struct _NSHashTable *table, const void *anObject);
} NSHashTableCallBacks;

struct _NSHashNode {
    void		*key;
    struct _NSHashNode 	*next;
};

typedef struct _NSHashTable {
    struct _NSHashNode	**nodes;
    unsigned int    	hashSize;
    unsigned int	itemsCount;
    NSHashTableCallBacks callbacks;
    NSZone*		zone;
    BOOL		keysInvisible;
} NSHashTable;

typedef struct _NSHashEnumerator {
    struct _NSHashTable	*table;
    struct _NSHashNode	*node;
    int			bucket;
} NSHashEnumerator;

/* Predefined callback sets */
LF_EXPORT const NSHashTableCallBacks NSIntHashCallBacks;
LF_EXPORT const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks; 
LF_EXPORT const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks; 
LF_EXPORT const NSHashTableCallBacks NSObjectHashCallBacks; 
LF_EXPORT const NSHashTableCallBacks NSOwnedObjectIdentityHashCallBacks; 
LF_EXPORT const NSHashTableCallBacks NSOwnedPointerHashCallBacks; 
LF_EXPORT const NSHashTableCallBacks NSPointerToStructHashCallBacks; 

/* Hash Table Functions */

/* Create a Table */
NSHashTable *NSCreateHashTable(NSHashTableCallBacks callBacks, 
	unsigned capacity);
NSHashTable *NSCreateHashTableWithZone(NSHashTableCallBacks callBacks, 
	unsigned capacity, NSZone *zone);
NSHashTable *NSCopyHashTableWithZone(NSHashTable *table, 
	NSZone *zone);

/* Create a hash table whose keys are not collectable */
NSHashTable *NSCreateHashTableInvisibleKeys(NSHashTableCallBacks callBacks,
						unsigned capacity);

/* Free a Table */
void NSFreeHashTable(NSHashTable *table); 
void NSResetHashTable(NSHashTable *table); 

/* Compare Two Tables */
BOOL NSCompareHashTables(NSHashTable *table1, NSHashTable *table2);	

/* Get the Number of Items */
unsigned NSCountHashTable(NSHashTable *table);

/* Retrieve Items */
void *NSHashGet(NSHashTable *table, const void *pointer);
NSArray *NSAllHashTableObjects(NSHashTable *table);
NSHashEnumerator NSEnumerateHashTable(NSHashTable *table);
void *NSNextHashEnumeratorItem(NSHashEnumerator *enumerator);

/* Add or Remove an Item */
void NSHashInsert(NSHashTable *table, const void *pointer);
void NSHashInsertKnownAbsent(NSHashTable *table, const void *pointer);
void *NSHashInsertIfAbsent(NSHashTable *table, const void *pointer);
void NSHashRemove(NSHashTable *table, const void *pointer);

/* Get a String Representation */
NSString *NSStringFromHashTable(NSHashTable *table);

#endif /* __NSHashTable_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
