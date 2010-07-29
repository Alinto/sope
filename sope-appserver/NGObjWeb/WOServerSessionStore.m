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

/*
  The default session store. It stores all the sessions in memory
  (it's basically a simple hashmap of the session-id to the session object).

  If the application goes down, all sessions will go down - this store
  doesn't provide "session-failover".
*/

@interface WOServerSessionStore : WOSessionStore
{
  NSMapTable *idToSession;
  NSMapTable *activeSessions;
}
@end

#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOSession.h>
#include "common.h"

/* hh: moved in here from application, check whether it's required ... */
@interface WOSessionInfo : NSObject
{
@private
  NSString *sessionID;
  NSDate   *timeoutDate;
}

+ (WOSessionInfo *)infoForSession:(WOSession *)_session;

- (NSString *)sessionID;
- (NSDate *)timeoutDate;

@end

@implementation WOServerSessionStore

static BOOL logExpiredSessions = NO;

+ (int)version {
  return [super version] + 0;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)init {
  if ((self = [super init])) {
    self->idToSession = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                         NSObjectMapValueCallBacks,
                                         128);
    self->activeSessions = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                            NSObjectMapValueCallBacks,
                                            128);
    self->checkedOutSessions = [[NSMutableSet allocWithZone:[self zone]]
                                              initWithCapacity:64];
    
    if ([[[NSUserDefaults standardUserDefaults]
                          objectForKey:@"WORunMultithreaded"]
                          boolValue]) {
      self->lock         = [[NSRecursiveLock allocWithZone:[self zone]] init];
      self->checkoutLock = [[NSConditionLock allocWithZone:[self zone]]
                                             initWithCondition:0];
    }
  }
  return self;
}

- (void)dealloc {
  if (self->activeSessions) {
    NSFreeMapTable(self->activeSessions);
    self->activeSessions = NULL;
  }
  if (self->idToSession) {
    NSFreeMapTable(self->idToSession);
    self->idToSession = NULL;
  }
  [self->checkedOutSessions release];
  [self->checkoutLock       release];
  [self->lock               release];
  [super dealloc];
}

/* accessors */

- (int)activeSessionsCount {
  int count;
  
  [self->lock lock];
  count = NSCountMapTable(self->idToSession);
  [self->lock unlock];

  return count;
}

/* store */

- (void)saveSessionForContext:(WOContext *)_context {
  if (![_context hasSession])
    return;
  
  [self->lock lock];
  {
    WOSession *sn = [_context session];
      
    if ([sn isTerminating]) {
      sn = [sn retain];
        
      NSMapRemove(self->idToSession,    [sn sessionID]);
      NSMapRemove(self->activeSessions, [sn sessionID]);
        
      NSLog(@"session %@ terminated at %@ ..",
	    [sn sessionID], [NSCalendarDate calendarDate]);
        
      [sn release]; sn = nil;
    }
    else {
      WOSessionInfo *info;
        
      NSMapInsert(self->idToSession, [sn sessionID], sn);
        
      info = [WOSessionInfo infoForSession:sn];
      NSMapInsert(self->activeSessions, [sn sessionID], info);
    }
  }
  [self->lock unlock];
}

- (id)restoreSessionWithID:(NSString *)_sid request:(WORequest *)_request {
  WOSession *session = nil;

  if ([_sid length] == 0)
    return nil;
  
  if (![_sid isKindOfClass:[NSString class]]) {
    [self warnWithFormat:@"%s: got invalid session id (expected string !): %@",
            __PRETTY_FUNCTION__, _sid];
    return nil;
  }
  
  if ([_sid isEqualToString:@"expired"])
    return nil;

  [self->lock lock];
  session = NSMapGet(self->idToSession, _sid);
  [self->lock unlock];

  if (logExpiredSessions) {
    if (session == nil)
      [self logWithFormat:@"session with id %@ expired.", _sid];
  }

  return session;
}

/* termination */

- (void)sessionExpired:(NSString *)_sessionID {
  [self->lock lock];
  NSMapRemove(self->idToSession, _sessionID);
  [self->lock unlock];
}

- (void)sessionTerminated:(WOSession *)_session {
  _session = [_session retain];
  [self->lock lock];
  NSMapRemove(self->idToSession, [_session sessionID]);
  [self->lock unlock];
  [_session release];
  
  [[WOApplication application]
                  logWithFormat:
                    @"WOServerSessionStore: session %@ terminated.",
                    [_session sessionID]];
}

/* expiration check */

- (void)performExpirationCheck:(NSTimer *)_timer {
  NSNotificationCenter *nc;
  NSMutableArray  *timedOut = nil;
  NSMapEnumerator e;
  NSString        *sid  = nil;
  WOSessionInfo   *info = nil;
  NSDate          *now;
  unsigned cnt, count;
    
  //NSLog(@"%s: perform expiration check ...", __PRETTY_FUNCTION__);
  
  if (self->activeSessions == NULL)
    count = 0;
  else
    count = NSCountMapTable(self->activeSessions);
  
  if (!(count > 0 && (self->activeSessions != NULL)))
    return;
  
  e   = NSEnumerateMapTable(self->activeSessions);
  now = [NSDate date];
      
  /* search for expired sessions */
  while (NSNextMapEnumeratorPair(&e, (void **)&sid, (void **)&info)) {
    NSDate *timeOutDate = [info timeoutDate];
    
    if (timeOutDate == nil) continue;

    if ([now compare:timeOutDate] != NSOrderedAscending) {
        [self logWithFormat:@"session %@ expired at %@.", sid, now];
          
        if (timedOut == nil)
          timedOut = [NSMutableArray arrayWithCapacity:32];
        [timedOut addObject:info];
    }
  }
      
  /* Expire sessions */
  if (!timedOut)
    return;

  nc = [NSNotificationCenter defaultCenter];
        
  for (cnt = 0, count = [timedOut count]; cnt < count; cnt++) {
    NSString *sid;
          
    info = [timedOut objectAtIndex:cnt];
    sid  = [[info sessionID] copy];
          
    NSMapRemove(self->activeSessions, sid);
    NSMapRemove(self->idToSession,    sid);
          
    [nc postNotificationName:WOSessionDidTimeOutNotification
	object:sid];
    
    [sid release];
  }
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: active=%i>",
                     NSStringFromClass([self class]), self,
                     [self activeSessionsCount]
                   ];
}

@end /* WOServerSessionStore */

@implementation WOSessionInfo

- (id)initWithSession:(WOSession *)_session {
  self->sessionID = RETAIN([_session sessionID]);

  if ([_session respondsToSelector:@selector(timeoutDate)]) {
    self->timeoutDate = [(id)_session timeoutDate];
  }
  else {
    NSTimeInterval timeOut = [_session timeOut];
    
    self->timeoutDate = (timeOut > 0.0)
      ? [NSDate dateWithTimeIntervalSinceNow:(timeOut + 1.0)]
      : [NSDate distantFuture];
  }
  self->timeoutDate = RETAIN(self->timeoutDate);
  
  return self;
}

+ (WOSessionInfo *)infoForSession:(WOSession *)_session {
  return AUTORELEASE([[self alloc] initWithSession:_session]);
}

- (void)dealloc {
  [self->sessionID   release];
  [self->timeoutDate release];
  [super dealloc];
}

- (NSString *)sessionID {
  return self->sessionID;
}
- (NSDate *)timeoutDate {
  return self->timeoutDate;
}

@end /* WOSessionInfo */
