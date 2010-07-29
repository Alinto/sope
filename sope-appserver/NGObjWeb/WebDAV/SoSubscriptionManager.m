/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "SoSubscriptionManager.h"
#include "SoSubscription.h"
#include "SoObject.h"
#import <EOControl/EOControl.h>
#include "common.h"

@implementation SoSubscriptionManager

static BOOL           debugOn         = NO;
static NSTimeInterval defaultLifeTime = 3600;
static int            expirationInterval = 10 * 60 /* every 10 minutes */;

static SoSubscriptionManager *sm = nil;

+ (id)sharedSubscriptionManager {
  if (sm == nil) {
    debugOn = [[NSUserDefaults standardUserDefaults] 
                boolForKey:@"SoSubscriptionManagerDebugEnabled"];
    
    sm = [[SoSubscriptionManager alloc] init];
  }
  return sm;
}

- (id)init {
  if ((self = [super init])) {
    self->idToSubscription = [[NSMutableDictionary alloc] init];

    [[NSNotificationCenter defaultCenter] 
      addObserver:self selector:@selector(trackChange:)
      name:@"SoObjectChanged" object:nil];
  }
  return self;
}
- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->idToSubscription release];
  [super dealloc];
}

/* subscriptions */

- (NSString *)nextSubscriptionID {
  static int i = 1000;
  i++;
  return [NSString stringWithFormat:@"%i", i];
}

- (NSString *)subscribeURL:(NSURL *)_url forObserver:(NSURL *)_callback
  type:(NSString *)_type delay:(NSTimeInterval)_delay
  lifetime:(NSTimeInterval)_lifetime
{
  /* subscribe httpu://127.0.0.1:14970/ for 3600s (type update, delay 30s) */
  SoSubscription *s;
  NSString *sid;
  
  if (_lifetime == 0.0) _lifetime = defaultLifeTime;
  sid = [self nextSubscriptionID];
  
  if (debugOn) {
    [self debugWithFormat:@"subscribe url %@", _url];
    [self debugWithFormat:@"  observer:   %@", _callback];
    [self debugWithFormat:@"  type:       %@", _type];
    [self debugWithFormat:@"  delay:      %i", (int)_delay];
    [self debugWithFormat:@"SID:          %@", sid];
  }
  
  s = [[SoSubscription alloc] initWithID:sid 
                              url:_url observer:_callback type:_type
                              delay:_delay lifetime:_lifetime];
  [self->idToSubscription setObject:s forKey:sid];
  [s autorelease];
  
  [self debugWithFormat:@"expires: %@", [s expirationDate]];

  if (s != nil && self->timer == nil) {
    self->timer = [[NSTimer scheduledTimerWithTimeInterval:expirationInterval
                            target:self 
                            selector:@selector(performExpirationCheck:)
                            userInfo:nil
                            repeats:YES]
                            retain];
  }
  
  return [s subscriptionID];
}

- (NSString *)renewSubscription:(NSString *)_sid onURL:(NSURL *)_url {
  SoSubscription *s;
  
  if (debugOn)
    [self debugWithFormat:@"renew subscription %@, url: %@", _sid, _url];
  
  if ((s = [self->idToSubscription objectForKey:_sid]) == nil) {
    [self logWithFormat:
            @"attempt to renew non-existing subscription '%@'", _sid];
    return nil;
  }
  
  if (![s isValidForURL:_url]) {
    [self logWithFormat:
            @"mismatch between subscription-id and subscribed resource"];
    return nil;
  }
  
  if (![s renewSubscription])
    return _sid;
  
  return _sid;
}

- (BOOL)unsubscribeID:(NSString *)_sid onURL:(NSURL *)_url {
  SoSubscription *s;
  
  if (_sid == nil) return NO;
  if (_url == nil) return NO;

  if ((s = [self->idToSubscription objectForKey:_sid]) == nil) {
    [self debugWithFormat:@"no subscription with id '%@'", _sid];
    return NO;
  }
  if (![s isValidForURL:_url]) {
    [self logWithFormat:
            @"mismatch between subscription-id and subscribed resource"];
    return NO;
  }
  
  [self->idToSubscription removeObjectForKey:_sid];
  [self debugWithFormat:@"canceled subscription '%@'", _sid];
  return YES;
}

- (id)pollSubscriptions:(NSArray *)_sids onURL:(NSURL *)_url {
  NSEnumerator   *e;
  NSMutableArray *pending  = nil;
  NSMutableArray *inactive = nil;
  NSString       *sid;
  
  e = [_sids objectEnumerator];
  while ((sid = [e nextObject])) {
    SoSubscription *s;
    
    if ((s = [self->idToSubscription objectForKey:sid]) == nil) {
      [self debugWithFormat:@"no subscription with id '%@'", sid];
      continue;
    }
    if (![s isValidForURL:_url]) {
      [self debugWithFormat:@"subscription '%@' is not valid for given URL", 
              sid];
      continue;
    }
    
    [s renewSubscription]; /* renew subscription on access ... */
    
    if ([s hasEventsPending]) {
      [self debugWithFormat:@"events pending on sid '%@' ...", sid];
      [s resetEvents];
      if (pending == nil) pending = [[NSMutableArray alloc] init];
      [pending addObject:sid];
    }
    else {
      [self debugWithFormat:@"no events pending on sid '%@' ...", sid];
      if (inactive == nil) inactive = [[NSMutableArray alloc] init];
      [inactive addObject:sid];
    }
  }
  
  if (pending  == nil) pending  = [NSArray array];
  if (inactive == nil) inactive = [NSArray array];
  return [NSDictionary dictionaryWithObjectsAndKeys:
                         pending,  @"pending",
                         inactive, @"inactive",
                         nil];
}

/* tracking changes */

- (void)trackChangedURL:(NSURL *)_url {
  [self debugWithFormat:@"url was changed: %@", _url];
}
- (void)trackChangedPath:(NSString *)_path {
  [self debugWithFormat:@"path was changed: %@", _path];
}
- (void)trackChangedObject:(id)_object {
  id url = nil;

  if ((url = [_object baseURLInContext:nil]))
    url = [NSURL URLWithString:url];
  
  if (url) {
    [self debugWithFormat:@"object with URL was changed: %@", _object];
    [self trackChangedURL:url];
  }
  else
    [self debugWithFormat:@"object without URL was changed: %@", _object];
}

- (void)trackChange:(NSNotification *)_notification {
  id object;
  
  if ((object = [_notification object]) == nil) {
    [self logWithFormat:@"missing changed object in change notification ..."];
    return;
  }
  
  if ([object isKindOfClass:[NSURL class]])
    [self trackChangedURL:object];
  else if ([object isKindOfClass:[NSString class]])
    [self trackChangedPath:object];
  else
    [self trackChangedObject:object];
}

/* expiration check */

- (void)performExpirationCheck:(NSTimer *)_timer {
  NSAutoreleasePool *pool;
  NSArray        *subs;
  NSEnumerator   *e;
  SoSubscription *s;
  
  pool = [[NSAutoreleasePool alloc] init];

  /* scan for expired subscriptions */
  
  subs = [[self->idToSubscription allValues] shallowCopy];
  if (debugOn) {
    [self debugWithFormat:@"perform expiration check (%i subscriptions) ...",
            [subs count]];
  }
  
  e = [subs objectEnumerator];
  while ((s = [e nextObject])) {
    if ([s isExpired]) {
      if (debugOn)
        [self debugWithFormat:@"  expired: %@", [s subscriptionID]];
      [self->idToSubscription removeObjectForKey:[s subscriptionID]];
    }
  }
  
  /* remove timer if we have no subscriptions ... */
  
  if ([self->idToSubscription count] == 0) {
    [self debugWithFormat:@"  no subscriptions left, removing timer .."];
    [self->timer invalidate];
    [self->timer release]; self->timer = nil;
  }
  
  [pool release];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SoSubscriptionManager */
