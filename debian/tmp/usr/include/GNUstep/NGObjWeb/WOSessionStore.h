/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGObjWeb_WOSessionStore_H__
#define __NGObjWeb_WOSessionStore_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSMapTable.h>

@class NSString, NSMutableSet, NSRecursiveLock, NSConditionLock, NSTimer;
@class WOSession, WOContext, WORequest;

@interface WOSessionStore : NSObject
{
@protected
  NSRecursiveLock *lock;
  NSConditionLock *checkoutLock;
  NSMutableSet    *checkedOutSessions;
}

+ (WOSessionStore *)serverSessionStore;

/* checkin/out */

- (id)checkOutSessionWithSessionID:(NSString *)_id
  request:(WORequest *)_request;

- (void)checkInSessionForContext:(WOContext *)_context;

/* store (WO4) */

- (id)restoreSessionWithID:(NSString *)_id request:(WORequest *)_request;

- (void)saveSessionForContext:(WOContext *)_context;

/* store (deprecated in WO4) */

- (void)saveSession:(WOSession *)_session; // deprecated in WO4
- (id)restoreSessionWithID:(NSString *)_id; // deprecated in WO4

@end

@interface WOSessionStore(PrivateMethods)

- (int)activeSessionsCount;
- (void)sessionExpired:(NSString *)_sessionID;
- (void)sessionTerminated:(WOSession *)_session;

@end

#endif /* __NGObjWeb_WOSessionStore_H__ */
