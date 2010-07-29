/* 
   EOAdaptorContext.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

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

#import <Foundation/NSValue.h>
#import <Foundation/NSArray.h>

#import "common.h"
#import "EOAdaptor.h"
#import "EOAdaptorContext.h"
#import "EOAdaptorChannel.h"

@implementation EOAdaptorContext

- (id)initWithAdaptor:(EOAdaptor *)_adaptor {
  ASSIGN(self->adaptor, _adaptor);
  self->channels = [[NSMutableArray alloc] initWithCapacity:2];
  [self->adaptor contextDidInit:self];
  return self;
}

- (void)dealloc {
  [self->adaptor contextWillDealloc:self];
  [self->adaptor  release];
  [self->channels release];
  [super dealloc];
}

/* channels */

- (EOAdaptorChannel *)createAdaptorChannel {
  return [[[[adaptor adaptorChannelClass] alloc]
	    initWithAdaptorContext:self] autorelease];
}
- (NSArray *)channels {
  NSMutableArray *ma;
  unsigned i, count;
  
  if ((count = [self->channels count]) == 0)
    return nil;

  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++)
    [ma addObject:[[self->channels objectAtIndex:i] nonretainedObjectValue]];
  
  return ma;
}

- (void)channelDidInit:aChannel {
  [self->channels addObject:[NSValue valueWithNonretainedObject:aChannel]];
}

- (void)channelWillDealloc:(id)aChannel {
    int i;
    
    for (i = [self->channels count] - 1; i >= 0; i--)
        if ([[channels objectAtIndex:i] nonretainedObjectValue] == aChannel) {
            [channels removeObjectAtIndex:i];
            break;
        }
}

- (BOOL)hasOpenChannels {
    int i, count = [channels count];

    for (i = 0; i < count; i++)
        if ([[[channels objectAtIndex:i] nonretainedObjectValue] isOpen])
            return YES;

    return NO;
}

- (BOOL)hasBusyChannels {
    int i, count = [channels count];

    for (i = 0; i < count; i++)
        if ([[[channels objectAtIndex:i] nonretainedObjectValue]
                isFetchInProgress])
            return YES;

    return NO;
}

/* transactions */

- (BOOL)beginTransaction {
    if (transactionNestingLevel && ![self canNestTransactions])
        return NO;

    if ([self->channels count] == 0)
        return NO;

    if (delegateRespondsTo.willBegin) {
        EODelegateResponse response = [delegate adaptorContextWillBegin:self];
        if (response == EODelegateRejects)
            return NO;
        else if (response == EODelegateOverrides)
            return YES;
    }
    if ([self primaryBeginTransaction] == NO)
        return NO;

    [self transactionDidBegin];

    if (delegateRespondsTo.didBegin)
        [delegate adaptorContextDidBegin:self];
    return YES;
}

- (BOOL)commitTransaction {
    if (!transactionNestingLevel || [self hasBusyChannels])
        return NO;

    if (![channels count])
        return NO;

    if (delegateRespondsTo.willCommit) {
        EODelegateResponse response = [delegate adaptorContextWillCommit:self];
        if (response == EODelegateRejects)
            return NO;
        else if (response == EODelegateOverrides)
            return YES;
    }

    if ([self primaryCommitTransaction] == NO)
        return NO;

    [self transactionDidCommit];

    if (delegateRespondsTo.didCommit)
        [delegate adaptorContextDidCommit:self];
    return YES;
}

- (BOOL)rollbackTransaction {
    if (!transactionNestingLevel || [self hasBusyChannels])
        return NO;

    if (![channels count])
        return NO;

    if (delegateRespondsTo.willRollback) {
        EODelegateResponse response
                = [delegate adaptorContextWillRollback:self];
        if (response == EODelegateRejects)
            return NO;
        else if (response == EODelegateOverrides)
            return YES;
    }

    if ([self primaryRollbackTransaction] == NO)
        return NO;

    [self transactionDidRollback];

    if (delegateRespondsTo.didRollback)
        [delegate adaptorContextDidRollback:self];
    return YES;
}

- (void)transactionDidBegin {
    /* Increment the transaction scope */
    transactionNestingLevel++;
}

- (void)transactionDidCommit {
    /* Decrement the transaction scope */
    transactionNestingLevel--;
}

- (void)transactionDidRollback {
    /* Decrement the transaction scope */
    transactionNestingLevel--;
}

/* delegate */

- (void)setDelegate:(id)_delegate {
    self->delegate = _delegate;

    delegateRespondsTo.willBegin = 
        [delegate respondsToSelector:@selector(adaptorContextWillBegin:)];
    delegateRespondsTo.didBegin = 
        [delegate respondsToSelector:@selector(adaptorContextDidBegin:)];
    delegateRespondsTo.willCommit = 
        [delegate respondsToSelector:@selector(adaptorContextWillCommit:)];
    delegateRespondsTo.didCommit = 
        [delegate respondsToSelector:@selector(adaptorContextDidCommit:)];
    delegateRespondsTo.willRollback = 
        [delegate respondsToSelector:@selector(adaptorContextWillRollback:)];
    delegateRespondsTo.didRollback =
        [delegate respondsToSelector:@selector(adaptorContextDidRollback:)];
}
- (id)delegate {
    return self->delegate;
}

/* adaptor */

- (EOAdaptor *)adaptor {
  return self->adaptor;
}

/* transactions */

- (BOOL)canNestTransactions {
  /* deprecated in WO 4.5 */
  return NO;
}
- (unsigned)transactionNestingLevel {
  /* deprecated in WO 4.5 */
  return self->transactionNestingLevel;
}
- (BOOL)hasOpenTransaction {
  /* new in WO 4.5 */
  return self->transactionNestingLevel > 0 ? YES : NO;
}

- (BOOL)primaryBeginTransaction {
    return NO;
}

- (BOOL)primaryCommitTransaction {
    return NO;
}

- (BOOL)primaryRollbackTransaction {
    return NO;
}

@end /* EOAdaptorContext */
