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

#include "NSConcreteDictionary.h"

/*
* NSConcreteMutableDictionary class
*/

@interface _NSConcreteMutableDictionaryKeyEnumerator : NSEnumerator
{
    NSConcreteMutableDictionary *dict;
    struct _NSMapNode *node;
    int		      bucket;
}
@end
@interface _NSConcreteMutableDictionaryObjectEnumerator : NSEnumerator
{
    NSConcreteMutableDictionary *dict;
    struct _NSMapNode *node;
    int		      bucket;
}
@end

@implementation NSConcreteMutableDictionary

/* 
   static method cache for keys, which are almost always NSStrings, so this
   should give a very good hit rate.
*/
static Class        LastKeyClass = Nil;
static BOOL         (*KeyEq)(id, SEL, id);
static unsigned int (*KeyHash)(id, SEL);
static IMP          KeyRetain;

static __inline__ int _getHashSize(NSConcreteMutableDictionary *self)
{
    return self->hashSize;
}

static __inline__ struct _NSMapNode *
_getNodeAt(NSConcreteMutableDictionary *self, int idx)
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

static void mdMapGrow(NSConcreteMutableDictionary *table, unsigned newSize)
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

static void mdCheckMapTableFull(NSConcreteMutableDictionary *table)
{
    if( ++(table->itemsCount) >= ((table->hashSize * 3) / 4)) {
	unsigned newSize;
        
        newSize = nextPrime((table->hashSize * 4) / 3);
	if(newSize != table->hashSize)
	    mdMapGrow(table, newSize);
    }
}

static __inline__ void
mdInsert(NSConcreteMutableDictionary *table, id key, id value)
{
    unsigned int h;
    struct _NSMapNode *node;
    
    if (*(Class *)key != LastKeyClass) {
        LastKeyClass = *(Class *)key;
        if (object_is_instance(key)) {
            KeyEq   = (void *)method_get_imp(class_get_instance_method(
                        LastKeyClass, @selector(isEqual:)));
            KeyHash = (void *)method_get_imp(class_get_instance_method(
                        LastKeyClass, @selector(hash)));
            KeyRetain = method_get_imp(class_get_instance_method(
                        LastKeyClass, @selector(retain)));
        }
        else {
            KeyEq   = (void *)method_get_imp(class_get_class_method(
                        LastKeyClass, @selector(isEqual:)));
            KeyHash = (void *)method_get_imp(class_get_class_method(
                        LastKeyClass, @selector(hash)));
            KeyRetain = method_get_imp(class_get_class_method(
                        LastKeyClass, @selector(retain)));
        }
    }
    
    h = KeyHash(key, NULL /* dangerous? */) % table->hashSize;
    
    for (node = table->nodes[h]; node; node = node->next) {
        if (KeyEq(key, NULL /* dangerous? */, node->key))
            break;
    }
    
    /* Check if an entry for key exist in nodeTable. */
    if (node) {
        /* key exist. Set for it new value and return the old value of it. */
	if (key != node->key) {
            KeyRetain(key, NULL /* dangerous? */);
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
    node->key   = (void*)KeyRetain(key, NULL /* dangerous? */);
    node->value = (void*)RETAIN(value);
    node->next  = table->nodes[h];
    table->nodes[h] = node;
    
    mdCheckMapTableFull(table);
}

static __inline__ id mdGet(NSConcreteMutableDictionary *table, id key) {
    static Class LastKeyClass = Nil;
    static unsigned int (*mhash)(id, SEL);
    static BOOL (*meq)(id, SEL, id);
    register struct _NSMapNode *node;
    
    if (key == nil)
	// TODO: are nil-keys allowed in Cocoa? Maybe print a warning
	return nil;
    if (LastKeyClass != *(id *)key) {
	LastKeyClass = *(id *)key;
	mhash = (void *)method_get_imp(class_get_instance_method(LastKeyClass, 
          @selector(hash)));
	meq   = (void *)method_get_imp(class_get_instance_method(LastKeyClass, 
          @selector(isEqual:)));
    }
    
    node = table->nodes[mhash(key, NULL /* dangerous? */) % table->hashSize];
    for (; node; node = node->next) {
        /* could cache method .. */
        if (meq(key, NULL /*dangerous?*/, node->key))
            return node->value;
    }
    return nil;
}

static __inline__ void mdRemove(NSConcreteMutableDictionary *table, id key) {
    unsigned int h;
    struct _NSMapNode *node, *node1 = NULL;

    if (key == nil)
        return;

    h = [key hash] % table->hashSize;
    
    // node point to current bucket, and node1 to previous bucket or to NULL
    // if current node is the first node in the list 
    
    for (node = table->nodes[h]; node; node1 = node, node = node->next) {
        /* could cache method .. */
        if (![key isEqual:node->key])
            continue;
        
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

/* Allocating and Initializing */

- (id)init
{
    return [self initWithCapacity:0];
}

- (id)initWithCapacity:(unsigned int)aNumItems
{
    unsigned capacity;

    if (aNumItems != 0) {
        capacity = (aNumItems * 4) / 3;
        if (!is_prime(capacity))
            capacity = nextPrime(capacity);
    }
    else {
        capacity = 13;
    }

#if LOG_INIT_CAPACITY
    printf("MDICT initWithCapacity:%i\n", capacity);
#endif
    
    self->hashSize   = capacity;
    self->nodes      = NSZoneCalloc([self zone], capacity, sizeof(void *));
    self->itemsCount = 0;
    return self;
}

- (id)initWithObjects:(id *)objects
  forKeys:(id *)keys 
  count:(unsigned int)count
{
    unsigned capacity;

    if (count != 0) {
        capacity = (count * 4) / 3;
        if (!is_prime(capacity))
            capacity = nextPrime(capacity);
    }
    else
        capacity = 13;
    
#if LOG_INIT_CAPACITY
    printf("MDICT initWithCapacity:%i\n", capacity);
#endif
    
    self->hashSize   = capacity;
    self->nodes      = NSZoneCalloc([self zone], capacity, sizeof(void *));
    self->itemsCount = 0;
    
    if (count == 0)
        return self;

    while (count--) {
        register id key, value;
        
	if ((key = keys[count]) == nil) {
	    [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil key to be added in dictionary"] raise];
        }
	if ((value = objects[count]) == nil) {
	    [[[InvalidArgumentException alloc] 
		    initWithReason:@"Nil value to be added in dictionary"] raise];
        }
        
	mdInsert(self, key, value);
    }
    return self;
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    unsigned     capacity;
    NSEnumerator *keys;
    id           key;

    capacity = [dictionary count] * 4 / 3;
    capacity = capacity != 0 ? capacity : 13;
    if (!is_prime(capacity))
	capacity = nextPrime(capacity);

    self->hashSize   = capacity;
    self->nodes      = NSZoneCalloc([self zone], capacity, sizeof(void *));
    self->itemsCount = 0;
    
#if LOG_INIT_CAPACITY
    printf("MDICT initWithCapacity:%i\n", capacity);
#endif
    
    keys = [dictionary keyEnumerator];
    while ((key = [keys nextObject]))
	mdInsert(self, key, [dictionary objectForKey:key]);
    
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
#if !LIB_FOUNDATION_BOEHM_GC
                [(id)node->key   release];
                [(id)node->value release];
#endif
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
        KeyEnumClass = [_NSConcreteMutableDictionaryKeyEnumerator class];
    return AUTORELEASE([[KeyEnumClass alloc] initWithDictionary:self]);
}
- (NSEnumerator *)objectEnumerator
{
    return AUTORELEASE([[_NSConcreteMutableDictionaryObjectEnumerator alloc]
                           initWithDictionary:self]);
}

- (id)objectForKey:(id)aKey
{
    return mdGet(self, aKey);
}

- (unsigned int)count
{
    return self->itemsCount;
}

/* Modifying dictionary */

- (void)setObject:(id)anObject forKey:(id)aKey
{
    if (aKey == nil) {
	[[[InvalidArgumentException alloc]
		    initWithFormat:
                      @"nil key to be added in dictionary (object=0x%p)",
                      anObject] raise];
    }
    if (anObject == nil) {
	[[[InvalidArgumentException alloc]
		    initWithFormat:
                      @"nil object to be added in dictionary (key=%@)",
                      aKey] raise];
    }
    mdInsert(self, aKey, anObject);
}

- (void)removeObjectForKey:(id)aKey
{
    mdRemove(self, aKey);
}

- (void)removeAllObjects
{
    if (self->itemsCount > 0) {
        NSZone *z = [self zone];
        unsigned i;
        
        for (i = 0; i < self->hashSize; i++) {
            struct _NSMapNode *next, *node;
            
            node = self->nodes[i];
            self->nodes[i] = NULL;
            while (node) {
#if !LIB_FOUNDATION_BOEHM_GC
                [(id)node->key   release];
                [(id)node->value release];
#endif
                next = node->next;
                NSZoneFree(z, node);
                node = next;
            }
        }
        self->itemsCount = 0;
    }
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone
{
    if (self->itemsCount == 0)
        return [[NSConcreteMutableDictionary allocWithZone:_zone] init];
    
    if (self->itemsCount == 1) {
        struct _NSMapNode *node  = NULL;
        int		  bucket = -1;
        
	for (bucket++; ((unsigned)bucket) < self->hashSize; bucket++) {
            
            if (_getNodeAt(self, bucket)) {
                node = _getNodeAt(self, bucket);
                break;
	    }
        }
	NSAssert(((unsigned)bucket) < self->hashSize,
                 @"invalid hashtable state !");
        
        return [[NSConcreteSingleObjectDictionary allocWithZone:_zone]
                                                  initWithObjects:
                                                    (id *)&(node->value) 
                                                  forKeys:(id *)&(node->key)
                                                  count:1];
    }
    
#if defined(SMALL_NSDICTIONARY_SIZE) && 0
    if (self->itemsCount <= SMALL_NSDICTIONARY_SIZE) {
        return [[NSConcreteSmallDictionary allocWithZone:_zone]
                                           initWithDictionary:self
                                           copyItems:NO];
    }
#endif
    
    return [[NSConcreteHashDictionary allocWithZone:_zone]
                                      initWithDictionary:self copyItems:NO];
}

@end /* NSConcreteMutableDictionary */

@implementation _NSConcreteMutableDictionaryKeyEnumerator

- (id)initWithDictionary:(NSConcreteMutableDictionary *)_dict
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

@end /* _NSConcreteMutableDictionaryKeyEnumerator */

@implementation _NSConcreteMutableDictionaryObjectEnumerator

- (id)initWithDictionary:(NSConcreteMutableDictionary *)_dict
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
	for (self->bucket++;
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

@end /* _NSConcreteMutableDictionaryObjectEnumerator */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
