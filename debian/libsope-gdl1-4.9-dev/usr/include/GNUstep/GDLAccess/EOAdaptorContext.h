/* 
   EOAdaptorContext.h

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

#ifndef __EOAdaptorContext_h__
#define __EOAdaptorContext_h__

#import <Foundation/NSObject.h>

@class NSArray, NSMutableArray;

@class EOAdaptor;
@class EOAdaptorChannel;

/* The EOAdaptorContext class could be overriden for a concrete database
   adaptor. You have to override only those methods marked in this header
   with `override'.
*/

@interface EOAdaptorContext : NSObject
{
    EOAdaptor      *adaptor;
    NSMutableArray *channels;      // values with channels
    id             delegate;       // not retained
    int            transactionNestingLevel;

    /* Flags used to check if the delegate responds to several messages */
    struct {
      BOOL      willBegin:1;
      BOOL      didBegin:1;
      BOOL      willCommit:1;
      BOOL      didCommit:1;
      BOOL      willRollback:1;
      BOOL      didRollback:1;
    } delegateRespondsTo;
}

/* Initializing an adaptor context */
- (id)initWithAdaptor:(EOAdaptor*)adaptor;

/* Setting and getting the adaptor */
- (EOAdaptor*)adaptor;

/* Creating a new channel */
- (EOAdaptorChannel*)createAdaptorChannel;      // override
- (NSArray *)channels;

/* Checking connection status */
- (BOOL)hasOpenChannels;

/* Finding open channels */
- (BOOL)hasBusyChannels;

/* Controlling transactions */
- (BOOL)beginTransaction;
- (BOOL)commitTransaction;
- (BOOL)rollbackTransaction;

/* Notifying of other transactions */
- (void)transactionDidBegin;
- (void)transactionDidCommit;
- (void)transactionDidRollback;

/* Nesting transactions */
- (BOOL)canNestTransactions;         // override, deprecated
- (unsigned)transactionNestingLevel; // deprecated
- (BOOL)hasOpenTransaction;          // new in WO 4.5

/* Setting the delegate */
- (id)delegate;
- (void)setDelegate:(id)aDelegate;

/* Primary methods that control the transactions. This methods dont't call the
   delegate. You should implement these methods instead of the similar ones but
   without the `primary' prefix. */
- (BOOL)primaryBeginTransaction;                // override
- (BOOL)primaryCommitTransaction;               // override
- (BOOL)primaryRollbackTransaction;             // override

@end /* EOAdaptorContext*/


@interface EOAdaptorContext(Private)
- (void)channelDidInit:(id)aChannel;
- (void)channelWillDealloc:(id)aChannel;
@end

#import <GDLAccess/EODelegateResponse.h>

@interface NSObject(EOAdaptorContextDelegate)

- (EODelegateResponse)adaptorContextWillBegin:(id)aContext;
- (void)adaptorContextDidBegin:(id)aContext;
- (EODelegateResponse)adaptorContextWillCommit:(id)aContext;
- (void)adaptorContextDidCommit:(id)aContext;
- (EODelegateResponse)adaptorContextWillRollback:(id)aContext;
- (void)adaptorContextDidRollback:(id)aContext;

@end /* NSObject(EOAdaptorContextDelegate) */

#endif          /* __EOAdaptorContext_h__*/
