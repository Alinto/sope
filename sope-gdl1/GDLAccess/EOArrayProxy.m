/* 
   EOArrayProxy.m

   Copyright (C) 1999 MDlink online service center GmbH, Helge Hess

   Author: Helge Hess (hh@mdlink.de)
   Date:   1999

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
// $Id: EOArrayProxy.m 1 2004-08-20 10:38:46Z znek $

#import "common.h"
#import "EOArrayProxy.h"
#import "EODatabaseChannel.h"
#import "EODatabaseContext.h"
#import "EOEntity.h"
#import "EOSQLQualifier.h"
#import "EOGenericRecord.h"

@implementation EOArrayProxy

- (id)initWithQualifier:(EOSQLQualifier *)_qualifier
  fetchOrder:(NSArray *)_fetchOrder
  channel:(EODatabaseChannel *)_channel
{
  self->qualifier  = RETAIN(_qualifier);
  self->fetchOrder = RETAIN(_fetchOrder);
  self->channel    = RETAIN(_channel);
  return self;
}

+ (id)arrayProxyWithQualifier:(EOSQLQualifier *)_qualifier
  fetchOrder:(NSArray *)_fetchOrder
  channel:(EODatabaseChannel *)_channel
{
  return AUTORELEASE([[self alloc] initWithQualifier:_qualifier
                                   fetchOrder:_fetchOrder
                                   channel:_channel]);
}

- (void)dealloc {
  AUTORELEASE(self->content);
  RELEASE(self->qualifier);
  RELEASE(self->fetchOrder);
  RELEASE(self->channel);
  [super dealloc];
}

// accessors

- (BOOL)isFetched {
  return self->content ? YES : NO;
}

- (EODatabaseChannel *)databaseChannel {
  return self->channel;
}
- (EOEntity *)entity {
  return [self->qualifier entity];
}
- (NSArray *)fetchOrder {
  return self->fetchOrder;
}
- (EOSQLQualifier *)qualifier {
  return self->qualifier;
}

// operations

- (void)clear {
  RELEASE(self->content);
  self->content = nil;
}

- (BOOL)fetch {
  BOOL           inTransaction;
  BOOL           didOpenChannel;
  NSMutableArray *result;
  
  [self clear];
  result = [NSMutableArray arrayWithCapacity:16];

  didOpenChannel = (![self->channel isOpen])
    ? [self->channel openChannel]
    : NO;
    
  if ([self->channel isFetchInProgress]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"attempt to fetch with busy channel: %@", self];
  }

  inTransaction = 
    [[self->channel databaseContext] transactionNestingLevel] > 0;
  if (!inTransaction) {
    if (![[self->channel databaseContext] beginTransaction]) {
      NSLog(@"WARNING: could not begin transaction to fetch array proxy !");

      if (didOpenChannel)
        [self->channel closeChannel];
      return NO;
    }
  }
    
  if (![self->channel selectObjectsDescribedByQualifier:self->qualifier
                      fetchOrder:self->fetchOrder]) {
    if (!inTransaction)
      [[self->channel databaseContext] rollbackTransaction];
    if (didOpenChannel)
      [self->channel closeChannel];
    
    NSLog(@"ERROR: select on array proxy failed ..");
    return NO;
  }

  { // fetch objects
    NSZone *z = [self zone];
    id object;
    
    while ((object = [self->channel fetchWithZone:z]))
      [result addObject:object];
    object = nil;
  }
  [self->channel cancelFetch];

  if (!inTransaction) {
    if (![[self->channel databaseContext] commitTransaction]) {
      NSLog(@"WARNING: could not commit array proxy's transaction !");
      
      if (didOpenChannel)
        [self->channel closeChannel];
      return NO;
    }
  }

  if (didOpenChannel)
    [self->channel closeChannel];
  
  self->content = [result copyWithZone:[self zone]];
  return YES;
}

// turn fault to real array ..

void _checkFetch(EOArrayProxy *self) {
  if (self->content) return;
  [self fetch];
}

// NSArray operations

- (id)objectAtIndex:(unsigned int)_index {
  _checkFetch(self);
  return [self->content objectAtIndex:_index];
}
- (unsigned int)count {
  _checkFetch(self);
  return [self->content count];
}
- (BOOL)isNotEmpty {
  _checkFetch(self);
  return [self->content count] > 0 ? YES : NO;
}
- (unsigned int)indexOfObjectIdenticalTo:(id)_object {
  _checkFetch(self);
  return [self->content indexOfObjectIdenticalTo:_object];
}

// NSCopying

- (id)copyWithZone:(NSZone*)zone {
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else {
    _checkFetch(self);
    return [[NSArray allocWithZone:zone] initWithArray:self->content copyItems:NO];
  }
}

- (id)mutableCopyWithZone:(NSZone*)zone {
  _checkFetch(self);
  return [[NSMutableArray alloc] initWithArray:self->content];
}


#if 0

// forwarding

- (void)forwardInvocation:(NSInvocation *)_invocation {
  _checkFetch(self);
  [_invocation invokeWithTarget:self->content];
}

- (retval_t)forward:(SEL)_selector:(arglist_t)_frame {
  _checkFetch(self);
  return objc_msg_sendv(self->content, _selector, _frame);
}

#endif

@end
