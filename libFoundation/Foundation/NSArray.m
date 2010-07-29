/* 
   NSArray.m

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
#include <stdlib.h>
#include <string.h>

#include <Foundation/common.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSException.h>
#include <Foundation/NSCoder.h>
#include <Foundation/PropertyListParser.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSURL.h>

#include <Foundation/exceptions/GeneralExceptions.h>

#include "NSConcreteArray.h"
#include "NSObject+PropLists.h"

/*
 * NSArray Implementation
 * 
 * primary methods are
 *     init
 *     initWithObjects:count:
 *     dealloc
 *     count
 *     objectAtIndex:
 */

@implementation NSArray

static Class NSArrayClass         = Nil;
static Class NSMutableArrayClass  = Nil;
static Class NSConcreteArrayClass = Nil;

/* Allocating and Initializing an Array */

+ (id)allocWithZone:(NSZone*)zone
{
    if (NSArrayClass == Nil)
        NSArrayClass = [NSArray class];
    if (NSConcreteArrayClass == Nil)
        NSConcreteArrayClass = [NSConcreteArray class];
    
    return NSAllocateObject( (self == NSArrayClass) ? 
                             NSConcreteArrayClass : (Class)self, 0, zone);
}

+ (id)array
{
    return AUTORELEASE([[self alloc] init]);
}

+ (id)arrayWithObject:(id)anObject
{
    return AUTORELEASE([[self alloc] initWithObjects:&anObject count:1]);
}

+ (id)arrayWithObjects:(id)firstObj,...
{
    id array, obj, *objects;
    va_list list;
    unsigned int count;

    va_start(list, firstObj);
    for (count=0, obj = firstObj; obj; obj = va_arg(list,id))
	count++;
    va_end(list);

    objects = Malloc(sizeof(id) * count);
    {
        va_start(list, firstObj);
        for (count = 0, obj = firstObj; obj; obj = va_arg(list,id))
            objects[count++] = obj;
        va_end(list);

        array = [[self alloc] initWithObjects:objects count:count];
    }
    lfFree(objects);
    return AUTORELEASE(array);
}

+ (id)arrayWithArray:(NSArray*)anotherArray
{
    return AUTORELEASE([[self alloc] initWithArray:anotherArray]);
}

+ (id)arrayWithContentsOfFile:(NSString *)fileName
{
    volatile id plist = nil;

    NSString *format = @"%@: Caught exception %@ with reason %@ ";
    
    NS_DURING {
        plist = NSParsePropertyListFromFile(fileName);

        if (NSArrayClass == Nil)
            NSArrayClass = [NSArray class];
        if (![plist isKindOfClass:NSArrayClass])
            plist = nil;
    } 
    NS_HANDLER {
        NSLog(format, self, [localException name], [localException reason]);
        plist = nil;
    }
    NS_ENDHANDLER;
    
    return plist;
}
+ (id)arrayWithContentsOfURL:(NSURL *)_url
{
    id plist;
    
    if ([_url isFileURL])
        return [self arrayWithContentsOfFile:[_url path]];

    if (NSArrayClass == Nil)
        NSArrayClass = [NSArray class];
    
    plist = [[NSString stringWithContentsOfURL:_url] propertyList];
    if (![plist isKindOfClass:NSArrayClass])
        return nil;
    return plist;
}

+ (id)arrayWithObjects:(id*)objects count:(unsigned int)count
{
    return AUTORELEASE([[self alloc]
                              initWithObjects:objects count:count]);
}

- (NSArray*)arrayByAddingObject:(id)anObject
{
    int i, count = [self count];
    id array;
    id *objects;

    objects = Malloc(sizeof(id) * (count + 1));
    {
        for (i = 0; i < count; i++)
            objects[i] = [self objectAtIndex:i];
        objects[i] = anObject;
        
        if (NSArrayClass == Nil)
            NSArrayClass = [NSArray class];
        
        array = AUTORELEASE([[NSArrayClass alloc]
                                      initWithObjects:objects count:count+1]);
    }
    lfFree(objects);
    return array;
}

- (NSArray*)arrayByAddingObjectsFromArray:(NSArray*)anotherArray;
{
    unsigned int i, count = [self count], another = [anotherArray count];
    id array;
    id *objects;

    objects = Malloc(sizeof(id) * (count+another));
    {
        for (i = 0; i < count; i++)
            objects[i] = [self objectAtIndex:i];
        for (i = 0; i < another; i++)
            objects[i + count] = [anotherArray objectAtIndex:i];
        
        if (NSArrayClass == Nil)
            NSArrayClass = [NSArray class];
        
        array = AUTORELEASE([[NSArrayClass alloc]
                                      initWithObjects:objects count:count + another]);
    }    
    lfFree(objects);
    return array;
}

- (id)initWithArray:(NSArray*)anotherArray
{
    return [self initWithArray:anotherArray copyItems:NO];
}

- (id)initWithArray:(NSArray*)anotherArray copyItems:(BOOL)flag;
{
    unsigned int i, count = [anotherArray count];
    id *objects;

    if (count == 0)
        return [self initWithObjects:NULL count:0];

    objects = Malloc(sizeof(id) * count);
    {
        for (i = 0; i < count; i++) {
            objects[i] = flag
                ? [anotherArray objectAtIndex:i]
                : AUTORELEASE([[anotherArray objectAtIndex:i] copyWithZone:NULL]);
        }
        self = [self initWithObjects:objects count:count];
    }
    lfFree(objects);

    return self;
}

- (id)initWithObjects:(id)firstObj,...
{
    id obj, *objects;
    va_list list;
    unsigned int count;

    va_start(list, firstObj);
    for (count = 0, obj = firstObj; obj; obj = va_arg(list,id))
	count++;
    va_end(list);

    objects = Malloc(sizeof(id) * count);
    {
        va_start(list, firstObj);
        for (count = 0, obj = firstObj; obj; obj = va_arg(list,id))
            objects[count++] = obj;
        va_end(list);

        self = [self initWithObjects:objects count:count];
    }
    lfFree(objects);
    return self;
}

- (id)initWithObjects:(id*)objects count:(unsigned int)count
{
    [self subclassResponsibility:_cmd];
    return self;
}

- (id)initWithContentsOfFile:(NSString*)fileName
{
    NSArray *plist;

    if (NSArrayClass == Nil)
        NSArrayClass = [NSArray class];
    
    if ((plist = [NSArrayClass arrayWithContentsOfFile:fileName])) {
        return [self initWithArray:plist];
    }
    else {
        self = AUTORELEASE(self);
        return nil;
    }
}
- (id)initWithContentsOfURL:(NSURL *)_url
{
    NSArray *plist;

    if (NSArrayClass == Nil)
        NSArrayClass = [NSArray class];
    
    if ((plist = [NSArrayClass arrayWithContentsOfURL:_url])) {
        return [self initWithArray:plist];
    }
    else {
        self = AUTORELEASE(self);
        return nil;
    }
}

/* Querying the Array */

- (BOOL)containsObject:(id)anObject
{
    return ([self indexOfObject:anObject] == NSNotFound) ? NO : YES;
}

- (unsigned int)count
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned int)indexOfObject:(id)anObject
{
    return [self indexOfObject:anObject
	    inRange:NSMakeRange(0, [self count])];
}

- (unsigned int)indexOfObjectIdenticalTo:(id)anObject;
{
    return [self indexOfObjectIdenticalTo:anObject
	    inRange:NSMakeRange(0, [self count])];
}

- (unsigned int)indexOfObject:(id)anObject inRange:(NSRange)aRange
{
    unsigned int index;
    for (index = 0; index < aRange.length; index++)
	if ([anObject isEqual:[self objectAtIndex:aRange.location+index]])
	    return aRange.location+index;
    return NSNotFound;
}

- (unsigned int)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)aRange
{
    unsigned int index;
    for (index = 0; index < aRange.length; index++)
	if (anObject == [self objectAtIndex:aRange.location+index])
	    return index;
    return NSNotFound;
}

- (id)lastObject
{
    int count = [self count];

    return count ? [self objectAtIndex:count - 1] : nil;
}

- (id)objectAtIndex:(unsigned int)index
{
    [self subclassResponsibility:_cmd];
    return self;
}

- (void)getObjects:(id *)buffer
{
    unsigned i, count = [self count];
    
    for (i = 0; i < count; i++) {
        buffer[i] = [self objectAtIndex: i];
    }
}
- (void)getObjects:(id *)buffer range:(NSRange)range
{
    /* naive implementation, to be fixed ... */
    return [[self subarrayWithRange:range] getObjects:buffer];
}

- (NSEnumerator *)objectEnumerator
{
    return AUTORELEASE([[_NSArrayEnumerator alloc]
                           initWithArray:self reverse:NO]);
}

- (NSEnumerator *)reverseObjectEnumerator
{
    return AUTORELEASE([[_NSArrayEnumerator alloc]
                           initWithArray:self reverse:YES]);
}

/* Sending Messages to Elements */

- (void)makeObjectsPerformSelector:(SEL)aSelector
{
    unsigned int index, count = [self count];
    for (index = 0; index < count; index++)
	[[self objectAtIndex:index] performSelector:aSelector];
}

- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(id)anObject
{
    unsigned int index, count = [self count];
    for (index = 0; index < count; index++)
	[[self objectAtIndex:index]
	      performSelector:aSelector withObject:anObject];
}

/* Obsolete methods */
- (void)makeObjectsPerform:(SEL)aSelector
{
    unsigned int index, count = [self count];
    for (index = 0; index < count; index++)
	[[self objectAtIndex:index] performSelector:aSelector];
}

- (void)makeObjectsPerform:(SEL)aSelector withObject:(id)anObject
{
    unsigned int index, count = [self count];
    for (index = 0; index < count; index++)
	[[self objectAtIndex:index]
	      performSelector:aSelector withObject:anObject];
}

/* Comparing Arrays */

- (id)firstObjectCommonWithArray:(NSArray*)otherArray
{
    unsigned int index, count = [self count];
    for (index = 0; index < count; index++) {
	id object = [self objectAtIndex:index];
	if ([otherArray containsObject:object])
	    return object;
    }
    return nil;
}

- (BOOL)isEqualToArray:(NSArray*)otherArray
{
    unsigned int index, count;
    if( otherArray == self )
	return YES;
    if ([otherArray count] != (count = [self count]))
	return NO;
    for (index = 0; index < count; index++) {
        register id o1, o2;
        o1 = [self objectAtIndex:index];
        o2 = [otherArray objectAtIndex:index];
	if (![o1 isEqual:o2])
	    return NO;
    }
    return YES;
}

/* Deriving New Arrays */

- (NSArray *)sortedArrayUsingFunction:
	    (int(*)(id element1, id element2, void *userData))comparator
    context:(void *)context
{
    NSMutableArray *sortedArray;
    NSArray        *result;
    
    sortedArray = [self mutableCopy];
    [sortedArray sortUsingFunction:comparator context:context];
    result = [sortedArray copy];
    RELEASE(sortedArray);
    return AUTORELEASE(result);
}

static int compare(id elem1, id elem2, void* comparator)
{
    return (int)(long)[elem1 performSelector:comparator withObject:elem2];
}

- (NSArray*)sortedArrayUsingSelector:(SEL)comparator
    // Returns an array listing the receiver's elements in ascending order,
    // as determined by the comparison method specified by the selector 
    // comparator.
{
    return [self sortedArrayUsingFunction:compare context:(void*)comparator];
}

- (NSArray*)subarrayWithRange:(NSRange)range
{
    id array;
    unsigned int index;
    id *objects;

    objects = Malloc(sizeof(id) * range.length);
    {
        for (index = 0; index < range.length; index++)
            objects[index] = [self objectAtIndex:range.location+index];

        if (NSArrayClass == Nil)
            NSArrayClass = [NSArray class];
	    
        array = AUTORELEASE([[NSArrayClass alloc]
                                      initWithObjects:objects count:range.length]);
    }
    lfFree(objects);
    return array;
}
    // Returns an array containing the receiver's elements
    // that fall within the limits specified by range.

/* Joining String Elements */

- (NSString*)componentsJoinedByString:(NSString*)separator
{
    unsigned int index, count = [self count];

    if (!separator)
	separator = @"";

    if (count > 0) {
	NSMutableString* string = [NSMutableString new];
        id elem;
        SEL sel;
        IMP imp;
	CREATE_AUTORELEASE_POOL(pool);

	elem = [self objectAtIndex:0];
	sel = @selector(appendString:);
	imp = [string methodForSelector:sel];

	if (![elem isKindOfClass:[NSString class]])
	    elem = [elem description];

	(*imp)(string, sel, elem);

	for (index = 1; index < count; index++) {
	    elem = [self objectAtIndex:index];
	    if (![elem isKindOfClass:[NSString class]])
		elem = [elem description];

	    (*imp)(string, sel, separator);
	    (*imp)(string, sel, elem);
	}
	RELEASE(pool);
	return AUTORELEASE(string);
    }

    return @"";
}

/* Creating a String Description of the Array */

- (NSString *)propertyListStringWithLocale:(NSDictionary *)_locale
  indent:(unsigned int)_indent
{
    return [self descriptionWithLocale:_locale indent:_indent];
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
	unsigned int index;
	CREATE_AUTORELEASE_POOL(pool);

	object = [self objectAtIndex:0];
        stringRepresentation = [object propertyListStringWithLocale:locale
                                       indent:indent1];

	(*imp)(description, sel, indentation);
	(*imp)(description, sel, stringRepresentation);

	for (index = 1; index < count; index++) {
	    object = [self objectAtIndex:index];

            stringRepresentation = [object propertyListStringWithLocale:locale
                                           indent:indent1];
            
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

- (NSString*)descriptionWithLocale:(NSDictionary*)locale
{
    return [self descriptionWithLocale:locale indent:0];
}

- (NSString*)description
{
    return [self descriptionWithLocale:nil indent:0];
}

- (NSString*)stringRepresentation
{
    return [self descriptionWithLocale:nil indent:0];
}

/* Write plist to file */

- (BOOL)writeToFile:(NSString*)fileName atomically:(BOOL)flag
{
    volatile BOOL success = NO;
    
    TRY {
	id content = [self description];
	success = [content writeToFile:fileName atomically:flag];
    } END_TRY
    OTHERWISE {
	success = NO;
    } END_CATCH
    
    return success;
}

/* From adopted/inherited protocols */

- (unsigned)hash
{
    return [self count];
}

- (BOOL)isEqual:(id)anObject
{
    if (NSArrayClass == Nil)
        NSArrayClass = [NSArray class];
    
    if (![anObject isKindOfClass:NSArrayClass])
        return NO;
    return [self isEqualToArray:anObject];
}

/* Copying */

- (id)copyWithZone:(NSZone *)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else {
        if (NSArrayClass == Nil)
            NSArrayClass = [NSArray class];
        
	return [[NSArrayClass allocWithZone:zone]
                              initWithArray:self copyItems:NO];
    }
}

- (id)mutableCopyWithZone:(NSZone*)zone
{
    if (NSMutableArrayClass == Nil)
        NSMutableArrayClass = [NSMutableArray class];
    return [[NSMutableArrayClass alloc] initWithArray:self];
}

/* Encoding */

- (Class)classForCoder
{
    if (NSArrayClass == Nil)
        NSArrayClass = [NSArray class];
    return NSArrayClass;
}

- (void)encodeWithCoder:(NSCoder*)aCoder
{
    IMP imp = [aCoder methodForSelector:@selector(encodeObject:)];
    int i, count = [self count];

    [aCoder encodeValueOfObjCType:@encode(int) at:&count];
    for(i = 0; i < count; i++)
	(*imp)(aCoder, @selector(encodeObject:), [self objectAtIndex:i]);
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    IMP imp = [aDecoder methodForSelector:@selector(decodeObject)];
    int i, count;

    [aDecoder decodeValueOfObjCType:@encode(int) at:&count];
    if (count > 0) {
        id* objects;
        objects = Malloc(sizeof(id) * count);
        {
            for(i = 0; i < count; i++)
                objects[i] = (*imp)(aDecoder, @selector(decodeObject));

            self = [self initWithObjects:objects count:count];
        }
        lfFree(objects);
    }
    else {
        self = [self init]; // empty array
    }
    return self;
}

@end /* NSArray */

/*
 * Extensions to NSArray
 */

@implementation NSArray (NSArrayExtensions)

/* Sending Messages to Elements */

- (void)makeObjectsPerform:(SEL)aSelector
  withObject:(id)anObject1 withObject:(id)anObject2
{
    unsigned int index, count = [self count];
    for (index = 0; index < count; index++)
	[[self objectAtIndex:index]
	  performSelector:aSelector withObject:anObject1 withObject:anObject2];
}

/* Deriving New Arrays */

- (NSArray *)map:(SEL)aSelector
{
    unsigned int index, count = [self count];
    id array;
    if (NSMutableArrayClass == Nil)
        NSMutableArrayClass = [NSMutableArray class];
    array = [NSMutableArrayClass arrayWithCapacity:count];
    
    for (index = 0; index < count; index++) {
	[array insertObject:[[self objectAtIndex:index]
				performSelector:aSelector]
	       atIndex:index];
    }
    return array;
}

- (NSArray *)map:(SEL)aSelector with:(id)anObject
{
    unsigned int index, count = [self count];
    id array;
    if (NSMutableArrayClass == Nil)
        NSMutableArrayClass = [NSMutableArray class];
    array = [NSMutableArrayClass arrayWithCapacity:count];
    for (index = 0; index < count; index++) {
	[array insertObject:[[self objectAtIndex:index]
				performSelector:aSelector withObject:anObject]
		atIndex:index];
    }
    return array;
}

- (NSArray *)map:(SEL)aSelector with:(id)anObject with:(id)otherObject;
{
    unsigned int index, count = [self count];
    id array;
    if (NSMutableArrayClass == Nil)
        NSMutableArrayClass = [NSMutableArray class];
    array = [NSMutableArrayClass arrayWithCapacity:count];
    for (index = 0; index < count; index++) {
	[array insertObject:[[self objectAtIndex:index]
	  performSelector:aSelector withObject:anObject withObject:otherObject]
		atIndex:index];
    }
    return array;
}

- (NSArray *)arrayWithObjectsThat:(BOOL(*)(id anObject))comparator;
    // Returns an array listing the receiver's elements for that comparator
    // function returns YES
{
    unsigned i, m, n = [self count];
    id *objects;
    id array;

    objects = Malloc(sizeof(id) * n);
    {
        for (i = m = 0; i < n; i++) {
            id obj = [self objectAtIndex:i];
            if (comparator(obj))
                objects[m++] = obj;
        }
        
        array = AUTORELEASE([[[self class] alloc] initWithObjects:objects count:m]);
    }
    lfFree(objects);
    return array;
}

- (NSArray *)map:(id(*)(id anObject))function
  objectsThat:(BOOL(*)(id anObject))comparator;
    // Returns an array listing the objects returned by function applied to
    // objects for that comparator returns YES
{
    unsigned i, m, n = [self count];
    id *objects;
    id array;

    objects = Malloc(sizeof(id) * n);
    {
        for (i = m = 0; i < n; i++) {
            id obj = [self objectAtIndex:i];
            if (comparator(obj))
                objects[m++] = function(obj);
        }
    
        array = AUTORELEASE([[[self class] alloc] initWithObjects:objects count:m]);
    }
    lfFree(objects);
    return array;
}

@end

/*
 * NSMutableArray class
 *
 * primary methods are
 *   init
 *   initWithCapacity:
 *   initWithObjects:count:
 *   dealloc
 *   count
 *   objectAtIndex:
 *   addObject:
 *   replaceObjectAtIndex:withObject:
 *   insertObject:atIndex:
 *   removeObjectAtIndex:
 */

@implementation NSMutableArray

+ (id)arrayWithContentsOfFile:(NSString *)fileName
{
    id array;
    
    if ((array = [super arrayWithContentsOfFile:fileName])) {
        if (NSMutableArrayClass == Nil)
            NSMutableArrayClass = [NSMutableArray class];
        
        if (![array isKindOfClass:NSMutableArrayClass]) {
            array = [[NSMutableArrayClass alloc] initWithArray:array];
            array = AUTORELEASE(array);
        }
    }
    return array;
}

/* Creating and Initializing an NSMutableArray */

+ (id)allocWithZone:(NSZone*)zone
{
    static Class NSConcreteMutableArrayClass = Nil;

    if (NSMutableArrayClass == Nil)
        NSMutableArrayClass = [NSMutableArray class];
    if (NSConcreteMutableArrayClass == Nil)
        NSConcreteMutableArrayClass = [NSConcreteMutableArray class];
    
    return NSAllocateObject( (self == NSMutableArrayClass) ? 
                             NSConcreteMutableArrayClass : (Class)self,
			     0, zone);
}

+ (id)arrayWithCapacity:(unsigned int)aNumItems
{
    return AUTORELEASE([[self alloc] initWithCapacity:aNumItems]);
}

- (id)init
{
    return [self initWithCapacity:0];
}

- (id)initWithCapacity:(unsigned int)aNumItems
{
    [self subclassResponsibility:_cmd];
    return self;
}

- (id)copyWithZone:(NSZone*)zone
{
    if (NSArrayClass == Nil)
        NSArrayClass = [NSArray class];
    return [[NSArrayClass alloc] initWithArray:self copyItems:YES];
}

/* Adding Objects */

- (void)addObject:(id)anObject
{
    [self insertObject:anObject atIndex:[self count]];
}

- (void)addObjectsFromArray:(NSArray*)anotherArray
{
    unsigned int i, j, n;
    n = [anotherArray count];
    for (i = 0, j = [self count]; i < n; i++)
	[self insertObject:[anotherArray objectAtIndex:i] atIndex:j++];
}

- (void)insertObject:(id)anObject atIndex:(unsigned int)index
{
    [self subclassResponsibility:_cmd];
}

/* Removing Objects */

- (void)removeAllObjects
{
    int count = [self count];
    while (--count >= 0)
	[self removeObjectAtIndex:count];
}

- (void)removeLastObject
{
    [self removeObjectAtIndex:[self count]-1];
}

- (void)removeObject:(id)anObject
{
    unsigned int i, n;
    n = [self count];
    for (i = 0; i < n; i++) {
	id obj = [self objectAtIndex:i];
	if ([obj isEqual:anObject]) {
	    [self removeObjectAtIndex:i];
	    n--; i--;
	}
    }
}

- (void)removeObjectAtIndex:(unsigned int)index
{
    [self subclassResponsibility:_cmd];
}

- (void)removeObjectIdenticalTo:(id)anObject
{
    unsigned int i, n;
    i = n = [self count];
    for (i = 0; i < n; i++) {
	id obj = [self objectAtIndex:i];
	if (obj == anObject) {
	    [self removeObjectAtIndex:i];
	    n--; i--;
	}
    }
}

static int __cmp_unsigned_ints(unsigned int* i1, unsigned int* i2)
{
    return (*i1 == *i2) ? 0 : ((*i1 < *i2) ? -1 : +1);
}

- (void)removeObjectsFromIndices:(unsigned int*)indices
  numIndices:(unsigned int)count;
{
    unsigned int *indexes;
    int i;
    
    if (!count)
	return;
    
    indexes = Malloc(count * sizeof(unsigned int));
    {
        memcpy(indexes, indices, count * sizeof(unsigned int));
        qsort(indexes, count, sizeof(unsigned int),
              (int(*)(const void *, const void*))__cmp_unsigned_ints);
		
        for (i = count - 1; i >= 0; i++)
            [self removeObjectAtIndex:indexes[i]];
    }
    lfFree(indexes);
}

- (void)removeObjectsInArray:(NSArray*)otherArray
{
    unsigned int i, n = [otherArray count];
    for (i = 0; i < n; i++)
	[self removeObject:[otherArray objectAtIndex:i]];
}

- (void)removeObject:(id)anObject inRange:(NSRange)aRange
{
    unsigned int index;
    for (index = aRange.location-1; index >= aRange.location; index--)
	if ([anObject isEqual:[self objectAtIndex:index+aRange.location]])
	    [self removeObjectAtIndex:index+aRange.location];
}

- (void)removeObjectIdenticalTo:(id)anObject inRange:(NSRange)aRange
{
    unsigned int index;
    for (index = aRange.location-1; index >= aRange.location; index--)
	if (anObject == [self objectAtIndex:index+aRange.location])
	    [self removeObjectAtIndex:index+aRange.location];
}

- (void)removeObjectsInRange:(NSRange)aRange
{
    unsigned int index;
    for (index = aRange.location-1; index >= aRange.location; index--)
	[self removeObjectAtIndex:index+aRange.location];
}

/* Replacing Objects */

- (void)replaceObjectAtIndex:(unsigned int)index  withObject:(id)anObject
{
    [self subclassResponsibility:_cmd];
}

- (void)replaceObjectsInRange:(NSRange)rRange
  withObjectsFromArray:(NSArray*)anArray
{
    [self replaceObjectsInRange:rRange
	withObjectsFromArray:anArray
	range:NSMakeRange(0, [anArray count])];
}

- (void)replaceObjectsInRange:(NSRange)rRange
  withObjectsFromArray:(NSArray*)anArray range:(NSRange)aRange
{
    unsigned int index;
    [self removeObjectsInRange:rRange];
    for (index = 0; index < aRange.length; index++)
	[self insertObject:[anArray objectAtIndex:aRange.location+index]
	    atIndex:rRange.location+index];
}

- (void)setArray:(NSArray*)otherArray
{
    [self removeAllObjects];
    [self addObjectsFromArray:otherArray];
}

- (void)sortUsingFunction:
  (int(*)(id element1, id element2, void *userData))comparator
  context:(void*)context
{
    /* Shell sort algorithm taken from SortingInAction - a NeXT example */
#define STRIDE_FACTOR 3	// good value for stride factor is not well-understood
			// 3 is a fairly good choice (Sedgewick)
    register int c,d, stride;
    BOOL found;
    int  count;
    id   (*objAtIdx)(id, SEL, unsigned int);
    
    if ((count = [self count]) < 2)
        return;
    
    objAtIdx = (void *)[self methodForSelector:@selector(objectAtIndex:)];
    
    stride = 1;
    while (stride <= count)
        stride = stride * STRIDE_FACTOR + 1;
    
    while(stride > (STRIDE_FACTOR - 1)) {
	// loop to sort for each value of stride
	stride = stride / STRIDE_FACTOR;
	for (c = stride; c < count; c++) {
	    found = NO;
	    d = c - stride;
	    while ((d >= 0) && !found) {
		// move to left until correct place
		register id a =
                    objAtIdx(self, @selector(objectAtIndex:), d + stride);
		register id b =
                    objAtIdx(self, @selector(objectAtIndex:), d);
                
		if ((*comparator)(a, b, context) == NSOrderedAscending) {
#if !LIB_FOUNDATION_BOEHM_GC
                    [a retain];
                    [b retain];
#endif
                    
		    [self replaceObjectAtIndex:(d + stride) withObject:b];
		    [self replaceObjectAtIndex:d            withObject:a];
		    d -= stride;		// jump by stride factor
                    
#if !LIB_FOUNDATION_BOEHM_GC
                    [a release];
                    [b release];
#endif
		}
		else
                    found = YES;
	    }
	}
    }
}

static int selector_compare(id elem1, id elem2, void* comparator)
{
    return (int)(long)[elem1 performSelector:(SEL)comparator withObject:elem2];
}

- (void)sortUsingSelector:(SEL)comparator
{
    [self sortUsingFunction:selector_compare context:(void*)comparator];
}

/* Encoding */
- (Class)classForCoder
{
    if (NSMutableArrayClass == Nil)
        NSMutableArrayClass = [NSMutableArray class];
    return NSMutableArrayClass;
}

@end /* NSMutableArray */

/*
 * Extensions to NSArray
 */

@implementation NSMutableArray (NSMutableArrayExtensions)

- (void)removeObjectsFrom:(unsigned int)index count:(unsigned int)count
{
    if (count) {
	while (count--)
	[self removeObjectAtIndex:index+count];
    }
}

- (void)removeObjectsThat:(BOOL(*)(id anObject))comparator
{
    unsigned int index, count = [self count];
    for (index = 0; index < count; index++)
	if (comparator([self objectAtIndex:index])) {
	    [self removeObjectAtIndex:index];
	    index--; count--;
	}
}

@end /* NSMutableArray(NSMutableArrayExtensions) */

/*
 * NSArrayEnumerator class
 */

@implementation _NSArrayEnumerator 

- (id)initWithArray:(NSArray*)anArray reverse:(BOOL)isReverse
{
    unsigned count = [anArray count];
    
    self->reverse = isReverse;
    self->array = RETAIN(anArray);
    self->index = (reverse)
        ? (count ? count - 1 : NSNotFound)
        : (count ? 0 : NSNotFound);
    return self;
}

- (void)dealloc
{
    RELEASE(self->array);
    [super dealloc];
}

- (id)nextObject
{
    id object;

    NSAssert(array, @"Invalid Array enumerator");
    if (self->index == NSNotFound)
	return nil;

    object = [self->array objectAtIndex:index];
    if (self->reverse) {
        if (self->index == 0)
            self->index = NSNotFound;
        else
            self->index--;
    } else {
        self->index++;
        if (self->index >= [array count])
            self->index = NSNotFound;
    }
    
    return object;
}

@end /* _NSArrayEnumerator */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
