/* 
   NSArray.h

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

#ifndef __NSArray_h__
#define __NSArray_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>

@class NSString;
@class NSEnumerator;
@class NSDictionary;
@class NSURL;

@interface NSArray : NSObject <NSCoding, NSCopying, NSMutableCopying>

/* Allocating and Initializing an Array */
+ (id)allocWithZone:(NSZone*)zone;
+ (id)array;
+ (id)arrayWithObject:(id)anObject;
+ (id)arrayWithObjects:(id)firstObj,...;
+ (id)arrayWithArray:(NSArray*)anotherArray;
+ (id)arrayWithContentsOfFile:(NSString *)fileName;
+ (id)arrayWithContentsOfURL:(NSURL *)_url;
+ (id)arrayWithObjects:(id*)objects count:(unsigned int)count;
- (id)initWithArray:(NSArray*)anotherArray;
- (id)initWithArray:(NSArray*)anotherArray copyItems:(BOOL)flag;
- (id)initWithObjects:(id)firstObj,...;
- (id)initWithObjects:(id *)objects count:(unsigned int)count;
- (id)initWithContentsOfURL:(NSURL *)_url;

/* Querying the Array */
- (BOOL)containsObject:(id)anObject;
- (unsigned int)count;
- (unsigned int)indexOfObject:(id)anObject;
- (unsigned int)indexOfObjectIdenticalTo:(id)anObject;
- (unsigned int)indexOfObject:(id)anObject inRange:(NSRange)aRange;
- (unsigned int)indexOfObjectIdenticalTo:(id)anObject inRange:(NSRange)aRange;
- (id)lastObject;
- (id)objectAtIndex:(unsigned int)index;
- (void)getObjects:(id *)buffer;
- (void)getObjects:(id *)buffer range:(NSRange)range;
- (NSEnumerator*)objectEnumerator;
- (NSEnumerator*)reverseObjectEnumerator;

/* Sending Messages to Elements */
- (void)makeObjectsPerformSelector:(SEL)aSelector;
- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(id)anObject;
/* Obsolete messages */
- (void)makeObjectsPerform:(SEL)aSelector;
- (void)makeObjectsPerform:(SEL)aSelector withObject:(id)anObject;

/* Comparing Arrays */
- (id)firstObjectCommonWithArray:(NSArray*)otherArray;
- (BOOL)isEqualToArray:(NSArray*)otherArray;

/* Deriving New Array */
- (NSArray*)arrayByAddingObject:(id)anObject;
- (NSArray*)arrayByAddingObjectsFromArray:(NSArray*)anotherArray;
- (NSArray*)sortedArrayUsingFunction:
  (int(*)(id element1, id element2, void *userData))comparator
  context:(void*)context;
- (NSArray*)sortedArrayUsingSelector:(SEL)comparator;
- (NSArray*)subarrayWithRange:(NSRange)range;

/* Joining String Elements */
- (NSString*)componentsJoinedByString:(NSString*)separator;

/* Creating a String Description of the Array */
- (NSString*)description;
- (NSString*)stringRepresentation;
- (NSString*)descriptionWithLocale:(NSDictionary*)locale;
- (NSString*)descriptionWithLocale:(NSDictionary*)locale
   indent:(unsigned int)level;

/* Write plist to file */
- (BOOL)writeToFile:(NSString*)fileName atomically:(BOOL)flag;

/* From adopted/inherited protocols */
- (unsigned)hash;
- (BOOL)isEqual:(id)anObject;

@end

/*
 * Extensions to NSArray
 */

@interface NSArray (NSArrayExtensions)

/* Sending Messages to Elements */
- (void)makeObjectsPerform:(SEL)aSelector
  withObject:(id)anObject1 withObject:(id)anObject2;

/* Deriving New Arrays */
- (NSArray*)map:(SEL)aSelector;
- (NSArray*)map:(SEL)aSelector with:anObject;
- (NSArray*)map:(SEL)aSelector with:anObject with:otherObject;

- (NSArray*)arrayWithObjectsThat:(BOOL(*)(id anObject))comparator;
- (NSArray*)map:(id(*)(id anObject))function
  objectsThat:(BOOL(*)(id anObject))comparator;

@end

/*
 * NSMutableArray class
 */

@interface NSMutableArray : NSArray

/* Creating and Initializing an NSMutableArray */
+ (id)allocWithZone:(NSZone*)zone;
+ (id)arrayWithCapacity:(unsigned int)aNumItems;
- (id)initWithCapacity:(unsigned int)aNumItems;
- (id)init;

/* Adding Objects */
- (void)addObject:(id)anObject;
- (void)addObjectsFromArray:(NSArray*)anotherArray;
- (void)insertObject:(id)anObject atIndex:(unsigned int)index;

/* Removing Objects */
- (void)removeAllObjects;
- (void)removeLastObject;
- (void)removeObject:(id)anObject;
- (void)removeObjectAtIndex:(unsigned int)index;
- (void)removeObjectIdenticalTo:(id)anObject;
- (void)removeObjectsFromIndices:(unsigned int*)indices
  numIndices:(unsigned int)count;
- (void)removeObjectsInArray:(NSArray*)otherArray;
- (void)removeObject:(id)anObject inRange:(NSRange)aRange;
- (void)removeObjectIdenticalTo:(id)anObject inRange:(NSRange)aRange;
- (void)removeObjectsInRange:(NSRange)aRange;

/* Sorting */
- (void)sortUsingFunction:(int (*)(id ,id ,void*))compare
	context:(void*)context;
- (void)sortUsingSelector:(SEL)comparator;

/* Replacing Objects */
- (void)replaceObjectAtIndex:(unsigned int)index withObject:(id)anObject;
- (void)replaceObjectsInRange:(NSRange)rRange
  withObjectsFromArray:(NSArray*)anArray;
- (void)replaceObjectsInRange:(NSRange)rRange
  withObjectsFromArray:(NSArray*)anArray range:(NSRange)aRange;
- (void)setArray:(NSArray*)otherArray;

@end

/*
 * Extensions to NSArray
 */

@interface NSMutableArray (NSMutableArrayExtensions)

/* Removing Objects */
- (void)removeObjectsFrom:(unsigned int)index count:(unsigned int)count;
- (void)removeObjectsThat:(BOOL(*)(id anObject))comparator;

@end

#endif /* __NSArray_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
