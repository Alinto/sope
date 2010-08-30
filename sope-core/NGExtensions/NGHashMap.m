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

#include "NGHashMap.h"
#include "common.h"

#if !LIB_FOUNDATION_LIBRARY
@interface NSException(SetUI) /* allowed on Jaguar ? */
- (void)setUserInfo:(NSDictionary *)_ui;
@end
#endif

typedef struct _LList {
  struct _LList *next;
  id            object;
  unsigned int  count;
} LList;

static inline void *initLListElement(id _object, LList* _next) {
  LList *element  = malloc(sizeof(LList));
  _object = [_object retain];
  element->object = _object;
  element->next   = _next;
  element->count  = 0;
  return element;
}

static inline void checkForAddErrorMessage(id _self, id _object, id _key) {
  NSException  *exc;
  NSDictionary *ui;
  NSString     *r;
  
  if (_key == nil) {
    r = [[NSString alloc] initWithFormat:
			    @"nil key to be added in HashMap with object %@",
			    (_object != nil ? _object : (id)@"<nil>")];
    ui = [[NSDictionary alloc] initWithObjectsAndKeys:
				 _self,                            @"map",
			         _key ? _key : (id)@"<nil>",       @"key",
			         _object ? _object : (id)@"<nil>", @"object",
			       nil];
    exc = [NSException exceptionWithName:NSInvalidArgumentException
                       reason:r userInfo:ui];
    [r  release]; r  = nil;
    [ui release]; ui = nil;
    [exc raise];
  }
  if (_object == nil) {
    r = [[NSString alloc] initWithFormat:
			    @"nil object to be added in HashMap for key %@",
			    _key ? _key : (id)@"<nil>"];
    ui = [[NSDictionary alloc] initWithObjectsAndKeys:
				 _self,                            @"map",
			         _key ? _key : (id)@"<nil>",       @"key",
			         _object ? _object : (id)@"<nil>", @"object",
			       nil];
    exc = [NSException exceptionWithName:NSInvalidArgumentException
                       reason:r userInfo:ui];
    [r  release]; r  = nil;
    [ui release]; ui = nil;
    [exc raise];
  }
}

static inline void checkForRemoveErrorMessage(id _self, id _object, id _key) {
  NSException  *exc;
  NSDictionary *ui;
  NSString     *r;
  
  if (_object != nil && _key != nil)
    return;
  
  r = [[NSString alloc] initWithFormat:
			  @"nil object to be removed in HashMap for key %@",
			  _key ? _key : (id)@"<nil>"];
  ui = [[NSDictionary alloc] initWithObjectsAndKeys:
			       _self,                            @"map",
			       _key ? _key : (id)@"<nil>",       @"key",
			       _object ? _object : (id)@"<nil>", @"object",
			     nil];
  exc = [NSException exceptionWithName:NSInvalidArgumentException
                     reason:r userInfo:ui];
  [ui release]; ui = nil;
  [r  release]; r  = nil;
  [exc raise];
}

static inline void raiseInvalidArgumentExceptionForNilKey(id _self) {
  NSException *exc = nil;
  exc = [NSException exceptionWithName:NSInvalidArgumentException
                     reason:@"key is nil"
                     userInfo:[NSDictionary dictionaryWithObject:_self forKey:@"map"]];
  [exc raise];
}

@interface _NGHashMapObjectEnumerator : NSEnumerator
{
  NSEnumerator *keys;
  NSEnumerator *elements;
  NGHashMap    *hashMap;
}
- (id)initWithHashMap:(NGHashMap *)_hashMap;
- (id)nextObject;
@end

@interface _NGHashMapObjectForKeyEnumerator : NSEnumerator
{
  LList *element;
  NGHashMap    *map;
}
- (id)initWithHashMap:(NGHashMap *)_hashMap andKey:(id)_key;
- (id)nextObject;
@end

@interface _NGHashMapKeyEnumerator : NSEnumerator
{
  NSMapEnumerator enumerator;
  NGHashMap *map;
}
- (id)initWithHashMap:(NGHashMap *)_hashMap;
- (id)nextObject;
@end

// ************************* NGHashMap *************************

@interface NGHashMap(private)
- (LList *)__structForKey:(id)_key;
- (NSMapEnumerator)__keyEnumerator;
- (void)__removeAllObjectsForKey:(id)_key;
- (void)__removeAllObjects;
@end

static Class NSArrayClass = Nil;

@implementation NGHashMap

+ (void)initialize {
  NSArrayClass = [NSArray class];
}

/* final methods */

static inline void _removeAllObjectsInList(LList *list) {
  while (list) {
    register LList *element;
    
    [list->object release];
    element = list;
    list    = list->next;
    if (element) free(element);
  }
}

static inline LList *__structForKey(NGHashMap *self, id _key) {
  if (_key == nil) raiseInvalidArgumentExceptionForNilKey(self);
#if DEBUG
  NSCAssert(self->table, @"missing table ..");
#endif
  return (LList *)NSMapGet(self->table, (void *)_key);
}

static inline unsigned __countObjectsForKey(NGHashMap *self, id _key) {
  LList *list = NULL;
  return (list = __structForKey(self, _key)) ? list->count : 0;
}

/* methods */

+ (id)hashMap {
  return [[[self alloc] init] autorelease];
}
+ (id)hashMapWithHashMap:(NGHashMap *)_hashMap {
  return [[[self alloc] initWithHashMap:_hashMap] autorelease];
}
+ (id)hashMapWithObjects:(NSArray *)_objects forKey:(id)_key {
  return [[[self alloc] initWithObjects:_objects forKey:_key] autorelease];
}
+ (id)hashMapWithDictionary:(NSDictionary *)_dict {
  return [[[self alloc] initWithDictionary:_dict] autorelease];
}

- (id)init {
  return [self initWithCapacity:0];
}

- (id)initWithCapacity:(NSUInteger)_size {
  if ((self = [super init])) {
    self->table = NSCreateMapTableWithZone(NSObjectMapKeyCallBacks,
                                           NSNonOwnedPointerMapValueCallBacks, 
                                           _size * 4/3 ,NULL);
    NSAssert1(self->table, @"missing table for hashmap of size %d ..", _size);
  }
  return self;
}

- (id)initWithHashMap:(NGHashMap *)_hashMap {
  NSEnumerator *keys    = nil;
  id            key     = nil;
  LList *list    = NULL;
  LList *newList = NULL;
  LList *oldList = NULL;

  if ((self = [self initWithCapacity:[_hashMap count]])) {
    keys  = [_hashMap keyEnumerator];
    while ((key = [keys nextObject])) {
      list           = [_hashMap __structForKey:key];
      newList        = initLListElement(list->object,NULL);
      newList->count = list->count;
      NSMapInsert(self->table,key,newList);
      while (list->next) {
        oldList       = newList;
        list          = list->next;
        newList       = initLListElement(list->object,NULL);
        oldList->next = newList;
      }
    }
  }
  return self;
}

- (id)initWithObjects:(NSArray *)_objects forKey:(id)_key {
  LList *root    = NULL;
  LList *element = NULL;
  LList *pred    = NULL;  
  int           count   = 0;
  int           i       = 0; 

  if (( self = [self initWithCapacity:1])) {
    count = [_objects count];
    if (count == 0) 
      return self;

    root = initLListElement([_objects objectAtIndex:0], NULL);
    pred = root;
    for (i = 1; i < count; i++) {
      element    = initLListElement([_objects objectAtIndex:i], NULL);
      pred->next = element;
      pred       = element;
    }
    root->count = i;
    NSMapInsert(self->table,_key, root);
  }
  NSAssert(self->table, @"missing table for hashmap ..");
  return self;
}

- (id)initWithDictionary:(NSDictionary *)_dictionary {
  if (![self isKindOfClass:[NGMutableHashMap class]]) {
    self = [self autorelease];
    self = [[NGMutableHashMap allocWithZone:[self zone]]
                              initWithCapacity:[_dictionary count]];
  }
  else
    self = [self initWithCapacity:[_dictionary count]];
  
  if (self) {
    NSEnumerator *keys;
    id key;
    
    keys = [_dictionary keyEnumerator];
    while ((key = [keys nextObject])) {
      [(NGMutableHashMap *)self
			   setObject:[_dictionary objectForKey:key] 
			   forKey:key];
    }
  }
  NSAssert(self->table, @"missing table for hashmap ..");
  return self;
}

- (void)dealloc {
  if (self->table) {
    NSMapEnumerator mapenum;
    id key = nil, value = nil;

    mapenum = [self __keyEnumerator];

    while (NSNextMapEnumeratorPair(&mapenum, (void **)&key, (void **)&value))
      _removeAllObjectsInList((LList *)value);

    NSFreeMapTable(self->table);
    self->table = NULL;
  }
  [super dealloc];
}

/* removing */

- (void)__removeAllObjectsForKey:(id)_key {
  _removeAllObjectsInList(__structForKey(self, _key));
  NSMapRemove(self->table, _key);
}

- (void)__removeAllObjects {
  NSEnumerator *keys = nil;
  id           key  = nil;

  keys = [self keyEnumerator];
  while ((key = [keys nextObject]))
    _removeAllObjectsInList(__structForKey(self, key));

  NSResetMapTable(self->table);
}

/* equality */

- (NSUInteger)hash {
  return [self count];
}

- (BOOL)isEqual:(id)anObject {
  if (self == anObject)
    return YES;
  
  if (![anObject isKindOfClass:[NGHashMap class]])
    return NO;
  
  return [self isEqualToHashMap:anObject];
}

- (BOOL)isEqualToHashMap:(NGHashMap *)_other {
  NSEnumerator *keyEnumerator = nil;
  id            key           = nil;
  LList *selfList      = NULL;
  LList *otherList     = NULL;

  if (_other == self) 
    return YES;

  if ([self count] != [_other count])
    return NO;

  keyEnumerator = [self keyEnumerator];
  while ((key = [keyEnumerator nextObject])) {
    if (__countObjectsForKey(self, key) != [_other countObjectsForKey:key])
      return NO;

    selfList  = __structForKey(self, key);
    otherList = [_other __structForKey:key];
    while (selfList) {
      if (![selfList->object isEqual:otherList->object]) 
        return NO;

      selfList = selfList->next;
      otherList = otherList->next;      
    }
  }
  return YES;
}


- (id)objectForKey:(id)_key {
  LList *list;
  
  if (!(list = __structForKey(self, _key))) 
    return nil;

  if (list->next) {
    NSLog(@"WARNING[%s] more than one element for key %@ objects: %@, "
          @"return first object", __PRETTY_FUNCTION__, _key,
          [self objectsForKey:_key]);
  }
  return list->object;
}

- (NSArray *)objectsForKey:(id)_key {
  NSArray         *array      = nil;
  NSEnumerator    *objectEnum = nil;
  id              object      = nil;
  id              *objects    = NULL;
  unsigned int    i           = 0;

  if ((objectEnum = [self objectEnumeratorForKey:_key]) == nil)
    return nil;
  
  objects = calloc(__countObjectsForKey(self, _key) + 1, sizeof(id));
  for (i = 0; (object = [objectEnum nextObject]); i++)
    objects[i] = object;
  
  array = [NSArrayClass arrayWithObjects:objects count:i];
  if (objects) free(objects);
  return array;
}

- (id)objectAtIndex:(NSUInteger)_index forKey:(id)_key {
  LList *list = NULL;
  
  if (!(list = __structForKey(self, _key)))
    return nil;
  
  if ((_index < list->count) == 0) {
    [NSException raise:NSRangeException
                 format:@"index %d out of range for key %@ of length %d",
                   _index, _key, list->count];
    return nil;
  }

  while (_index--)
    list = list->next;

  return list->object;
}

- (NSArray *)allKeys {
  NSArray      *array   = nil;
  NSEnumerator *keys;  
  id           *objects;
  id           object;
  int          i;
  
  objects = calloc([self count] + 1, sizeof(id));
  keys    = [self keyEnumerator];
  for(i = 0; (object = [keys nextObject]); i++)
    objects[i] = object;
  
  array = [[NSArrayClass alloc] initWithObjects:objects count:i];
  if (objects) free (objects);
  return [array autorelease];
}

- (NSArray *)allObjects {
  NSEnumerator   *keys   = nil;
  id             object  = nil;
  NSMutableArray *mArray = nil;
  NSArray        *result = nil;
  
  mArray = [[NSMutableArray alloc] init];
  keys   = [self keyEnumerator];
  while ((object = [keys nextObject])) 
    [mArray addObjectsFromArray:[self objectsForKey:object]];

  result = [mArray copy];
  [mArray release]; mArray = nil;
  return [result autorelease];
}

- (NSUInteger)countObjectsForKey:(id)_key {
  return __countObjectsForKey(self, _key);
}

- (NSEnumerator *)keyEnumerator {
  return [[[_NGHashMapKeyEnumerator alloc] initWithHashMap:self] autorelease];
}

- (NSEnumerator *)objectEnumerator {
  return [[[_NGHashMapObjectEnumerator alloc] 
	    initWithHashMap:self] autorelease];
}

- (NSEnumerator *)objectEnumeratorForKey:(id)_key {
  if (_key == nil)
    raiseInvalidArgumentExceptionForNilKey(self);
  
  return [[[_NGHashMapObjectForKeyEnumerator alloc]
              initWithHashMap:self andKey:_key] autorelease];
}

- (NSDictionary *)asDictionaryWithArraysForValues:(BOOL)arraysOnly {
  NSDictionary  *dict    = nil;
  NSEnumerator  *keys;
  id            key;
  id            *dicObj;
  id            *dicKeys;
  int           cntKey;
  
  keys    = [self keyEnumerator];
  cntKey  = [self count];
  dicObj  = calloc(cntKey + 1, sizeof(id));
  dicKeys = calloc(cntKey + 1, sizeof(id));  
  
  for (cntKey = 0; (key = [keys nextObject]); ) {
    id     object   = nil;    
    LList  *list;
    
    if ((list = __structForKey(self, key)) == NULL) {
      NSLog(@"ERROR(%s): did not find key '%@' in hashmap: %@", 
	    __PRETTY_FUNCTION__, key, self);
      continue;
    }
    
    if (list->next) {
      id   *objects = NULL;
      int  cntObj   = 0;      
      
      objects = calloc(list->count + 1, sizeof(id));
      {
        cntObj  = 0;
        while (list) {
          objects[cntObj++] = list->object;
          list = list->next;
        }
        
		object = [NSArray arrayWithObjects:objects count:cntObj];
      }
      if (objects) free(objects); objects = NULL;
    }
    else {
		if (arraysOnly) {
          object = [NSArray arrayWithObject:list->object ];
		} else {
		  object = list->object;
		}
	}
	
    dicObj[cntKey]    = object;
    dicKeys[cntKey++] = key;
  }
  
  dict = [[NSDictionary alloc]
                        initWithObjects:dicObj forKeys:dicKeys count:cntKey];
  
  if (dicObj)  free(dicObj);  dicObj  = NULL;
  if (dicKeys) free(dicKeys); dicKeys = NULL;
  return [dict autorelease];
}

- (NSDictionary *)asDictionary {
	return [ self asDictionaryWithArraysForValues: NO ];
}

- (NSDictionary *)asDictionaryWithArraysForValues {
	return [ self asDictionaryWithArraysForValues: YES ];
}


- (id)propertyList {
  NSDictionary  *dict    = nil;
  NSEnumerator  *keys    = nil;
  id            key;
  id            *dicObj  = NULL;
  id            *dicKeys = NULL;
  int           cntKey   = 0;

  keys    = [self keyEnumerator];
  cntKey  = [self count];
  dicObj  = calloc(cntKey + 1, sizeof(id));
  dicKeys = calloc(cntKey + 1, sizeof(id));
  
  for (cntKey = 0; (key = [keys nextObject]); ) {
    id            object   = nil;    
    LList  *list    = NULL;
    
    list = __structForKey(self, key);
    if (list->next) {
      id   *objects = NULL;
      int  cntObj   = 0;      
      
      objects = calloc(list->count + 1, sizeof(id));
      {
        cntObj  = 0;
        while (list) {
          objects[cntObj++] = list->object;
          list = list->next;
        }
        object = [NSArrayClass arrayWithObjects:objects count:cntObj];
      }
      if (objects) free(objects); objects = NULL;
    }
    else 
      object = list->object;
    
    dicObj[cntKey]  = object;
    dicKeys[cntKey] = key;
    cntKey++;
  }
  dict = [[[NSDictionary alloc] initWithObjects:dicObj forKeys:dicKeys
                                count:cntKey] autorelease];
  if (dicObj)  free(dicObj);  dicObj  = NULL;
  if (dicKeys) free(dicKeys); dicKeys = NULL;
  return dict;
}

/* description */

- (NSString *)description {
  return [[self propertyList] description];
}

- (NSUInteger)count {
  return self->table ? NSCountMapTable(table) : 0;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[NGHashMap allocWithZone:_zone] initWithHashMap:self];    
}

- (id)mutableCopyWithZone:(NSZone *)_zone {
  return [[NGMutableHashMap allocWithZone:_zone] initWithHashMap:self];  
}

/* */

- (NSMapEnumerator)__keyEnumerator {
  return NSEnumerateMapTable(table);
}

- (LList *)__structForKey:(id)_key {
  return __structForKey(self, _key);
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_encoder {
  unsigned        keyCount = [self count];
  NSMapEnumerator mapenum  = [self __keyEnumerator];
  id              key      = nil;
  LList           *value   = NULL;
  
  [_encoder encodeValueOfObjCType:@encode(unsigned) at:&keyCount];

  while (NSNextMapEnumeratorPair(&mapenum, (void **)&key, (void **)&value)) {
    unsigned valueCount = value ? value->count : 0;
    unsigned outCount   = 0; // debugging

    [_encoder encodeObject:key];
    [_encoder encodeValueOfObjCType:@encode(unsigned) at:&valueCount];

    while (value) {
      [_encoder encodeObject:value->object];
      value = value->next;
      outCount++;
    }

    NSAssert(valueCount == outCount, @"didn't encode enough value objects");
  }
}

- (id)initWithCoder:(NSCoder *)_decoder {
  NGMutableHashMap *map = [[NGMutableHashMap alloc] init];
  unsigned keyCount;
  unsigned cnt;

  [_decoder decodeValueOfObjCType:@encode(unsigned) at:&keyCount];
  for (cnt = 0; cnt < keyCount; cnt++) {
    unsigned valueCount = 0, cnt2 = 0;
    id       key        = nil;

    key = [_decoder decodeObject];
    [_decoder decodeValueOfObjCType:@encode(unsigned) at:&valueCount];

    for (cnt2 = 0; cnt2 < valueCount; cnt2++) {
      id value = [_decoder decodeObject];
      [map addObject:value forKey:key];
    }
  }

  self = [self initWithHashMap:map];
  [map release]; map = nil;

  return self;
}

@end /* NGHashMap */

// ************************* NGMutableHashMap ******************

@implementation NGMutableHashMap

+ (id)hashMapWithCapacity:(NSUInteger)_numItems {
  return [[[self alloc] initWithCapacity:_numItems] autorelease];
}

- (id)init {
  return [self initWithCapacity:0];
}

/* inserting objects */

- (void)insertObject:(id)_object atIndex:(NSUInteger)_index forKey:(id)_key {
  [self insertObjects:&_object count:1 atIndex:_index forKey:_key];
}

- (void)insertObjects:(NSArray *)_objects atIndex:(NSUInteger)_index
  forKey:(id)_key 
{
  id  *objects = NULL;
  int i        = 0;
  int cntI     = 0;
  
  cntI    = [_objects count];
  objects = calloc(cntI + 1, sizeof(id));
  for (i = 0 ; i < cntI; i++) 
    objects[i] = [_objects objectAtIndex:i];

  [self insertObjects:objects count:cntI atIndex:_index forKey:_key];
  if (objects) free(objects);
}

- (void)insertObjects:(id*)_objects count:(NSUInteger)_count
  atIndex:(NSUInteger)_index forKey:(id)_key 
{
  id            object  = nil;
  LList *root    = NULL;
  LList *element = NULL;
  unsigned i = 0;
  
  if (_count == 0)
    return;

  checkForAddErrorMessage(self, _objects[0],_key);
  if ((root = [self __structForKey:_key]) == NULL) {
    if (_index > 0) {
      [NSException raise:NSRangeException
                   format:@"index %d out of range in map 0x%p", 
                    _index, self];
      return;
    }

    root        = initLListElement(_objects[0], NULL);
    root->count = _count;
    NSMapInsert(self->table, _key, root);
  }
  else {
    if (!(_index < root->count)) {
      [NSException raise:NSRangeException
                   format:@"index %d out of range in map 0x%p length %d", 
                    _index, self, root->count];
      return;
    }
    
    root->count += _count;
    if (_index == 0) {
      element         = initLListElement(_objects[0],NULL);
      object          = element->object;
      element->next   = root->next;
      element->object = root->object;      
      root->object    = object;
      root->next      = element;
    }
    else {
      while (--_index)
        root = root->next;

      element       = initLListElement(_objects[0], NULL);
      element->next = root->next;
      root->next    = element;
      root          = root->next;
    }
  }
  for (i = 1; i < _count; i++) {
    checkForAddErrorMessage(self, _objects[i], _key);
    element       = initLListElement(_objects[i], NULL);
    element->next = root->next;
    root->next    = element;
    root          = element;
  }
}

/* adding objects */

- (void)addObjects:(id*)_objects count:(NSUInteger)_count forKey:(id)_key {
  LList *root     = NULL;
  LList *element  = NULL;
  unsigned i      = 0;

  if (_count == 0)
    return;

  checkForAddErrorMessage(self, _objects[0],_key);
  if ((root = [self __structForKey:_key]) == NULL) {
    root        = initLListElement(_objects[0], NULL);
    root->count = _count;
    NSMapInsert(self->table, _key, root);
  }
  else {
    root->count += _count;
    while (root->next)
      root = root->next;
    
    element    = initLListElement(_objects[0], NULL);
    root->next = element;
    root       = root->next;
  }
  for (i = 1; i < _count; i++) {
    checkForAddErrorMessage(self, _objects[i], _key);
    element    = initLListElement(_objects[i], NULL);
    root->next = element;
    root       = element;
  }
}

- (void)addObject:(id)_object forKey:(id)_key {
  checkForAddErrorMessage(self, _object,_key);
  [self addObjects:&_object count:1 forKey:_key];  
}

- (void)addObjects:(NSArray *)_objects forKey:(id)_key {
  id  *objects = NULL;
  int i        = 0;
  int cntI     = 0;
  
  cntI    = [_objects count];
  objects = calloc(cntI + 1, sizeof(id));
  for (i = 0 ; i < cntI; i++) 
    objects[i] = [_objects objectAtIndex:i];

  [self addObjects:objects count:cntI forKey:_key];
  if (objects) free(objects);
}

/* setting objects */

- (void)setObject:(id)_object forKey:(id)_key {
  checkForAddErrorMessage(self, _object, _key);
  [self removeAllObjectsForKey:_key];
  [self addObjects:&_object count:1 forKey:_key];
}

- (void)setObjects:(NSArray *)_objects forKey:(id)_key {
  checkForAddErrorMessage(self, _objects, _key);  
  [self removeAllObjectsForKey:_key];
  [self addObjects:_objects forKey:_key];
}

/* removing objects */

- (void)removeAllObjects {
  [self __removeAllObjects];
}

- (void)removeAllObjectsForKey:(id)_key {
  [self __removeAllObjectsForKey:_key];
}

- (void)removeAllObjects:(id)_object forKey:(id)_key {
  LList  *list    = NULL;
  LList  *root    = NULL;
  LList  *oldList = NULL;  
  unsigned int  cnt      = 0;

  checkForRemoveErrorMessage(self, _object, _key);
  if (!(root = [self __structForKey:_key])) 
    return;

  while ([root->object isEqual:_object]) {
    [root->object release];
    if (root->next == NULL) {
      if (root) free(root);
      root = NULL;
      NSMapRemove(self->table,_key);
      break;
    }
    else {
      list         = root->next;
      root->next   = list->next;
      root->object = list->object;
      root->count--;
      if (list) free(list);
      list = NULL;
    }
  }
  if (root) {
    list = root;
    while (list->next) {
      oldList = list;    
      list    = list->next;
      if ([list->object isEqual:_object]) {
        cnt++;
        oldList->next = list->next;
        if (list) free(list);
        list = oldList;
      }
    }
    root->count -= cnt;
  }
}

- (void)removeAllObjectsForKeys:(NSArray *)_keyArray {
  register int index  = 0;
  for (index = [_keyArray count]; index > 0;)
    [self removeAllObjectsForKey:[_keyArray objectAtIndex:--index]];
}

@end /* NGMutableHashMap */

// ************************* Enumerators ******************

@implementation _NGHashMapKeyEnumerator

- (id)initWithHashMap:(NGHashMap *)_hashMap {
  self->map        = [_hashMap retain];
  self->enumerator = [_hashMap __keyEnumerator];
  return self;
}
- (void)dealloc {
  [self->map release];
  [super dealloc];
}

- (id)nextObject {
  id key, value;
  return NSNextMapEnumeratorPair(&self->enumerator,(void**)&key, (void**)&value) ?
         key : nil;
}

@end /* _NGHashMapKeyEnumerator */

@implementation _NGHashMapObjectEnumerator

- (id)initWithHashMap:(NGHashMap *)_hashMap {
  self->keys     = [[_hashMap keyEnumerator] retain];
  self->hashMap  = [_hashMap retain];
  self->elements = nil;
  return self;
}

- (void)dealloc {
  [self->keys     release];
  [self->hashMap  release];
  [self->elements release];
  [super dealloc];
}

- (id)nextObject {
  id object;
  id key;
  
  if ((object = [self->elements nextObject]))
    return object;
  
  if ((key = [self->keys nextObject])) {
    ASSIGN(self->elements, [self->hashMap objectEnumeratorForKey:key]);
    object = [self->elements nextObject];
  }
  return object;
}

@end /* _NGHashMapObjectEnumerator */

@implementation _NGHashMapObjectForKeyEnumerator

- (id)initWithHashMap:(NGHashMap *)_hashMap andKey:(id)_key {
  element = [_hashMap __structForKey:_key];
  self->map = [_hashMap retain];
  return self;
}
- (void)dealloc {
  [self->map release];
  [super dealloc];
}

- (id)nextObject {
  id object;
  
  if (element == NULL) 
    return nil;
  
  object  = element->object;
  element = element->next;
  return object;
}

@end /* _NGHashMapObjectForKeyEnumerator */
