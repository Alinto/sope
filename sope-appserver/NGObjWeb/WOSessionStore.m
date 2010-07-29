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

#include <NGObjWeb/WOSessionStore.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOSession.h>
#include "common.h"

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (void)subclassResponsibility:(SEL)cmd;
@end
#endif

@implementation WOSessionStore

+ (int)version {
  return 2;
}

+ (WOSessionStore *)serverSessionStore {
  return
    [[[NSClassFromString(@"WOServerSessionStore") alloc] init] autorelease];
}

- (int)activeSessionsCount {
  [self subclassResponsibility:_cmd];
  return -1;
}

/* checkin/out */

- (id)checkOutSessionWithSessionID:(NSString *)_sid request:(WORequest *)_rq {
  WOSession *session;
  *(&session) = nil;
  
  SYNCHRONIZED(self) { // this must become a condition lock !!!
    if (![self->checkedOutSessions containsObject:_sid]) {
      if ((session = [self restoreSessionWithID:_sid]))
        [self->checkedOutSessions addObject:_sid];
    }
    else {
    }
  }
  END_SYNCHRONIZED;
  
  return session;
}

- (void)checkInSessionForContext:(WOContext *)_context {
  NSString *sid;
  *(&sid) = [[_context session] sessionID];
  
  SYNCHRONIZED(self) { // this must become a condition lock !!!
    [self saveSessionForContext:_context];
    
    if ([self->checkedOutSessions containsObject:sid])
      [self->checkedOutSessions removeObject:sid];
  }
  END_SYNCHRONIZED;
}

/* deprecated store */

- (void)saveSession:(WOSession *)_session {
  IS_DEPRECATED;
  [self saveSessionForContext:[_session context]];
}
- (id)restoreSessionWithID:(NSString *)_sid {
  IS_DEPRECATED;
  return [self restoreSessionWithID:_sid request:nil];
}

/* store (WO4) */

- (void)saveSessionForContext:(WOContext *)_context {
  [self subclassResponsibility:_cmd];
}
- (id)restoreSessionWithID:(NSString *)_sid request:(WORequest *)_request {
  [self subclassResponsibility:_cmd];
  return nil;
}

@end /* WOSessionStore */
