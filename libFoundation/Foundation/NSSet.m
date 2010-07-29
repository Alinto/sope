/* 
   NSSet.m

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
#include <stdio.h>

#include <Foundation/common.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include "NSConcreteSet.h"

/*
 * NSSet 
 */

@implementation NSSet

/* Allocating and Initializing a Set */

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject( (self == [NSSet class]) ? 
			     [NSConcreteSet class] : (Class)self, 0, zone);
}

+ (id)set
{
    return AUTORELEASE([[self alloc] init]);
}

+ (id)setWithArray:(NSArray*)array
{
    return AUTORELEASE([[self alloc] initWithArray:array]);
}

+ (id)setWithObject:(id)anObject
{
    return AUTORELEASE(([[self alloc] initWithObjects:anObject, nil]));
}

+ (id)setWithObjects:(id)firstObj,...
{
    id set;
    va_list va;
    va_start(va, firstObj);
    set = AUTORELEASE([[self alloc] initWithObject:firstObj arglist:va]);
    va_end(va);
    return set;
}

+ (id)setWithObjects:(id*)objects count:(unsigned int)count
{
    return AUTORELEASE([[self alloc] initWithObjects:objects count:count]);
}

+ (id)setWithSet:(NSSet*)aSet
{
    return AUTORELEASE([[self alloc] initWithSet:aSet]);
}

- (id)init
{
    [self subclassResponsibility:_cmd];
    return self;
}

- (id)initWithArray:(NSArray*)array
{
    int i, n = [array count];
    id *objects;

    if (n == 0)
        return [self initWithObjects:NULL count:0];
    
    objects = Malloc(sizeof(id) * n);
    
    for (i = 0; i < n; i++)
	objects[i] = [array objectAtIndex:i];
	    
    self = [self initWithObjects:objects count:n];
    
    lfFree(objects);
    return self;
}

- (id)initWithObjects:(id)firstObj,...
{
    va_list va;
    va_start(va, firstObj);
    self = [self initWithObject:firstObj arglist:va];
    va_end(va);
    return self;
}

- (id)initWithObject:(id)firstObject arglist:(va_list)argList
{
    id object;
    id *objs;
    va_list va;
    int count = 0;

#ifdef __va_copy
    __va_copy(va, argList);
#else
    va = argList;
#endif

    for (object = firstObject; object; object = va_arg(va,id))
	count++;

    if (count == 0)
        return [self initWithObjects:NULL count:0];
    
    objs = Malloc(sizeof(id)*count);
    
    for (count=0, object=firstObject; object; object=va_arg(argList,id)) {
	objs[count] = object;
	count++;
    }

    self = [self initWithObjects:objs count:count];

    lfFree(objs);
    return self;
}

- (id)initWithObjects:(id*)objects count:(unsigned int)count
{
    [self subclassResponsibility:_cmd];
    return self;
}

- (id)initWithSet:(NSSet*)set copyItems:(BOOL)flag;
{
    NSEnumerator *keys = [set objectEnumerator];
    id       key;
    id       *objs;
    unsigned i = 0;
    
    objs = Malloc(sizeof(id)*[set count]);

    while((key = [keys nextObject])) {
	objs[i++] = flag ? AUTORELEASE([key copyWithZone:NULL]) : key;
    }
    
    self = [self initWithObjects:objs count:i];
    
    lfFree(objs);
    return self;
}

- (id)initWithSet:(NSSet*)aSet
{
    return [self initWithSet:aSet copyItems:NO];
}

/* Querying the Set */

- (NSArray *)allObjects
{
    id array;
    id *objs;
    id keys;
    id key;
    unsigned i = 0, count;
    
    if ((count = [self count]) == 0) return [NSArray array];
    
    objs = Malloc(sizeof(id)*[self count]);
    keys = [self objectEnumerator];
    
    for (i = 0; (key = [keys nextObject]); i++)
	objs[i] = key;
    
    array = [[NSArray alloc] initWithObjects:objs count:count];
    lfFree(objs);
#if DEBUG
    NSAssert(array, @"missing array ..");
#endif
    return AUTORELEASE(array);
}

- (id)anyObject
{
    return [[self objectEnumerator] nextObject];
}

- (BOOL)containsObject:(id)anObject
{
    return [self member:anObject] ? YES : NO;
}

- (unsigned int)count
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (id)member:(id)anObject
{
    [self subclassResponsibility:_cmd];
    return nil;
}

- (NSEnumerator*)objectEnumerator
{
    [self subclassResponsibility:_cmd];
    return nil;
}

/* Sending Messages to Elements of the Set */

- (void)makeObjectsPerformSelector:(SEL)aSelector
{
    id keys = [self objectEnumerator];
    id key;

    while ((key = [keys nextObject]))
	[key performSelector:aSelector];
}

- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(id)anObject
{
    id keys = [self objectEnumerator];
    id key;

    while ((key = [keys nextObject]))
	[key performSelector:aSelector withObject:anObject];
}

/* Obsolete methods */
- (void)makeObjectsPerform:(SEL)aSelector
{
    id keys = [self objectEnumerator];
    id key;

    while ((key = [keys nextObject]))
	[key performSelector:aSelector];
}

- (void)makeObjectsPerform:(SEL)aSelector withObject:(id)anObject
{
    id keys = [self objectEnumerator];
    id key;

    while ((key = [keys nextObject]))
	[key performSelector:aSelector withObject:anObject];
}

/* Comparing Sets */

- (BOOL)intersectsSet:(NSSet*)otherSet
{
    id keys = [self objectEnumerator];
    id key;

    while ((key = [keys nextObject]))
	if ([otherSet containsObject:key])
	    return YES;
    return NO;
}

- (BOOL)isEqualToSet:(NSSet*)otherSet
{
    id keys = [self objectEnumerator];
    id key;

    if ([self count] != [otherSet count])
	return NO;
    
    while ((key = [keys nextObject]))
	if (![otherSet containsObject:key])
	    return NO;
    
    return YES;
}

- (BOOL)isSubsetOfSet:(NSSet *)otherSet
{
    NSEnumerator *keys;
    id key;
    
    if (otherSet == nil)
        return NO;

    keys = [self objectEnumerator];
    
    while ((key = [keys nextObject]))
	if (![otherSet containsObject:key])
	    return NO;
    return YES;
}

/* Creating a String Description of the Set */

- (NSString*)descriptionWithLocale:(NSDictionary*)locale
{
    return [self descriptionWithLocale:locale indent:0];
}

- (NSString*)description
{
    return [self descriptionWithLocale:nil indent:0];
}

- (NSString*)descriptionWithLocale:(NSDictionary*)locale
   indent:(unsigned int)indent;
{
    NSMutableString* description = [NSMutableString stringWithCString:"(\n"];
    unsigned int indent1 = indent + 4;
    NSMutableString* indentation
	    = [NSString stringWithFormat:
			[NSString stringWithFormat:@"%%%dc", indent1], ' '];
    unsigned int count = [self count];
    SEL sel = @selector(appendString:);
    IMP imp = [description methodForSelector:sel];

    if(count) {
	id object;
	id stringRepresentation;
	id enumerator;
	CREATE_AUTORELEASE_POOL(pool);

        enumerator = [self objectEnumerator];

	object = [enumerator nextObject];
	if ([object respondsToSelector:
		@selector(descriptionWithLocale:indent:)])
	    stringRepresentation = [object descriptionWithLocale:locale
		indent:indent1];
	else if ([object respondsToSelector:
		@selector(descriptionWithLocale:)])
	    stringRepresentation = [object descriptionWithLocale:locale];
	else
	    stringRepresentation = [object stringRepresentation];

	(*imp)(description, sel, indentation);
	(*imp)(description, sel, stringRepresentation);

	while((object = [enumerator nextObject])) {
	    if ([object respondsToSelector:
		    @selector(descriptionWithLocale:indent:)])
		stringRepresentation = [object descriptionWithLocale:locale
		    indent:indent1];
	    else if ([object respondsToSelector:
		    @selector(descriptionWithLocale:)])
		stringRepresentation = [object descriptionWithLocale:locale];
	    else
		stringRepresentation = [object stringRepresentation];

	    (*imp)(description, sel, @",\n");
	    (*imp)(description, sel, indentation);
	    (*imp)(description, sel, stringRepresentation);
	}
	RELEASE(pool);
    }

    (*imp)(description, sel, indent
	    ? [NSMutableString stringWithFormat:
			[NSString stringWithFormat:@"\n%%%dc)", indent], ' ']
	    : [NSMutableString stringWithCString:"\n)"]);
    return description;
}

/* From adopted/inherited protocols */

- (unsigned)hash
{
    return [self count];
}

- (BOOL)isEqual:(id)anObject
{
    if ([anObject isKindOfClass:isa] == NO)
	    return NO;
    return [self isEqualToSet:anObject];
}

- (id)copyWithZone:(NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else
	return [[NSSet allocWithZone:zone] initWithSet:self copyItems:NO];
}

- (id)mutableCopyWithZone:(NSZone*)zone
{
    return [[NSMutableSet allocWithZone:zone] initWithSet:self copyItems:NO];
}

- (Class)classForCoder
{
    return [NSSet class];
}

- (void)encodeWithCoder:(NSCoder*)aCoder
{
    NSEnumerator* enumerator = [self objectEnumerator];
    int count = [self count];
    id object;

    [aCoder encodeValueOfObjCType:@encode(int) at:&count];
    while((object = [enumerator nextObject]))
	[aCoder encodeObject:object];
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    int i, count;
    id* objects;

    [aDecoder decodeValueOfObjCType:@encode(int) at:&count];
    objects = Malloc(sizeof(id) * count);
    for(i = 0; i < count; i++)
	objects[i] = [aDecoder decodeObject];

    [self initWithObjects:objects count:count];
    
    lfFree(objects);

    return self;
}

@end /* NSSet */

/*
 * NSMutableSet 
 */

@implementation NSMutableSet

/* Methods from NSSet */

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject( (self == [NSMutableSet class]) ? 
			     [NSConcreteMutableSet class] : (Class)self,
			     0, zone);
}

+ (id)setWithCapacity:(unsigned)numItems
{
    return AUTORELEASE([[self alloc] initWithCapacity:numItems]);
}

- (id)initWithCapacity:(unsigned)numItems
{
    [self subclassResponsibility:_cmd];
    return self;
}

/* Adding Objects */

- (void)addObject:(id)object
{
    [self subclassResponsibility:_cmd];
}

- (void)addObjectsFromArray:(NSArray*)array
{
    int i, n = [array count];
    IMP _addObject = [self methodForSelector:@selector(addObject:)];
    
    for (i = 0; i < n; i++)
        _addObject(self, @selector(addObject:), [array objectAtIndex:i]);
}

- (void)unionSet:(NSSet *)other
{
    if (self != (id)other) {
        id keys = [other objectEnumerator];
        id key;

        while ((key = [keys nextObject]))
            [self addObject:key];
    }
}

- (void)setSet:(NSSet *)other
{
    if (self != (id)other) {
        [self removeAllObjects];
        [self unionSet:other];
    }
}

/* Removing Objects */

- (void)intersectSet:(NSSet*)other
{
    if (self != (id)other) {
        NSMutableArray *toBeRemoved = nil;
        id keys, key;

        if ((keys = [self objectEnumerator]) == nil)
            return;
        
        while ((key = [keys nextObject])) {
            if (![other containsObject:key]) {
                if (toBeRemoved == nil)
                    toBeRemoved = [NSMutableArray arrayWithCapacity:16];
                [toBeRemoved addObject:key];
            }
        }
        if (toBeRemoved) {
            keys = [toBeRemoved objectEnumerator];
            while ((key = [keys nextObject]))
                [self removeObject:key];
        }
    }
}

- (void)minusSet:(NSSet*)other
{
    if (other == self)
        [self removeAllObjects];
    else {
        id keys, key;

        if ((keys = [other objectEnumerator]) == nil)
            return;

        while ((key = [keys nextObject]))
            [self removeObject:key];
    }
}

- (void)removeAllObjects
{
    id en = [self objectEnumerator];
    id key;
    while ((key=[en nextObject]))
	[self removeObject:key];
}

- (void)removeObject:(id)object
{
    [self subclassResponsibility:_cmd];
}

- (id)copyWithZone:(NSZone*)zone
{
    return [[NSSet allocWithZone:zone] initWithSet:self copyItems:NO];
}

- (Class)classForCoder
{
    return [NSMutableSet class];
}

@end /* NSMutableSet */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

