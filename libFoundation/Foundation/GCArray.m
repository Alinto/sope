/* 
   GCArray.m

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

#include "common.h"
#include <extensions/objc-runtime.h>
#include <extensions/GCArray.h>
#include <extensions/GCObject.h>
#include <extensions/GarbageCollector.h>
#include <extensions/NSException.h>
#include <extensions/exceptions/GeneralExceptions.h>
#include <Foundation/NSUtilities.h>

@implementation GCArray

+ (void)initialize
{
    static BOOL initialized = NO;

    if(!initialized) {
	initialized = YES;
	class_add_behavior(self, [GCObject class]);
    }
}

- (id)initWithObjects:(id *)objects count:(unsigned int)count
{
    unsigned i;
    
    self->items =
        Calloc(count > 0 ? count : 1, sizeof(id));
    self->isGarbageCollectable =
        CallocAtomic(count > 0 ? count : 1, sizeof(BOOL));
    self->itemsCount = count;
    for (i = 0; i < count; i++) {
	if (!(items[i] = RETAIN(objects[i])))
	    [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in array"] raise];
	else isGarbageCollectable[i] = [objects[i] isGarbageCollectable];
    }
    return self;
}

- (id)initWithArray:(NSArray*)anotherArray
{
    unsigned i, count = [anotherArray count];

    self->items = Calloc(count > 0 ? count : 1, sizeof(id));
    self->isGarbageCollectable =
        CallocAtomic(count > 0 ? count : 1, sizeof(BOOL));
    self->itemsCount = count;
    for (i = 0; i < itemsCount; i++) {
	items[i] = RETAIN([anotherArray objectAtIndex:i]);
	isGarbageCollectable[i] = [items[i] isGarbageCollectable];
    }
    return self;
}

- (void)dealloc
{
    unsigned int index;

    if ([GarbageCollector isGarbageCollecting]) {
	for (index = 0; index < itemsCount; index++)
	    if(!isGarbageCollectable[index])
		RELEASE(items[index]);
    }
    else {
	for (index = 0; index < itemsCount; index++)
	    RELEASE(items[index]);
    }

    lfFree(items);
    lfFree(isGarbageCollectable);
    [super dealloc];
}

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    return [[GCArray allocWithZone:zone] initWithArray:self copyItems:YES];
}

- (id)mutableCopyWithZone:(NSZone*)zone
{
    return [[GCMutableArray allocWithZone:zone]
		initWithArray:self copyItems:YES];
}

- (id)objectAtIndex:(unsigned int)index
{
    if (index >= itemsCount)
	[[[RangeException alloc] 
		initWithReason:@"objectAtIndex: in NSArray" 
		size:itemsCount index:index] raise];
    return items[index];
}

- (unsigned int)count
{
    return itemsCount;
}

- (unsigned int)indexOfObjectIdenticalTo:(id)anObject
{
    unsigned i;
    for (i = 0; i < itemsCount; i++)
	if (items[i] == anObject)
		return i;
    return NSNotFound;
}

- (void)gcDecrementRefCountOfContainedObjects
{
    int i, count;

    for (i = 0, count = [self count]; i < count; i++)
	if (isGarbageCollectable[i])
	    [[self objectAtIndex:i] gcDecrementRefCount];
}

- (BOOL)gcIncrementRefCountOfContainedObjects
{
    int i, count;

    if ([(id)self gcAlreadyVisited])
	return NO;
    [(id)self gcSetVisited:YES];

    for (i = 0, count = [self count]; i < count; i++)
	if(isGarbageCollectable[i]) {
	    id object = [self objectAtIndex:i];
	    [object gcIncrementRefCount];
	    [object gcIncrementRefCountOfContainedObjects];
	}
    return YES;
}

- (Class)classForCoder
{
    return [GCArray class];
}

@end /* GCArray */


@implementation GCMutableArray

+ (void)initialize
{
    static BOOL initialized = NO;
    if(!initialized) {
	initialized = YES;
	class_add_behavior(self, [GCArray class]);
    }
}

- (id)init
{
    return [self initWithCapacity:1];
}

- (id)initWithCapacity:(unsigned int)aNumItems
{
    if (aNumItems == 0) aNumItems = 16;
    self->items = Calloc(aNumItems, sizeof(id));
    self->isGarbageCollectable = CallocAtomic(aNumItems, sizeof(BOOL));
    self->maxItems = aNumItems;
    self->itemsCount = 0;
    return self;
}

- (id)initWithObjects:(id *)objects count:(unsigned int)count
{
    unsigned i;
    
    self->maxItems = count > 0 ? count : 1;
    self->items = Calloc(maxItems, sizeof(id));
    self->isGarbageCollectable = CallocAtomic(maxItems, sizeof(BOOL));
    self->itemsCount = count;
    
    for (i = 0; i < count; i++) {
	if (!(items[i] = RETAIN(objects[i]))) {
	    [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in array"] raise];
        }
	else
            isGarbageCollectable[i] = [objects[i] isGarbageCollectable];
    }
    return self;
}

- (id)initWithArray:(NSArray*)anotherArray
{
    unsigned i, count = [anotherArray count];

    self->maxItems = count > 0 ? count : 1;
    self->items = Calloc(self->maxItems, sizeof(id));
    self->isGarbageCollectable = CallocAtomic(self->maxItems, sizeof(BOOL));
    self->itemsCount = count;
    for (i = 0; i < itemsCount; i++) {
	items[i] = RETAIN([anotherArray objectAtIndex:i]);
	isGarbageCollectable[i] = [items[i] isGarbageCollectable];
    }
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    return [[GCArray allocWithZone:zone] 
		initWithArray:self copyItems:YES];
}

- (id)mutableCopyWithZone:(NSZone*)zone
{
    return [[GCMutableArray allocWithZone:zone] 
		initWithArray:self copyItems:YES];
}

- (void)insertObject:(id)anObject atIndex:(unsigned int)index
{
    unsigned int i;
    if (!anObject)
	[[[InvalidArgumentException alloc] 
		initWithReason:@"Nil object to be added in array"] raise];
    if (index > itemsCount)
	[[[RangeException alloc] 
		initWithReason:@"insertObject:atIndex: in GCMutableArray" 
		size:itemsCount index:index] raise];
    if (itemsCount == maxItems) {
	if (maxItems) {
	    maxItems += (maxItems >> 1) ? (maxItems >>1) : 1;
	}
	else {
	    maxItems = 1;
	}
	items = (id*)Realloc(items, sizeof(id) * maxItems);
	isGarbageCollectable = (BOOL*)Realloc(isGarbageCollectable,
					      sizeof(BOOL) * maxItems);
    }
    for(i = itemsCount; i > index; i--) {
	items[i] = items[i - 1];
	isGarbageCollectable[i] = isGarbageCollectable[i - 1];
    }
    items[index] = RETAIN(anObject);
    isGarbageCollectable[index] = [anObject isGarbageCollectable];
    itemsCount++;
}

- (void)addObject:(id)anObject
{
    [self insertObject:anObject atIndex:itemsCount];
}

- (void)replaceObjectAtIndex:(unsigned int)index  withObject:(id)anObject
{
    if (!anObject)
	[[[InvalidArgumentException alloc] 
		initWithReason:@"Nil object to be added in array"] raise];
    if (index >= itemsCount)
	[[[RangeException alloc] 
		initWithReason:@"GCMutableArray replaceObjectAtIndex" 
		size:itemsCount index:index] raise];
    ASSIGN(items[index], anObject);
    isGarbageCollectable[index] = [anObject isGarbageCollectable];
}

- (void)removeObjectsFrom:(unsigned int)index
	count:(unsigned int)count
{
    unsigned i;
    if (index + count > itemsCount)
	[[[RangeException alloc]
		initWithReason:@"removeObjectsFrom:count: in GCMutableArray"
		size:itemsCount index:index] raise];
    if (!count)
	return;
    for (i = index; i < index + count; i++)
	RELEASE(items[index]);

    for (i = index + count; i < itemsCount; i++, index++) {
	items[index] = items[i];
	isGarbageCollectable[index] = isGarbageCollectable[i];
    }
    for (; index < itemsCount; index++)
	items[index] = (id)0x3;

    itemsCount -= count;
}

- (void)removeAllObjects
{
    [self removeObjectsFrom:0 count:itemsCount];
}

- (void)removeLastObject
{
    if (itemsCount)
	[self removeObjectsFrom:(itemsCount - 1) count:1];
}

- (void)removeObjectAtIndex:(unsigned int)index
{
    [self removeObjectsFrom:index count:1];
}

- (Class)classForCoder
{
    return [GCMutableArray class];
}

@end /* GCMutableArray */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

