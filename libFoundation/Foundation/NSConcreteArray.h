/* 
   NSConcreteArray.h

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

#ifndef __NSConcreteArray_h__
#define __NSConcreteArray_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSEnumerator.h>

@class NSString;

/*
 * NSConcreteArray class
 */

@interface NSConcreteArray : NSArray
{
    id		*items;		// data of the array object
    unsigned int itemsCount;	// Actual number of elements
}

- (id)init;
- (id)initWithObjects:(id *)objects count:(unsigned int)count;
- (id)initWithArray:(NSArray *)anotherArray;
- (void)dealloc;

- (id)objectAtIndex:(unsigned int)index;
- (unsigned int)count;
- (unsigned int)indexOfObjectIdenticalTo:(id)anObject;

@end

/*
 * NSConcreteArray class
 */

@interface NSConcreteEmptyArray : NSArray
{
}

- (id)init;
- (id)initWithObjects:(id *)objects count:(unsigned int)count;
- (id)initWithArray:(NSArray *)anotherArray;

- (id)objectAtIndex:(unsigned int)index;
- (unsigned int)count;
- (unsigned int)indexOfObjectIdenticalTo:(id)anObject;

@end

/*
 * NSConcreteSingleObjectArray class
 */

@interface NSConcreteSingleObjectArray : NSArray
{
    id item;
}

- (id)init;
- (id)initWithObjects:(id *)objects count:(unsigned int)count;
- (id)initWithArray:(NSArray *)anotherArray;

- (id)objectAtIndex:(unsigned int)index;
- (unsigned int)count;
- (unsigned int)indexOfObjectIdenticalTo:(id)anObject;

@end

/*
 * NSConcreteMutableArray class
 */

@interface NSConcreteMutableArray : NSMutableArray
{
    id		*items;		// data of the array object
    unsigned	itemsCount;	// Actual number of elements
    unsigned	maxItems;	// Maximum number of elements
}

- (id)init;
- (id)initWithCapacity:(unsigned int)aNumItems;
- (id)initWithObjects:(id *)objects count:(unsigned int)count;

- (void)insertObject:(id)anObject atIndex:(unsigned int)index;
- (void)replaceObjectAtIndex:(unsigned int)index withObject:(id)anObject;
- (void)removeAllObjects;
- (void)removeLastObject;
- (void)removeObjectAtIndex:(unsigned int)index;
- (void)removeObjectsFrom:(unsigned int)index count:(unsigned int)count;

@end

/*
 * NSArrayEnumerator class
 */

@interface _NSArrayEnumerator : NSEnumerator
{
	NSArray *array;
	unsigned int index;
	BOOL reverse;
}

- (id)initWithArray:(NSArray*)anArray reverse:(BOOL)isReverse;
- (id)nextObject;

@end

#endif /* __NSConcreteArray_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
