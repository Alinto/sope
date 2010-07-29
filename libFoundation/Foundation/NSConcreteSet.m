/* 
   NSConcreteSet.m

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

#include <stdarg.h>

#include <Foundation/common.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>

#include <Foundation/NSException.h>
#include "NSConcreteSet.h"

/*
 * NSConcreteSet
 */

@implementation NSConcreteSet

/* Allocating and Initializing */

- (id)init
{
    self->table =
        NSCreateHashTableWithZone(NSObjectHashCallBacks, 0, [self zone]);
    return self;
}

- (id)initWithObjects:(id *)objects count:(unsigned int)count
{
    unsigned i;
    
    self->table =
        NSCreateHashTableWithZone(NSObjectHashCallBacks, count, [self zone]);
    for (i = 0; i < count; i++) {
	NSHashInsert(self->table, objects[i]);
    }
    return self;
}

- (id)initWithSet:(NSSet *)set copyItems:(BOOL)flag
{
    id en = [set objectEnumerator];
    id obj;
    
    self->table = NSCreateHashTableWithZone(NSObjectHashCallBacks, 
                                            [set count], [self zone]);
    while((obj = [en nextObject])) {
        obj = flag ? [obj copy] : obj;
	NSHashInsert(self->table, obj);
        if (flag) RELEASE(obj);
    }
    return self;
}

/* Destroying */

- (void)dealloc
{
    NSFreeHashTable(self->table);
    [super dealloc];
}

/* Copying */

- (id)copy
{
    return RETAIN(self);
}

- (id)copyWithZone:(NSZone*)zone
{
    return (zone == [self zone])
        ? RETAIN(self)
        : [[NSConcreteSet allocWithZone:zone] initWithSet:self copyItems:NO];
}

/* Accessing keys and values */

- (unsigned int)count
{
    return NSCountHashTable(table);
}

- (id)member:(id)anObject
{
    return (NSObject*)NSHashGet(table, anObject);
}

/* Entries */

- (NSEnumerator *)objectEnumerator
{
    return AUTORELEASE([[_NSConcreteSetEnumerator alloc]
                           initWithSet:self mode:setEnumHash]);
}

/* Private methods */

- (void)__setObjectEnumerator:(void*)en;
{
    *((NSHashEnumerator*)en) = NSEnumerateHashTable(table);
}

@end /* NSConcreteSet */

/*
 * NSConcreteMutableSet
 */
 
@implementation NSConcreteMutableSet

/* Allocating and Initializing */


- (id)init
{
    self->table =
        NSCreateHashTableWithZone(NSObjectHashCallBacks, 0, [self zone]);
    return self;
}

- (id)initWithCapacity:(unsigned)_capacity
{
    self->table = NSCreateHashTableWithZone(NSObjectHashCallBacks, 
                                            _capacity, [self zone]);
    return self;
}

- (id)initWithObjects:(id*)objects count:(unsigned int)count
{
    unsigned i;
    
    self->table = NSCreateHashTableWithZone(NSObjectHashCallBacks, 
                                            count, [self zone]);
    for (i = 0; i < count; i++)
	NSHashInsert(self->table, objects[i]);
    return self;
}

- (id)initWithSet:(NSSet *)set copyItems:(BOOL)flag
{
    id en = [set objectEnumerator];
    id obj;
    
    table = NSCreateHashTableWithZone(NSObjectHashCallBacks, 
					[set count], [self zone]);
    while((obj = [en nextObject])) {
        obj = flag ? [obj copy] : obj;
	NSHashInsert(table, obj);
        if (flag) RELEASE(obj);
    }
    return self;
}

/* Destroying */

- (void)dealloc
{
    NSFreeHashTable(self->table);
    [super dealloc];
}

/* Accessing keys and values */

- (unsigned int)count
{
    return NSCountHashTable(self->table);
}

- (id)member:(id)anObject
{
    return (NSObject*)NSHashGet(self->table, anObject);
}

/* Entries */

- (NSEnumerator *)objectEnumerator
{
    return AUTORELEASE([[_NSConcreteSetEnumerator alloc]
                           initWithSet:self mode:setEnumHash]);
}

/* Add and remove entries */

- (void)addObject:(id)object
{
    NSHashInsert(self->table, object);
}

- (void)removeObject:(id)object
{
    NSHashRemove(self->table, object);
}

- (void)removeAllObjects
{
    NSResetHashTable(self->table);
}

/* Private methods */

- (void)__setObjectEnumerator:(void*)en;
{
    *((NSHashEnumerator*)en) = NSEnumerateHashTable(self->table);
}

@end /* NSConcreteMutableSet */

/*
 * NSCountedSet
 */

@implementation NSCountedSet

/* Allocating and Initializing */

- (id)init
{
    return [self initWithCapacity:0];
}

- (id)initWithObjects:(id*)objects count:(unsigned int)count
{
    unsigned i;
    self = [self initWithCapacity:count];
    for (i = 0; i < count; i++)
	[self addObject:objects[i]];
    return self;
}

- (id)initWithSet:(NSSet *)set copyItems:(BOOL)flag
{
    id en = [set objectEnumerator];
    id obj;
    
    self = [self initWithCapacity:[set count]];
    while((obj = [en nextObject])) {
        obj = flag ? [obj copy] : obj; /* copy returns retained object */
	[self addObject:obj];
        if (flag) RELEASE(obj);
    }
    return self;
}

- (id)initWithCapacity:(unsigned int)aNumItems
{
    self->table =
        NSCreateMapTableWithZone(NSObjectMapKeyCallBacks,
                                 NSIntMapValueCallBacks,
                                 aNumItems, [self zone]);
    return self;
}

/* Destroying */

- (void)dealloc
{
    NSFreeMapTable(self->table);
    [super dealloc];
}

/* Copying */

- (id)mutableCopyWithZone:(NSZone *)zone
{
    return [[NSCountedSet allocWithZone:zone] initWithSet:self copyItems:NO];
}

/* Accessing keys and values */

- (unsigned int)count
{
    return NSCountMapTable(table);
}

- (id)member:(id)anObject
{
    id key, value;
    return NSMapMember(table, (void*)anObject, (void**)&key, (void**)&value)
        ? key : nil;
}

- (unsigned)countForObject:(id)anObject
{
    return (unsigned)(unsigned long)NSMapGet(table, anObject);
}

- (NSEnumerator *)objectEnumerator
{
    return AUTORELEASE([[_NSConcreteSetEnumerator alloc]
                           initWithSet:self mode:setEnumMap]);
}

/* Add and remove entries */

- (void)addObject:(id)object
{
    register unsigned long objectCount;
    /* get old object count */
    objectCount = (unsigned long)NSMapGet(table, object);
    objectCount++;
    /* store new object count */
    NSMapInsert(table, object, (void *)objectCount);
}

- (void)removeObject:(id)object
{
    NSMapRemove(table, object);
}

- (void)removeAllObjects
{
    NSResetMapTable(table);
}

- (NSString *)descriptionWithLocale:(NSDictionary*)locale
   indent:(unsigned int)level;
{
    NSMutableDictionary* dict
        = [NSMutableDictionary dictionaryWithCapacity:[self count]];
    NSEnumerator* enumerator = [self objectEnumerator];
    id key;
    
    while((key = [enumerator nextObject]))
	[dict setObject:
		[NSNumber numberWithUnsignedInt:[self countForObject:key]] 
	    forKey:key];
    
    return [dict descriptionWithLocale:locale indent:level];
}

/* Private methods */

- (void)__setObjectEnumerator:(void*)en;
{
    *((NSMapEnumerator*)en) = NSEnumerateMapTable(table);
}

@end

/*
 * _NSConcreteSetEnumerator
 */

@implementation _NSConcreteSetEnumerator

- (id)initWithSet:(NSSet*)_set mode:(SetEnumMode)_mode;
{
    self->set = RETAIN(_set);
    self->mode = _mode;
    if (self->mode == setEnumHash)
	[set __setObjectEnumerator:&(self->enumerator.hash)];
    if (self->mode == setEnumMap)
	[set __setObjectEnumerator:&(self->enumerator.map)];
    return self;
}

- (void)dealloc
{
    RELEASE(self->set);
    [super dealloc];
}

- (id)nextObject
{
    if (mode == setEnumHash) {
	return (id)NSNextHashEnumeratorItem(&(self->enumerator.hash));
    }
    if (mode == setEnumMap) {
	id key, value;
        
	return NSNextMapEnumeratorPair(&(self->enumerator.map),
					(void**)&key,(void**)&value)==YES
            ? key : nil;
    }
    return nil;
}

@end /* _NSConcreteSetEnumerator */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
