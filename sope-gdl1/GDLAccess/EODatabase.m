/* 
   EODatabase.m

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
#import "EODatabase.h"
#import "EOAdaptor.h"
#import "EOModel.h"
#import "EOEntity.h"
#import "EOGenericRecord.h"
#import "EODatabaseContext.h"
#import "EOObjectUniquer.h"
#import "EODatabaseFault.h"

NSTimeInterval NSDistantPastTimeInterval = 0.0;

@implementation EODatabase

// Database Global Methods

static NSMutableArray  *databaseInstances = nil;
static NSRecursiveLock *lock              = nil;

+ (void)initialize {
  static BOOL isInitialized = NO;
  // THREAD
  if (!isInitialized) {
    isInitialized = YES;
    databaseInstances = [[NSMutableArray alloc] init];
    lock              = [[NSRecursiveLock alloc] init];
  }
}

static inline void _addDatabaseInstance(EODatabase *_db) {
  [lock lock];
  [databaseInstances addObject:[NSValue valueWithNonretainedObject:_db]];
  [lock unlock];
}
static inline void _removeDatabaseInstance(EODatabase *_db) {
  [lock lock];
  {
    int i;
    
    for (i = [databaseInstances count] - 1; i >= 0; i--) {
      EODatabase *db;

      db = [[databaseInstances objectAtIndex:i] nonretainedObjectValue];
      if (db == _db) {
        [databaseInstances removeObjectAtIndex:i];
        break;
      }
    }
  }
  [lock unlock];
}

/*
 * Initializing new instances
 */

- (id)initWithAdaptor:(EOAdaptor *)_adaptor {
  if (_adaptor == nil) {
    AUTORELEASE(self);
    return nil;
  }
    
  self->adaptor           = RETAIN(_adaptor);
  self->objectsDictionary = [[EOObjectUniquer allocWithZone:[self zone]] init];
  self->contexts          = [[NSMutableArray  allocWithZone:[self zone]] init];
    
  self->flags.isUniquingObjects  = YES;
  self->flags.isKeepingSnapshots = YES;
  self->flags.isLoggingWarnings  = YES;

  _addDatabaseInstance(self);
    
  return self;
}

- (id)initWithModel:(EOModel *)_model {
  return [self initWithAdaptor:[EOAdaptor adaptorWithModel:_model]];
}
- (id)init {
  return [self initWithAdaptor:nil];
}

- (void)dealloc {
  _removeDatabaseInstance(self);
  
  RELEASE(self->adaptor);
  RELEASE(self->objectsDictionary);
  RELEASE(self->contexts);
  [super dealloc];
}

// accessors

- (EOAdaptor *)adaptor {
  return self->adaptor;
}

- (EOObjectUniquer *)objectUniquer {
  return self->objectsDictionary;
}

// Checking connection status

- (BOOL)hasOpenChannels {
  int i;
    
  for (i = ([self->contexts count] - 1); i >= 0; i--) {
    if ([[[self->contexts objectAtIndex:i] nonretainedObjectValue]
                          hasOpenChannels])
      return YES;
  }
  return NO;
}

/*
 * Getting the database contexts
 */

- (id)createContext {
  return AUTORELEASE([[EODatabaseContext alloc] initWithDatabase:self]);
}

- (NSArray *)contexts {
  NSMutableArray *array = nil;
  int i, n;

  n = [self->contexts count];
  array = [[NSMutableArray alloc] initWithCapacity:n];
    
  for (i = 0; i < n; i++) {
    EODatabaseContext *ctx;

    ctx = [[self->contexts objectAtIndex:i] nonretainedObjectValue];
    [array addObject:ctx];
  }
  return AUTORELEASE(array);
}

- (void)contextDidInit:(id)_context {
  [self->contexts addObject:[NSValue valueWithNonretainedObject:_context]];
}

- (void)contextWillDealloc:(id)aContext {
  int i;
    
  for (i = [self->contexts count]-1; i >= 0; i--) {
    if ([[self->contexts objectAtIndex:i] nonretainedObjectValue] == aContext) {
      [self->contexts removeObjectAtIndex:i];
      break;
    }
  }
}

/*
 * Uniquing/snapshotting
 */

- (void)setUniquesObjects:(BOOL)yn {
  if ([self hasOpenChannels]) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabase:%x: All channels must be closed when changing "
              @"uniquing mode in the EODatabase, "
              @"in [EODatabase setUniquesObjects:]",
		 self];
  }

  if ((!yn) && (self->flags.isUniquingObjects))
    [self->objectsDictionary forgetAllObjects];
  self->flags.isUniquingObjects = yn;
}
- (BOOL)uniquesObjects {
  return self->flags.isUniquingObjects;
}

- (void)setKeepsSnapshots:(BOOL)yn {
  if ([self hasOpenChannels]) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabase:%x: All channels must be closed when changing "
              @"snapshoting mode in the EODatabase, "
              @"in [EODatabase setKeepsSnapshots:]",
		 self];
  }

  if ((yn == NO) && self->flags.isKeepingSnapshots)
    [self->objectsDictionary forgetAllSnapshots];
  
  self->flags.isKeepingSnapshots = yn;
}
- (BOOL)keepsSnapshots {
  return self->flags.isKeepingSnapshots;
}

// ******************** Handle Objects ********************

- (void)forgetAllObjects {
  [self->objectsDictionary forgetAllObjects];
}

+ (void)forgetObject:(id)_object {
  static Class UniquerClass = Nil;
  if (UniquerClass == Nil) UniquerClass = [EOObjectUniquer class];
  [(EOObjectUniquer *)UniquerClass forgetObject:_object];

  [lock lock];
  {
    int i;
    
    for (i = [databaseInstances count] - 1; i >= 0; i--) {
      EODatabase *db;

      db = [[databaseInstances objectAtIndex:i] nonretainedObjectValue];
      [db forgetObject:_object];
    }
  }
  [lock unlock];
}

- (void)forgetObject:(id)_object {
  /*
    NSLog(@"DB[0x%p]: forget object 0x%p<%s> entity=%@",
        self, _object, class_get_class_name(*(Class *)_object),
        [[_object entity] name]);
  */
  [self->objectsDictionary forgetObject:_object];
}

- (void)forgetAllSnapshots {
  [self->objectsDictionary forgetAllSnapshots];
}

- (id)objectForPrimaryKey:(NSDictionary *)_key entity:(EOEntity *)_entity {
  if (self->flags.isUniquingObjects && (_key != nil) && (_entity != nil)) {
    _key = [_entity primaryKeyForRow:_key];
    if (_key == nil)
      return nil;
    else {
      id object = [self->objectsDictionary objectForPrimaryKey:_key entity:_entity];
      
#if 0
      if (object) {
        if (![object isKindOfClass:[EOGenericRecord class]])
          NSLog(@"object 0x%p pkey=%@ entity=%@", object, _key, _entity);
      }
#endif
      return object;
    }
  }
  return nil;
}

- (NSDictionary *)snapshotForObject:_object {
  EOUniquerRecord* rec = [self->objectsDictionary recordForObject:_object];
    
  return rec ? rec->snapshot : nil;
}

- (NSDictionary *)primaryKeyForObject:(id)_object {
  EOUniquerRecord* rec = [self->objectsDictionary recordForObject:_object];
    
  return rec ? rec->pkey : nil;
}

- (void)primaryKey:(NSDictionary**)_key
  andSnapshot:(NSDictionary**)_snapshot
  forObject:(id)_object {

  EOUniquerRecord *rec = [self->objectsDictionary recordForObject:_object];
    
  if (rec) {
    if (_key)      *_key      = rec->pkey;
    if (_snapshot) *_snapshot = rec->snapshot;
  }
  else {
    if (_key)      *_key      = nil;
    if (_snapshot) *_snapshot = nil;
  }
}

- (void)recordObject:(id)_object
  primaryKey:(NSDictionary *)_key
  snapshot:(NSDictionary *)_snapshot {

  EOEntity *entity;

  entity = [_object respondsToSelector:@selector(entity)]
    ? [_object entity]
    : [[self->adaptor model] entityForObject:_object];
    
  [self recordObject:_object
        primaryKey:_key
        entity:entity
        snapshot:_snapshot];
}

- (void)recordObject:(id)_object
  primaryKey:(NSDictionary *)_key
  entity:(EOEntity *)_entity
  snapshot:(NSDictionary *)_snapshot
{
  if (_object == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:
		   @"EODatabase:%x: Cannot record null object, "
  		   @"in [EODatabase recordObject:primaryKey:entity:snapshot:]",
		   self];
  }
  if ((_entity == nil) && self->flags.isUniquingObjects) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabase:%x: Cannot record object with null entity "
              @"when the database is uniquing objects, "
              @"in [EODatabase recordObject:primaryKey:entity:snapshot:]",
		 self];
  }
  _key = [_entity primaryKeyForRow:_key];
  if ((_key == nil) && self->flags.isUniquingObjects) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabase:%x: Cannot record object with null key "
              @"when the database is uniquing objects, "
              @"in [EODatabase recordObject:primaryKey:entity:snapshot:]",
		 self];
  }
  if ((_snapshot == nil) && self->flags.isKeepingSnapshots) {
    [NSException raise:NSInvalidArgumentException
		 format:
              @"EODatabase:%x: Cannot record object with null snapshot "
              @"when the database is keeping snapshots, "
              @"in [EODatabase recordObject:primaryKey:entity:snapshot:]",
		 self];
  }

  [objectsDictionary recordObject:_object 
                     primaryKey:
		       self->flags.isUniquingObjects ? _key:(NSDictionary *)nil
                     entity:self->flags.isUniquingObjects
		       ?_entity : (EOEntity *)nil
                     snapshot:
		       self->flags.isKeepingSnapshots
		       ? _snapshot : (NSDictionary *)nil];
}

- (BOOL)isObject:(id)_object 
  updatedOutsideContext:(EODatabaseContext *)_context 
{
  int i;
    
  for (i = [contexts count] - 1; i >= 0; i--) {
    EODatabaseContext *ctx;

    ctx = [[self->contexts objectAtIndex:i] nonretainedObjectValue];
        
    if ((ctx != _context) && [ctx isObjectUpdated:_object])
      return YES;
  }
  return NO;
}

// ******************** Error messages ********************
 
- (void)setLogsErrorMessages:(BOOL)yn {
  self->flags.isLoggingWarnings = yn;
}
- (BOOL)logsErrorMessages {
  return self->flags.isLoggingWarnings;
}

- (void)reportErrorFormat:(NSString*)format, ... {
  va_list va;
    
  va_start(va, format);
  [self reportErrorFormat:format arguments:va];
  va_end(va);
}

- (void)reportErrorFormat:(NSString*)format arguments:(va_list)arguments {
  [self reportError:AUTORELEASE([[NSString alloc] initWithFormat:format 
                                                  arguments:arguments])];
}

- (void)reportError:(NSString*)error {
  if (self->flags.isLoggingWarnings)
    NSLog(@"EODatabase:%x:%@", self, error);
}

@end /* EODatabase */

@implementation EODatabase(EOF2Additions)

- (NSArray *)models {
  EOModel *model;

  model = [[self adaptor] model];
  return model ? [NSArray arrayWithObject:model] : nil;
}

- (void)addModel:(EOModel *)_model {
  EOModel *model;

  model = [[self adaptor] model];

  if (model == nil)
    [[self adaptor] setModel:_model];
  else
    [self notImplemented:_cmd];
}

- (BOOL)addModelIfCompatible:(EOModel *)_model {
  NSEnumerator *e;
  EOModel *m;

  if (![[self adaptor] canServiceModel:_model])
    return NO;

  e = [[self models] objectEnumerator];
  while ((m = [e nextObject])) {
    if (m == _model)
      return YES;

    if (![[m adaptorName] isEqualToString:[_model adaptorName]])
      return NO;
  }
  
  [self addModel:_model];
  return YES;
}

- (EOEntity *)entityForObject:(id)_object {
  return [[[self adaptor] model] entityForObject:_object];
}
- (EOEntity *)entityNamed:(NSString *)_name {
  return [[[self adaptor] model] entityNamed:_name];
}

/* snapshots */

- (void)forgetSnapshotsForGlobalIDs:(NSArray *)_gids {
  NSEnumerator *e;
  EOGlobalID   *gid;

  e = [_gids objectEnumerator];
  while ((gid = [e nextObject]))
    [self forgetSnapshotsForGlobalID:gid];
}
- (void)forgetSnapshotsForGlobalID:(EOGlobalID *)_gid {
  [self notImplemented:_cmd];
}

- (void)recordSnapshot:(NSDictionary *)_snapshot forGlobalID:(EOGlobalID *)_gid {
  [self notImplemented:_cmd];
}
- (void)recordSnapshots:(NSDictionary *)_snapshots {
  NSEnumerator *gids;
  EOGlobalID   *gid;

  gids = [_snapshots keyEnumerator];
  while ((gid = [gids nextObject]))
    [self recordSnapshot:[_snapshots objectForKey:gid] forGlobalID:gid];
}

- (void)recordSnapshot:(NSArray *)_gids
  forSourceGlobalID:(EOGlobalID *)_gid
  relationshipName:(NSString *)_name
{
  /* to-many snapshot */
  [self notImplemented:_cmd];
}
- (void)recordToManySnapshots:(NSDictionary *)_snapshots {
  NSEnumerator *gids;
  EOGlobalID   *gid;

  gids = [_snapshots keyEnumerator];
  while ((gid = [gids nextObject])) {
    NSDictionary *d;
    NSEnumerator *relNames;
    NSString     *relName;
    
    d = [_snapshots objectForKey:gid];
    relNames = [d keyEnumerator];

    while ((relName = [relNames nextObject])) {
      [self recordSnapshot:[d objectForKey:relName]
            forSourceGlobalID:gid
            relationshipName:relName];
    }
  }
}

- (NSDictionary *)snapshotForGlobalID:(EOGlobalID *)_gid
  after:(NSTimeInterval)_duration
{
  NSLog(@"ERROR(%s): subclasses must override this method!",
	__PRETTY_FUNCTION__);
  return nil;
}

- (NSDictionary *)snapshotForGlobalID:(EOGlobalID *)_gid {
  return [self snapshotForGlobalID:_gid after:NSDistantPastTimeInterval];
}

@end /* EODatabase(EOF2Additions) */
