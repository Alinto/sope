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

#include <NGObjWeb/WODirectAction.h>
#include "NSObject+WO.h"
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOSessionStore.h>
#include "common.h"

#if !LIB_FOUNDATION_LIBRARY
#  define NG_USE_KVC_FALLBACK 1
#endif

@implementation WODirectAction

+ (int)version {
  return 4;
}

- (id)initWithRequest:(WORequest *)_request {
  if ((self = [super init]) != nil) {
  }
  return self;
}
- (id)initWithContext:(WOContext *)_ctx {
  if ((self = [self initWithRequest:[_ctx request]])) {
    self->context = _ctx;
  }
  return self;
}
- (id)init {
  return [self initWithRequest:nil];
}

// - (void)dealloc {
//   [self->context release];
//   [super dealloc];
// }

/* accessors */

- (WOContext *)context {
  if (self->context == nil)
    self->context = [[WOApplication application] context];
  return self->context;
}

- (WORequest *)request {
  return [[self context] request];
}

- (id)session {
  return [[self context] session];
}

- (id)existingSession {
  WOContext *ctx = [self context];
  
  /* check whether the context has a session */
  
  return [ctx hasSession] ? [ctx session] : nil;
}

/* perform actions */

- (id<WOActionResults>)performActionNamed:(NSString *)_actionName {
  SEL actionSel;
  NSRange rng;

  /* discard everything after a point in the URL */
  rng = [_actionName rangeOfString:@"."];
  if (rng.length > 0)
    _actionName = [_actionName substringToIndex:rng.location];

  _actionName = [_actionName stringByAppendingString:@"Action"];
  actionSel   = NSSelectorFromString(_actionName);
  
  if ([self respondsToSelector:actionSel]) 
    return [self performSelector:actionSel];
  else {
    [self logWithFormat:@"DirectAction class %@ cannot handle action %@",
            NSStringFromClass([self class]), _actionName];
    return nil;
  }
}

/* applying form values */

- (void)takeFormValuesForKeyArray:(NSArray *)_keys {
  NSEnumerator *keys;
  NSString     *key;
  WORequest    *rq;

  rq   = [self request];
  keys = [_keys objectEnumerator];

  while ((key = [keys nextObject])) {
    NSString *value;

    value = [rq formValueForKey:key];
    
    [self takeValue:value forKey:key];
  }
}
- (void)takeFormValuesForKeys:(NSString *)_key1,... {
  va_list   va;
  NSString  *key;
  WORequest *rq;

  rq = [self request];

  va_start(va, _key1);
  {  
    for (key = _key1; key; key = va_arg(va, NSString *)) {
      NSString *value;

      value = [rq formValueForKey:key];
      [self takeValue:value forKey:key];
    }
  }
  va_end(va);
}

- (void)takeFormValueArraysForKeyArray:(NSArray *)_keys {
  NSEnumerator *keys;
  NSString     *key;
  WORequest    *rq;

  rq   = [self request];
  keys = [_keys objectEnumerator];

  while ((key = [keys nextObject])) {
    NSArray *value;

    value = [rq formValuesForKey:key];
    [self takeValue:value forKey:key];
  }
}
- (void)takeFormValueArraysForKeys:(NSString *)_key1,... {
  va_list   va;
  NSString  *key;
  WORequest *rq;

  rq = [self request];
  
  va_start(va, _key1);
  {  
    for (key = _key1; key; key = va_arg(va, NSString *)) {
      NSArray *value;

      value = [rq formValuesForKey:key];
      [self takeValue:value forKey:key];
    }
  }
  va_end(va);
}

/* pages */

- (id)pageWithName:(NSString *)_name {
  return [[WOApplication application]
                         pageWithName:_name
                         inContext:[self context]];
}

/* logging */

- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@">%@>", NSStringFromClass([self class])];
}
- (BOOL)isDebuggingEnabled {
  static char showDebug = 2;
  
  if (showDebug == 2)
    showDebug = [WOApplication isDebuggingEnabled] ? 1 : 0;
  return showDebug ? YES : NO;
}

/* Key-Value coding */

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  if (!WOSetKVCValueUsingMethod(self, _key, _value))
    [self handleTakeValue:_value forUnboundKey:_key];
}
- (id)valueForKey:(NSString *)_key {
  return WOGetKVCValueUsingMethod(self, _key);
}

#if !LIB_FOUNDATION_LIBRARY

- (void)setValue:(id)_value forUndefinedKey:(NSString *)_key {
  [self warnWithFormat:
          @"tried to set value for undefined KVC key: '%@'", _key];
}
- (id)valueForUndefinedKey:(NSString *)_key {
  [self warnWithFormat:
             @"tried to access undefined KVC key: '%@'", _key];
  return nil;
}

#endif

@end /* WODirectAction */
