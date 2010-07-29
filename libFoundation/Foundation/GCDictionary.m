/* 
   GCDictionary.m

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

#include <config.h>
#include <Foundation/NSString.h>

#include <extensions/objc-runtime.h>
#include <extensions/GCDictionary.h>
#include <extensions/NSException.h>
#include <extensions/exceptions/GeneralExceptions.h>
#include <extensions/GCObject.h>
#include <extensions/GarbageCollector.h>
#include "common.h"

/*
 * TODO: copyWithZone:
 */

@interface _GCDictionaryKeyEnumerator : NSEnumerator
{
    GCDictionary*	dict;
    NSMapEnumerator	enumerator;
}

- (id)initWithDictionary:(id)_dict;
- (id)nextObject;

@end /* _GCDictionaryKeyEnumerator */

@implementation _GCDictionaryKeyEnumerator

- (id)initWithDictionary:(id)_dict
{
    dict = RETAIN(_dict);
    enumerator = [dict __keyEnumerator];
    return self;
}

- (void)dealloc
{
    RELEASE(dict);
    [super dealloc];
}

- (id)nextObject
{
    GCObjectCollectable *keyStruct, *valueStruct;
    return NSNextMapEnumeratorPair(&enumerator, 
	(void**)&keyStruct, (void**)&valueStruct) ? keyStruct->object : nil;
}

@end /* _GCDictionaryKeyEnumerator */


@implementation GCDictionary

static unsigned __GCHashObject(NSMapTable *table,
    const GCObjectCollectable* objectStruct)
{
    return [(NSObject*)(objectStruct->object) hash];
}

static BOOL __GCCompareObjects(
    NSMapTable *table, 
    const GCObjectCollectable* objectStruct1,
    const GCObjectCollectable* objectStruct2)
{
    return [objectStruct1->object isEqual:objectStruct2->object];
}

static void __GCRetainObjects(NSMapTable *table,
    const GCObjectCollectable* objectStruct)
{
    (void)RETAIN(objectStruct->object);
}

static void __GCReleaseObjects(NSMapTable *table,
    GCObjectCollectable* objectStruct)
{
    if([GarbageCollector isGarbageCollecting]) {
	if(!objectStruct->isGarbageCollectable)
	    RELEASE(objectStruct->object);
    }
    else
	RELEASE(objectStruct->object);
    lfFree(objectStruct);
}

static NSString* __GCDescribeObjects(NSMapTable *table,
    const GCObjectCollectable* objectStruct)
{
    return [objectStruct->object description];
}

static const NSMapTableKeyCallBacks GCOwnedStructMapKeyCallBacks = {
    (unsigned(*)(NSMapTable *, const void *))__GCHashObject,
    (BOOL(*)(NSMapTable *, const void *, const void *))__GCCompareObjects,
    (void (*)(NSMapTable *, const void *anObject))__GCRetainObjects,
    (void (*)(NSMapTable *, void *anObject))__GCReleaseObjects,
    (NSString *(*)(NSMapTable *, const void *))__GCDescribeObjects,
    (const void *)NULL
}; 

static const NSMapTableValueCallBacks GCOwnedStructValueCallBacks = {
    (void (*)(NSMapTable *, const void *))__GCRetainObjects,
    (void (*)(NSMapTable *, void *))__GCReleaseObjects,
    (NSString *(*)(NSMapTable *, const void *))__GCDescribeObjects
}; 

+ (void)initialize
{
    static BOOL initialized = NO;

    if(!initialized) {
	initialized = YES;
	class_add_behavior(self, [GCObject class]);
    }
}

- (void)_createTableWithSize:(unsigned)size
{
    table = NSCreateMapTableWithZone(GCOwnedStructMapKeyCallBacks,
		    GCOwnedStructValueCallBacks, size, [self zone]);
}

- (id)initWithDictionary:(NSDictionary*)dictionary
{
    id keys = [dictionary keyEnumerator];
    id key;

    [self _createTableWithSize:([dictionary count] * 4) / 3];

    while ((key = [keys nextObject])) {
	GCObjectCollectable* keyStruct = Malloc(sizeof(GCObjectCollectable));
	GCObjectCollectable* valueStruct = Malloc(sizeof(GCObjectCollectable));
	id value = [dictionary objectForKey:key];
	keyStruct->object = key;
	keyStruct->isGarbageCollectable = [key isGarbageCollectable];
	valueStruct->object = value;
	valueStruct->isGarbageCollectable = [value isGarbageCollectable];
	NSMapInsert(table, keyStruct, valueStruct);
    }
    
    return self;
}

- (id)initWithObjects:(id*)objects
    forKeys:(id*)keys 
    count:(unsigned int)count
{
    [self _createTableWithSize:(count * 4) / 3];

    if (!count)
	return self;
    while(count--) {
	GCObjectCollectable* keyStruct;
	GCObjectCollectable* valueStruct;

	if (!keys[count] || !objects[count])
	    [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in dictionary"] raise];
	keyStruct = Malloc(sizeof(GCObjectCollectable));
	valueStruct = Malloc(sizeof(GCObjectCollectable));
	keyStruct->object = keys[count];
	keyStruct->isGarbageCollectable = [keys[count] isGarbageCollectable];
	valueStruct->object = objects[count];
	valueStruct->isGarbageCollectable
	    = [objects[count] isGarbageCollectable];
	NSMapInsert(table, keyStruct, valueStruct);
    }
    return self;
}

- (void)dealloc
{
    NSFreeMapTable(table);
    [super dealloc];
}

- (NSEnumerator *)keyEnumerator
{
    return AUTORELEASE([(_GCDictionaryKeyEnumerator *)
			   [_GCDictionaryKeyEnumerator alloc]
                           initWithDictionary:self]);    
}

- (id)objectForKey:(id)key
{
    GCObjectCollectable keyStruct = { key, 0 };
    GCObjectCollectable* valueStruct = NSMapGet(table,
						(void**)&keyStruct);
    return valueStruct ? valueStruct->object : nil;
}

- (unsigned int)count
{
    return NSCountMapTable(table);
}

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else return	[[GCDictionary alloc] initWithDictionary:self copyItems:YES];
}

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [(GCMutableDictionary *)[GCMutableDictionary allocWithZone:zone]
				   initWithDictionary:self];
}

/* Private */
- (NSMapEnumerator)__keyEnumerator
{
    return NSEnumerateMapTable(table);
}

- (void)gcDecrementRefCountOfContainedObjects
{
    NSMapEnumerator enumerator = NSEnumerateMapTable(table);
    GCObjectCollectable *keyStruct, *valueStruct;

    while(NSNextMapEnumeratorPair(&enumerator,
	    (void**)&keyStruct, (void**)&valueStruct)) {
	if(keyStruct->isGarbageCollectable)
	    [keyStruct->object gcDecrementRefCount];
	if(valueStruct->isGarbageCollectable)
	    [valueStruct->object gcDecrementRefCount];
    }
}

- (BOOL)gcIncrementRefCountOfContainedObjects
{
    NSMapEnumerator enumerator;
    GCObjectCollectable *keyStruct, *valueStruct;

    if([(id)self gcAlreadyVisited])
	return NO;
    [(id)self gcSetVisited:YES];

    enumerator = NSEnumerateMapTable(table);
    while(NSNextMapEnumeratorPair(&enumerator,
	    (void**)&keyStruct, (void**)&valueStruct)) {
	if(keyStruct->isGarbageCollectable) {
	    [keyStruct->object gcIncrementRefCount];
	    [keyStruct->object gcIncrementRefCountOfContainedObjects];
	}
	if(valueStruct->isGarbageCollectable) {
	    [valueStruct->object gcIncrementRefCount];
	    [valueStruct->object gcIncrementRefCountOfContainedObjects];
	}
    }
    return YES;
}

- (Class)classForCoder
{
    return [GCDictionary class];
}

@end /* GCDictionary */


@implementation GCMutableDictionary

+ (void)initialize
{
    static BOOL initialized = NO;
    if(!initialized) {
	initialized = YES;
	class_add_behavior(self, [GCDictionary class]);
    }
}

- (id)init
{
    return [self initWithCapacity:0];
}

- (id)initWithCapacity:(unsigned int)aNumItems
{
    [(id)self _createTableWithSize:(aNumItems * 4) / 3];
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    return [(GCDictionary *)[GCDictionary allocWithZone:zone] 
			    initWithDictionary:self];
}

- (void)setObject:(id)anObject forKey:(id)aKey
{
    GCObjectCollectable *keyStruct   = Malloc(sizeof(GCObjectCollectable));
    GCObjectCollectable *valueStruct = Malloc(sizeof(GCObjectCollectable));
    
    keyStruct->object                 = aKey;
    keyStruct->isGarbageCollectable   = [aKey isGarbageCollectable];
    valueStruct->object               = anObject;
    valueStruct->isGarbageCollectable = [anObject isGarbageCollectable];
    NSMapInsert(table, keyStruct, valueStruct);
}

- (void)removeObjectForKey:(id)key
{
    GCObjectCollectable keyStruct = { key, 0 };
    NSMapRemove(table, (void**)&keyStruct);
}

- (void)removeAllObjects
{
    NSResetMapTable(table);
}

- (Class)classForCoder
{
    return [GCMutableDictionary class];
}

@end /* GCMutableDictionary */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
