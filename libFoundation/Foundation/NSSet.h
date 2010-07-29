/* 
   NSSet.h

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

#ifndef __NSSet_h__
#define __NSSet_h__

#include <stdarg.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSUtilities.h>

@class NSString;
@class NSArray;
@class NSDictionary;
@class NSEnumerator;

/*
 * NSSet class
 */

@interface NSSet : NSObject <NSCoding, NSCopying, NSMutableCopying>

/* Allocating and Initializing a Set */

+ (id)allocWithZone:(NSZone*)zone;
+ (id)set;
+ (id)setWithArray:(NSArray*)array;
+ (id)setWithObject:(id)anObject;
+ (id)setWithObjects:(id)firstObj,...;
+ (id)setWithObjects:(id*)objects count:(unsigned int)count;
+ (id)setWithSet:(NSSet*)aSet;
- (id)initWithArray:(NSArray*)array;
- (id)initWithObjects:(id)firstObj,...;
- (id)initWithObject:(id)firstObj arglist:(va_list)arglist;
- (id)initWithObjects:(id*)objects count:(unsigned int)count;
- (id)initWithSet:(NSSet*)anotherSet;
- (id)initWithSet:(NSSet*)set copyItems:(BOOL)flag;
- (id)initWithSet:(NSSet*)aSet;

/* Querying the Set */

- (NSArray*)allObjects;
- (id)anyObject;
- (BOOL)containsObject:(id)anObject;
- (unsigned int)count;
- (id)member:(id)anObject;
- (NSEnumerator*)objectEnumerator;

/* Sending Messages to Elements of the Set */
- (void)makeObjectsPerformSelector:(SEL)aSelector;
- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(id)anObject;
/* Obsolete methods */
- (void)makeObjectsPerform:(SEL)aSelector;
- (void)makeObjectsPerform:(SEL)aSelector withObject:(id)anObject;

/* Comparing Sets */

- (BOOL)intersectsSet:(NSSet*)otherSet;
- (BOOL)isEqualToSet:(NSSet*)otherSet;
- (BOOL)isSubsetOfSet:(NSSet*)otherSet;

/* Creating a String Description of the Set */

- (NSString*)description;
- (NSString*)descriptionWithLocale:(NSDictionary*)locale;
- (NSString*)descriptionWithLocale:(NSDictionary*)locale
   indent:(unsigned int)level;

@end

/*
 * NSMutableSet
 */

@interface NSMutableSet : NSSet

+ (id)allocWithZone:(NSZone*)zone;
+ (id)setWithCapacity:(unsigned)numItems;
- (id)initWithCapacity:(unsigned)numItems;

/* Adding Objects */

- (void)addObject:(id)object;
- (void)addObjectsFromArray:(NSArray *)array;
- (void)unionSet:(NSSet *)other;
- (void)setSet:(NSSet *)other;

/* Removing Objects */

- (void)intersectSet:(NSSet *)other;
- (void)minusSet:(NSSet *)other;
- (void)removeAllObjects;
- (void)removeObject:(id)object;

@end

/*
 * NSCountedSet Class
 */

@interface NSCountedSet : NSMutableSet
{
	NSMapTable*	table;
}

/* Allocating and Initializing */

- (id)init;
- (id)initWithObjects:(id*)objects count:(unsigned int)count;
- (id)initWithSet:(NSSet*)set copyItems:(BOOL)flag;

/* Accessing keys and values */

- (unsigned int)count;
- (id)member:(id)anObject;
- (NSEnumerator*)objectEnumerator;

/* Add and remove entries */

- (void)addObject:(id)object;
- (void)removeObject:(id)object;
- (void)removeAllObjects;

/* Querying the NSCountedSet */

- (unsigned)countForObject:(id)anObject;

/* Private */

- (void)__setObjectEnumerator:(void*)en;

@end

#endif /* __NSSet_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
