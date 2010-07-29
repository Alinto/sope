/* 
   EODatabaseChannel.h

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

#ifndef __EODatabaseChannel_h__
#define __EODatabaseChannel_h__

#import <Foundation/NSObject.h>

@class NSArray, NSMutableArray, NSDictionary, NSMutableDictionary;
@class NSString, NSMutableString, NSNotificationCenter;
@class EOAdaptor, EOAdaptorContext, EOAdaptorChannel;
@class EOEntity, EOSQLQualifier, EORelationship;
@class EOObjectUniquer, EODatabase, EODatabaseContext;
@class EOGlobalID;

extern NSString *EODatabaseChannelWillOpenNotificationName;
extern NSString *EODatabaseChannelDidOpenNotificationName;
extern NSString *EODatabaseChannelCouldNotOpenNotificationName;
extern NSString *EODatabaseChannelWillCloseNotificationName;
extern NSString *EODatabaseChannelDidCloseNotificationName;
extern NSString *EODatabaseChannelWillInsertObjectName;
extern NSString *EODatabaseChannelDidInsertObjectName;
extern NSString *EODatabaseChannelWillUpdateObjectName;
extern NSString *EODatabaseChannelDidUpdateObjectName;
extern NSString *EODatabaseChannelWillDeleteObjectName;
extern NSString *EODatabaseChannelDidDeleteObjectName;
extern NSString *EODatabaseChannelWillLockObjectName;
extern NSString *EODatabaseChannelDidLockObjectName;

@interface EODatabaseChannel : NSObject
{
@private
  NSNotificationCenter *notificationCenter;
  EOAdaptorChannel  *adaptorChannel;
  EODatabaseContext *databaseContext;
  id                delegate;
  EOEntity          *currentEntity;
  Class             currentClass;
  NSArray           *currentAttributes;
  NSArray           *currentRelations;
  BOOL              currentReady;
  id                currentEditingContext;
  
  /* statistics */
  unsigned int successfulOpenCount;
  unsigned int failedOpenCount;
  unsigned int closeCount;
  unsigned int insertCount;
  unsigned int updateCount;
  unsigned int deleteCount;
  unsigned int lockCount;
}

// Initializing a new instance
- (id)initWithDatabaseContext:(EODatabaseContext*)aDatabaseContext;

// Getting the adaptor channel
- (EOAdaptorChannel*)adaptorChannel;

// Getting the database context
- (EODatabaseContext*)databaseContext;

// Setting the delegate
- (void)setDelegate:(id)aDelegate;
- (id)delegate;

// Opening and closing a channel
- (BOOL)isOpen;
- (BOOL)openChannel;
- (void)closeChannel;

// Modifying objects
- (BOOL)insertObject:(id)anObj;
- (BOOL)updateObject:(id)anObj;
- (BOOL)deleteObject:(id)anObj;
- (BOOL)lockObject:(id)anObj;
- (BOOL)refetchObject:(id)anObj;
- (id)allocateObjectForRow:(NSDictionary*)row
  entity:(EOEntity*)anEntity
  zone:(NSZone*)zone;
- (id)initializedObjectForRow:(NSDictionary*)row
  entity:(EOEntity*)anEntity
  zone:(NSZone*)zone;

// Fetching objects
- (BOOL)selectObjectsDescribedByQualifier:(EOSQLQualifier*)qualifier
  fetchOrder:(NSArray*)fetchOrder;
- (id)fetchWithZone:(NSZone*)zone;
- (BOOL)isFetchInProgress;
- (void)cancelFetch;
- (void)setCurrentEntity:(EOEntity*)anEntity;

@end /* EODatabaseChannel */

/* statistics */

@interface EODatabaseChannel(Statistics)
- (unsigned int)successfulOpenCount;
- (unsigned int)failedOpenCount;
- (unsigned int)closeCount;
- (unsigned int)insertCount;
- (unsigned int)updateCount;
- (unsigned int)deleteCount;
- (unsigned int)lockCount;
@end

/*
 * Delegate methods
 */

@interface NSObject(EODatabaseChannelDelegateProtocol)

- (id)databaseChannel:aChannel
  willInsertObject:anObj;
- (void)databaseChannel:aChannel
  didInsertObject:anObj;
- (id)databaseChannel:aChannel
  willDeleteObject:anObj;
- (void)databaseChannel:aChannel
  didDeleteObject:anObj;
- (id)databaseChannel:aChannel
  willUpdateObject:anObj;
- (void)databaseChannel:aChannel
  didUpdateObject:anObj;
- (NSDictionary*)databaseChannel:aChannel
  willRefetchObject:anObj;
- (NSDictionary*)databaseChannel:aChannel
  didRefetchObject:anObj;
- (NSDictionary*)databaseChannel:aChannel
  willRefetchObject:anObj
  fromSnapshot:(NSDictionary*)snapshot;
- (NSDictionary*)databaseChannel:aChannel
  willRefetchConflictingObject:anObj
  withSnapshot:(NSMutableDictionary*)snapshot;
- (BOOL)databaseChannel:aChannel
  willSelectObjectsDescribedByQualifier:(EOSQLQualifier*)qualifier
  fetchOrder:(NSArray*)fetchOrder;
- (void)databaseChannel:aChannel
  didSelectObjectsDescribedByQualifier:(EOSQLQualifier*)qualifier
  fetchOrder:(NSArray*)fetchOrder;
- (void)databaseChannel:aChannel
  willFetchObjectOfClass:(Class)class
  withZone:(NSZone*)zone;
- (void)databaseChannel:aChannel
  didFetchObject:anObj;
- databaseChannel:aChannel
  willLockObject:anObj;
- (void)databaseChannel:aChannel
  didLockObject:anObj;
- (Class)databaseChannel:aChannel
  failedToLookupClassNamed:(const char*)name;
- (EORelationship*)databaseChannel:aChannel
  relationshipForRow:(NSDictionary*)row 
  relationship:(EORelationship*)relationship;

@end

@interface NSObject(EODatabaseChannelEONotifications)

- (BOOL)prepareForDeleteInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx;
- (void)wasDeletedInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx;

- (BOOL)prepareForInsertInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx;
- (void)wasInsertedInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx;

- (BOOL)prepareForUpdateInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx;
- (void)wasUpdatedInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx;

- (BOOL)prepareForLockInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx;
- (void)wasLockedInChannel:(EODatabaseChannel *)_channel
  context:(EODatabaseContext *)_ctx;
  
@end

/*
 * Object Awaking (EODatabaseChannelNotification protocol)
 */

@interface NSObject(EODatabaseChannelNotification)
- (void)awakeForDatabaseChannel:(EODatabaseChannel*)channel;
@end

#endif /* __EODatabaseChannel_h__ */
