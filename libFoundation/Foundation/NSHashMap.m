/* 
   NSHashMap.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <math.h>

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include "lfmemory.h"

static void __NSHashGrow(NSHashTable *table, unsigned newSize);
static void __NSMapGrow(NSMapTable *table, unsigned newSize);

#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
/* Bucket descriptor for hash tables */
static GC_descr hashBucketKeyInvisible = 0;

/* Bucket descriptors for map tables */
static GC_descr mapBucketKeyInvisible = 0;
static GC_descr mapBucketValueInvisible = 0;
static GC_descr mapBucketKeyValueInvisible = 0;
#endif

/*
 *  Hash and Map Table utilities
 */

static BOOL is_prime(unsigned n)
{
    int i, n2 = sqrt(n);

    for(i = 2; i <= n2; i++)
        if(n % i == 0)
            return NO;
    return YES;
}

static unsigned nextPrime(unsigned old_value)
{
    unsigned i, new_value = old_value | 1;

    for(i = new_value; i >= new_value; i += 2)
        if(is_prime(i))
            return i;
    return old_value;
}

/* Check if nodeTable isn't full. */
static void __NSCheckHashTableFull(NSHashTable* table)
{
    if( ++(table->itemsCount) >= ((table->hashSize * 3) / 4)) {
	unsigned newSize = nextPrime((table->hashSize * 4) / 3);
	if(newSize != table->hashSize)
	    __NSHashGrow(table, newSize);
    }
}

static void __NSCheckMapTableFull(NSMapTable* table)
{
    if( ++(table->itemsCount) >= ((table->hashSize * 3) / 4)) {
	unsigned newSize = nextPrime((table->hashSize * 4) / 3);
	if(newSize != table->hashSize)
	    __NSMapGrow(table, newSize);
    }
}

/*
 * NSHashTable functions
 */

/* Create a Table */
LF_DECLARE NSHashTable *NSCreateHashTable(NSHashTableCallBacks callBacks, 
					  unsigned capacity)
{
    return NSCreateHashTableWithZone(callBacks, capacity, NULL);
}

static NSHashTable*
_NSCreateHashTableWithZone(NSHashTableCallBacks callBacks, 
	unsigned capacity, NSZone *zone, BOOL keysInvisible)
{
    NSHashTable* table = NSZoneMalloc(zone, sizeof(NSHashTable));

#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
    /* Create the descriptor used by the bucket whose key is uncollectable */
    if (!hashBucketKeyInvisible) {
        GC_word bm = 0x4;
        hashBucketKeyInvisible = GC_make_descriptor (&bm, 2);
    }
#endif
    
    capacity = capacity ? capacity : 13;
    if (!is_prime(capacity))
	capacity = nextPrime(capacity);

    table->hashSize = capacity;
    table->nodes = NSZoneCalloc(zone, table->hashSize, sizeof(void*));
    table->itemsCount = 0;
    table->callbacks = callBacks;
    table->zone = zone ? zone : NSDefaultMallocZone();
    if (table->callbacks.hash == NULL)
	table->callbacks.hash = 
	    (unsigned(*)(NSHashTable*, const void*))__NSHashPointer;
    if (table->callbacks.isEqual == NULL)
	table->callbacks.isEqual = 
	(BOOL(*)(NSHashTable*, const void*, const void*)) __NSComparePointers;
    if (table->callbacks.retain == NULL)
	table->callbacks.retain = 
	    (void(*)(NSHashTable*, const void*))__NSRetainNothing;
    if (table->callbacks.release == NULL)
	table->callbacks.release = 
	    (void(*)(NSHashTable*, void*))__NSReleaseNothing;
    if (table->callbacks.describe == NULL)
	table->callbacks.describe = 
	    (NSString*(*)(NSHashTable*, const void*))__NSDescribePointers;
    table->keysInvisible = keysInvisible;
    return table;
}

LF_EXPORT
NSHashTable *NSCreateHashTableWithZone(NSHashTableCallBacks callBacks, 
				       unsigned capacity, NSZone *zone)
{
  return _NSCreateHashTableWithZone (callBacks, capacity, zone, NO);
}

/* Create a hash table whose keys are not collectable */
LF_DECLARE
NSHashTable *NSCreateHashTableInvisibleKeys(NSHashTableCallBacks callBacks,
					    unsigned capacity)
{
  return _NSCreateHashTableWithZone (callBacks, capacity, NULL, YES);
}

LF_DECLARE
NSHashTable *NSCopyHashTableWithZone(NSHashTable *table, NSZone *zone)
{
    NSHashTable *new;
    struct _NSHashNode *oldnode, *newnode;
    unsigned i;
    
    zone = zone ? zone : NSDefaultMallocZone();
    new = NSZoneMalloc(zone, sizeof(NSHashTable));
    new->zone = zone;
    new->hashSize = table->hashSize;
    new->itemsCount = table->itemsCount;
    new->callbacks = table->callbacks;
    new->nodes = NSZoneCalloc(zone, new->hashSize, sizeof(void*));
    
    for (i = 0; i < new->hashSize; i++) {
	for (oldnode = table->nodes[i]; oldnode; oldnode = oldnode->next) {
#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
	    if (table->keysInvisible)
	        newnode =
		  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSHashNode),
					      hashBucketKeyInvisible);
	    else
#endif
	        newnode = NSZoneMalloc(zone, sizeof(struct _NSHashNode));
	    newnode->key = oldnode->key;
	    newnode->next = new->nodes[i];
	    new->nodes[i] = newnode;
	    table->callbacks.retain(new, oldnode->key);
	}
    }
    
    return new;
}

/* Free a Table */
LF_DECLARE void NSFreeHashTable(NSHashTable *table)
{
    NSResetHashTable(table);
    NSZoneFree(table->zone, table->nodes);
    NSZoneFree(table->zone, table);
}

LF_DECLARE void NSResetHashTable(NSHashTable *table)
{
    unsigned i;

    if (!table->itemsCount)
        return;

    for(i=0; i < table->hashSize; i++) {
	struct _NSHashNode *next, *node;
	
	node = table->nodes[i];
	table->nodes[i] = NULL;		
	while (node) {
	    table->callbacks.release(table, node->key);
	    next = node->next;
	    NSZoneFree(table->zone, node);
	    node = next;
	}
    }
    table->itemsCount = 0;
}

/* Compare Two Tables */
LF_DECLARE BOOL NSCompareHashTables(NSHashTable *table1, NSHashTable *table2)
{
    unsigned i;
    struct _NSHashNode *node1;
    
    if (table1->hashSize != table2->hashSize)
	return NO;
    for (i=0; i<table1->hashSize; i++) {
	for (node1 = table1->nodes[i]; node1; node1 = node1->next) {
	    if (NSHashGet(table2, node1->key) == NULL)
		return NO;
	}
    }
    return YES;;
}	

/* Get the Number of Items */
LF_DECLARE unsigned NSCountHashTable(NSHashTable *table)
{
    return table->itemsCount;
}

/* Retrieve Items */
LF_DECLARE void *NSHashGet(NSHashTable *table, const void *pointer)
{
    struct _NSHashNode* node = table->nodes[
		table->callbacks.hash(table, pointer) % table->hashSize];
    for(; node; node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key))
            return node->key;
    return NULL;
}

LF_DECLARE NSArray *NSAllHashTableObjects(NSHashTable *table)
{
    id array = [NSMutableArray arrayWithCapacity:table->itemsCount];
    struct _NSHashNode *node;
    unsigned i;

    for(i=0; i < table->hashSize; i++)
	for(node=table->nodes[i]; node; node=node->next)
		[array addObject:(NSObject*)(node->key)];
    return array;
}

LF_DECLARE NSHashEnumerator NSEnumerateHashTable(NSHashTable *table)
{
    NSHashEnumerator en;
    en.table = table;
    en.node = NULL;
    en.bucket = -1;
    return en;
}

LF_DECLARE void *NSNextHashEnumeratorItem(NSHashEnumerator *en)
{
    if(en->node)
	en->node = en->node->next;
    if(en->node == NULL) {
	for(en->bucket++; ((unsigned)en->bucket)<en->table->hashSize; en->bucket++)
	    if (en->table->nodes[en->bucket]) {
		    en->node = en->table->nodes[en->bucket];
		    break;
	    };
	if (((unsigned)en->bucket) >= en->table->hashSize) {
	    en->node = NULL;
	    en->bucket = en->table->hashSize-1;
	    return NULL;
	}
    }
    return en->node->key;
}

/* Add or Remove an Item */
static void __NSHashGrow(NSHashTable *table, unsigned newSize)
{
    unsigned i;
    struct _NSHashNode** newNodeTable = NSZoneCalloc(table->zone, 
	newSize, sizeof(struct _NSHashNode*));
    
    for(i = 0; i < table->hashSize; i++) {
	struct _NSHashNode *next, *node;
	unsigned int h;

	node = table->nodes[i];
	while(node) {
	    next = node->next;
	    h = table->callbacks.hash(table, node->key) % newSize;
	    node->next = newNodeTable[h];
	    newNodeTable[h] = node;
	    node = next;
	}
    }
    NSZoneFree(table->zone, table->nodes);
	table->nodes = newNodeTable;
    table->hashSize = newSize;
}

LF_DECLARE void NSHashInsert(NSHashTable *table, const void *pointer)
{
    unsigned int h;
    struct _NSHashNode *node;

    if (pointer == nil)
	[[[InvalidArgumentException alloc] initWithReason:
		@"Nil object to be added in NSHashTable"] raise];

    h = table->callbacks.hash(table, pointer) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key))
            break;

    /* Check if an entry for key exist in nodeTable. */
    if(node) {
        /* key exist. Set for it new value and return the old value of it. */
	if (pointer != node->key) {
	    table->callbacks.retain(table, pointer);
	    table->callbacks.release(table, node->key);
	}
	node->key = (void*)pointer;
        return;
    }

    /* key not found. Allocate a new bucket and initialize it. */
#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
    if (table->keysInvisible)
        node = GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSHashNode),
					   hashBucketKeyInvisible);
    else
#endif
    node = NSZoneMalloc(table->zone, sizeof(struct _NSHashNode));

    table->callbacks.retain(table, pointer);
    node->key = (void*)pointer;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    __NSCheckHashTableFull(table);
}

LF_DECLARE
void NSHashInsertKnownAbsent(NSHashTable *table, const void *pointer)
{
    unsigned int h;
    struct _NSHashNode *node;

    if (pointer == nil)
	[[[InvalidArgumentException alloc] initWithReason:
		@"Nil object to be added in NSHashTable"] raise];

    h = table->callbacks.hash(table, pointer) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key))
            break;

    /* Check if an entry for key exist in nodeTable. */
    if(node) 
	[[[InvalidArgumentException alloc] initWithReason:
		@"Nil object already existing in NSHashTable"] raise];

    /* key not found. Allocate a new bucket and initialize it. */
#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
    if (table->keysInvisible)
        node = GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSHashNode),
					   hashBucketKeyInvisible);
    else
#endif
    node = NSZoneMalloc(table->zone, sizeof(struct _NSHashNode));

    table->callbacks.retain(table, pointer);
    node->key = (void*)pointer;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    __NSCheckHashTableFull(table);
}

LF_DECLARE void *NSHashInsertIfAbsent(NSHashTable *table, const void *pointer)
{
    unsigned int h;
    struct _NSHashNode *node;

    if (pointer == nil)
	[[[InvalidArgumentException alloc] initWithReason:
		@"Nil object to be added in NSHashTable"] raise];

    h = table->callbacks.hash(table, pointer) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key))
            break;

    /* Check if an entry for key exist in nodeTable. */
    if(node)
	return node->key;
	
    /* key not found. Allocate a new bucket and initialize it. */
#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
    if (table->keysInvisible)
        node = GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSHashNode),
					   hashBucketKeyInvisible);
    else
#endif
    node = NSZoneMalloc(table->zone, sizeof(struct _NSHashNode));
    table->callbacks.retain(table, pointer);
    node->key = (void*)pointer;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    __NSCheckHashTableFull(table);
    
    return NULL;
}

LF_DECLARE void NSHashRemove(NSHashTable *table, const void *pointer)
{
    unsigned int h;
    struct _NSHashNode *node, *node1 = NULL;

    if (pointer == nil)
	    return;

    h = table->callbacks.hash(table, pointer) % table->hashSize;

    // node point to current bucket, and node1 to previous bucket or to NULL
    // if current node is the first node in the list 

    for(node = table->nodes[h]; node; node1 = node, node = node->next)
        if(table->callbacks.isEqual(table, pointer, node->key)) {
	    table->callbacks.release(table, node->key);
            if(!node1)
                table->nodes[h] = node->next;
            else
                node1->next = node->next;
	    NSZoneFree(table->zone, node);
	    (table->itemsCount)--;
	    return;
        }
}

/* Get a String Representation */
LF_DECLARE NSString *NSStringFromHashTable(NSHashTable *table)
{
    id ret = [NSMutableString new];
    unsigned i;
    struct _NSHashNode *node;
    
    for (i=0; i<table->hashSize; i++)
	for (node = table->nodes[i]; node; node = node->next) {
	    [ret appendString:table->callbacks.describe(table, node->key)];
	    [ret appendString:@" "];
	}
    
    return ret;
}

/* 
 * Map Table Functions 
 */

/* Create a Table */
LF_DECLARE
NSMapTable *NSCreateMapTable(NSMapTableKeyCallBacks keyCallbacks, 
			     NSMapTableValueCallBacks valueCallbacks,
			     unsigned capacity)
{
    return NSCreateMapTableWithZone(keyCallbacks, valueCallbacks, capacity, NULL);
}

LF_DECLARE
NSMapTable *_NSCreateMapTableWithZone(NSMapTableKeyCallBacks   keyCallbacks, 
				      NSMapTableValueCallBacks valueCallbacks,
				      unsigned capacity,
				      NSZone   *zone,
				      BOOL     keysInvisible,
				      BOOL     valuesInvisible)
{
    NSMapTable *table = NSZoneMalloc(zone, sizeof(NSMapTable));

#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
    if (!mapBucketKeyInvisible) {
        GC_word bm1 = 0x6, bm2 = 0x5, bm3 = 0x4;
        
        mapBucketKeyInvisible      = GC_make_descriptor (&bm1, 3);
	mapBucketValueInvisible    = GC_make_descriptor (&bm2, 3);
	mapBucketKeyValueInvisible = GC_make_descriptor (&bm3, 3);
    }
#endif

    capacity = capacity ? capacity : 13;
    if (!is_prime(capacity))
	capacity = nextPrime(capacity);

    table->hashSize = capacity;
    table->nodes = NSZoneCalloc(zone, table->hashSize, sizeof(void*));
    table->itemsCount = 0;
    table->keyCallbacks = keyCallbacks;
    table->valueCallbacks = valueCallbacks;
    table->zone = zone ? zone : NSDefaultMallocZone();
    if (table->keyCallbacks.hash == NULL)
	table->keyCallbacks.hash = 
		(unsigned(*)(NSMapTable*, const void*))__NSHashPointer;
    if (table->keyCallbacks.isEqual == NULL)
	table->keyCallbacks.isEqual = 
	(BOOL(*)(NSMapTable*, const void*, const void*)) __NSComparePointers;
    if (table->keyCallbacks.retain == NULL)
	table->keyCallbacks.retain = 
	    (void(*)(NSMapTable*, const void*))__NSRetainNothing;
    if (table->keyCallbacks.release == NULL)
	table->keyCallbacks.release = 
	    (void(*)(NSMapTable*, void*))__NSReleaseNothing;
    if (table->keyCallbacks.describe == NULL)
	table->keyCallbacks.describe = 
	    (NSString*(*)(NSMapTable*, const void*))__NSDescribePointers;
    if (table->valueCallbacks.retain == NULL)
	table->valueCallbacks.retain = 
	    (void(*)(NSMapTable*, const void*))__NSRetainNothing;
    if (table->valueCallbacks.release == NULL)
	table->valueCallbacks.release = 
	    (void(*)(NSMapTable*, void*))__NSReleaseNothing;
    if (table->valueCallbacks.describe == NULL)
	table->valueCallbacks.describe = 
	    (NSString*(*)(NSMapTable*, const void*))__NSDescribePointers;
    table->keysInvisible = keysInvisible;
    table->valuesInvisible = valuesInvisible;
    return table;
}

LF_DECLARE
NSMapTable *NSCreateMapTableWithZone(NSMapTableKeyCallBacks keyCallbacks, 
				     NSMapTableValueCallBacks valueCallbacks,
				     unsigned capacity,
				     NSZone *zone)
{
    return _NSCreateMapTableWithZone (keyCallbacks, valueCallbacks,
				      capacity, zone, NO, NO);
}

LF_DECLARE NSMapTable *NSCreateMapTableInvisibleKeysOrValues(
    NSMapTableKeyCallBacks keyCallbacks, 
    NSMapTableValueCallBacks valueCallbacks,
    unsigned capacity,
    BOOL keysInvisible,
    BOOL valuesInvisible)
{
    return _NSCreateMapTableWithZone (keyCallbacks, valueCallbacks,
				      capacity, NULL,
				      keysInvisible, valuesInvisible);
}

LF_DECLARE NSMapTable *NSCopyMapTableWithZone(NSMapTable *table, NSZone *zone)
{
    NSMapTable *new;
    struct _NSMapNode *oldnode, *newnode;
    unsigned i;
    
    zone = zone ? zone : NSDefaultMallocZone();
    new = NSZoneMalloc(zone, sizeof(NSMapTable));
    new->zone = zone;
    new->hashSize = table->hashSize;
    new->itemsCount = table->itemsCount;
    new->keyCallbacks = table->keyCallbacks;
    new->valueCallbacks = table->valueCallbacks;
    new->nodes = NSZoneCalloc(zone, new->hashSize, sizeof(void*));
    
    for (i=0; i<new->hashSize; i++) {
	for (oldnode = table->nodes[i]; oldnode; oldnode = oldnode->next) {
#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
	    if (table->keysInvisible && table->valuesInvisible)
	        newnode =
		  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
					      mapBucketKeyValueInvisible);
	    else if (table->keysInvisible)
	        newnode =
		  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
					      mapBucketKeyInvisible);
	    else if (table->valuesInvisible)
	        newnode =
		  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
					      mapBucketValueInvisible);
	    else
#endif
	        newnode = NSZoneMalloc(zone, sizeof(struct _NSMapNode));
	    newnode->key = oldnode->key;
	    newnode->value = oldnode->value;
	    newnode->next = new->nodes[i];
	    new->nodes[i] = newnode;
	    table->keyCallbacks.retain(new, oldnode->key);
	    table->valueCallbacks.retain(new, oldnode->value);
	}
    }
    
    return new;
}

/* Free a Table */
LF_DECLARE void NSFreeMapTable(NSMapTable *table)
{
    NSResetMapTable(table);
    NSZoneFree(table->zone, table->nodes);
    NSZoneFree(table->zone, table);
}

LF_DECLARE void NSResetMapTable(NSMapTable *table)
{
    unsigned i;

    if (!table->itemsCount)
        return;
    
    for(i=0; i < table->hashSize; i++) {
	struct _NSMapNode *next, *node;
	
	node = table->nodes[i];
	table->nodes[i] = NULL;		
	while (node) {
	    table->keyCallbacks.release(table, node->key);
	    table->valueCallbacks.release(table, node->value);
	    next = node->next;
	    NSZoneFree(table->zone, node);
	    node = next;
	}
    }
    table->itemsCount = 0;
}

/* Compare Two Tables */
LF_DECLARE BOOL NSCompareMapTables(NSMapTable *table1, NSMapTable *table2)
{
    unsigned i;
    struct _NSMapNode *node1;
    
    if (table1->hashSize != table2->hashSize)
	return NO;
    for (i=0; i<table1->hashSize; i++) {
	for (node1 = table1->nodes[i]; node1; node1 = node1->next) {
	    if (NSMapGet(table2, node1->key) != node1->value)
		return NO;
	}
    }
    return YES;
}

/* Get the Number of Items */
LF_DECLARE unsigned NSCountMapTable(NSMapTable *table)
{
    return table->itemsCount;
}

/* Retrieve Items */
LF_DECLARE BOOL NSMapMember(NSMapTable *table, const void *key, 
			    void **originalKey, void **value)
{
    struct _NSMapNode* node = table->nodes[
		table->keyCallbacks.hash(table, key) % table->hashSize];
    for(; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key)) {
            *originalKey = node->key;
	    *value = node->value;
	    return YES;
	}
    return NO;
}

LF_DECLARE void *NSMapGet(NSMapTable *table, const void *key)
{
    struct _NSMapNode* node = table->nodes[
		table->keyCallbacks.hash(table, key) % table->hashSize];
    for(; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key))
            return node->value;
    return NULL;
}

LF_DECLARE NSMapEnumerator NSEnumerateMapTable(NSMapTable *table)
{
    NSMapEnumerator en;
    en.table = table;
    en.node = NULL;
    en.bucket = -1;
    return en;
}

LF_DECLARE BOOL NSNextMapEnumeratorPair(NSMapEnumerator *en, 
					void **key, void **value)
{
    if(en->node)
	en->node = en->node->next;
    if(en->node == NULL) {
	for(en->bucket++; ((unsigned)en->bucket)<en->table->hashSize; en->bucket++)
	    if (en->table->nodes[en->bucket]) {
		    en->node = en->table->nodes[en->bucket];
		    break;
	    }
	if (((unsigned)en->bucket) >= en->table->hashSize) {
	    en->node = NULL;
	    en->bucket = en->table->hashSize-1;
	    return NO;
	}
    }
    *key = en->node->key;
    *value = en->node->value;
    return YES;
}

LF_DECLARE NSArray *NSAllMapTableKeys(NSMapTable *table)
{
    id array = [NSMutableArray arrayWithCapacity:table->itemsCount];
    struct _NSMapNode *node;
    unsigned i;

    for(i=0; i < table->hashSize; i++)
	for(node=table->nodes[i]; node; node=node->next)
	    [array addObject:(NSObject*)(node->key)];
    return array;
}

LF_DECLARE NSArray *NSAllMapTableValues(NSMapTable *table)
{
    id array = [NSMutableArray arrayWithCapacity:table->itemsCount];
    struct _NSMapNode *node;
    unsigned i;

    for(i=0; i < table->hashSize; i++)
	for(node=table->nodes[i]; node; node=node->next)
	    [array addObject:(NSObject*)(node->value)];
    return array;
}

/* Add or Remove an Item */
static void __NSMapGrow(NSMapTable *table, unsigned newSize)
{
    unsigned i;
    struct _NSMapNode** newNodeTable = NSZoneCalloc(table->zone,
	newSize, sizeof(struct _NSMapNode*));

    for(i = 0; i < table->hashSize; i++) {
	struct _NSMapNode *next, *node;
	unsigned int h;

	node = table->nodes[i];
	while(node) {
	    next = node->next;
	    h = table->keyCallbacks.hash(table, node->key) % newSize;
	    node->next = newNodeTable[h];
	    newNodeTable[h] = node;
	    node = next;
	}
    }
    NSZoneFree(table->zone, table->nodes);
    table->nodes = newNodeTable;
    table->hashSize = newSize;
}

LF_DECLARE void NSMapInsert(NSMapTable *table, const void *key, const void *value)
{
    unsigned int h;
    struct _NSMapNode *node;

    if (key == table->keyCallbacks.notAKeyMarker)
	[[[InvalidArgumentException alloc] initWithReason:
		@"Invalid key to be added in NSMapTable"] raise];

    h = table->keyCallbacks.hash(table, key) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key))
            break;

    /* Check if an entry for key exist in nodeTable. */
    if(node) {
        /* key exist. Set for it new value and return the old value of it. */
	if (key != node->key) {
	    table->keyCallbacks.retain(table, key);
	    table->keyCallbacks.release(table, node->key);
	}
	if (value != node->value) {
	    table->valueCallbacks.retain(table, value);
	    table->valueCallbacks.release(table, node->value);
	}
	node->key   = (void*)key;
	node->value = (void*)value;
        return;
    }

    /* key not found. Allocate a new bucket and initialize it. */
#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
    if (table->keysInvisible && table->valuesInvisible)
        node =
	  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
				      mapBucketKeyValueInvisible);
    else if (table->keysInvisible)
        node =
	  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
				      mapBucketKeyInvisible);
    else if (table->valuesInvisible)
        node =
	  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
				      mapBucketValueInvisible);
    else
#endif
        node = NSZoneMalloc(table->zone, sizeof(struct _NSMapNode));

    table->keyCallbacks.retain(table, key);
    table->valueCallbacks.retain(table, value);
    node->key = (void*)key;
    node->value = (void*)value;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    __NSCheckMapTableFull(table);
}

LF_DECLARE void *NSMapInsertIfAbsent(NSMapTable *table, const void *key, 
				     const void *value)
{
    unsigned int h;
    struct _NSMapNode *node;

    if (key == table->keyCallbacks.notAKeyMarker)
	[[[InvalidArgumentException alloc] initWithReason:
		@"Invalid key to be added in NSMapTable"] raise];

    h = table->keyCallbacks.hash(table, key) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key))
            break;

    /* Check if an entry for key exist in nodeTable. */
    if(node) {
        return node->key;
    }

    /* key not found. Allocate a new bucket and initialize it. */
#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
    if (table->keysInvisible && table->valuesInvisible)
        node =
	  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
				      mapBucketKeyValueInvisible);
    else if (table->keysInvisible)
        node =
	  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
				      mapBucketKeyInvisible);
    else if (table->valuesInvisible)
        node =
	  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
				      mapBucketValueInvisible);
    else
#endif
        node = NSZoneMalloc(table->zone, sizeof(struct _NSMapNode));

    table->keyCallbacks.retain(table, key);
    table->valueCallbacks.retain(table, value);
    node->key = (void*)key;
    node->value = (void*)value;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    __NSCheckMapTableFull(table);

    return NULL;
}

LF_DECLARE void NSMapInsertKnownAbsent(NSMapTable *table, const void *key, 
				       const void *value)
{
    unsigned int h;
    struct _NSMapNode *node;

    if (key == table->keyCallbacks.notAKeyMarker)
	[[[InvalidArgumentException alloc] initWithReason:
		@"Invalid key to be added in NSMapTable"] raise];

    h = table->keyCallbacks.hash(table, key) % table->hashSize;
    for(node = table->nodes[h]; node; node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key))
            break;

    /* Check if an entry for key exist in nodeTable. */
    if(node) 
	[[[InvalidArgumentException alloc] initWithReason:
		@"Nil object already existing in NSMapTable"] raise];

    /* key not found. Allocate a new bucket and initialize it. */
#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC
    if (table->keysInvisible && table->valuesInvisible)
        node =
	  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
				      mapBucketKeyValueInvisible);
    else if (table->keysInvisible)
        node =
	  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
				      mapBucketKeyInvisible);
    else if (table->valuesInvisible)
        node =
	  GC_MALLOC_EXPLICTLY_TYPED (sizeof (struct _NSMapNode),
				      mapBucketValueInvisible);
    else
#endif
        node = NSZoneMalloc(table->zone, sizeof(struct _NSMapNode));

    table->keyCallbacks.retain(table, key);
    table->valueCallbacks.retain(table, value);
    node->key = (void*)key;
    node->value = (void*)value;
    node->next = table->nodes[h];
    table->nodes[h] = node;

    __NSCheckMapTableFull(table);
}

LF_DECLARE void NSMapRemove(NSMapTable *table, const void *key)
{
    unsigned int h;
    struct _NSMapNode *node, *node1 = NULL;

    if (key == nil)
	    return;

    h = table->keyCallbacks.hash(table, key) % table->hashSize;

    // node point to current bucket, and node1 to previous bucket or to NULL
    // if current node is the first node in the list 

    for(node = table->nodes[h]; node; node1 = node, node = node->next)
        if(table->keyCallbacks.isEqual(table, key, node->key)) {
	    table->keyCallbacks.release(table, node->key);
	    table->valueCallbacks.release(table, node->value);
            if(!node1)
                table->nodes[h] = node->next;
            else
                node1->next = node->next;
	    NSZoneFree(table->zone, node);
	    (table->itemsCount)--;
	    return;
        }
}

LF_DECLARE NSString *NSStringFromMapTable(NSMapTable *table)
{
    id ret = [NSMutableString new];
    unsigned i;
    struct _NSMapNode *node;
    
    for (i=0; i<table->hashSize; i++)
	for (node = table->nodes[i]; node; node = node->next) {
	    [ret appendString:table->keyCallbacks.describe(table, node->key)];
	    [ret appendString:@"="];
	    [ret appendString:table->valueCallbacks.describe(table, node->value)];
	    [ret appendString:@"\n"];
	}
    
    return ret;
}

/*
 * Convenience functions
 */
 
LF_DECLARE unsigned __NSHashObject(void *table, const void *anObject)
{
    return (unsigned)[(id)anObject hash];
}

LF_DECLARE unsigned __NSHashPointer(void *table, const void *anObject)
{
    return (unsigned)((long)anObject / 4);
}

LF_DECLARE unsigned __NSHashInteger(void *table, const void *anObject)
{
    return (unsigned)(long)anObject;
}

/* From Aho, Sethi & Ullman: Principles of compiler design. */
LF_DECLARE unsigned __NSHashCString(void *table, const void *aString)
{
    register const char* p = (char*)aString;
    register unsigned hash = 0, hash2;
    register int i, n = Strlen((char*)aString);

    for(i=0; i < n; i++) {
        hash <<= 4;
        hash += *p++;
        if((hash2 = hash & 0xf0000000))
            hash ^= (hash2 >> 24) ^ hash2;
    }
    return hash;
}

LF_DECLARE BOOL __NSCompareObjects(void *table, 
				   const void *anObject1,
				   const void *anObject2)
{
    return [(NSObject*)anObject1 isEqual:(NSObject*)anObject2];
}

LF_DECLARE BOOL __NSComparePointers(void *table, 
				    const void *anObject1,
				    const void *anObject2)
{
    return anObject1 == anObject2;
}

LF_DECLARE BOOL __NSCompareInts(void *table, 
				const void *anObject1, const void *anObject2)
{
    return anObject1 == anObject2;
}

LF_DECLARE BOOL __NSCompareCString(void *table, 
				   const void *anObject1,
				   const void *anObject2)
{
    return Strcmp((char*)anObject1, (char*)anObject2) == 0;
}

LF_DECLARE void __NSRetainNothing(void *table, const void *anObject)
{
}

LF_DECLARE void __NSRetainObjects(void *table, const void *anObject)
{
    (void)RETAIN((NSObject*)anObject);
}

LF_DECLARE void __NSReleaseNothing(void *table, void *anObject)
{
}

LF_DECLARE void __NSReleaseObjects(void *table, void *anObject)
{
    RELEASE((NSObject*)anObject);
}

LF_DECLARE void __NSReleasePointers(void *table, void *anObject)
{
    lfFree(anObject);
}

LF_DECLARE NSString* __NSDescribeObjects(void *table, const void *anObject)
{
    return [(NSObject*)anObject description];
}

LF_DECLARE NSString* __NSDescribePointers(void *table, const void *anObject)
{
    return [NSString stringWithFormat:@"%p", anObject];
}

LF_DECLARE NSString* __NSDescribeInts(void *table, const void *anObject)
{
    return [NSString stringWithFormat:@"%ld", (long)anObject];
}

/*
* NSHashTable predefined callbacks
*/

LF_DECLARE const NSHashTableCallBacks NSIntHashCallBacks = { 
    (unsigned(*)(NSHashTable*, const void*))__NSHashInteger, 
    (BOOL(*)(NSHashTable*, const void*, const void*))__NSCompareInts, 
    (void(*)(NSHashTable*, const void*))__NSRetainNothing, 
    (void(*)(NSHashTable*, void*))__NSReleaseNothing, 
    (NSString*(*)(NSHashTable*, const void*))__NSDescribeInts 
};

LF_DECLARE const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks = { 
    (unsigned(*)(NSHashTable*, const void*))__NSHashPointer, 
    (BOOL(*)(NSHashTable*, const void*, const void*))__NSComparePointers, 
    (void(*)(NSHashTable*, const void*))__NSRetainNothing, 
    (void(*)(NSHashTable*, void*))__NSReleaseNothing, 
    (NSString*(*)(NSHashTable*, const void*))__NSDescribePointers 
};

LF_DECLARE const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks = { 
    (unsigned(*)(NSHashTable*, const void*))__NSHashObject, 
    (BOOL(*)(NSHashTable*, const void*, const void*))__NSCompareObjects, 
    (void(*)(NSHashTable*, const void*))__NSRetainNothing, 
    (void(*)(NSHashTable*, void*))__NSReleaseNothing, 
    (NSString*(*)(NSHashTable*, const void*))__NSDescribeObjects 
};
 
LF_DECLARE const NSHashTableCallBacks NSObjectHashCallBacks = { 
    (unsigned(*)(NSHashTable*, const void*))__NSHashObject, 
    (BOOL(*)(NSHashTable*, const void*, const void*))__NSCompareObjects, 
    (void(*)(NSHashTable*, const void*))__NSRetainObjects, 
    (void(*)(NSHashTable*, void*))__NSReleaseObjects, 
    (NSString*(*)(NSHashTable*, const void*))__NSDescribeObjects 
};

LF_DECLARE const NSHashTableCallBacks NSOwnedObjectIdentityHashCallBacks = { 
    (unsigned(*)(NSHashTable*, const void*))__NSHashPointer, 
    (BOOL(*)(NSHashTable*, const void*, const void*))__NSComparePointers, 
    (void(*)(NSHashTable*, const void*))__NSRetainObjects, 
    (void(*)(NSHashTable*, void*))__NSReleaseObjects, 
    (NSString*(*)(NSHashTable*, const void*))__NSDescribeObjects 
};

LF_DECLARE const NSHashTableCallBacks NSOwnedPointerHashCallBacks = { 
    (unsigned(*)(NSHashTable*, const void*))__NSHashObject, 
    (BOOL(*)(NSHashTable*, const void*, const void*))__NSCompareObjects, 
    (void(*)(NSHashTable*, const void*))__NSRetainNothing, 
    (void(*)(NSHashTable*, void*))__NSReleasePointers, 
    (NSString*(*)(NSHashTable*, const void*))__NSDescribePointers 
};

LF_DECLARE const NSHashTableCallBacks NSPointerToStructHashCallBacks = { 
    (unsigned(*)(NSHashTable*, const void*))__NSHashPointer, 
    (BOOL(*)(NSHashTable*, const void*, const void*))__NSComparePointers, 
    (void(*)(NSHashTable*, const void*))__NSRetainNothing, 
    (void(*)(NSHashTable*, void*))__NSReleasePointers, 
    (NSString*(*)(NSHashTable*, const void*))__NSDescribePointers 
};

/*
* NSMapTable predefined callbacks
*/

LF_DECLARE const NSMapTableKeyCallBacks NSIntMapKeyCallBacks = {
    (unsigned(*)(NSMapTable *, const void *))__NSHashInteger,
    (BOOL(*)(NSMapTable *, const void *, const void *))__NSCompareInts,
    (void (*)(NSMapTable *, const void *anObject))__NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))__NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribeInts,
    (const void *)NULL
};

LF_DECLARE const NSMapTableValueCallBacks NSIntMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))__NSRetainNothing,
    (void (*)(NSMapTable *, void *))__NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribeInts
};

LF_DECLARE const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks = {
    (unsigned(*)(NSMapTable *, const void *))__NSHashPointer,
    (BOOL(*)(NSMapTable *, const void *, const void *))__NSComparePointers,
    (void (*)(NSMapTable *, const void *anObject))__NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))__NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribePointers,
    (const void *)NULL
}; 

LF_DECLARE const NSMapTableKeyCallBacks NSNonOwnedCStringMapKeyCallBacks = {
    (unsigned(*)(NSMapTable *, const void *))__NSHashCString,
    (BOOL(*)(NSMapTable *, const void *, const void *))__NSCompareCString,
    (void (*)(NSMapTable *, const void *anObject))__NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))__NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribePointers,
    (const void *)NULL
}; 

LF_DECLARE const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))__NSRetainNothing,
    (void (*)(NSMapTable *, void *))__NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribePointers
};

LF_DECLARE const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks = {
    (unsigned(*)(NSMapTable *, const void *))__NSHashPointer,
    (BOOL(*)(NSMapTable *, const void *, const void *))__NSComparePointers,
    (void (*)(NSMapTable *, const void *anObject))__NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))__NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribePointers,
    (const void *)NSNotAPointerMapKey
};

LF_DECLARE const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks = {
    (unsigned(*)(NSMapTable *, const void *))__NSHashObject,
    (BOOL(*)(NSMapTable *, const void *, const void *))__NSCompareObjects,
    (void (*)(NSMapTable *, const void *anObject))__NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))__NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribeObjects,
    (const void *)NULL
};

LF_DECLARE const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))__NSRetainNothing,
    (void (*)(NSMapTable *, void *))__NSReleaseNothing,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribeObjects
}; 

LF_DECLARE const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks = {
    (unsigned(*)(NSMapTable *, const void *))__NSHashObject,
    (BOOL(*)(NSMapTable *, const void *, const void *))__NSCompareObjects,
    (void (*)(NSMapTable *, const void *anObject))__NSRetainObjects,
    (void (*)(NSMapTable *, void *anObject))__NSReleaseObjects,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribeObjects,
    (const void *)NULL
}; 

LF_DECLARE const NSMapTableValueCallBacks NSObjectMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))__NSRetainObjects,
    (void (*)(NSMapTable *, void *))__NSReleaseObjects,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribeObjects
}; 

LF_DECLARE const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks = {
    (unsigned(*)(NSMapTable *, const void *))__NSHashPointer,
    (BOOL(*)(NSMapTable *, const void *, const void *))__NSComparePointers,
    (void (*)(NSMapTable *, const void *anObject))__NSRetainNothing,
    (void (*)(NSMapTable *, void *anObject))__NSReleasePointers,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribePointers,
    (const void *)NULL
};

LF_DECLARE const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks = {
    (void (*)(NSMapTable *, const void *))__NSRetainNothing,
    (void (*)(NSMapTable *, void *))__NSReleasePointers,
    (NSString *(*)(NSMapTable *, const void *))__NSDescribePointers
}; 

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
