/* 
   EODatabaseFaultResolver.m

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
#import "EODatabaseFaultResolver.h"
#import "EODatabaseChannel.h"
#import "EODatabaseContext.h"
#import "EOEntity.h"
#import "EODatabaseFault.h"
#import "EOSQLQualifier.h"
#import "EOGenericRecord.h"

@implementation EODatabaseFaultResolver

- (id)initWithDatabaseChannel:(EODatabaseChannel *)aChannel
  zone:(NSZone *)aZone  
  targetClass:(Class)_targetClass 
{
  if ((self = [super init])) {
    self->channel         = aChannel;
    self->targetClass     = _targetClass;
    self->zone            = aZone;
    self->faultReferences = 0;
  }
  return self;
}

- (BOOL)fault {
  return NO;
}

- (EODatabaseChannel *)databaseChannel {
  return self->channel;
}

- (Class)targetClass; {
  return self->targetClass;
}

- (NSDictionary *)primaryKey {
  return nil;
}
- (EOEntity *)entity {
  return nil;
}
- (EOSQLQualifier *)qualifier {
  return nil;
}
- (NSArray *)fetchOrder {
  return nil;
}

@end /* EODatabaseFaultResolver */

@implementation EOArrayFault

- (id)initWithQualifier:(EOSQLQualifier *)aQualifier
  fetchOrder:(NSArray *)aFetchOrder 
  databaseChannel:(EODatabaseChannel *)aChannel 
  zone:(NSZone *)aZone  
  targetClass:(Class)_targetClass 
{
  
  if ((self = [super initWithDatabaseChannel:aChannel zone:aZone 
                     targetClass:_targetClass])) {
    self->qualifier  = RETAIN(aQualifier);
    self->fetchOrder = RETAIN(aFetchOrder);

    NSAssert([(NSObject *)self->targetClass isKindOfClass:[NSArray class]],
             @"target class of an array fault is not an array class");
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->qualifier);
  RELEASE(self->fetchOrder);
  [super dealloc];
}

- (EOEntity *)entity {
  return [self->qualifier entity];
}

- (EOSQLQualifier *)qualifier {
  return self->qualifier;
}

- (NSArray *)fetchOrder {
  return self->fetchOrder;
}

- (void)completeInitializationOfObject:(id)_fault {
  unsigned int oldRetainCount;
  BOOL         inTransaction;

  NSAssert([(NSObject *)self->targetClass isKindOfClass:[NSArray class]],
           @"target class of an array fault is not an array class");
  
  oldRetainCount = [_fault retainCount];
    
  [EOFault clearFault:_fault];
  NSAssert([(id)_fault init] == _fault, @"init modified fault reference ..");

  NSAssert([_fault isKindOfClass:[NSArray class]],
           @"resolved-object of an array fault is not of an array class");
  
  if ([self->channel isFetchInProgress]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"attempt to fault with busy channel: %@", self];
  }
    
  inTransaction = [[self->channel databaseContext] transactionNestingLevel] > 0;
  if (!inTransaction) {
    if (![[self->channel databaseContext] beginTransaction]) {
      [NSException raise:@"DBFaultResolutionException"
                   format:@"could not begin transaction to resolve fault !"];
    }
  }
    
  if (![self->channel selectObjectsDescribedByQualifier:self->qualifier
                      fetchOrder:self->fetchOrder]) {
    if (!inTransaction)
      [[self->channel databaseContext] rollbackTransaction];
    [NSException raise:@"DBFaultResolutionException"
                 format:@"select for fault failed !"];
  }

  { // fetch objects
    id object;
    
    while ((object = [self->channel fetchWithZone:zone])) {
      if (![object isKindOfClass:[EOGenericRecord class]]) {
        NSLog(@"Object is of class %@", NSStringFromClass([object class]));
        abort();
      }
      NSAssert([object isKindOfClass:[EOGenericRecord class]],
               @"fetched object is not a EOGenericRecord ..");
      [(id)_fault addObject:object];
    }

    object = nil;
  }
    
  [self->channel cancelFetch];

  if (!inTransaction) {
    if (![[self->channel databaseContext] commitTransaction]) {
      NSLog(@"WARNING: could not commit fault's transaction !");
      [NSException raise:@"DBFaultResolutionException"
                   format:@"could not commit fault's transaction !"];
    }
  }

#if MOF2_DEBUG
  if ([fault retainCount] != oldRetainCount) {
    NSLog(@"fault retain count does not match replacement (old=%d, new=%d)",
          oldRetainCount, [fault retainCount]);
  }
#endif

  NSAssert([_fault retainCount] == oldRetainCount,
           @"fault retain count does not match replacement's retain count");
}

- (NSString *)descriptionForObject:(id)_fault {
  return [NSString stringWithFormat:
                   @"<Array fault 0x%x (qualifier=%@, order=%@, channel=%@)>",
                   _fault, qualifier, fetchOrder, channel];
}

@end /* EOArrayFault */

@implementation EOObjectFault

- (id)initWithPrimaryKey:(NSDictionary *)_key
  entity:(EOEntity *)anEntity 
  databaseChannel:(EODatabaseChannel *)aChannel 
  zone:(NSZone *)aZone  
  targetClass:(Class)_targetClass 
{
  [super initWithDatabaseChannel:aChannel
         zone:aZone 
         targetClass:_targetClass];
  self->entity     = RETAIN(anEntity);
  self->primaryKey = RETAIN(_key);
  return self;
}

- (void)dealloc {
  RELEASE(self->entity);
  RELEASE(self->primaryKey);
  [super dealloc];
}

- (NSDictionary*)primaryKey {
  return self->primaryKey;
}

- (EOEntity *)entity {
  return self->entity;
}

- (void)completeInitializationOfObject:(id)_fault {
  EOSQLQualifier *qualifier = nil;
  BOOL        channelIsOpen = YES;
  BOOL        inTransaction = YES;
  id          object = nil;
    
  if ([self->channel isFetchInProgress]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"attempt to fault with busy channel: %@", self];
  }
  
  qualifier =
    [EOSQLQualifier qualifierForPrimaryKey:primaryKey entity:self->entity];
  if (qualifier == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:@"could not build qualifier for fault: %@", self];
  }

  channelIsOpen = [self->channel isOpen];
  if (!channelIsOpen) {
    if (![self->channel openChannel])
      goto done;
  }

  inTransaction = [[self->channel databaseContext] transactionNestingLevel] != 0;
  if (!inTransaction) {
    if (![[self->channel databaseContext] beginTransaction]) {
      if (!channelIsOpen) [self->channel closeChannel];
      goto done;
    }
  }
    
  if (![self->channel selectObjectsDescribedByQualifier:qualifier fetchOrder:nil]) {
    if (!inTransaction) {
      [[self->channel databaseContext] rollbackTransaction];
      if (!channelIsOpen) [self->channel closeChannel];
    }
    goto done;
  }

  // Fetch the object
  object = [self->channel fetchWithZone:zone];

  // The fetch failed!
  if (object == nil) {
    [self->channel cancelFetch];
    if (!inTransaction) [[self->channel databaseContext] rollbackTransaction];
    if (!channelIsOpen) [self->channel closeChannel];
    goto done;
  }

  // Make sure we only fetched one object
  if ([self->channel fetchWithZone:zone])
    object = nil;
    
  [self->channel cancelFetch];
    
  if (!inTransaction) {
    if (![[self->channel databaseContext] commitTransaction]) object = nil;
    if (!channelIsOpen) [self->channel closeChannel];
  }

 done:
  if (object != _fault) {
    if ([EOFault isFault:_fault])
      [EOFault clearFault:_fault];
    
    [(id)_fault unableToFaultWithPrimaryKey:primaryKey 
                entity:self->entity
                databaseChannel:self->channel];
  }
}

- (NSString *)descriptionForObject:(id)_fault {
  return [NSString stringWithFormat:
                     @"<Object fault 0x%X "
                     @"(class=%@, entity=%@, key=%@, channel=%@)>",
                     _fault,
                     NSStringFromClass(targetClass), 
                     [entity name], 
                     [primaryKey description], 
                     [channel description]];
}

@end /* EOObjectFault */
