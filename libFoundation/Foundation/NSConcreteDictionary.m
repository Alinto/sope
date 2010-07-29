/* 
   NSConcreteDictionary.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.
   
   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
           Helge Hess <helge.hess@skyrix.com>
   
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
#include <math.h>

#include <Foundation/common.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include <extensions/objc-runtime.h>

#include "NSConcreteDictionary.h"

@interface _NSConcreteHashDictionaryKeyEnumerator : NSEnumerator
{
    NSConcreteHashDictionary *dict;
    struct _NSMapNode *node;
    int		      bucket;
}
@end
@interface _NSConcreteHashDictionaryObjectEnumerator : NSEnumerator
{
    NSConcreteHashDictionary *dict;
    struct _NSMapNode *node;
    int		      bucket;
}
@end

static Class NSConcreteMutableDictionaryClass = Nil;
static NSConcreteEmptyDictionary *sharedEmptyDict = nil;

/*
 * NSConcreteHashDictionary class
 */

@implementation NSConcreteHashDictionary

static __inline__ int _getHashSize(NSConcreteHashDictionary *self)
{
    return self->hashSize;
}

static __inline__ struct _NSMapNode *
_getNodeAt(NSConcreteHashDictionary *self, int idx)
{
    return self->nodes[idx];
}

static BOOL is_prime(unsigned n)
{
    int i, n2 = sqrt(n);

    for(i = 2; i <= n2; i++)
        if(n % i == 0)
            return NO;
    return YES;
}
static unsigned nextPrime(unsigned old_value)
{
    unsigned i, new_value = old_value | 1;

    for (i = new_value; i >= new_value; i += 2)
        if (is_prime(i))
            return i;
    return old_value;
}
static void dMapGrow(NSConcreteHashDictionary *table, unsigned newSize)
{
    unsigned i;
    struct _NSMapNode **newNodeTable;
    
    newNodeTable =
        NSZoneCalloc([table zone], newSize, sizeof(struct _NSMapNode*));
    
    for (i = 0; i < table->hashSize; i++) {
	struct _NSMapNode *next, *node;
	unsigned int h;
        
	node = table->nodes[i];
	while (node) {
	    next = node->next;
	    h = [(id)node->key hash] % newSize;
	    node->next = newNodeTable[h];
	    newNodeTable[h] = node;
	    node = next;
	}
    }
    NSZoneFree([table zone], table->nodes);
    table->nodes    = newNodeTable;
    table->hashSize = newSize;
}

static void dCheckMapTableFull(NSConcreteHashDictionary *table)
{
    if( ++(table->itemsCount) >= ((table->hashSize * 3) / 4)) {
	unsigned newSize;
        
        newSize = nextPrime((table->hashSize * 4) / 3);
	if(newSize != table->hashSize)
	    dMapGrow(table, newSize);
    }
}

static __inline__ void
dInsert(NSConcreteHashDictionary *table, id key, id value)
{
    unsigned int h;
    struct _NSMapNode *node;
    
    h = [key hash] % table->hashSize;
    
    for (node = table->nodes[h]; node; node = node->next) {
        /* might cache the selector .. */
        if ([key isEqual:node->key])
            break;
    }
    
    /* Check if an entry for key exist in nodeTable. */
    if (node) {
        /* key exist. Set for it new value and return the old value of it. */
	if (key != node->key) {
            RETAIN(key);
            RELEASE((id)node->key);
	}
	if (value != node->value) {
            RETAIN(value);
            RELEASE((id)node->value);
	}
	node->key   = key;
	node->value = value;
        return;
    }
    
    /* key not found. Allocate a new bucket and initialize it. */
    node = NSZoneMalloc([table zone], sizeof(struct _NSMapNode));
    RETAIN(key);
    RETAIN(value);
    node->key   = (void*)key;
    node->value = (void*)value;
    node->next  = table->nodes[h];
    table->nodes[h] = node;
    
    dCheckMapTableFull(table);
}

static __inline__ id dGet(NSConcreteHashDictionary *table, id key) {
    struct _NSMapNode *node;
    
    node = table->nodes[[key hash] % table->hashSize];
    for (; node; node = node->next) {
        /* could cache method .. */
        if ([key isEqual:node->key])
            return node->value;
    }
    return nil;
}

static __inline__ void dRemove(NSConcreteHashDictionary *table, id key) {
    unsigned int h;
    struct _NSMapNode *node, *node1 = NULL;

    if (key == nil)
        return;

    h = [key hash] % table->hashSize;
    
    // node point to current bucket, and node1 to previous bucket or to NULL
    // if current node is the first node in the list 
    
    for (node = table->nodes[h]; node; node1 = node, node = node->next) {
        /* could cache method .. */
        if ([key isEqual:node->key]) {
            RELEASE((id)node->key);
            RELEASE((id)node->value);
            
            if (!node1)
                table->nodes[h] = node->next;
            else
                node1->next = node->next;
	    NSZoneFree([table zone], node);
	    (table->itemsCount)--;
	    return;
        }
    }
}

+ (void)initialize {
    if (sharedEmptyDict == nil)
        sharedEmptyDict = [[NSConcreteEmptyDictionary alloc] init];
}

/* Allocating and Initializing */

- (id)init
{
    RELEASE(self);
    return RETAIN(sharedEmptyDict);
}

- (id)initWithObjects:(id *)objects
  forKeys:(id *)keys 
  count:(unsigned int)count
{
    unsigned capacity;
    
    if (count == 0) {
        RELEASE(self);
        return RETAIN(sharedEmptyDict);
    }
    else if (count == 1) {
        RELEASE(self);
        return [[NSConcreteSingleObjectDictionary alloc]
                   initWithObjects:objects forKeys:keys count:count];
    }
    
    capacity = (count * 4) / 3;
    capacity = capacity ? capacity : 13;
    if (!is_prime(capacity))
	capacity = nextPrime(capacity);
    
    self->hashSize   = capacity;
    self->nodes      = NSZoneCalloc([self zone], capacity, sizeof(void *));
    self->itemsCount = 0;
    
    while (count--) {
	if (!keys[count] || !objects[count])
	    [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in dictionary"] raise];
	dInsert(self, keys[count], objects[count]);
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    NSEnumerator *keys;
    id key;
    unsigned capacity;
    
    capacity = [dictionary count] * 4 / 3;
    capacity = capacity ? capacity : 13;
    if (!is_prime(capacity))
	capacity = nextPrime(capacity);

    self->hashSize   = capacity;
    self->nodes      = NSZoneCalloc([self zone], capacity, sizeof(void *));
    self->itemsCount = 0;
    
    keys = [dictionary keyEnumerator];
    while ((key = [keys nextObject]))
	dInsert(self, key, [dictionary objectForKey:key]);
    
    return self;
}

- (void)dealloc
{
    if (self->itemsCount > 0) {
        NSZone *z = [self zone];
        unsigned i;
        
        for (i = 0; i < self->hashSize; i++) {
            struct _NSMapNode *next, *node;
            
            node = self->nodes[i];
            self->nodes[i] = NULL;		
            while (node) {
                RELEASE((id)node->key);
                RELEASE((id)node->value);
                next = node->next;
                NSZoneFree(z, node);
                node = next;
            }
        }
        self->itemsCount = 0;
    }
    
    if (self->nodes)
        NSZoneFree([self zone], self->nodes);
    [super dealloc];
}

/* Accessing keys and values */

- (NSEnumerator *)keyEnumerator
{
    static Class KeyEnumClass = Nil;
    if (KeyEnumClass == Nil)
        KeyEnumClass = [_NSConcreteHashDictionaryKeyEnumerator class];
    return AUTORELEASE([[KeyEnumClass alloc] initWithDictionary:self]);
}
- (NSEnumerator *)objectEnumerator
{
    return AUTORELEASE([[_NSConcreteHashDictionaryObjectEnumerator alloc]
                           initWithDictionary:self]);
}

- (id)objectForKey:(id)aKey
{
    return dGet(self, aKey);
}

- (unsigned int)count
{
    return self->itemsCount;
}

@end /* NSConcreteHashDictionary */

/*
 * NSConcreteEmptyDictionary class
 */

@implementation NSConcreteEmptyDictionary

/* Allocating and Initializing */

- (id)init
{
    return [self initWithDictionary:nil];
}

- (id)initWithObjects:(id*)objects
    forKeys:(id*)keys 
    count:(unsigned int)_count
{
    if (_count > 1) {
        RELEASE(self);
        return [[NSConcreteHashDictionary alloc]
                   initWithObjects:objects forKeys:keys count:_count];
    }
    else if (_count == 1) {
        RELEASE(self);
        return [[NSConcreteSingleObjectDictionary alloc]
                   initWithObjects:objects forKeys:keys count:_count];
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary*)dictionary
{
    unsigned count = [dictionary count];
    
    if (count > 1) {
        RELEASE(self);
        return [[NSConcreteHashDictionary alloc] initWithDictionary:dictionary];
    }
    else if (count == 1) {
        RELEASE(self);
        return [[NSConcreteSingleObjectDictionary alloc]
                                                  initWithDictionary:dictionary];
    }
    return self;
}

/* Accessing keys and values */

- (NSEnumerator *)keyEnumerator
{
    return AUTORELEASE([[_NSConcreteSingleObjectDictionaryKeyEnumerator alloc]
                            initWithObject:nil]);
}

- (id)objectForKey:(id)aKey
{
    return nil;
}

- (unsigned int)count
{
    return 0;
}

/* NSCopying */

- (id)mutableCopyWithZone:(NSZone *)_zone
{
    if (NSConcreteMutableDictionaryClass == Nil)
        NSConcreteMutableDictionaryClass = [NSConcreteMutableDictionary class];
    
    return [[NSConcreteMutableDictionaryClass alloc] init];
}

@end /* NSConcreteEmptyDictionary */

/*
 * NSConcreteSingleObjectDictionary class
 */

@implementation NSConcreteSingleObjectDictionary

+ (void)initialize {
    if (sharedEmptyDict == nil)
        sharedEmptyDict = [[NSConcreteEmptyDictionary alloc] init];
}

/* Allocating and Initializing */

- (id)init
{
    RELEASE(self);
    return RETAIN(sharedEmptyDict);
}

- (id)initWithObjects:(id *)objects
    forKeys:(id *)keys 
    count:(unsigned int)_count
{
    if (_count == 0) {
        RELEASE(self);
        return RETAIN(sharedEmptyDict);
    }
    else if (_count > 1) {
        RELEASE(self);
        return [[NSConcreteHashDictionary alloc]
                   initWithObjects:objects forKeys:keys count:_count];
    }

    if (*keys == nil) {
        [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil key to be added in dictionary"] raise];
    }
    if (*objects == nil) {
        [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in dictionary"] raise];
    }
    self->key   = RETAIN(*keys);
    self->value = RETAIN(*objects);
    return self;
}

- (id)initWithDictionary:(NSDictionary*)dictionary
{
    unsigned count = [dictionary count];

    if (count == 0) {
        RELEASE(self);
        return RETAIN(sharedEmptyDict);
    }
    else if (count > 1) {
        RELEASE(self);
        return [[NSConcreteHashDictionary alloc]
                   initWithDictionary:dictionary];
    }

    self->key   = RETAIN([[dictionary keyEnumerator] nextObject]);
    self->value = RETAIN([dictionary objectForKey:key]);
    return self;
}

- (void)dealloc
{
    RELEASE(self->key);
    RELEASE(self->value);
    [super dealloc];
}

/* Accessing keys and values */

- (NSEnumerator *)keyEnumerator
{
    return AUTORELEASE([[_NSConcreteSingleObjectDictionaryKeyEnumerator alloc]
                            initWithObject:self->key]);
}

- (id)objectForKey:(id)aKey
{
    return ([self->key isEqual:aKey]) ? self->value : nil;
}

- (unsigned int)count
{
    return 1;
}

/* NSCopying */

- (id)mutableCopyWithZone:(NSZone *)_zone
{
    if (NSConcreteMutableDictionaryClass == Nil)
        NSConcreteMutableDictionaryClass = [NSConcreteMutableDictionary class];
    return [[NSConcreteMutableDictionaryClass alloc]
               initWithObjects:&(self->value) forKeys:&(self->key) count:1];
}

@end /* NSConcreteSingleObjectDictionary */

#if defined(SMALL_NSDICTIONARY_SIZE)

/*
 * NSConcreteSmallDictionary class
 */

@implementation NSConcreteSmallDictionary

- (id)init
{
    RELEASE(self);
    return RETAIN(sharedEmptyDict);
}

- (id)initWithObjects:(id*)_objects forKeys:(id*)_keys 
  count:(unsigned int)_count
{
    if (_count == 0) {
        RELEASE(self);
        return RETAIN(sharedEmptyDict);
    }
    else if (_count == 1) {
        RELEASE(self);
        return [[NSConcreteSingleObjectDictionary alloc]
                   initWithObjects:_objects forKeys:_keys count:_count];
    }
    
    NSAssert2(_count <= SMALL_NSDICTIONARY_SIZE,
              @"too many objects for small dictionary (max=%i, count=%i)!",
              SMALL_NSDICTIONARY_SIZE, _count);
    self->count = _count;
    
    while(_count--) {
	if ((_keys[_count] == nil) || (_objects[_count] == nil)) {
	    [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil object to be added in dictionary"] raise];
        }
        self->entries[_count].key   = RETAIN(_keys[_count]);
        self->entries[_count].hash  = [_keys[_count] hash];
        self->entries[_count].value = RETAIN(_objects[_count]);
    }
    return self;
}
- (id)initWithDictionary:(NSDictionary*)dictionary
{
    NSEnumerator  *keys = [dictionary keyEnumerator];
    unsigned char i;
    
    self->count = [dictionary count];
    NSAssert2(self->count <= SMALL_NSDICTIONARY_SIZE,
              @"too many objects for small dictionary (max=%i, count=%i)!",
              SMALL_NSDICTIONARY_SIZE, self->count);

    for (i = 0; i < self->count; i++) {
        id key = [keys nextObject];
        self->entries[i].key   = RETAIN(key);
        self->entries[i].hash  = [key hash];
        self->entries[i].value = RETAIN([dictionary objectForKey:key]);
    }
    return self;
}

- (void)dealloc {
    unsigned char i;
    for (i = 0; i < self->count; i++) {
        RELEASE(self->entries[i].key);
        RELEASE(self->entries[i].value);
    }
    [super dealloc];
}

- (id)objectForKey:(id)aKey
{
    register NSSmallDictionaryEntry *e = self->entries;
    register signed char i;
    register unsigned hash = [aKey hash];
    
    for (i = (self->count - 1); i >= 0; i--, e++) {
        if (e->hash == hash) {
            if (e->key == aKey)        return e->value;
            if ([e->key isEqual:aKey]) return e->value;
        }
    }
    return nil;
}

- (unsigned int)count
{
    return self->count;
}
- (NSEnumerator *)keyEnumerator
{
    return AUTORELEASE([[_NSConcreteSmallDictionaryKeyEnumerator alloc]
                            initWithDictionary:self
                            firstEntry:self->entries count:self->count]);
}

@end /* NSConcreteSmallDictionary */

#endif /* SMALL_NSDICTIONARY_SIZE */

@implementation _NSConcreteSingleObjectDictionaryKeyEnumerator

- (id)initWithObject:(id)_object
{
    self->nextObject = RETAIN(_object);
    return self;
}
- (void)dealloc {
    RELEASE(self->nextObject);
    [super dealloc];
}

- (id)nextObject
{
    id no = self->nextObject;
    if (no) {
        self->nextObject = AUTORELEASE(self->nextObject);
        self->nextObject = nil;
    }
    return no;
}

@end

#if defined(SMALL_NSDICTIONARY_SIZE)

@implementation _NSConcreteSmallDictionaryKeyEnumerator

- (id)initWithDictionary:(NSConcreteSmallDictionary *)_dict
  firstEntry:(NSSmallDictionaryEntry *)_firstEntry
  count:(unsigned char)_count
{
    self->dict         = RETAIN(_dict);
    self->currentEntry = _firstEntry;
    self->count        = _count;
    return self;
}

- (void)dealloc {
    RELEASE(self->dict);
    [super dealloc];
}

- (id)nextObject {
    if (self->count > 0) {
        id obj;
        obj = self->currentEntry->key;
        self->currentEntry++;
        self->count--;
        return obj;
    }
    else
        return nil;
}

@end /* _NSConcreteSmallDictionaryKeyEnumerator */

#endif /* SMALL_NSDICTIONARY_SIZE */

@implementation _NSConcreteHashDictionaryKeyEnumerator

- (id)initWithDictionary:(NSConcreteHashDictionary *)_dict
{
    self->dict   = RETAIN(_dict);
    self->node   = NULL;
    self->bucket = -1;
    return self;
}

- (void)dealloc
{
    RELEASE(dict);
    [super dealloc];
}

- (id)nextObject
{
    if (self->node)
	self->node = self->node->next;
    
    if (self->node == NULL) {
	for(self->bucket++;
            ((int)self->bucket) < _getHashSize(self->dict);
            self->bucket++) {

            if (_getNodeAt(self->dict, self->bucket)) {
                self->node = _getNodeAt(self->dict, self->bucket);
                break;
	    }
        }
	if (((int)self->bucket) >= _getHashSize(self->dict)) {
	    self->node = NULL;
	    self->bucket = (_getHashSize(self->dict) - 1);
	    return nil;
	}
    }
    return self->node->key;
}

@end /* _NSConcreteHashDictionaryKeyEnumerator */

@implementation _NSConcreteHashDictionaryObjectEnumerator

- (id)initWithDictionary:(NSConcreteHashDictionary *)_dict
{
    self->dict   = RETAIN(_dict);
    self->node   = NULL;
    self->bucket = -1;
    return self;
}

- (void)dealloc
{
    RELEASE(dict);
    [super dealloc];
}

- (id)nextObject
{
    if (self->node)
	self->node = self->node->next;
    
    if (self->node == NULL) {
	for(self->bucket++;
            ((int)self->bucket) < _getHashSize(self->dict);
            self->bucket++) {

            if (_getNodeAt(self->dict, self->bucket)) {
                self->node = _getNodeAt(self->dict, self->bucket);
                break;
	    }
        }
	if (((int)self->bucket) >= _getHashSize(self->dict)) {
	    self->node = NULL;
	    self->bucket = (_getHashSize(self->dict) - 1);
	    return nil;
	}
    }
    return self->node->value;
}

@end /* _NSConcreteHashDictionaryObjectEnumerator */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

