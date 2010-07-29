/* 
   NSConcreteDictionary.h

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

#ifndef __NSConcreteDictionary_h__
#define __NSConcreteDictionary_h__

#include <Foundation/NSUtilities.h>

#define SMALL_NSDICTIONARY_SIZE 8

/*
 * NSConcreteHashDictionary class
 */

@interface NSConcreteHashDictionary : NSDictionary
{
    struct _NSMapNode **nodes;
    unsigned int      hashSize;
    unsigned int      itemsCount;
}

/* Allocating and Initializing an Dictionary */
- (id)initWithObjects:(id*)objects forKeys:(id*)keys 
  count:(unsigned int)count;
- (id)initWithDictionary:(NSDictionary *)dictionary;

/* Accessing keys and values */
- (id)objectForKey:(id)aKey;
- (unsigned int)count;
- (NSEnumerator *)keyEnumerator;

@end /* NSConcreteHashDictionary */

/*
 * NSConcreteEmptyDictionary class
 */

@interface NSConcreteEmptyDictionary : NSDictionary
{
}

/* Allocating and Initializing an Dictionary */
- (id)initWithObjects:(id*)objects forKeys:(id*)keys 
  count:(unsigned int)count;
- (id)initWithDictionary:(NSDictionary*)dictionary;

/* Accessing keys and values */
- (id)objectForKey:(id)aKey;
- (unsigned int)count;
- (NSEnumerator *)keyEnumerator;

@end /* NSConcreteEmptyDictionary */

/*
 * NSConcreteSingleObjectDictionary class
 */

@interface NSConcreteSingleObjectDictionary : NSDictionary
{
    id key;
    id value;
}

/* Allocating and Initializing an Dictionary */
- (id)initWithObjects:(id*)objects forKeys:(id*)keys 
  count:(unsigned int)count;
- (id)initWithDictionary:(NSDictionary*)dictionary;

/* Accessing keys and values */
- (id)objectForKey:(id)aKey;
- (unsigned int)count;
- (NSEnumerator *)keyEnumerator;

@end /* NSConcreteSingleObjectDictionary */

#if defined(SMALL_NSDICTIONARY_SIZE)

/*
 * NSConcreteSmallDictionary class
 */

typedef struct _NSSmallDictionaryEntry {
    unsigned hash;
    id       key;
    id       value;
} NSSmallDictionaryEntry;

@interface NSConcreteSmallDictionary : NSDictionary
{
    unsigned char          count;
    NSSmallDictionaryEntry entries[1];
}

/* Allocating and Initializing an Dictionary */
- (id)initWithObjects:(id*)objects forKeys:(id*)keys 
  count:(unsigned int)count;
- (id)initWithDictionary:(NSDictionary*)dictionary;

/* Accessing keys and values */
- (id)objectForKey:(id)aKey;
- (unsigned int)count;
- (NSEnumerator *)keyEnumerator;

@end /* NSConcreteSmallDictionary */

#endif

/*
 * NSConcreteMutableDictionary class
 */

@interface NSConcreteMutableDictionary : NSMutableDictionary
{
    struct _NSMapNode **nodes;
    unsigned int      hashSize;
    unsigned int      itemsCount;
}

/* Allocating and Initializing an Dictionary */
- (id)init;
- (id)initWithCapacity:(unsigned int)aNumItems;


/* Modifying dictionary */
- (void)setObject:(id)anObject forKey:(id)aKey;
- (void)removeObjectForKey:(id)theKey;
- (void)removeAllObjects;

@end /* NSConcreteMutableDictionary */

/*
 * NSDictionary Enumerator classes
 */

@interface _NSDictionaryObjectEnumerator : NSEnumerator
{
    NSDictionary* dict;
    NSEnumerator* keys;
}

- initWithDictionary:(NSDictionary*)_dict;
- nextObject;

@end /* _NSDictionaryObjectEnumerator */

/*
 * NSDictionary Enumerator classes
 */

@interface _NSConcreteSingleObjectDictionaryKeyEnumerator : NSEnumerator
{
    id nextObject;
}

- (id)initWithObject:(id)_object;
- (id)nextObject;

@end /* _NSConcreteSingleObjectDictionaryKeyEnumerator */

#if defined(SMALL_NSDICTIONARY_SIZE)

@interface _NSConcreteSmallDictionaryKeyEnumerator : NSEnumerator
{
    NSDictionary *dict;
    NSSmallDictionaryEntry *currentEntry;
    unsigned char count;
}

- (id)initWithDictionary:(NSConcreteSmallDictionary *)_dict
  firstEntry:(NSSmallDictionaryEntry *)_firstEntry
  count:(unsigned char)_count;

- (id)nextObject;

@end

#endif /* SMALL_NSDICTIONARY_SIZE */

#endif /* __NSConcreteDictionary_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
