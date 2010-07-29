/* 
   NSConcreteArray.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <stdio.h>

#include <Foundation/common.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include <extensions/objc-runtime.h>

#include "NSConcreteArray.h"

#define DO_NOT_USE_ZONE 1

static NSConcreteEmptyArray *sharedEmptyArray = nil;

/*
 * NSConcreteArray class
 */

@implementation NSConcreteArray

+ (void)initialize
{
    if (sharedEmptyArray == nil)
        sharedEmptyArray = [[NSConcreteEmptyArray alloc] init];
}

- (id)init
{
    RELEASE(self);
    return RETAIN(sharedEmptyArray);
}

- (id)initWithObjects:(id *)objects count:(unsigned int)count
{
    unsigned i;

    if (count == 0) {
        RELEASE(self);
        return RETAIN(sharedEmptyArray);
    }
    else if (count == 1) {
        RELEASE(self);
        return [[NSConcreteSingleObjectArray alloc]
                                             initWithObjects:objects count:1];
    }
    
#if DO_NOT_USE_ZONE
    self->items      = calloc(count, sizeof(id));
#else
    self->items      = NSZoneCalloc([self zone], sizeof(id), count);
#endif
    self->itemsCount = count;
    for (i = 0; i < count; i++) {
	if (!(self->items[i] = RETAIN(objects[i]))) {
	    [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in array"] raise];
        }
    }
    return self;
}

- (id)initWithArray:(NSArray *)anotherArray
{
    unsigned i, count = [anotherArray count];

    if (count == 0) {
        RELEASE(self);
        return RETAIN(sharedEmptyArray);
    }
    else if (count == 1) {
        id item = [anotherArray objectAtIndex:0];
        
        RELEASE(self);
        return [[NSConcreteSingleObjectArray alloc]
                                             initWithObjects:&item count:1];
    }
    
#if DO_NOT_USE_ZONE
    self->items = calloc(count, sizeof(id));
#else
    self->items = NSZoneCalloc([self zone], sizeof(id), count);
#endif
    self->itemsCount = count;
    for (i = 0; i < itemsCount; i++)
	self->items[i] = RETAIN([anotherArray objectAtIndex:i]);
    return self;
}

- (void)dealloc
{
    register signed int index; // Note: this limits the size of the array
    
    if ((index = self->itemsCount) > 0) {
	/* 
	   Not using static cache because the array content is only similiar
	   inside a single collection, not across collections (arrays being
	   used in various contexts).
	   Hitrate of the cache is about 75% (including initial miss).
	*/
	register Class LastClass  = Nil;
	register IMP   objRelease = NULL;
	
	for (index--; index >= 0; index--) {
	    // TODO: cache RELEASE IMP
#if LIB_FOUNDATION_BOEHM_GC
	    self->items[index] = nil;
#else
	    register id obj = self->items[index];
	    
	    if (*(id *)obj != LastClass) {
		LastClass = *(id *)obj;
		objRelease = method_get_imp(object_is_instance(obj)
                  ? class_get_instance_method(LastClass, @selector(release))
		  : class_get_class_method(LastClass, @selector(release)));
	    }
	    
	    objRelease(obj, NULL /* dangerous? */);
	}
#endif
    }
    
#if DO_NOT_USE_ZONE
    if (self->items) free(self->items);
#else
    lfFree(self->items);
#endif
    [super dealloc];
}

/* Querying the Array */

- (id)objectAtIndex:(unsigned int)index
{
    if (index >= self->itemsCount) {
	[[[RangeException alloc] 
		initWithReason:@"objectAtIndex: in NSArray" 
		size:self->itemsCount index:index] raise];
    }
    return self->items[index];
}

- (unsigned int)count
{
    return self->itemsCount;
}

- (unsigned int)indexOfObjectIdenticalTo:(id)anObject
{
    unsigned i;
    
    for (i = 0; i < self->itemsCount; i++) {
	if (items[i] == anObject)
		return i;
    }
    return NSNotFound;
}

@end /* NSConcreteArray */

/*
 * NSConcreteEmptyArray class
 */

@implementation NSConcreteEmptyArray

- (id)init
{
    return self;
}
- (id)initWithObjects:(id *)objects count:(unsigned int)count
{
    if (count > 0) {
        RELEASE(self);
        self = [[NSConcreteArray alloc] initWithObjects:objects count:count];
    }
    return self;
}
- (id)initWithArray:(NSArray *)anotherArray
{
    if ([anotherArray count] > 0) {
        id tmp;
        tmp = [[NSConcreteArray alloc] initWithArray:anotherArray];
        RELEASE(self);
        return tmp;
    }
    return self;
}

- (id)objectAtIndex:(unsigned int)index
{
    [[[RangeException alloc] 
              initWithReason:@"objectAtIndex: in NSArray" size:0 index:index] raise];
    return nil;
}
- (unsigned int)count
{
    return 0;
}
- (unsigned int)indexOfObjectIdenticalTo:(id)anObject
{
    return NSNotFound;
}

@end /* NSConcreteEmptyArray */

/*
 * NSConcreteSingleObjectArray class
 */

@implementation NSConcreteSingleObjectArray

+ (void)initialize {
    // force setup of shared emtpy
    if (sharedEmptyArray == nil)
        sharedEmptyArray = [[NSConcreteEmptyArray alloc] init];
}

- (id)init
{
    RELEASE(self);
    return RETAIN(sharedEmptyArray);
}
- (id)initWithObjects:(id *)objects count:(unsigned int)count
{
    if (count == 0) {
        RELEASE(self);
        return RETAIN(sharedEmptyArray);
    }
    if (count > 1) {
        RELEASE(self);
        self = [[NSConcreteArray allocWithZone:[self zone]]
                                 initWithObjects:objects count:count];
    }
    
    if ((self->item = objects[0]) == nil) {
        [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in array"] raise];
    }
    self->item = RETAIN(self->item);
    return self;
}
- (id)initWithArray:(NSArray *)anotherArray
{
    unsigned count = [anotherArray count];
    
    if (count == 0) {
        RELEASE(self);
        return RETAIN(sharedEmptyArray);
    }
    if (count > 1) {
        RELEASE(self);
        self = [[NSConcreteArray alloc] initWithArray:anotherArray];
    }
    
    if ((self->item = [anotherArray objectAtIndex:0]) == nil) {
        [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in array"] raise];
    }
    self->item = RETAIN(self->item);
    return self;
}

- (void)dealloc
{
    RELEASE(self->item);
    [super dealloc];
}

// query array

- (id)objectAtIndex:(unsigned int)index
{
    if (index > 0) {
      [[[RangeException alloc] 
                initWithReason:@"objectAtIndex: in NSArray" size:1 index:index] raise];
    }
    return self->item;
}
- (unsigned int)count
{
    return 1;
}
- (unsigned int)indexOfObjectIdenticalTo:(id)anObject
{
    return (self->item == anObject) ? 0 : NSNotFound;
}

@end /* NSConcreteSingleObjectArray */

/*
 * NSConcreteMutableArray class
 */

@implementation NSConcreteMutableArray

+ (void)initialize
{
    static BOOL initialized = NO;
    if(!initialized) {
	initialized = YES;
	class_add_behavior(self, [NSConcreteArray class]);
    }
}

- (id)init
{
#if DO_NOT_USE_ZONE
    self->items = calloc(1, sizeof(id));
#else
    self->items = NSZoneCalloc([self zone], 1, sizeof(id));
#endif
    self->maxItems   = 1;
    self->itemsCount = 0;
    return self;
}

- (id)initWithCapacity:(unsigned int)aNumItems
{
    self->maxItems = aNumItems ? aNumItems : 16;
#if DO_NOT_USE_ZONE
    self->items = calloc(self->maxItems, sizeof(id));
#else
    self->items = NSZoneCalloc([self zone], sizeof(id), self->maxItems);
#endif
    self->itemsCount = 0;
    return self;
}

- (id)initWithObjects:(id *)objects count:(unsigned int)count
{
    unsigned i;

    if (count > 0) {
        self->maxItems   = count;
        self->itemsCount = count;
    }
    else {
        self->maxItems   = 1;
        self->itemsCount = 0;
    }
    
#if DO_NOT_USE_ZONE
    self->items = calloc(self->maxItems, sizeof(id));
#else
    self->items = NSZoneCalloc([self zone], sizeof(id), self->maxItems);
#endif

    for (i = 0; i < count; i++) {
	if ((self->items[i] = RETAIN(objects[i])) == nil) {
	    [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in array"] raise];
        }
    }
    return self;
}

- (id)initWithArray:(NSArray *)anotherArray
{
    unsigned i, count = [anotherArray count];

    if (count > 0) {
        self->maxItems   = count;
        self->itemsCount = count;
    }
    else {
        self->maxItems   = 1;
        self->itemsCount = 0;
    }
    
#if DO_NOT_USE_ZONE
    self->items = calloc(self->maxItems, sizeof(id));
#else
    self->items = NSZoneCalloc([self zone], sizeof(id), self->maxItems);
#endif

    for (i = 0; i < self->itemsCount; i++) {
	self->items[i] = RETAIN([anotherArray objectAtIndex:i]);
    }
    return self;
}

- (void)dealloc
{
    /* basically a copy of the NSConcreteArray -dealloc, might use a macro */
    register signed int index;
    
    if ((index = self->itemsCount) > 0) {
	/* 
	   Not using static cache because the array content is only similiar
	   inside a single collection, not across collections (arrays being
	   used in various contexts).
	   Hitrate of the cache is about 75% including initial miss.
	*/
	register Class LastClass  = Nil;
	register IMP   objRelease = NULL;
	
	for (index--; index >= 0; index--) {
	    // TODO: cache RELEASE IMP
#if LIB_FOUNDATION_BOEHM_GC
	    self->items[index] = nil;
#else
	    register id obj = self->items[index];
	    
	    if (*(id *)obj != LastClass) {
		LastClass = *(id *)obj;
		objRelease = method_get_imp(object_is_instance(obj)
                  ? class_get_instance_method(LastClass, @selector(release))
		  : class_get_class_method(LastClass, @selector(release)));
	    }
	    
	    objRelease(obj, NULL /* dangerous? */);
	}
#endif
    }

#if DO_NOT_USE_ZONE
    if (self->items) free(self->items);
#else
    lfFree(self->items);
#endif
    [super dealloc];
}

/* Altering the Array */

- (void)insertObject:(id)anObject atIndex:(unsigned int)index
{
    unsigned int i;
    
    if (anObject == nil) {
	[[[InvalidArgumentException alloc] 
		initWithReason:@"Nil object to be added in array"] raise];
    }
    if (index > itemsCount) {
	[[[RangeException alloc] 
		initWithReason:@"__insertObject:atIndex: in NSMutableArray" 
		size:itemsCount index:index] raise];
    }

    /* resize item array */
    if (itemsCount == maxItems) {
	if (maxItems != 0) {
	    maxItems += (maxItems >> 1) ? (maxItems >>1) : 1;
	}
	else {
	    maxItems = 1;
	}
	items = (id*)Realloc(items, sizeof(id) * maxItems);
    }
    
    /* move items */
    for(i = itemsCount; i > index; i--)
	items[i] = items[i - 1];
    
    /* place new item */
    items[index] = RETAIN(anObject);
    itemsCount++;
}

- (void)replaceObjectAtIndex:(unsigned int)index  withObject:(id)anObject
{
    if (anObject == nil) {
	[[[InvalidArgumentException alloc] 
		initWithReason:@"Nil object to be added in array"] raise];
    }
    if (index >= self->itemsCount) {
	[[[RangeException alloc] 
		initWithReason:@"NSConcreteMutableArray replaceObjectAtIndex" 
		size:self->itemsCount index:index] raise];
    }
    ASSIGN(self->items[index], anObject);
}

/* removing objects */

static inline void
_removeObjectsFrom(register NSConcreteMutableArray *self,
                   register unsigned int index, register unsigned int count)
{
    register unsigned int i;
    
    if ((index + count) > self->itemsCount) {
	[[[RangeException alloc]
		initWithReason:@"removeObjectsFrom:count in NSMutableArray"
		size:self->itemsCount index:(index + count)] raise];
    }
    if (count == 0)
	return;

#if !LIB_FOUNDATION_BOEHM_GC
    // TODO: why autorelease?
    for (i = index; i < index + count; i++)
	[self->items[i] autorelease];
#endif

    for (i = index + count; i < self->itemsCount; i++, index++)
	self->items[index] = self->items[i];
    for (; index < self->itemsCount; index++) {
#if DEBUG // better for crashing
	self->items[index] = (id)0x3;
#else // more stable against bugs
        self->items[index] = nil;
#endif
    }

    self->itemsCount -= count;
}

- (void)removeObjectsFrom:(unsigned int)index count:(unsigned int)count
{
    _removeObjectsFrom(self, index, count);
}
- (void)removeObjectsInRange:(NSRange)aRange
{
    _removeObjectsFrom(self, aRange.location, aRange.length);
}
- (void)removeAllObjects
{
    _removeObjectsFrom(self, 0, self->itemsCount);
}
- (void)removeLastObject
{
    if (self->itemsCount > 0) _removeObjectsFrom(self, (itemsCount - 1), 1);
}
- (void)removeObjectAtIndex:(unsigned int)index
{
    _removeObjectsFrom(self, index, 1);
}

@end /* NSConcreteMutableArray */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
