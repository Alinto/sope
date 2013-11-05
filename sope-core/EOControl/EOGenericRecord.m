/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "EOGenericRecord.h"
#include "EONull.h"
#include "EOClassDescription.h"
#include "EOObserver.h"
#include "EOKeyValueCoding.h"
#include "common.h"
#include <math.h>

@interface NSObject(MappedArray)
- (NSArray *)mappedArrayUsingSelector:(SEL)_selector;
@end

@interface _EOConcreteEOGenericRecordKeyEnumerator : NSEnumerator
{
    EOGenericRecord   *dict;
    struct _NSMapNode *node;
    int		      bucket;
}
+ (id)enumWithEO:(EOGenericRecord *)_eo;
@end

#if !LIB_FOUNDATION_LIBRARY
struct _NSMapNode {
    void *key;
    void *value;
    struct _NSMapNode *next;
};
#endif

@implementation EOGenericRecord

/* final methods */

static __inline__ unsigned _getHashSize(EOGenericRecord *self);
static __inline__ struct _NSMapNode *_getNodeAt(EOGenericRecord *self, int idx);
static BOOL is_prime(unsigned n);
static unsigned nextPrime(unsigned old_value);
static void eoMapGrow(EOGenericRecord *table, unsigned newSize);
static void eoCheckMapTableFull(EOGenericRecord *table);
static __inline__ void eoInsert(EOGenericRecord *table, id key, id value);
static __inline__ id eoGet(EOGenericRecord *table, id key);
static __inline__ void eoRemove(EOGenericRecord *table, id key);

static EONull *null = nil;

+ (int)version {
  return 2;
}

+ (void)initialize {
  if (null == nil) null = [[EONull null] retain];
}

- (id)initWithEditingContext:(id)_ec
  classDescription:(EOClassDescription *)_classDesc
  globalID:(EOGlobalID *)_oid
{
  unsigned capacity;
  
#if DEBUG
  NSAssert(_classDesc, @"did not find class description for EOGenericRecord !");
#endif

  capacity = 16 * 4 / 3;
  capacity = capacity ? capacity : 13;
  if (!is_prime(capacity))
    capacity = nextPrime(capacity);

  self->hashSize   = capacity;
  self->nodes      = NSZoneCalloc([self zone], capacity, sizeof(void *));
  self->itemsCount = 0;
  
  self->classDescription = [_classDesc retain];
  self->willChange = [self methodForSelector:@selector(willChange)];
  return self;
}

- (id)init {
  EOClassDescription *c;
  
  c = (EOClassDescription *)
    [EOClassDescription classDescriptionForClass:[self class]];
  
  return [self initWithEditingContext:nil classDescription:c globalID:nil];
}

- (void)dealloc {
  if ([self respondsToSelector:@selector(_letDatabasesForget)])
    [self performSelector:@selector(_letDatabasesForget)];
  
  if (self->itemsCount > 0) {
    NSZone *z = [self zone];
    unsigned i;
        
    for (i = 0; i < self->hashSize; i++) {
      struct _NSMapNode *next, *node;
            
      node = self->nodes[i];
      self->nodes[i] = NULL;		
      while (node) {
        [(id)node->key   release];
        [(id)node->value release];
        next = node->next;
        NSZoneFree(z, node);
        node = next;
      }
    }
    self->itemsCount = 0;
  }
    
  if (self->nodes)
    NSZoneFree([self zone], self->nodes);

  [self->classDescription release];
  [super dealloc];
}

/* class description */

- (NSClassDescription *)classDescription {
  return self->classDescription;
}

static inline void _willChange(EOGenericRecord *self) {
  if (self->willChange)
    self->willChange(self, @selector(willChange:));
  else
    [self willChange];
}

#if GNUSTEP_BASE_LIBRARY
- (void)setValue:(id)_value forKey:(NSString *)_key {
  [self takeValue:_value forKey:_key];
}
#endif
- (void)takeValue:(id)_value forKey:(NSString *)_key {
  id value;
  
  if (_value == nil) _value = null;
  
#if DEBUG
  NSAssert1(_key, @"called -takeValue:0x%p forKey:nil !", _value);
#endif
  
  value = eoGet(self, _key);
  
  if (value != _value) {
    _willChange(self);
    
    if (_value == nil)
      eoRemove(self, _key);
    else
      eoInsert(self, _key, _value);
  }
}
- (id)valueForKey:(NSString *)_key {
  id v;
  
  if ((v = eoGet(self, _key)) == nil) {
#if DEBUG && 0
    if ([_key isEqualToString:@"description"]) {
      NSLog(@"WARNING(%s): -valueForKey:%@ is nil, calling super",
            __PRETTY_FUNCTION__, _key);
    }
#endif
    
    return [super valueForKey:_key];
  }

#if DEBUG
  NSAssert(null != nil, @"missing null ..");
#endif
  
  return v == null ? nil : v;
}

- (void)takeValuesFromDictionary:(NSDictionary *)dictionary {
  _willChange(self);
  {
    NSEnumerator *e = [dictionary keyEnumerator];
    NSString     *key;

    while ((key = [e nextObject])) {
      id value = [dictionary objectForKey:key];
      NSAssert(value, @"tried to set <nil> value ..");
      eoInsert(self, key, value);
    }
  }
}

- (NSDictionary *)valuesForKeys:(NSArray *)keys {
  // OPT - cache IMP for objectAtIndex, objectForKey, setObject:forKey:
  NSMutableDictionary *dict;
  IMP objAtIdx, setObjForKey;
  unsigned int i, n;

  if (keys == nil) return nil;

  n = [keys count];
  dict = [NSMutableDictionary dictionaryWithCapacity:n];

  objAtIdx     = [keys methodForSelector:@selector(objectAtIndex:)];
  setObjForKey = [dict methodForSelector:@selector(setObject:forKey:)];
    
  for (i = 0; i < n; i++) {
    NSString *key;
    id       value;

    key = objAtIdx(keys, @selector(objectAtIndex:), i);
    NSAssert(key, @"invalid key <nil>");
    
    value = [self valueForKey:key];
    if (value == nil) value = null;
    
#if DEBUG
    NSAssert2(value, @"eo of type %@, missing value for attribute %@",
              self->classDescription, key);
#endif
    
    setObjForKey(dict, @selector(setObject:forKey:), value, key);
  }
  return dict;
}

- (void)takeStoredValue:(id)_value forKey:(NSString *)_key {
  if (_value == nil) _value = null;
  [self takeValue:_value forKey:_key];
}
- (id)storedValueForKey:(NSString *)_key {
  id v;

  v = [self valueForKey:_key];
#if DEBUG && 0
  NSAssert(v != null, @"valueForKey: return NSNull !");
#endif
  //if (v == nil) return [super storedValueForKey:_key];
  return v;
}

- (void)setObject:(id)object forKey:(id)key {
  if (object == nil) object = null;
  
  _willChange(self);
  eoInsert(self, key, object);
}

- (id)objectForKey:(id)key {
  return eoGet(self, key);
}

- (void)removeObjectForKey:(id)key {
  _willChange(self);
  eoRemove(self, key);
}

- (BOOL)kvcIsPreferredInKeyPath {
  return YES;
}

- (NSEnumerator *)keyEnumerator {
  return [_EOConcreteEOGenericRecordKeyEnumerator enumWithEO:self];
}

/* copying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<EOGenericRecord: description %@ attributes=%@>",
                     [self entityName],
                     [self valuesForKeys:[self attributeKeys]]];
}

/* final methods */

static __inline__ unsigned _getHashSize(EOGenericRecord *self)
{
    return self->hashSize;
}

static __inline__ struct _NSMapNode *
_getNodeAt(EOGenericRecord *self, int idx)
{
    return self->nodes[idx];
}

static BOOL is_prime(unsigned n) {
  int i, n2 = sqrt(n);

  for (i = 2; i <= n2; i++) {
    if (n % i == 0)
      return NO;
  }
  return YES;
}
static unsigned nextPrime(unsigned old_value) {
  unsigned i, new_value = old_value | 1;

  for (i = new_value; i >= new_value; i += 2) {
    if (is_prime(i))
      return i;
  }
  return old_value;
}

static void eoMapGrow(EOGenericRecord *table, unsigned newSize) {
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

static void eoCheckMapTableFull(EOGenericRecord *table) {
  if( ++(table->itemsCount) >= ((table->hashSize * 3) / 4)) {
    unsigned newSize;
    
    newSize = nextPrime((table->hashSize * 4) / 3);
    if(newSize != table->hashSize)
      eoMapGrow(table, newSize);
  }
}

static __inline__ void eoInsert(EOGenericRecord *table, id key, id value) {
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
      key = [key retain];
      [(id)node->key release];
    }
    if (value != node->value) {
      value = [value retain];
      [(id)node->value release];
    }
    node->key   = key;
    node->value = value;
    return;
  }
  
  /* key not found. Allocate a new bucket and initialize it. */
  node = NSZoneMalloc([table zone], sizeof(struct _NSMapNode));
  key   = [key   retain];
  value = [value retain];
  node->key   = (void*)key;
  node->value = (void*)value;
  node->next  = table->nodes[h];
  table->nodes[h] = node;
  
  eoCheckMapTableFull(table);
}

static __inline__ id eoGet(EOGenericRecord *table, id key) {
    struct _NSMapNode *node;
    
    node = table->nodes[[key hash] % table->hashSize];
    for (; node; node = node->next) {
        /* could cache method .. */
        if ([key isEqual:node->key])
            return node->value;
    }
    return nil;
}

static __inline__ void eoRemove(EOGenericRecord *table, id key) {
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
            [(id)node->key   release];
            [(id)node->value release];
            
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

@end /* EOGenericRecord */

@implementation _EOConcreteEOGenericRecordKeyEnumerator

- (id)initWithEO:(EOGenericRecord *)_eo {
  self->dict   = [_eo retain];
  self->node   = NULL;
  self->bucket = -1;
  return self;
}

- (void)dealloc {
  [self->dict release];
  [super dealloc];
}

+ (id)enumWithEO:(EOGenericRecord *)_eo {
  return [[[self alloc] initWithEO:_eo] autorelease];
}

- (id)nextObject
{
    if (self->node)
	self->node = self->node->next;
    
    if (self->node == NULL) {
	for(self->bucket++;
            ((unsigned)self->bucket) < _getHashSize(self->dict);
            self->bucket++) {

            if (_getNodeAt(self->dict, self->bucket)) {
                self->node = _getNodeAt(self->dict, self->bucket);
                break;
	    }
        }
	if (((unsigned)self->bucket) >= _getHashSize(self->dict)) {
	    self->node = NULL;
	    self->bucket = (_getHashSize(self->dict) - 1);
	    return nil;
	}
    }
    return self->node->key;
}

@end /* _EOConcreteEOGenericRecordKeyEnumerator */
