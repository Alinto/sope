/* 
   EOObjectUniquer.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#import "common.h"
#import "EOEntity.h"
#import "EOObjectUniquer.h"
#import "EOPrimaryKeyDictionary.h"
#import "EODatabaseFault.h"
#import "EOGenericRecord.h"

static unsigned uniquerHash(NSMapTable* table, EOUniquerRecord* rec) {
  // efficient hash for dictionaries is done in the concrete
  // dictionaries implementation; dictionaries are allocated
  // from EOPrimaryKeyDictionary concrete subclasses
  return  ((unsigned long)(rec->entity) >> 4L) +
          ((EOPrimaryKeyDictionary*)(rec->pkey))->fastHash;
}

static BOOL uniquerCompare(NSMapTable *table, EOUniquerRecord *rec1,
                           EOUniquerRecord *rec2) {
  // efficient compare between dictionaries is done in the concrete
  // dictionaries implementation; dictionaries are allocated
  // from EOPrimaryKeyDictionary concrete subclasses
  return (rec1->entity == rec2->entity) &&  [rec1->pkey fastIsEqual:rec2->pkey];
}

static NSString* uniqDescription(NSMapTable *t, EOUniquerRecord* rec) {
  return [NSString stringWithFormat:
                     @"<<pkey:%08x entity:%08x object:%08x snapshot:%08x>>",
                     rec->pkey, rec->entity, rec->object, rec->snapshot];
}

static void uniquerRetain(NSMapTable *table, EOUniquerRecord* rec) {
  rec->refCount++;
}

static void uniquerRelease(NSMapTable *table, EOUniquerRecord *rec) {
  rec->refCount--;
  
  if (rec->refCount <= 0) {
    RELEASE(rec->pkey);     rec->pkey     = NULL;
    RELEASE(rec->entity);   rec->entity   = NULL;
    RELEASE(rec->snapshot); rec->snapshot = NULL;
    Free(rec); rec = NULL;
  }
}

static inline EOUniquerRecord *uniquerCreate(id pkey, id entity, id object,
                                             id snapshot) {
  EOUniquerRecord *rec = NULL;
  
  rec = (EOUniquerRecord *)Malloc(sizeof(EOUniquerRecord));
  rec->refCount = 0;
  rec->pkey     = RETAIN(pkey);
  rec->entity   = RETAIN(entity);
  rec->object   = object;
  rec->snapshot = RETAIN(snapshot);
    
  return rec;
}

static void uniquerNoAction(NSMapTable * t, const void *_object) {
}

static NSMapTableKeyCallBacks uniquerKeyMapCallbacks = {
    (NSUInteger(*)(NSMapTable *, const void *))uniquerHash,
    (BOOL(*)(NSMapTable *, const void *, const void *))uniquerCompare,
    (void (*)(NSMapTable *, const void *))uniquerNoAction,
    (void (*)(NSMapTable *, void *))uniquerNoAction,
    (NSString *(*)(NSMapTable *, const void *))uniqDescription,
    (const void *)NULL
};

static NSMapTableValueCallBacks uniquerValueMapCallbacks = {
    (void (*)(NSMapTable *, const void *))uniquerRetain,
    (void (*)(NSMapTable *, void *))uniquerRelease,
    (NSString *(*)(NSMapTable *, const void *))uniqDescription
}; 

static int initialHashSize = 1021;

@implementation EOObjectUniquer

static NSMutableArray  *uniquerExtent = nil;
static NSRecursiveLock *lock          = nil;

+ (void)initialize {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;

    uniquerExtent = [[NSMutableArray alloc] initWithCapacity:16];
    // THREAD: lock = [[NSRecursiveLock alloc] init];
  }
}

static inline void _addUniquerInstance(EOObjectUniquer *_uniquer) {
  [lock lock];
  [uniquerExtent addObject:[NSValue valueWithNonretainedObject:_uniquer]];
  [lock unlock];
}
static inline void _removeUniquerInstance(EOObjectUniquer *_uniquer) {
  [lock lock];
  {
    int i;
    
    for (i = [uniquerExtent count] - 1; i >= 0; i--) {
      EOObjectUniquer *uniquer;

      uniquer = [[uniquerExtent objectAtIndex:i] nonretainedObjectValue];
      if (uniquer == _uniquer) {
        [uniquerExtent removeObjectAtIndex:i];
        break;
      }
    }
  }
  [lock unlock];
}

// Initializing a uniquing dictionary

- (id)init {
  self->primaryKeyToRec = NSCreateMapTable(uniquerKeyMapCallbacks, 
                                           uniquerValueMapCallbacks,
                                           initialHashSize);
#if LIB_FOUNDATION_LIBRARY
  self->objectsToRec    = NSCreateMapTableInvisibleKeysOrValues
                            (NSNonOwnedPointerMapKeyCallBacks, 
                             uniquerValueMapCallbacks, initialHashSize,
                             YES, NO);
#else
  self->objectsToRec = NSCreateMapTable
                            (NSNonOwnedPointerMapKeyCallBacks, 
                             uniquerValueMapCallbacks, initialHashSize);
#endif
  self->keyRecord = uniquerCreate(nil, nil, nil, nil);

  _addUniquerInstance(self);

  return self;
}

- (void)dealloc {
    [self forgetAllObjects];
    _removeUniquerInstance(self);
    
    NSFreeMapTable(self->objectsToRec);
    NSFreeMapTable(self->primaryKeyToRec);
    if (self->keyRecord) {
      Free(self->keyRecord);
      self->keyRecord = NULL;
    }
    [super dealloc];
}

// Transfer self to parent

- (void)transferTo:(EOObjectUniquer *)_dest
  objects:(BOOL)isKey andSnapshots:(BOOL)isSnap
{
  EOUniquerRecord *key = NULL;
  EOUniquerRecord *rec = NULL;
  NSMapEnumerator enumerator = NSEnumerateMapTable(primaryKeyToRec);
    
  while(NSNextMapEnumeratorPair(&enumerator, (void**)(&key), (void**)(&rec))) {
    [_dest recordObject:rec->object
           primaryKey:  isKey  ? rec->pkey     : nil
           entity:      isKey  ? rec->entity   : nil
           snapshot:    isSnap ? rec->snapshot : nil];
  }
  [self forgetAllObjects];
}

// Handling objects

- (void)forgetObject:(id)_object {
  EOUniquerRecord *rec = NULL;
    
  if (_object == nil)
    return;
  
  rec = (EOUniquerRecord *)NSMapGet(self->objectsToRec, _object);
  
  if (rec == NULL)
    return;
  
  /*
  NSLog(@"Uniquer[0x%p]: forget object 0x%p<%s> entity=%@",
        self, _object, class_get_class_name(*(Class *)_object),
        [[_object entity] name]);
  */
  
  if (rec->pkey)
    NSMapRemove(self->primaryKeyToRec, rec);
  NSMapRemove(self->objectsToRec, _object);
}

- (void)forgetAllObjects {
  NSResetMapTable(self->primaryKeyToRec);
  NSResetMapTable(self->objectsToRec);
}

- (void)forgetAllSnapshots {
  NSMapEnumerator enumerator;
  EOUniquerRecord *rec       = NULL;
  id              key        = nil;
  
  NSLog(@"uniquer 0x%p forgetAllSnapshots ..", self);
  
  enumerator = NSEnumerateMapTable(self->objectsToRec);
  while (NSNextMapEnumeratorPair(&enumerator, (void**)(&key), (void**)(&rec))) {
    RELEASE(rec->snapshot);
    rec->snapshot = nil;
  }
}

- (id)objectForPrimaryKey:(NSDictionary *)_key entity:(EOEntity *)_entity {
  EOUniquerRecord *rec;
    
  if (_key == nil || _entity == nil)
    return nil;
  
  if (![_key isKindOfClass:[EOPrimaryKeyDictionary class]]) {
    [NSException raise:NSInvalidArgumentException
		 format:
		   @"attempt to record object with non "
              @" EOPrimaryKeyDictionary class in EOObjectUniquer."
              @"This is a bug in EODatabase/Context/Channel."];
  }

  keyRecord->pkey   = _key;
  keyRecord->entity = _entity;
    
  rec = (EOUniquerRecord*)NSMapGet(primaryKeyToRec, keyRecord);
    
  return rec ? rec->object : nil;
}

- (EOUniquerRecord *)recordForObject:(id)_object {
    return (_object == nil)
      ? (EOUniquerRecord *)NULL
      : (EOUniquerRecord *)NSMapGet(self->objectsToRec, _object);
}

- (void)recordObject:(id)_object
  primaryKey:(NSDictionary *)_key
  entity:(EOEntity *)_entity
  snapshot:(NSDictionary *)_snapshot
{
    EOUniquerRecord *rec = NULL;
    EOUniquerRecord *orc = NULL;
    
    if (_object == nil)
      return;

    if ((_key == nil) || (_entity == nil)) {
        _key    = nil;
        _entity = nil;
    }
    
    if ((_key == nil) && (_snapshot == nil))
        return;
    
    if (_key && ![_key isKindOfClass:[EOPrimaryKeyDictionary class]]) {
      [NSException raise:NSInvalidArgumentException
		   format:
		     @"attempt to record object with non "
  		     @" EOPrimaryKeyDictionary class in EOObjectUniquer."
		     @"This is a bug in EODatabase/Context/Channel."];
    }

    keyRecord->pkey   = _key;
    keyRecord->entity = _entity;
    
    rec = (EOUniquerRecord*)NSMapGet(objectsToRec, _object);
    if (rec) {
        if (_key && uniquerCompare(NULL, rec, keyRecord)) {
            ASSIGN(rec->snapshot, _snapshot);
            return;
        }
        if (_key) {
            orc = (EOUniquerRecord*)NSMapGet(primaryKeyToRec, keyRecord);
            if (orc && orc != rec) {
                if (orc->pkey)
                    NSMapRemove(primaryKeyToRec, orc);

                NSMapRemove(objectsToRec, orc->object);
            }
            NSMapRemove(primaryKeyToRec, rec);
        }
        ASSIGN(rec->pkey, _key);
        ASSIGN(rec->entity, _entity);
        ASSIGN(rec->snapshot, _snapshot);

        if (_key)
            NSMapInsertKnownAbsent(primaryKeyToRec, rec, rec);
        return;
    }

    if (_key)
        rec = (EOUniquerRecord*)NSMapGet(primaryKeyToRec, keyRecord);
    if (rec) {
        if (rec->object == _object) {
            ASSIGN(rec->snapshot, _snapshot);
            return;
        }

        NSMapRemove(objectsToRec, rec->object);

        ASSIGN(rec->snapshot, _snapshot);
        rec->object = _object;
        NSMapInsertKnownAbsent(objectsToRec, _object, rec);
        return;
    }
    
    rec = uniquerCreate(_key, _entity, _object, _snapshot);
    if (_key)
        NSMapInsertKnownAbsent(primaryKeyToRec, rec, rec);
    NSMapInsertKnownAbsent(objectsToRec, _object, rec);
}


/* This method is called by the Boehm's garbage collector when an object
   is finalized */
- (void)_objectWillFinalize:(id)_object {
  //    printf ("_objectWillFinalize: %p (%s)\n",
  //            _object, class_get_class_name ([_object class]));
  [self forgetObject:_object];
}

+ (void)forgetObject:(id)_object {
  [lock lock];
  {
    int i;
    
    for (i = [uniquerExtent count] - 1; i >= 0; i--) {
      EOObjectUniquer *uniquer;

      uniquer = [[uniquerExtent objectAtIndex:i] nonretainedObjectValue];
      [uniquer forgetObject:_object];
    }
  }
  [lock unlock];
}

@end /* EOObjectUniquer */
