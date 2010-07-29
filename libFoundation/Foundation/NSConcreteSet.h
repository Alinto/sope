/* 
   NSConcreteSet.h

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

#ifndef __NSConcreteSet_h__
#define __NSConcreteSet_h__

#include <Foundation/NSSet.h>
#include <Foundation/NSEnumerator.h>
#include <Foundation/NSUtilities.h>

/*
 * Concrete class for NSSet
 */

@interface NSConcreteSet : NSSet
{
    NSHashTable* table;
}

/* Allocating and Initializing */

- (id)init;
- (id)initWithObjects:(id*)objects count:(unsigned int)count;
- (id)initWithSet:(NSSet *)set copyItems:(BOOL)flag;

/* Accessing keys and values */

- (unsigned int)count;
- (id)member:(id)anObject;
- (NSEnumerator *)objectEnumerator;

/* Private methods */

- (void)__setObjectEnumerator:(void*)en;

@end

/*
 * Concrete class for NSMutableSet
 */

@interface NSConcreteMutableSet : NSMutableSet
{
    NSHashTable* table;
}

/* Allocating and Initializing */

- (id)init;
- (id)initWithObjects:(id*)objects count:(unsigned int)count;
- (id)initWithSet:(NSSet *)set copyItems:(BOOL)flag;

/* Accessing keys and values */

- (unsigned int)count;
- (id)member:(id)anObject;
- (NSEnumerator *)objectEnumerator;

/* Add and remove entries */

- (void)addObject:(id)object;
- (void)removeObject:(id)object;
- (void)removeAllObjects;

/* Private methods */

- (void)__setObjectEnumerator:(void*)en;

@end

/*
 * _NSConcreteSetEnumerator class
 */

typedef enum {setEnumHash, setEnumMap} SetEnumMode;

@interface _NSConcreteSetEnumerator : NSEnumerator
{
    id set;
    SetEnumMode	mode;
    union {
	NSMapEnumerator  map;
	NSHashEnumerator hash;
    } enumerator;
}

- (id)initWithSet:(NSSet*)_set mode:(SetEnumMode)_mode;
- (id)nextObject;

@end /* _NSConcreteSetEnumerator */

#endif /* __NSConcreteSet_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
