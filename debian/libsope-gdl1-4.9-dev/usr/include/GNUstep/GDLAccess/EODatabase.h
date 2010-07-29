/* 
   EODatabase.h

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

#ifndef __eoaccess_EODatabase_h__
#define __eoaccess_EODatabase_h__

#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>

@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSMutableDictionary;
@class NSString;
@class NSMutableString;

@class EOAdaptor;
@class EOModel;
@class EOEntity;

@class EOObjectUniquer;
@class EODatabase, EODatabaseContext, EODatabaseChannel;

@protocol EOObjectRegistry

- (void)forgetObject:(id)anObj;
- (id)objectForPrimaryKey:(NSDictionary *)aKey entity:(EOEntity *)anEntity;

/* retrieving snapshots and primary keys */

- (NSDictionary *)snapshotForObject:(id)anObj;
- (NSDictionary *)primaryKeyForObject:(id)anObj;
- (void)primaryKey:(NSDictionary **)aKey
  andSnapshot:(NSDictionary **)aSnapshot
  forObject:(id)anObj;

/* recording objects */

- (void)recordObject:(id)anObj
  primaryKey:(NSDictionary *)aKey 
  snapshot:(NSDictionary *)aSnapshot;

- (void)recordObject:(id)anObj
  primaryKey:(NSDictionary *)aKey
  entity:(EOEntity *)anEntity
  snapshot:(NSDictionary *)aSnapshot;

@end

@interface EODatabase : NSObject < EOObjectRegistry >
{
  @private
    EOAdaptor       *adaptor;
    EOObjectUniquer *objectsDictionary;
    NSMutableArray  *contexts;
    
    struct {
        BOOL isUniquingObjects:1;
        BOOL isKeepingSnapshots:1;
        BOOL isLoggingWarnings:1;
    } flags;
}

// Initializing new instances
- (id)initWithAdaptor:(EOAdaptor *)anAdaptor;
- (id)initWithModel:(EOModel *)aModel;

// Getting the adaptor
- (EOAdaptor*)adaptor;

// Getting the database contexts
- (id)createContext;
- (NSArray*)contexts;

// Checking connection status
- (BOOL)hasOpenChannels;

// Uniquing/snapshotting
- (void)setUniquesObjects:(BOOL)yn;
- (BOOL)uniquesObjects;
- (void)setKeepsSnapshots:(BOOL)yn;
- (BOOL)keepsSnapshots;

// Handle Objects
+ (void)forgetObject:(id)anObj;
- (void)forgetAllObjects;
- (void)forgetAllSnapshots;

- (BOOL)isObject:(id)anObj updatedOutsideContext:(EODatabaseContext *)aContext;

// Error messages
- (BOOL)logsErrorMessages;
- (void)setLogsErrorMessages:(BOOL)yn;
- (void)reportError:(NSString*)error;
- (void)reportErrorFormat:(NSString*)format, ...;
- (void)reportErrorFormat:(NSString*)format arguments:(va_list)arguments;

@end /* EODatabase */

/*
 * Methods used by database classes internally
 */

@interface EODatabase(Private)
- (void)contextDidInit:(id)aContext;
- (void)contextWillDealloc:(id)aContext;
- (EOObjectUniquer*)objectUniquer;
@end

@class EOGlobalID;

extern NSTimeInterval NSDistantPastTimeInterval;

@interface EODatabase(EOF2Additions)

/* models */

- (NSArray *)models;
- (void)addModel:(EOModel *)_model;
- (BOOL)addModelIfCompatible:(EOModel *)_model;

/* entities */

- (EOEntity *)entityForObject:(id)_object;
- (EOEntity *)entityNamed:(NSString *)_name;

/* snapshots */

- (void)recordSnapshot:(NSDictionary *)_snapshot forGlobalID:(EOGlobalID *)_gid;
- (void)recordSnapshots:(NSDictionary *)_snapshots;

- (void)recordSnapshot:(NSArray *)_gids
  forSourceGlobalID:(EOGlobalID *)_gid
  relationshipName:(NSString *)_name;
- (void)recordToManySnapshots:(NSDictionary *)_snapshots;

- (NSDictionary *)snapshotForGlobalID:(EOGlobalID *)_gid
  after:(NSTimeInterval)_duration;
- (NSDictionary *)snapshotForGlobalID:(EOGlobalID *)_gid;

- (void)forgetSnapshotsForGlobalIDs:(NSArray *)_gids;
- (void)forgetSnapshotsForGlobalID:(EOGlobalID *)_gid;

@end

#endif /* __eoaccess_EODatabase_h__ */
