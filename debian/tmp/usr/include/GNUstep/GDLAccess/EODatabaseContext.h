/* 
   EODatabaseContext.h

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

#ifndef __EODatabaseContext_h__
#define __EODatabaseContext_h__

#import <Foundation/NSObject.h>
#import <GDLAccess/EODatabase.h>

@class NSArray, NSMutableArray, NSDictionary, NSMutableDictionary;
@class NSString, NSMutableString;
@class EOAdaptorContext;
@class EOEntity;
@class EOObjectUniquer, EODatabase, EODatabaseContext, EODatabaseChannel;

typedef enum {
    EOUpdateWithOptimisticLocking,
    EOUpdateWithPessimisticLocking,
    EOUpdateWithNoLocking,
    EONoUpdate,
} EOUpdateStrategy;

struct _EOTransactionScope;

extern NSString *EODatabaseContextWillBeginTransactionName;
extern NSString *EODatabaseContextDidBeginTransactionName;
extern NSString *EODatabaseContextWillRollbackTransactionName;
extern NSString *EODatabaseContextDidRollbackTransactionName;
extern NSString *EODatabaseContextWillCommitTransactionName;
extern NSString *EODatabaseContextDidCommitTransactionName;

struct EODatabaseContextModificationQueue;

@interface EODatabaseContext : NSObject < EOObjectRegistry >
//EOCooperatingObjectStore < EOObjectRegistry >
{
  EOAdaptorContext *adaptorContext;
  EODatabase       *database;
  NSMutableArray   *channels;
  EOUpdateStrategy updateStrategy;
  id               coordinator;
  id               delegate; /* non-retained */

  struct _EOTransactionScope *transactionStackTop;
  int                        transactionNestingLevel;
        
  // These fields should be in a bitfield but are ivars for debug purposes
  BOOL isKeepingSnapshots;
  BOOL isUniquingObjects;

  /* modified objects */
  struct EODatabaseContextModificationQueue *ops;

  /* statistics */
  unsigned int txBeginCount;
  unsigned int txCommitCount;
  unsigned int txRollbackCount;
}

// Initializing instances
- (id)initWithDatabase:(EODatabase *)aDatabase;

/* accessors */

- (void)setDelegate:(id)_delegate;
- (id)delegate;
- (EODatabase *)database;

// Getting the adaptor context
- (EOAdaptorContext*)adaptorContext;

// Finding channels
- (BOOL)hasBusyChannels;
- (BOOL)hasOpenChannels;
- (NSArray *)channels;
- (id)createChannel;

// Controlling transactions
- (BOOL)beginTransaction;
- (BOOL)commitTransaction;
- (BOOL)rollbackTransaction;

// Notifying of other transactions
- (void)transactionDidBegin;
- (void)transactionDidCommit;
- (void)transactionDidRollback;

// Nesting transactions
- (BOOL)canNestTransactions;
- (unsigned)transactionNestingLevel; 

// Setting the update strategy
- (void)setUpdateStrategy:(EOUpdateStrategy)aStrategy;
- (EOUpdateStrategy)updateStrategy;
- (BOOL)keepsSnapshots;

// Handle Objects

- (void)recordLockedObject:(id)anObj;
- (BOOL)isObjectLocked:(id)anObj;
- (void)recordUpdatedObject:(id)anObj;
- (BOOL)isObjectUpdated:(id)anObj;

@end /* EODatabaseContext */

@interface EODatabaseContext(Statistics)

- (unsigned int)transactionBeginCount;
- (unsigned int)transactionCommitCount;
- (unsigned int)transactionRollbackCount;

@end

/*
 * Methods used by database classess internally
 */

@interface EODatabaseContext(Private)
- (void)channelDidInit:(id)aChannel;
- (void)channelWillDealloc:(id)aChannel;
- (void)privateBeginTransaction;
- (void)privateCommitTransaction;
- (void)privateRollbackTransaction;
@end

@class EOModel;

@interface EODatabaseContext(NewInEOF2)

+ (void)setContextClassToRegister:(Class)_cclass;
+ (Class)contextClassToRegister;

#if 0
+ (EODatabaseContext *)registeredDatabaseContextForModel:(EOModel *)_model
  editingContext:(id)_ec;

- (id)coordinator;
#endif

/* managing channels */

- (EODatabaseChannel *)availableChannel;
- (NSArray *)registeredChannels;
- (void)registerChannel:(EODatabaseChannel *)_channel;
- (void)unregisterChannel:(EODatabaseChannel *)_channel;

@end

@class EOFetchSpecification;

@interface NSObject(EOF2DelegateMethods)

- (BOOL)databaseContext:(EODatabaseContext *)_ctx
  shouldSelectObjectsWithFetchSpecification:(EOFetchSpecification *)_fspec
  databaseChannel:(EODatabaseChannel *)_channel;

- (void)databaseContext:(EODatabaseContext *)_ctx
  didSelectObjectsWithFetchSpecification:(EOFetchSpecification *)_fspec
  databaseChannel:(EODatabaseChannel *)_channel;

- (BOOL)databaseContext:(EODatabaseContext *)_ctx
  shouldUsePessimisticLockWithFetchSpecification:(EOFetchSpecification *)_fspec
  databaseChannel:(EODatabaseChannel *)_channel;

@end

#endif /* __EODatabaseContext_h__ */
