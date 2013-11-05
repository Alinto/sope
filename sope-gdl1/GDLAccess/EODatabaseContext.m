/* 
   EODatabaseContext.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
   Date: 1996
   
   Author: Helge Hess <helge.hess@mdlink.de>
   Date: 1999
   
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
#import "EODatabaseContext.h"
#import "EOAdaptor.h"
#import "EOAdaptorContext.h"
#import "EODatabase.h"
#import "EODatabaseChannel.h"
#import "EOEntity.h"
#import "EODatabaseFault.h"
#import "EOGenericRecord.h"
#import "EOModel.h"
#import "EOObjectUniquer.h"
#include "EOModelGroup.h"
#include <EOControl/EOFetchSpecification.h>
#include <EOControl/EOKeyGlobalID.h>

NSString *EODatabaseContextWillBeginTransactionName =
  @"EODatabaseContextWillBeginTransaction";
NSString *EODatabaseContextDidBeginTransactionName =
  @"EODatabaseContextDidBeginTransaction";
NSString *EODatabaseContextWillRollbackTransactionName =
  @"EODatabaseContextWillRollbackTransaction";
NSString *EODatabaseContextDidRollbackTransactionName =
  @"EODatabaseContextDidRollbackTransaction";
NSString *EODatabaseContextWillCommitTransactionName =
  @"EODatabaseContextWillCommitTransaction";
NSString *EODatabaseContextDidCommitTransactionName =
  @"EODatabaseContextDidCommitTransaction";

struct EODatabaseContextModificationQueue {
  struct EODatabaseContextModificationQueue *next;
  enum {
    update,
    delete,
    insert
  } op;
  id object;
};

/*
 * Transaction scope
 */

typedef struct _EOTransactionScope {
  struct _EOTransactionScope *previous;
  EOObjectUniquer            *objectsDictionary;
  NSMutableArray             *objectsUpdated;
  NSMutableArray             *objectsDeleted;
  NSMutableArray             *objectsLocked;
} EOTransactionScope;

static inline EOTransactionScope *_newTxScope(NSZone *_zone) {
  EOTransactionScope *newScope;

  newScope = NSZoneMalloc(_zone, sizeof(EOTransactionScope));
  newScope->objectsDictionary = [[EOObjectUniquer   allocWithZone:_zone] init];
  newScope->objectsUpdated    = [[NSMutableArray    allocWithZone:_zone] init];
  newScope->objectsDeleted    = [[NSMutableArray    allocWithZone:_zone] init];
  newScope->objectsLocked     = [[NSMutableArray    allocWithZone:_zone] init];

  return newScope;
}
static inline void _freeTxScope(NSZone *_zone, EOTransactionScope *_txScope) {
  RELEASE(_txScope->objectsDictionary); _txScope->objectsDictionary = nil;
  RELEASE(_txScope->objectsUpdated);    _txScope->objectsUpdated    = nil;
  RELEASE(_txScope->objectsDeleted);    _txScope->objectsDeleted    = nil;
  RELEASE(_txScope->objectsLocked);     _txScope->objectsLocked     = nil;
  NSZoneFree(_zone, _txScope); _txScope = NULL;
}

@implementation EODatabaseContext

#if 0 // no such callback!
+ (void)initialize {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;
    [[NSNotificationCenter defaultCenter]
                           addObserver:self
                           selector:@selector(_objectStoreNeeded:)
                           name:@"EOCooperatingObjectStoreNeeded"
                           object:nil];
  }
}
#endif

static inline void _checkTxInProgress(EODatabaseContext *self,
                                      const char *_function)
{
  if (self->transactionNestingLevel == 0) {
    [NSException raise:NSInternalInconsistencyException
		 format:
              @"EODatabaseContext:%x: No transaction in progress "
              @"in %s", self, _function];
  }
}

// init

- (id)initWithDatabase:(EODatabase *)aDatabase {
  static int reuseAdaptorCtx = -1;
  if (reuseAdaptorCtx == -1) {
    reuseAdaptorCtx = [[[NSUserDefaults standardUserDefaults]
                                        objectForKey:@"EOReuseAdaptorContext"]
                                        boolValue] ? 1 : 0;
  }
  if (reuseAdaptorCtx) {
    NSEnumerator     *contexts;
    EOAdaptorContext *actx;
    
    contexts = [[[aDatabase adaptor] contexts] objectEnumerator];
    while ((actx = [contexts nextObject])) {
      if (![actx hasOpenTransaction]) {
#if DEBUG
        NSLog(@"reuse adaptor context: %@", actx);
#endif
        self->adaptorContext = actx;
        break;
      }
    }
    if (self->adaptorContext == nil)
      self->adaptorContext = [[aDatabase adaptor] createAdaptorContext];
  }
  else
    self->adaptorContext = [[aDatabase adaptor] createAdaptorContext];
  
  if ((aDatabase == nil) || (adaptorContext == nil)) {
    NSLog(@"EODatabaseContext could not create adaptor context");
    AUTORELEASE(self);
    return nil;
  }
  RETAIN(self->adaptorContext);
  
  self->database                = RETAIN(aDatabase);
  self->channels                = [[NSMutableArray allocWithZone:[self zone]] init];
  self->transactionStackTop     = NULL;
  self->transactionNestingLevel = 0;
  self->updateStrategy          = EOUpdateWithOptimisticLocking;
  self->isKeepingSnapshots      = YES;
  self->isUniquingObjects       = [self->database uniquesObjects];
  
  [database contextDidInit:self];
  return self;
}

- (void)dealloc {
  [database contextWillDealloc:self];

  if (self->ops) {
    struct EODatabaseContextModificationQueue *q;

    while ((q = self->ops)) {
      self->ops = q->next;
      RELEASE(q->object);
      free(q);
    }
  }
  
  while (self->transactionNestingLevel) {
    if (![self rollbackTransaction])
      break;
  }
  while (self->transactionStackTop)
    [self privateRollbackTransaction];

  RELEASE(self->adaptorContext); self->adaptorContext = nil;
  RELEASE(self->database);       self->database       = nil;
  RELEASE(self->channels);       self->channels       = nil;
  [super dealloc];
}

/* accessors */

- (void)setDelegate:(id)_delegate {
  self->delegate = _delegate;
}
- (id)delegate {
  return self->delegate;
}

- (EODatabase *)database {
  return self->database;
}

- (EOAdaptorContext *)adaptorContext {
  return self->adaptorContext;
}

// channels

- (BOOL)hasBusyChannels {
  int i;
    
  for (i = [channels count]-1; i >= 0; i--) {
    if ([[[channels objectAtIndex:i] nonretainedObjectValue]
                    isFetchInProgress])
      return YES;
  }
  return NO;
}

- (BOOL)hasOpenChannels {
  int i;
    
  for (i = [channels count]-1; i >= 0; i--) {
    if ([[[channels objectAtIndex:i] nonretainedObjectValue] isOpen])
      return YES;
  }
  return NO;
}

- (NSArray *)channels {
  return [self registeredChannels];
}

- (id)createChannel {
  return AUTORELEASE([[EODatabaseChannel alloc] initWithDatabaseContext:self]);
}

- (void)channelDidInit:(id)aChannel {
  [self registerChannel:aChannel];
}

- (void)channelWillDealloc:(id)aChannel {
  [self unregisterChannel:aChannel];
}

/*
 * Controlling transactions
 */

- (BOOL)beginTransaction {
  NSNotificationCenter *nc;
  
  if ([adaptorContext transactionNestingLevel] != 
      (unsigned)transactionNestingLevel) {
    [NSException raise:NSInternalInconsistencyException
		 format:
              @"EODatabaseContext:%x:transaction nesting levels do not match: "
              @"database has %d, adaptor has %d, "
              @"in [EODatabaseContext beginTransaction]",
              self, transactionNestingLevel, 
              [adaptorContext transactionNestingLevel]];
  }

  nc = [NSNotificationCenter defaultCenter];

  [nc postNotificationName:EODatabaseContextWillBeginTransactionName
      object:self];
  
  if (![self->adaptorContext beginTransaction])
    return NO;
  [self privateBeginTransaction];

  txBeginCount++;
  [nc postNotificationName:EODatabaseContextDidBeginTransactionName
      object:self];
  return YES;
}

- (BOOL)commitTransaction {
  NSNotificationCenter *nc;
  
  _checkTxInProgress(self, __PRETTY_FUNCTION__);

  if ([adaptorContext transactionNestingLevel] !=
      (unsigned)self->transactionNestingLevel) {
    [NSException raise:NSInternalInconsistencyException
		 format:
              @"EODatabaseContext:%x:transaction nesting levels do not match: "
              @"database has %d, adaptor has %d, "
              @"in [EODatabaseContext commitTransaction]",
              self, transactionNestingLevel, 
              [adaptorContext transactionNestingLevel]];
  }

  nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:EODatabaseContextWillCommitTransactionName
      object:self];
  
  if (![adaptorContext commitTransaction])
    return NO;
  [self privateCommitTransaction];
  
  self->txCommitCount++;
  [nc postNotificationName:EODatabaseContextDidCommitTransactionName
      object:self];
  return YES;
}

- (BOOL)rollbackTransaction {
  NSNotificationCenter *nc;
  
  _checkTxInProgress(self, __PRETTY_FUNCTION__);

  if ([self->adaptorContext transactionNestingLevel] !=
      (unsigned)self->transactionNestingLevel) {
    [NSException raise:NSInternalInconsistencyException
		 format:
              @"EODatabaseContext:%x:transaction nesting levels do not match: "
              @"database has %d, adaptor has %d, "
              @"in [EODatabaseContext rollbackTransaction]",
              self, transactionNestingLevel, 
              [adaptorContext transactionNestingLevel]];
  }

  nc = [NSNotificationCenter defaultCenter];
  [nc postNotificationName:EODatabaseContextWillRollbackTransactionName
      object:self];
  
  if (![self->adaptorContext rollbackTransaction])
    return NO;
  [self privateRollbackTransaction];
  
  self->txRollbackCount++;
  [nc postNotificationName:EODatabaseContextDidRollbackTransactionName
      object:self];
  return YES;
}


// ******************** notifications ********************

- (void)transactionDidBegin {
  [self->adaptorContext transactionDidBegin];
  [self privateBeginTransaction];
}

- (void)transactionDidCommit {
  _checkTxInProgress(self, __PRETTY_FUNCTION__);
  [self->adaptorContext transactionDidCommit];
  [self privateCommitTransaction];
}

- (void)transactionDidRollback {
  _checkTxInProgress(self, __PRETTY_FUNCTION__);
  [adaptorContext transactionDidRollback];
  [self privateRollbackTransaction];
}

/*
 * Nesting transactions
 */

- (BOOL)canNestTransactions {
  return [adaptorContext canNestTransactions];
}
- (unsigned)transactionNestingLevel {
  return transactionNestingLevel;
}

/*
 * Setting the update strategy
 */

- (void)setUpdateStrategy:(EOUpdateStrategy)aStrategy {
  if ([self transactionNestingLevel]) {
    [NSException raise:NSInvalidArgumentException
		 format:
        @"EODatabaseContext:%x: Cannot change update strategy "
        @"when context has a transaction open, "
        @"in [EODatabaseContext setUpdateStrategy]",
        self];
  }
  updateStrategy     = aStrategy;
  isKeepingSnapshots = (updateStrategy == EOUpdateWithNoLocking) ? NO : YES;
  isUniquingObjects  = [database uniquesObjects];
}

- (EOUpdateStrategy)updateStrategy {
  return self->updateStrategy;
}

- (BOOL)keepsSnapshots {
  return self->isKeepingSnapshots;
}

/*
 * Processing transactions internally
 */

- (void)privateBeginTransaction {
  EOTransactionScope *newScope = NULL;

  newScope = _newTxScope([self zone]);
  newScope->previous  = transactionNestingLevel ? transactionStackTop : NULL;
  transactionStackTop = newScope;
  transactionNestingLevel++;
    
  if (transactionNestingLevel == 1)
    self->isUniquingObjects = [database uniquesObjects];
}

- (void)privateCommitTransaction {
  EOTransactionScope *newScope = transactionStackTop;
  
  transactionStackTop = newScope->previous;
  transactionNestingLevel--;
    
  // In nested transaction fold updated and deleted objects 
  // into the parent transaction; locked objects are forgotten
  // deleted objects are deleted form the parent transaction
  if (transactionNestingLevel) {
    // Keep updated objects
    [transactionStackTop->objectsUpdated 
                        addObjectsFromArray:newScope->objectsUpdated];
    // Keep deleted objects
    [transactionStackTop->objectsDeleted 
                        addObjectsFromArray:newScope->objectsDeleted];
    // Register objects in parent transaction scope
    [newScope->objectsDictionary 
             transferTo:transactionStackTop->objectsDictionary 
             objects:YES andSnapshots:YES];
  }
  // If this was the first transaction then fold the changes 
  // into the database; locked and updateted objects are forgotten
  else {
    int i, n;
        
    for (i = 0, n = [newScope->objectsDeleted count]; i < n; i++)
      [database forgetObject:[newScope->objectsDeleted objectAtIndex:i]];
    
    // Register objects into the database
    if (self->isUniquingObjects || [database keepsSnapshots]) {
      [newScope->objectsDictionary transferTo:[database objectUniquer]
                                   objects:self->isUniquingObjects
                                   andSnapshots:[database keepsSnapshots]];
    }
  }

  // Kill transaction scope
  _freeTxScope([self zone], newScope);
}

- (void)privateRollbackTransaction {
  EOTransactionScope *newScope = transactionStackTop;
  
  transactionStackTop = newScope->previous;
  transactionNestingLevel--;
    
  // Forget snapshots, updated, deleted and locked objects
  // in current transaction
    
  // Kill transaction scope
  _freeTxScope([self zone], newScope);
}

// Handle Objects

- (void)forgetObject:(id)_object {
  EOTransactionScope *scope = NULL;

  _checkTxInProgress(self, __PRETTY_FUNCTION__);

  if (_object == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabaseContext:%x: Cannot forget null object, "
              @"in [EODatabaseContext forgetObject]",
              self];
  }
  if ([EOFault isFault:_object]) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabaseContext:%x: Cannot forget forget a fault object, "
              @"in [EODatabaseContext forgetObject]",
              self];
  }
    
  [transactionStackTop->objectsDeleted addObject:_object];

  for (scope = transactionStackTop; scope; scope = scope->previous) {
    [scope->objectsDictionary forgetObject:_object];
  }
}

- (id)objectForPrimaryKey:(NSDictionary *)_key entity:(EOEntity *)_entity {
  EOTransactionScope *scope  = NULL;
  id                 _object = nil;
    
  if (!self->isUniquingObjects || (_key == nil) || (_entity == nil))
    return nil;
    
  _key = [_entity primaryKeyForRow:_key];
  if (_key == nil) return nil;
    
  for (scope = transactionStackTop; scope; scope = scope->previous) {
    _object = [scope->objectsDictionary objectForPrimaryKey:_key 
                                        entity:_entity];
    if (_object)
      return _object;
  }
    
  return [self->database objectForPrimaryKey:_key entity:_entity];
}

- (void)recordObject:(id)_object
  primaryKey:(NSDictionary *)_key 
  entity:(EOEntity *)_entity
  snapshot:(NSDictionary *)snapshot
{
  _checkTxInProgress(self, __PRETTY_FUNCTION__);

  if (_object == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabaseContext:%x: Cannot record null object, "
              @"in [EODatabaseContext recordObject:primaryKey:entity:snapshot:]",
              self];
  }
  if ((_entity == nil) && self->isUniquingObjects) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabaseContext:%x: Cannot record object with null entity "
              @"when uniquing objects, "
              @"in [EODatabaseContext recordObject:primaryKey:entity:snapshot:]",
              self];
  }
  
  _key = [_entity primaryKeyForRow:_key];
  
  if ((_key == nil) && self->isUniquingObjects) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabaseContext:%x: Cannot record object with null key "
              @"when uniquing objects, "
              @"in [EODatabaseContext recordObject:primaryKey:entity:snapshot:]",
              self];
  }
  if ((snapshot == nil) && isKeepingSnapshots && ![EOFault isFault:_object]) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabaseContext:%x: Cannot record object with null snapshot "
              @"when keeping snapshots, "
              @"in [EODatabaseContext recordObject:primaryKey:entity:snapshot:]"
              @": snapshot=%s keepsSnapshots=%s isFault=%s",
              self,
              snapshot ? "yes" : "no",
              isKeepingSnapshots ? "yes" : "no",
              [EOFault isFault:_object] ? "yes" : "no"];
  }
    
  if (self->isKeepingSnapshots || self->isUniquingObjects) {
    EOObjectUniquer *cache = transactionStackTop->objectsDictionary;
    
    [cache recordObject:_object 
           primaryKey:  self->isUniquingObjects  ? _key   : (NSDictionary *)nil
           entity:      self->isUniquingObjects  ? _entity : (EOEntity *)nil
           snapshot:self->isKeepingSnapshots ? snapshot : (NSDictionary *)nil];
  }
}

- (void)recordObject:(id)_object
  primaryKey:(NSDictionary *)_key 
  snapshot:(NSDictionary *)_snapshot
{
  EOEntity *entity = nil;

  entity = [_object respondsToSelector:@selector(entity)]
    ? [_object entity]
    : [[[database adaptor] model] entityForObject:_object];
    
  [self recordObject:_object primaryKey:_key entity:entity snapshot:_snapshot];
}

- (NSDictionary *)snapshotForObject:(id)_object {
  EOTransactionScope *scope = NULL;
  EOUniquerRecord    *rec   = NULL;
    
  if (!isKeepingSnapshots)
    return nil;
    
  for (scope = transactionStackTop; scope; scope = scope->previous) {
    rec = [scope->objectsDictionary recordForObject:_object];
    if (rec)
      return rec->snapshot;
  }
    
  rec = [[self->database objectUniquer] recordForObject:_object];
  if (rec) return rec->snapshot;
    
  return nil;
}

- (NSDictionary*)primaryKeyForObject:(id)_object {
  EOTransactionScope *scope = NULL;
  EOUniquerRecord    *rec   = NULL;
    
  if ([self->database uniquesObjects])
    return nil;
    
  for (scope = transactionStackTop; scope; scope = scope->previous) {
    rec = [scope->objectsDictionary recordForObject:_object];
    if (rec) return rec->pkey;
  }
    
  rec = [[self->database objectUniquer] recordForObject:_object];
  if (rec) return rec->pkey;
  return nil;
}

- (void)primaryKey:(NSDictionary **)_key
  andSnapshot:(NSDictionary **)_snapshot
  forObject:_object
{
  EOTransactionScope *scope = NULL;
  EOUniquerRecord    *rec   = NULL;

  if (!self->isKeepingSnapshots && ![self->database uniquesObjects]) {
    *_key = *_snapshot = nil;
    return;
  }
    
  for (scope = transactionStackTop; scope; scope = scope->previous) {
    rec = [scope->objectsDictionary recordForObject:_object];
    if (rec) {
      if (_key)      *_key      = rec->pkey;
      if (_snapshot) *_snapshot = rec->snapshot;
      return;
    }
  }
    
  rec = [[self->database objectUniquer] recordForObject:_object];
  if (rec) {
    if (_key)      *_key      = rec->pkey;
    if (_snapshot) *_snapshot = rec->snapshot;
    return;
  }
    
  if (_key)      *_key = nil;
  if (_snapshot) *_snapshot = nil;
}

- (void)recordLockedObject:(id)_object {
  _checkTxInProgress(self, __PRETTY_FUNCTION__);
  
  if (_object == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabaseContext:%x: Cannot record null object as locked, "
              @"in [EODatabaseContext recordLockedObject:]",
              self];
  }
  if ([EOFault isFault:_object]) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabaseContext:%x: Cannot record a fault object as locked, "
              @"in [EODatabaseContext recordLockedObject:]",
              self];
  }
  [transactionStackTop->objectsLocked addObject:_object];
}

- (BOOL)isObjectLocked:(id)_object {
  EOTransactionScope *scope;
    
  for (scope = transactionStackTop; scope; scope = scope->previous) {
    if ([scope->objectsLocked indexOfObjectIdenticalTo:_object]!=NSNotFound)
      return YES;
  }
  return NO;
}

- (void)recordUpdatedObject:(id)_object {
  _checkTxInProgress(self, __PRETTY_FUNCTION__);

  if (_object == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:
               @"EODatabaseContext:%x: Cannot record null object as updatetd, "
               @"in [EODatabaseContext recordUpdatedObject:]",
               self];
  }
  if ([EOFault isFault:_object]) {
    [NSException raise:NSInvalidArgumentException
		 format:
               @"EODatabaseContext:%x: Cannot record fault object as updated, "
               @"in [EODatabaseContext recordUpdatedObject:]",
               self];
  }
    
  [transactionStackTop->objectsUpdated addObject:_object];
}

- (BOOL)isObjectUpdated:(id)_object {
  EOTransactionScope *scope;
    
  for (scope = transactionStackTop; scope; scope = scope->previous) {
    if ([scope->objectsUpdated indexOfObjectIdenticalTo:_object] != NSNotFound)
      return YES;
    if ([scope->objectsDeleted indexOfObjectIdenticalTo:_object] != NSNotFound)
      return YES;
  }
  return NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
		     @"<%@[0x%p]: #channels=%i tx-nesting=%i>",
                     NSStringFromClass([self class]), self,
                     [self->channels count],
                     [self transactionNestingLevel]];
}

@end /* EODatabaseContext */

@implementation EODatabaseContext(Statistics)

- (unsigned int)transactionBeginCount {
  return self->txBeginCount;
}
- (unsigned int)transactionCommitCount {
  return self->txCommitCount;
}
- (unsigned int)transactionRollbackCount {
  return self->txRollbackCount;
}

@end /* EODatabaseContext(Statistics) */

@implementation EODatabaseContext(NewInEOF2)

// THREAD
static Class EODatabaseContextClass = Nil;

+ (void)setContextClassToRegister:(Class)_cclass {
  EODatabaseContextClass = _cclass;
}
+ (Class)contextClassToRegister {
  return EODatabaseContextClass ? EODatabaseContextClass : (Class)self;
}

- (EODatabaseChannel *)availableChannel {
  int i;
    
  for (i = [self->channels count] - 1; i >= 0; i--) {
    EODatabaseChannel *channel;

    channel = [[self->channels objectAtIndex:i] nonretainedObjectValue];
    if (![channel isFetchInProgress])
      return channel;
  }

  [[NSNotificationCenter defaultCenter]
                         postNotificationName:@"EODatabaseChannelNeeded"
                         object:self];

  /* recheck for channel */
  
  for (i = [self->channels count] - 1; i >= 0; i--) {
    EODatabaseChannel *channel;

    channel = [[self->channels objectAtIndex:i] nonretainedObjectValue];
    if (![channel isFetchInProgress])
      return channel;
  }

  return nil;
}

- (NSArray *)registeredChannels {
  NSMutableArray *array;
  int i, n;
    
  array = [NSMutableArray array];
  for (i=0, n=[channels count]; i < n; i++) {
    EODatabaseChannel *channel = 
      [[channels objectAtIndex:i] nonretainedObjectValue];
    
    [array addObject:channel];
  }
    
  return array;
}
- (void)registerChannel:(EODatabaseChannel *)_channel {
  [self->channels addObject:[NSValue valueWithNonretainedObject:_channel]];
}
- (void)unregisterChannel:(EODatabaseChannel *)_channel {
  int i;
    
  for (i = [self->channels count] - 1; i >= 0; i--) {
    EODatabaseChannel *channel;

    channel = [[self->channels objectAtIndex:i] nonretainedObjectValue];
    
    if (channel == _channel) {
      [channels removeObjectAtIndex:i];
      break;
    }
  }
}

/* cooperating object store */

- (void)commitChanges {
  [self commitTransaction];
}
- (void)rollbackChanges {
  [self rollbackTransaction];
}

- (void)performChanges {
  [self notImplemented:_cmd];
}

/* store specific properties */

- (NSDictionary *)valuesForKeys:(NSArray *)_keys object:(id)_object {
  return [_object valuesForKeys:_keys];
}

/* capability */

- (BOOL)handlesFetchSpecification:(EOFetchSpecification *)_fspec {
  EOEntity *entity;

  entity = [[self database] entityNamed:[_fspec entityName]];
  return entity ? YES : NO;
}

/* graph */

- (BOOL)ownsObject:(id)_object {
  EOEntity *entity;
  
  entity = [[self database] entityNamed:[_object entityName]];
  return entity ? YES : NO;
}

- (BOOL)ownsGlobalID:(EOGlobalID *)_oid {
  EOEntity *entity;
  
  if (![_oid respondsToSelector:@selector(entityName)])
    return NO;

  entity = [[self database] entityNamed:[(id)_oid entityName]];
  return entity ? YES : NO;
}

@end /* EODatabaseContext(NewInEOF2) */
