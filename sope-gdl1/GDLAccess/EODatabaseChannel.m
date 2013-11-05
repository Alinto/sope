/* 
   EODatabaseChannel.m

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
#import "EODatabaseChannel.h"
#import "EOAdaptor.h"
#import "EOAdaptorChannel.h"
#import "EOAdaptorContext.h"
#import "EOAttribute.h"
#import "EODatabase.h"
#import "EODatabaseContext.h"
#import "EOEntity.h"
#import "EODatabaseFault.h"
#import "EOGenericRecord.h"
#import "EOModel.h"
#import "EOObjectUniquer.h"
#import "EOSQLQualifier.h"
#import "EORelationship.h"
#import <EOControl/EONull.h>
#import <EOControl/EOFetchSpecification.h>
#import <EOControl/EOKeyValueCoding.h>

@class EOGenericRecord;

NSString *EODatabaseChannelWillOpenNotificationName =
  @"EODatabaseChannelWillOpenNotification";
NSString *EODatabaseChannelDidOpenNotificationName =
  @"EODatabaseChannelDidOpenNotification";
NSString *EODatabaseChannelWillCloseNotificationName =
  @"EODatabaseChannelWillCloseNotification";
NSString *EODatabaseChannelDidCloseNotificationName =
  @"EODatabaseChannelDidCloseNotification";
NSString *EODatabaseChannelCouldNotOpenNotificationName =
  @"EODatabaseChannelCouldNotOpenNotification";
NSString *EODatabaseChannelWillInsertObjectName =
  @"EODatabaseChannelWillInsertObjectName";
NSString *EODatabaseChannelDidInsertObjectName =
  @"EODatabaseChannelDidInsertObjectName";
NSString *EODatabaseChannelWillUpdateObjectName =
  @"EODatabaseChannelWillUpdateObjectName";
NSString *EODatabaseChannelDidUpdateObjectName =
  @"EODatabaseChannelDidUpdateObjectName";
NSString *EODatabaseChannelWillDeleteObjectName =
  @"EODatabaseChannelWillDeleteObjectName";
NSString *EODatabaseChannelDidDeleteObjectName =
  @"EODatabaseChannelDidDeleteObjectName";
NSString *EODatabaseChannelWillLockObjectName =
  @"EODatabaseChannelWillLockObjectName";
NSString *EODatabaseChannelDidLockObjectName =
  @"EODatabaseChannelDidLockObjectName";

/*
 * Private methods declaration
 */

@interface EODatabaseChannel(Private)
- (id)privateFetchWithZone:(NSZone *)_zone;
- (Class)privateClassForEntity:(EOEntity *)anEntity;
- (void)privateUpdateCurrentEntityInfo;
- (void)privateClearCurrentEntityInfo;
- (void)privateReportError:(SEL)method:(NSString *)format, ...;
@end

/*
 * EODatabaseChannel implementation
 */

@implementation EODatabaseChannel

/*
 * Initializing a new instance
 */

- (id)initWithDatabaseContext:(EODatabaseContext *)_dbContext {
  if (_dbContext == nil) {
    AUTORELEASE(self);
    return nil;
  }
  
  self->notificationCenter = RETAIN([NSNotificationCenter defaultCenter]);
  
  self->databaseContext = RETAIN(_dbContext);
  [self setDelegate:[self->databaseContext delegate]];
  [self->databaseContext channelDidInit:self];
  
  return self;
}

- (void)dealloc {
  [self->databaseContext channelWillDealloc:self];
  RELEASE(self->currentEditingContext);
  RELEASE(self->databaseContext);
  RELEASE(self->adaptorChannel);
  RELEASE(self->notificationCenter);
  [super dealloc];
}

// notifications

- (void)postNotification:(NSString *)_name {
  [self->notificationCenter postNotificationName:_name object:self];
}
- (void)postNotification:(NSString *)_name object:(id)_obj {
  [self->notificationCenter postNotificationName:_name
                            object:self
                            userInfo:[NSDictionary dictionaryWithObject:_obj
                                                   forKey:@"object"]];
}

// accessors

- (EOAdaptorChannel *)adaptorChannel {
  if (self->adaptorChannel == nil) {
    static int reuseAdaptorCh = -1;
    if (reuseAdaptorCh == -1) {
      reuseAdaptorCh = [[[NSUserDefaults standardUserDefaults]
                                         objectForKey:@"EOReuseAdaptorChannel"]
                                         boolValue] ? 1 : 0;
    }
    
    if (reuseAdaptorCh) {
      NSEnumerator     *channels;
      EOAdaptorChannel *channel;
      
      channels =
        [[[[self databaseContext] adaptorContext] channels] objectEnumerator];
      
      while ((channel = [channels nextObject])) {
        if ([channel isFetchInProgress])
          continue;

#if DEBUG
        NSLog(@"reuse adaptor channel: %@", channel);
#endif
        self->adaptorChannel = channel;
        break;
      }
    }
    
    if (self->adaptorChannel == nil) {
      self->adaptorChannel =
        [[[self databaseContext] adaptorContext] createAdaptorChannel];
    }
    
    RETAIN(self->adaptorChannel);
  }
  return self->adaptorChannel;
}

- (EODatabaseContext *)databaseContext {
  return self->databaseContext;
}

// delegate

- (void)setDelegate:(id)_delegate {
  self->delegate = _delegate;
}
- (id)delegate {
  return self->delegate;
}

// Opening and closing a channel

- (BOOL)isOpen {
  return [[self adaptorChannel] isOpen];
}

- (BOOL)openChannel {
  BOOL result;

  [self postNotification:EODatabaseChannelWillOpenNotificationName];
  
  if ((result = [[self adaptorChannel] openChannel])) {
    self->successfulOpenCount++;
    [self postNotification:EODatabaseChannelDidOpenNotificationName];
  }
  else {
    self->failedOpenCount++;
    [self postNotification:EODatabaseChannelCouldNotOpenNotificationName];
  }

  return result;
}

- (void)closeChannel {
  [self postNotification:EODatabaseChannelWillCloseNotificationName];
  [[self adaptorChannel] closeChannel];
  self->closeCount++;
  [self postNotification:EODatabaseChannelDidCloseNotificationName];
}

// Modifying objects

- (BOOL)_isNoRaiseOnModificationException:(NSException *)_exception {
  /* for compatibility with non-X methods, translate some errors to a bool */
  NSString *n;
  
  n = [_exception name];
  if ([n isEqualToString:@"EOEvaluationError"])
    return YES;
  if ([n isEqualToString:@"EODelegateRejects"])
    return YES;

  return NO;
}

- (BOOL)insertObject:(id)anObj {
  // TODO: split up this method
  // TODO: write an insertObjectX: which returns an exception
  NSException  *exception   = nil;
  EOEntity     *entity      = nil;
  NSDictionary *pkey        = nil;
  NSDictionary *values      = nil;
  NSDictionary *snapshot    = nil;
  NSArray      *attributes  = nil;
  int i;
  
  [self postNotification:EODatabaseChannelWillInsertObjectName object:anObj];

  if (![anObj prepareForInsertInChannel:self context:self->databaseContext])
    return NO;
  
  // Check the delegate
  if ([self->delegate respondsToSelector:
                        @selector(databaseChannel:willInsertObject:)])
    anObj = [delegate databaseChannel:self willInsertObject:anObj];

  // Check nil (delegate disallowes or given object was nil)
  if (anObj == nil)
    return NO;
  
  // Check if fault
  if ([EOFault isFault:anObj]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"Attempt to insert a fault in a database channel"];
  }

  // Check if we can insert
  if ([databaseContext updateStrategy] == EONoUpdate) {
    [self privateReportError:_cmd : 
          @"cannot insert if context has 'NoUpdate' update strategy."];
    return NO;
  }
  
  /* validate object for insert */
  
  if ((exception = [anObj validateForInsert])) {
    /* validation failed */
    [exception raise];
  }
  
  // Check if in a transaction
  if (![databaseContext transactionNestingLevel]) {
    [self privateReportError:_cmd : 
          @"cannot insert if contex has no transaction opened."];
    return NO;
  }
    
  // Get entity
  entity = [anObj respondsToSelector:@selector(entity)]
    ? [anObj entity]
    : [[[[adaptorChannel adaptorContext] adaptor] model] entityForObject:anObj];
    
  // Check entity
  if (entity == nil) {
    [self privateReportError:_cmd : 
            @"cannot determine entity for object %p class %@.",
            anObj, NSStringFromClass([anObj class])];
    return NO;
  }
  if ([entity isReadOnly]) {
    [self privateReportError:_cmd : 
            @"cannot insert object %p for readonly entity %@.",
            anObj, [entity name]];
    return NO;
  }

  // Get array of attributes to insert
  attributes = [entity attributesUsedForInsert];

  // Get simple values and convert them to adaptor values
  values = [anObj valuesForKeys:[entity attributesNamesUsedForInsert]];
  values = [entity convertValuesToModel:values];
    
  // Get and check *must insert* attributes (primary key, lock, readonly)
  for (i = [attributes count]-1; i >= 0; i--) {
    EOAttribute *attribute = [attributes objectAtIndex:i];

    NSAssert(attribute, @"invalid attribute object ..");
    
    if (![values objectForKey:[attribute name]]) {
      [self privateReportError:_cmd : 
              @"null value for insert attribute %@ for object %@ entity %@",
              [attribute name], anObj, [entity name]];
      return NO;
    }
  }
    
  // Make primary key and snapshot
  snapshot = [entity snapshotForRow:values];
  if (snapshot == nil) {
    [self privateReportError:_cmd : 
            @"cannot determine snapshot for %p from values %@ entity %@.",
            anObj, [values description], [entity name]];
    return NO;
  }
  pkey = [entity primaryKeyForRow:values];
  if (pkey == nil) {
    [self privateReportError:_cmd : 
            @"cannot determine primary key for %p from values %@ entity %@.",
            anObj, [values description], [entity name]];
    return NO;
  }
    
  // Insert adaptor row
  exception = [adaptorChannel insertRowX:values forEntity:entity];
  if (exception) {
    if (![self _isNoRaiseOnModificationException:exception]) [exception raise];
    return NO;
  }
  
  // Record object in database context
  [databaseContext recordObject:anObj 
                   primaryKey:pkey entity:entity snapshot:values];

  self->insertCount++;
  [anObj wasInsertedInChannel:self context:self->databaseContext];
  
  // Notify delegate
  if ([delegate respondsToSelector:@selector(databaseChannel:didInsertObject:)])
    [delegate databaseChannel:self didInsertObject:anObj];

  [self postNotification:EODatabaseChannelDidInsertObjectName object:anObj];
  return YES;
}

- (BOOL)updateObject:(id)anObj {
  // TODO: split up this huge method
  // TODO: make an updateObjectX: method which returns an exception
  NSException    *exception    = nil;
  EOEntity       *entity       = nil;
  EOSQLQualifier *qualifier    = nil;
  NSDictionary   *old_pkey     = nil;
  NSDictionary   *old_snapshot = nil;
  NSDictionary   *new_pkey     = nil;
  NSDictionary   *new_snapshot = nil;
  NSDictionary   *values       = nil;
  BOOL needsOptimisticLock;

  [self postNotification:EODatabaseChannelWillUpdateObjectName object:anObj];

  if (![anObj prepareForUpdateInChannel:self context:self->databaseContext])
    return NO;
  
  // Check the delegate
  if ([delegate respondsToSelector:@selector(databaseChannel:willUpdateObject:)])
    anObj = [delegate databaseChannel:self willUpdateObject:anObj];

  // Check nil (delegate disallowes or given object was nil)
  if (anObj == nil)
    return NO;

  // Check if fault
  if ([EOFault isFault:anObj]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"Attempt to update a fault in a database channel"];
  }

  // Check if we can update
  if ([databaseContext updateStrategy] == EONoUpdate) {
    [self privateReportError:_cmd : 
          @"cannot update if context has 'NoUpdate' update strategy."];
    return NO;
  }

  /* validate object for update */
  
  if ((exception = [anObj validateForUpdate])) {
    /* validation failed */
    [exception raise];
  }
  
  // Check if in a transaction
  if (![databaseContext transactionNestingLevel]) {
    [self privateReportError:_cmd : 
            @"cannot update if contex has no transaction opened."];
    return NO;
  }
    
  // Get entity
  entity = [anObj respondsToSelector:@selector(entity)]
    ? [anObj entity]
    : [[[[adaptorChannel adaptorContext] adaptor] model] entityForObject:anObj];
    
  // Check entity
  {
    if (entity == nil) {
      [self privateReportError:_cmd : 
            @"cannot determine entity for object %p class %@.",
            anObj, NSStringFromClass([anObj class])];
      return NO;
    }
    if ([entity isReadOnly]) {
      [self privateReportError:_cmd : 
            @"cannot update object %p for readonly entity %@.",
            anObj, [entity name]];
      return NO;
    }
  }
  
  // Get and check old snapshot and primary key
  {
    [databaseContext primaryKey:&old_pkey
                     andSnapshot:&old_snapshot
                     forObject:anObj];
  
    if (old_snapshot == nil) {
      [self privateReportError:_cmd : 
            @"cannot update object %p because there is no snapshot for it."];
      return NO;
    }
    if (old_pkey == nil)
      old_pkey = [entity primaryKeyForRow:old_snapshot];
    if (old_pkey == nil) {
      [self privateReportError:_cmd : 
            @"cannot determine primary key for %p from snapshot %@ entity %@.",
            anObj, [old_snapshot description], [entity name]];
      return NO;
    }
  }
    
  // Get simple values and convert them to adaptor values
  values = [anObj valuesForKeys:[entity attributesNamesUsedForInsert]];
  values = [entity convertValuesToModel:values];
    
  // Get and check new primary key and snapshot
  {
    new_snapshot = [entity snapshotForRow:values];
    if (new_snapshot == nil) {
      [self privateReportError:_cmd : 
            @"cannot determine snapshot for %p from values %@ entity %@.",
            anObj, [values description], [entity name]];
      return NO;
    }
    new_pkey = [entity primaryKeyForRow:new_snapshot];
    if (new_pkey == nil) {
      [self privateReportError:_cmd : 
            @"cannot determine primary key for %p from values %@ entity %@.",
            anObj, [values description], [entity name]];
      return NO;
    }
  }
    
  // Check if we need to lock optimistic before update
  // that is compare locking attributes with the existing ones in database
  switch([databaseContext updateStrategy]) {
    case EOUpdateWithOptimisticLocking:
    case EOUpdateWithPessimisticLocking:
      needsOptimisticLock = ![databaseContext isObjectLocked:anObj];
      break;
    case EOUpdateWithNoLocking:
      needsOptimisticLock = NO;
      break;
    default:
      return NO;
  }
        
  // If we need an "optimistic lock" then perform lock
  // else just make the qualifier based on the primary key only
  if (needsOptimisticLock) {
    int i;
    BOOL         canUseQualifier = YES;
    NSArray      *lockAttrs = [entity attributesUsedForLocking];
    EOAdaptor    *adaptor   = [[adaptorChannel adaptorContext] adaptor];
    NSDictionary *row;
        
    // Check if attributes used for locking can be used in a qualifier
    for (i = [lockAttrs count]-1; i >= 0; i--) {
      if (![adaptor isValidQualifierType:
                      [[lockAttrs objectAtIndex:i] externalType]]) {
        canUseQualifier = NO;
        break;
      }
    }
        
    if (canUseQualifier)
      // If YES just build the qualifier
      qualifier = [EOSQLQualifier qualifierForRow:old_snapshot 
                               entity:entity];
    else {
      // If NO then lock the row in the database server, fetch the
      // new snapshot and compare it with the old one
      qualifier = [EOSQLQualifier qualifierForPrimaryKey:old_pkey 
                               entity:entity];
#ifdef DEBUG
      NSAssert2([lockAttrs count] > 0,
                @"missing locking attributes: lock=%@ object=%@",
                lockAttrs, anObj);
#endif
      if (![adaptorChannel selectAttributes:lockAttrs
                           describedByQualifier:qualifier
                           fetchOrder:nil 
                           lock:YES]) {
        [self privateReportError:_cmd : 
                @"could not lock=%@ with qualifier=%@ entity=%@.",
                anObj, [qualifier description], [entity name]];
        return NO;
      }
      row = [adaptorChannel fetchAttributes:lockAttrs withZone:NULL];
      [adaptorChannel cancelFetch];
      if (row == nil) {
        [self privateReportError:_cmd : 
              @"could not get row to lock %p with qualifier %@.",
              anObj, [qualifier description]];
        return NO;
      }
      [databaseContext recordLockedObject:anObj];
      if (![row isEqual:old_snapshot]) {
        [self privateReportError:_cmd : 
                @"could not lock %p. Snapshots: self %@ database %@.",
                anObj, [old_snapshot description], [row description]];
        return NO;
      }
    }
  }
  else {
    qualifier = [EOSQLQualifier qualifierForPrimaryKey:old_pkey 
                             entity:entity];
  }
    
  // Compute values as delta from values and old_snapshot
  {
    NSMutableDictionary *delta;
    NSString            *attributeName;
    NSArray             *allKeys;
    int                 i, count;
        
    allKeys = [values allKeys];
    delta   = [NSMutableDictionary dictionary];
    for (i = 0, count = [allKeys count]; i < count; i++) {
      id new_v, old_v;

      attributeName = [allKeys objectAtIndex:i];
      new_v         = [values objectForKey:attributeName];
      old_v         = [old_snapshot objectForKey:attributeName];
      
      if ((old_v == nil) || ![new_v isEqual:old_v])
        [delta setObject:new_v forKey:attributeName];
    }
    values = delta;
  }

  // no reason for update --> fetch to be sure, that no one has deleted it
  // HH: The object was not changed, so we refetch to determine whether it
  // was deleted
  if ([values count] == 0) {
    if (![self refetchObject:anObj])
      return NO;
  }
  // Update in adaptor
  else {
    NSException *ex;
    
    ex = [adaptorChannel updateRowX:values describedByQualifier:qualifier];
    if (ex != nil) {
      if (![self _isNoRaiseOnModificationException:ex]) [ex raise];
      return NO;
    }
  }
  // Record object in database context
  if (![new_pkey isEqual:old_pkey]) {
    NSLog(@"WARNING: (%@) primary key changed from %@ to %@",
          __PRETTY_FUNCTION__, old_pkey, new_pkey);
    [databaseContext forgetObject:anObj];
  }
  
  [databaseContext recordObject:anObj 
                   primaryKey:new_pkey
                   entity:entity
                   snapshot:new_snapshot];
  [databaseContext recordUpdatedObject:anObj];

  self->updateCount++;
  [anObj wasUpdatedInChannel:self context:self->databaseContext];
  
  // Notify delegate
  if ([delegate respondsToSelector:@selector(databaseChannel:didUpdateObject:)])
    [delegate databaseChannel:self didUpdateObject:anObj];

  [self postNotification:EODatabaseChannelDidUpdateObjectName object:anObj];
  return YES;
}

- (BOOL)deleteObject:(id)anObj {
  // TODO: split this method
  // TODO: add an deleteObjectX: method which returns an NSException
  NSException    *exception = nil;
  EOEntity       *entity    = nil;
  NSDictionary   *pkey      = nil;
  NSDictionary   *snapshot  = nil;
  EOSQLQualifier *qualifier = nil;

  [self postNotification:EODatabaseChannelWillDeleteObjectName object:anObj];

  if (![anObj prepareForDeleteInChannel:self context:self->databaseContext])
    return NO;
  
  // Check the delegate
  if ([delegate respondsToSelector:@selector(databaseChannel:willDeleteObject:)])
    anObj = [delegate databaseChannel:self willDeleteObject:anObj];

  // Check nil (delegate disallowes or given object was nil)
  if (anObj == nil)
    return NO;

  // Check if fault
  if ([EOFault isFault:anObj]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"Attempt to delete a fault in a database channel"];
  }

  // Check if we can delete
  if ([databaseContext updateStrategy] == EONoUpdate) {
    [self privateReportError:_cmd : 
            @"cannot delete if context has 'NoUpdate' update strategy."];
    return NO;
  }

  /* validate object for delete */
  
  if ((exception = [anObj validateForDelete])) {
    /* validation failed */
    [exception raise];
  }
  
  // Check if in a transaction
  if (![databaseContext transactionNestingLevel]) {
    [self privateReportError:_cmd : 
            @"cannot update if contex has no transaction opened."];
    return NO;
  }
  
  // Get entity
  entity = [anObj respondsToSelector:@selector(entity)]
    ? [anObj entity]
    : [[[[adaptorChannel adaptorContext] adaptor] model] entityForObject:anObj];
  
  // Check entity
  if (entity == nil) {
    [self privateReportError:_cmd : 
            @"cannot determine entity for object %p class %s.",
            anObj, NSStringFromClass([anObj class])];
    return NO;
  }
  if ([entity isReadOnly]) {
    [self privateReportError:_cmd : 
            @"cannot delete object %p for readonly entity %@.",
            anObj, [entity name]];
    return NO;
  }
    
  // Get snapshot and old primary key
  [databaseContext primaryKey:&pkey andSnapshot:&snapshot forObject:anObj];
  if (pkey == nil) {
    if (snapshot == nil)
      [self privateReportError:_cmd : 
            @"cannot delete object %p because there is no snapshot for it."];
    pkey = [entity primaryKeyForRow:snapshot];
  }
  if (pkey == nil) {
    [self privateReportError:_cmd : 
            @"cannot determine primary key for %p from values %@ entity %@.",
            anObj, [snapshot description], [entity name]];
    return NO;
  }
    
  // Get and check qualifier for object to delete
  qualifier = [EOSQLQualifier qualifierForPrimaryKey:pkey entity:entity];
  if (qualifier == nil) {
    [self privateReportError:_cmd : 
            @"cannot make qualifier to delete %p primary key %@ entity %@.",
            anObj, [pkey description], [entity name]];
    return NO;
  }
    
  // Delete adaptor row
  exception = [adaptorChannel deleteRowsDescribedByQualifierX:qualifier];
  if (exception != nil) {
    if (![self _isNoRaiseOnModificationException:exception]) [exception raise];
    return NO;
  }
  
  AUTORELEASE(RETAIN(anObj));
  
  // Forget object in database context
  [databaseContext forgetObject:anObj];

  self->deleteCount++;
  [anObj wasDeletedInChannel:self context:self->databaseContext];
  
  // Notify delegate
  if ([delegate respondsToSelector:
		  @selector(databaseChannel:didDeleteObject:)])
    [delegate databaseChannel:self didDeleteObject:anObj];

  [self postNotification:EODatabaseChannelDidDeleteObjectName object:anObj];
  return YES;
}

- (BOOL)lockObject:(id)anObj {
  EOEntity     *entity    = nil;
  NSDictionary *pkey      = nil;
  NSDictionary *snapshot  = nil;
  EOSQLQualifier  *qualifier = nil;

  [self postNotification:EODatabaseChannelWillLockObjectName object:anObj];

  if (![anObj prepareForLockInChannel:self context:self->databaseContext])
    return NO;
    
  // Check the delegate
  if ([delegate respondsToSelector:@selector(databaseChannel:willLockObject:)])
    anObj = [delegate databaseChannel:self willLockObject:anObj];

  // Check nil (delegate disallowes or given object was nil)
  if (anObj == nil)
    return NO;

  // Check if fault
  if ([EOFault isFault:anObj]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"Attempt to lock a fault in a database channel"];
  }

  // Check if we can lock
  if ([databaseContext updateStrategy] == EONoUpdate) {
    [self privateReportError:_cmd : 
            @"cannot lock if context has 'NoUpdate' update strategy."];
    return NO;
  }
    
  // Check if in a transaction
  if (![databaseContext transactionNestingLevel]) {
    [self privateReportError:_cmd : 
            @"cannot lock if contex has no transaction opened."];
    return NO;
  }
    
  // Check if fetch is in progress
  if ([self isFetchInProgress]) {
    [self privateReportError:_cmd : 
            @"cannot lock if contex has a fetch in progress."];
    return NO;
  }
    
  // Get entity
  entity =  [anObj respondsToSelector:@selector(entity)]
    ? [anObj entity]
    : [[[[adaptorChannel adaptorContext] adaptor] model] entityForObject:anObj];
    
  // Check entity
  if (entity == nil) {
    [self privateReportError:_cmd : 
            @"cannot determine entity for object %p class %s.",
            anObj, NSStringFromClass([anObj class])];
    return NO;
  }
  if ([entity isReadOnly]) {
    [self privateReportError:_cmd : 
            @"cannot lock object %p for readonly entity %@.",
            anObj, [entity name]];
    return NO;
  }
    
  // Get snapshot and old primary key
  [databaseContext primaryKey:&pkey andSnapshot:&snapshot forObject:anObj];
  if (snapshot == nil) {
    [self privateReportError:_cmd : 
            @"cannot lock object %p because there is no snapshot for it."];
    return NO;
  }
  
  if (pkey == nil) 
    pkey = [entity primaryKeyForRow:snapshot];

  if (pkey == nil) {
    [self privateReportError:_cmd : 
            @"cannot determine primary key for %p from values %@ entity %@.",
            anObj, [snapshot description], [entity name]];
    return NO;
  }
    
  {
    NSArray      *lockAttrs = [entity attributesUsedForLocking];
    NSDictionary *row       = nil;
        
    qualifier = [EOSQLQualifier qualifierForPrimaryKey:pkey entity:entity];
        
#ifdef DEBUG
      NSAssert2([lockAttrs count] > 0,
                @"missing locking attributes: lock=%@ object=%@",
                lockAttrs, anObj);
#endif
    if (![adaptorChannel selectAttributes:lockAttrs
                         describedByQualifier:qualifier
                         fetchOrder:nil 
                         lock:YES]) {
      [self privateReportError:_cmd : 
              @"could not lock %p with qualifier %@.",
              anObj, [qualifier description]];
      return NO;
    }
    row = [adaptorChannel fetchAttributes:lockAttrs withZone:NULL];
    [adaptorChannel cancelFetch];
    if (row == nil) {
      [self privateReportError:_cmd : 
              @"could not lock %p with qualifier %@.",
              anObj, [qualifier description]];
      return NO;
    }
    if (![row isEqual:snapshot]) {
      [self privateReportError:_cmd : 
              @"could not lock %p. Snapshots: self %@ database %@.",
              anObj, [snapshot description], [row description]];
      return NO;
    }
  }
    
  // Register lock object in database context
  [databaseContext recordLockedObject:anObj];

  self->lockCount++;
  [anObj wasLockedInChannel:self context:self->databaseContext];
  
  // Notify delegate
  if ([delegate respondsToSelector:@selector(databaseChannel:didLockObject:)])
    [delegate databaseChannel:self didLockObject:anObj];
  [self postNotification:EODatabaseChannelDidLockObjectName object:anObj];
  return YES;
}

- (BOOL)refetchObject:(id)anObj {
  EOEntity     *entity    = nil;
  NSDictionary *pkey      = nil;
  NSDictionary *snapshot  = nil;
  EOSQLQualifier  *qualifier = nil;
    
  // Check the delegate
  if ([delegate respondsToSelector:
                  @selector(databaseChannel:willRefetchObject:)])
    anObj = [delegate databaseChannel:self willRefetchObject:anObj];

  // Check nil (delegate disallowes or given object was nil)
  if (anObj == nil)
    return NO;

  // Check if fault
  if ([EOFault isFault:anObj]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"Attempt to refetch a fault in a database channel"];
  }

  // Check if in a transaction
  if (![databaseContext transactionNestingLevel]) {
    [self privateReportError:_cmd : 
          @"cannot refetch if context has no transaction opened."];
    return NO;
  }
    
  // Check if fetch is in progress
  if ([self isFetchInProgress]) {
    [self privateReportError:_cmd : 
          @"cannot refetch if context has a fetch in progress."];
    return NO;
  }
    
  // Get entity
  entity = [anObj respondsToSelector:@selector(entity)]
    ? [anObj entity]
    : [[[[adaptorChannel adaptorContext] adaptor] model] entityForObject:anObj];
    
  // Check entity
  if (entity == nil) {
    [self privateReportError:_cmd : 
          @"cannot determine entity for object %p class %s.",
          anObj, NSStringFromClass([anObj class])];
    return NO;
  }
    
  // Get snapshot and old primary key
  [databaseContext primaryKey:&pkey andSnapshot:&snapshot forObject:anObj];
  if (pkey == nil) {
    if (snapshot == nil)
      [self privateReportError:_cmd : 
              @"cannot refetch object %p because there is no snapshot for it."];
    pkey = [entity primaryKeyForRow:snapshot];
  }
  if (pkey == nil) {
    [self privateReportError:_cmd : 
            @"cannot determine primary key for %p from values %@ entity %@.",
            anObj, [snapshot description], [entity name]];
    return NO;
  }
    
  // Get and check qualifier for object to refetch
  qualifier = [EOSQLQualifier qualifierForPrimaryKey:pkey entity:entity];
  if (qualifier == nil) {
    [self privateReportError:_cmd : 
            @"cannot make qualifier to refetch %p primary key %@ entity %@.",
            anObj, [pkey description], [entity name]];
    return NO;
  }
    
  // Request object from adaptor
  [self setCurrentEntity:entity];
  [self privateUpdateCurrentEntityInfo];
  if (currentAttributes == nil) {
    [self privateReportError:_cmd : 
          @"internal inconsitency while refetching %p.", anObj];
    return NO;
  }
    
#ifdef DEBUG
  NSAssert3([currentAttributes count] > 0,
            @"missing attributes for select: lock=%@ object=%@ entity=%@",
            currentAttributes, anObj, entity);
#endif
  if (![adaptorChannel selectAttributes:currentAttributes
                       describedByQualifier:qualifier 
                       fetchOrder:nil
                       lock:([databaseContext updateStrategy] ==
                             EOUpdateWithPessimisticLocking)]) {
    [self privateClearCurrentEntityInfo];
    return NO;
  }

  // Get object from adaptor, re-build its faults and record new snapshot
  anObj = [self privateFetchWithZone:NULL];
  [self cancelFetch];
  if (anObj == nil) {
    [self privateReportError:_cmd : 
          @"could not refetch %p with qualifier %@.",
          anObj, [qualifier description]];
    return NO;
  }

  // Notify delegate
  if ([delegate respondsToSelector:@selector(databaseChannel:didRefetchObject:)])
    [delegate databaseChannel:self didRefetchObject:anObj];
  return YES;
}

- (id)_createObjectForRow:(NSDictionary*)aRow entity:(EOEntity*)anEntity 
  isPrimaryKey:(BOOL)yn zone:(NSZone*)zone {
  Class class = Nil;
  id    anObj = nil;
    
  if (anEntity == nil)
    return nil;
    
  class = [self privateClassForEntity:anEntity];

  // Create new instance
  if ([class respondsToSelector:@selector(classForEntity:values:)])
    class = [class classForEntity:anEntity values:aRow];
  
  anObj = [class allocWithZone:zone];
    
  return anObj;
}

- (id)allocateObjectForRow:(NSDictionary *)row entity:(EOEntity *)anEntity
  zone:(NSZone *)zone {
  
  Class class = Nil;
  id    anObj = nil;
    
  if (anEntity == nil)
    return nil;
    
  class = [self privateClassForEntity:anEntity];
    
  // Create new instance
  if ([class respondsToSelector:@selector(classForEntity:values:)])
    class = [class classForEntity:anEntity values:row];
  
  anObj = [class allocWithZone:zone];
    
  return anObj;
}

- (id)initializedObjectForRow:(NSDictionary *)row
  entity:(EOEntity *)anEntity
  zone:(NSZone *)zone
{
  id anObj;
  
  anObj = [self allocateObjectForRow:row entity:anEntity zone:zone];
  
  anObj = [anObj respondsToSelector:@selector(initWithPrimaryKey:entity:)]
    ? [anObj initWithPrimaryKey:row entity:anEntity]
    : [anObj init];
    
  return AUTORELEASE(anObj);
}

/*
 * Fetching objects
 */

- (id)_fetchObject:(id)anObj qualifier:(EOSQLQualifier *)qualifier {
  id obj;
    
  [self selectObjectsDescribedByQualifier:qualifier fetchOrder:nil];
  obj = [self fetchWithZone:NULL];
  [self cancelFetch];
  return obj;
}

- (BOOL)selectObjectsDescribedByQualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder
{
  if ([delegate respondsToSelector:
       @selector(databaseChannel:willSelectObjectsDescribedByQualifier:fetchOrder:)])
    if (![delegate databaseChannel:self 
                   willSelectObjectsDescribedByQualifier:qualifier
                   fetchOrder:fetchOrder])
      return NO;
 
  [self setCurrentEntity:[qualifier entity]];
  [self privateUpdateCurrentEntityInfo];
  if (self->currentAttributes == nil) {
    [self privateReportError:_cmd : 
          @"internal inconsitency while selecting."];
  }
#ifdef DEBUG
  NSAssert3([self->currentAttributes count] > 0,
            @"missing select attributes: attrs=%@, qualifier=%@, entity=%@",
            self->currentAttributes, qualifier, self->currentEntity);
#endif
  if (![adaptorChannel selectAttributes:self->currentAttributes
                       describedByQualifier:qualifier 
                       fetchOrder:fetchOrder
                       lock:([databaseContext updateStrategy] ==
                             EOUpdateWithPessimisticLocking)]) {
    [self privateClearCurrentEntityInfo];
    [self privateReportError:_cmd : 
            @"could not select attributes with qualifier %@.",
            [qualifier description]];
    return NO;
  }

  if ([delegate respondsToSelector:
       @selector(databaseChannel:didSelectObjectsDescribedByQualifier:fetchOrder:)])
    [delegate databaseChannel:self 
              didSelectObjectsDescribedByQualifier:qualifier
              fetchOrder:fetchOrder];
  return YES;
}

- (id)fetchWithZone:(NSZone *)zone {
  id object = nil;
    
  if ([delegate respondsToSelector:
                  @selector(databaseChannel:willFetchObjectOfClass:withZone:)]) {
    Class class;

    class = currentClass
      ? currentClass
      : [self privateClassForEntity:currentEntity];
    
    [delegate databaseChannel:self 
              willFetchObjectOfClass:class
              withZone:zone];
  }
  object = [self privateFetchWithZone:zone];
  if (object == nil)
    return nil;

  if ([delegate respondsToSelector:@selector(databaseChannel:didFetchObject:)])
    [delegate databaseChannel:self didFetchObject:object];
  
  return object;
}

- (BOOL)isFetchInProgress {
  return [[self adaptorChannel] isFetchInProgress];
}

- (void)cancelFetch {
  if ([[self adaptorChannel] isFetchInProgress]) {
    [self privateClearCurrentEntityInfo];
    [[self adaptorChannel] cancelFetch];
  }
}

- (void)setCurrentEntity:(EOEntity *)_entity {
  // Clear entity info
  [self privateClearCurrentEntityInfo];
  // Set new entity
  NSAssert(self->currentEntity == nil, @"entity not cleared correctly ..");
  self->currentEntity = RETAIN(_entity);
}

- (void)privateClearCurrentEntityInfo {
  RELEASE(self->currentEntity);     self->currentEntity = nil;
  RELEASE(self->currentAttributes); self->currentAttributes = nil;
  RELEASE(self->currentRelations);  self->currentRelations = nil;
  self->currentClass = Nil;
  self->currentReady = NO;
}

- (void)privateUpdateCurrentEntityInfo {
  if (self->currentEntity == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:@"Must use setCurrentEntity if select is not done "
		 @"through database"];
  }
  
  if (self->currentAttributes == nil)
    self->currentAttributes =
      RETAIN([self->currentEntity attributesUsedForFetch]);
  if (self->currentRelations == nil)
    self->currentRelations = RETAIN([self->currentEntity relationsUsedForFetch]);
  self->currentReady = YES;
}

/*
 * Private methods
 */

- (Class)privateClassForEntity:(EOEntity *)anEntity {
  Class class;
    
  if (anEntity == currentEntity && currentClass)
    return currentClass;
    
    // Get class for new object
  class = NSClassFromString([anEntity className]);

  if (!class && [delegate respondsToSelector:
                          @selector(databaseChannel:failedToLookupClassNamed:)])
    class = [delegate databaseChannel:self 
                      failedToLookupClassNamed:[[anEntity className] cString]];
  if (class == Nil)
    class = [EOGenericRecord class];

  if (anEntity == currentEntity)
    currentClass = class;
    
  return class;
}

- (id)privateFetchWithZone:(NSZone *)_zone {
  NSMutableDictionary *values = nil;
  id           object    = nil;
  NSDictionary *pkey     = nil;
  NSDictionary *snapshot = nil;
  NSDictionary *row      = nil;
  NSDictionary *dict     = nil;;
    
  // Be sure we have entity info (raises if no entity is set)
  if (!self->currentReady)
    [self privateUpdateCurrentEntityInfo];
    
  // fetch row from adaptor
  row = [[self adaptorChannel] fetchAttributes:self->currentAttributes
                              withZone:_zone];
  if (row == nil)
    // Results set finished or no more result sets
    return nil;
#if 0
  row = [row copyWithZone:_zone];
  AUTORELEASE(row);
#endif
  
  // determine primary key and snapshot
  snapshot = [self->currentEntity snapshotForRow:row];
  pkey     = [self->currentEntity primaryKeyForRow:row];
  
  if ((pkey == nil) || (snapshot == nil)) {
    // TODO - should we have a delegate method here ?
    [NSException raise:NSInvalidArgumentException
		 format:@"Cannot determine primary key and snapshot for row"];
  }
  
  // lookup object in context/database
  object = [self->databaseContext objectForPrimaryKey:pkey
                                  entity:currentEntity];
  
  // use old, make new, clear fault
  if (object == nil) {
    //NSLog(@"new anObj\n");
    object = [self initializedObjectForRow:row
                   entity:currentEntity
                   zone:_zone];
  }
  if ([EOFault isFault:object]) {
    [EODatabaseFault clearFault:object];
    
    object = [object respondsToSelector:@selector(initWithPrimaryKey:entity:)]
      ? [object initWithPrimaryKey:row entity:currentEntity]
      : [object init];
    
    if (object == nil) {
      [NSException raise:NSInvalidArgumentException
		   format:@"could not initialize cleared fault with "
		   @"row `%@' and entity %@",
		   [row description], [currentEntity name]];
    }
  }
    
  // make values
  // TODO - handle only class properties to object
  values = [NSMutableDictionary dictionaryWithCapacity:
                                  ([row count] + [currentRelations count])];
  [values addEntriesFromDictionary:row];
    
  // resolve relationships (to-one and to-many)
  {
    EORelationship *rel  = nil;
    int            i, n  = [self->currentRelations count];
    id             fault = nil;
        
    for (i = 0; i < n; i++) {
      rel = [self->currentRelations objectAtIndex:i];
            
      // Check if the delegate can provide a different relationship
      if ([delegate respondsToSelector:
                    @selector(databaseChannel:relationshipForRow:relationship:)]) {
        id nrel = [delegate databaseChannel:self
                            relationshipForRow:row
                            relationship:rel];
        rel = nrel ? nrel : (id)rel;
      }
      if ([rel isToMany]) {
        // Build to-many fault
        EOSQLQualifier* qualifier =
          [EOSQLQualifier qualifierForRow:row relationship:rel];
                
        if (qualifier == nil) {
          // HH: THROW was uncommented ..
	  [NSException raise:NSInvalidArgumentException
		       format:
			 @"Cannot build fault qualifier for relationship"];
          //    TODO    
          continue;
        }

#if LIB_FOUNDATION_LIBRARY
        if ([NSClassFromString([[rel destinationEntity] className])
                              isGarbageCollectable])
          fault = [EODatabaseFault gcArrayFaultWithQualifier:qualifier
                           fetchOrder:nil
                           databaseChannel:self
                           zone:_zone];
        else
#endif
          fault = [EODatabaseFault arrayFaultWithQualifier:qualifier
                           fetchOrder:nil
                           databaseChannel:self
                           zone:_zone];
      }
      else {
        // Build to-one fault
        EOEntity     *faultEntity;
        NSDictionary *faultKey;

        faultEntity = [rel         destinationEntity];
        faultKey    = [rel         foreignKeyForRow:row];
        faultKey    = [faultEntity primaryKeyForRow:faultKey];
                
        if (faultEntity == nil) {
	  [NSException raise:NSInvalidArgumentException
		       format:@"Cannot get entity for relationship"];
        }
        
        if (faultKey) {
          fault = [self->databaseContext objectForPrimaryKey:faultKey
                                         entity:faultEntity];
          if (fault == nil) {
            fault = [EODatabaseFault objectFaultWithPrimaryKey:faultKey
                                     entity:faultEntity
                                     databaseChannel:self
                                     zone:_zone];
            [databaseContext recordObject:fault 
                             primaryKey:faultKey
                             entity:faultEntity
                             snapshot:nil];
          }
        }
        else
          fault = [EONull null];
      }
            
      if (fault)
        [values setObject:fault forKey:[rel name]];
    }
  }
    
  // check if is updated in another context or just updated or new (delegate)
  dict = values;
  if ([[databaseContext database] isObject:object 
                                  updatedOutsideContext:databaseContext]) {
    if ([delegate respondsToSelector:
           @selector(databaseChannel:willRefetchConflictingObject:withSnapshot:)]) {
      dict = [delegate databaseChannel:self
                       willRefetchConflictingObject:object
                       withSnapshot:values];
    }
    else {
      [NSException raise:NSInvalidArgumentException
		   format:@"object updated in an uncommitted transaction "
		     @"was fetched"];
    }
  }
  else {
    if ([delegate respondsToSelector:
           @selector(databaseChannel:willRefetchObject:fromSnapshot:)]) {
      dict = [delegate databaseChannel:self
                       willRefetchObject:object
                       fromSnapshot:values];
    }
  }
  // does delegate disallow setting the new values and recording the fetch ?
  if (dict == nil)
    return object;
  
  // put values
  [object takeValuesFromDictionary:dict];
  
  // register lock if locked
  if ([databaseContext updateStrategy] == EOUpdateWithPessimisticLocking)
    [databaseContext recordLockedObject:object];
    
  // register object in context
  [databaseContext recordObject:object
                   primaryKey:pkey
                   entity:currentEntity
                   snapshot:snapshot];
    
  // awake object from database channel
  if ([object respondsToSelector:@selector(awakeForDatabaseChannel:)])
    [object awakeForDatabaseChannel:self];
  
  // Done.
  return object;
}

// ******************** Reporting errors ********************

- (void)privateReportError:(SEL)method :(NSString*)format,... {
  NSString* message;
  va_list va;
    
  if (![[databaseContext database] logsErrorMessages])
    return;
    
  va_start(va, format);
  message = AUTORELEASE([[NSString alloc] initWithFormat:format arguments:va]);
  va_end(va);
    
  [[databaseContext database]
                    reportErrorFormat:
                      @"EODatabaseChannel:error in [EODatabaseChannel %@]: %@",
                      NSStringFromSelector(method), message];
}

@end /* EODatabaseChannel */

@implementation NSObject(EODatabaseChannelEONotifications)

- (BOOL)prepareForDeleteInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx
{
  return YES;
}
- (void)wasDeletedInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx
{
}

- (BOOL)prepareForInsertInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx
{
  return YES;
}
- (void)wasInsertedInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx
{
}

- (BOOL)prepareForUpdateInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx
{
  return YES;
}
- (void)wasUpdatedInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx
{
}

- (BOOL)prepareForLockInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx
{
  return YES;
}
- (void)wasLockedInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx
{
}

@end /* NSObject(EODatabaseChannelNotifications) */

@implementation EODatabaseChannel(Statistics)

- (unsigned int)successfulOpenCount {
  return self->successfulOpenCount;
}

- (unsigned int)failedOpenCount {
  return self->failedOpenCount;
}

- (unsigned int)closeCount {
  return self->closeCount;
}

- (unsigned int)insertCount {
  return self->insertCount;
}

- (unsigned int)updateCount {
  return self->updateCount;
}

- (unsigned int)deleteCount {
  return self->deleteCount;
}

- (unsigned int)lockCount {
  return self->lockCount;
}

@end
