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

#include <NGObjWeb/WOApplication.h>
#include "common.h"

@interface WOApplication(DefaultsPrivates)
+ (NSUserDefaults *)userDefaults;
@end

@implementation WOApplication(Defaults)

static NSString *ck = nil;
static NSString *dk = nil;

+ (void)setComponentRequestHandlerKey:(NSString *)_key {
  [[self userDefaults]
         setObject:_key
         forKey:@"WOComponentRequestHandlerKey"];
  [ck release]; ck = nil;
}
+ (NSString *)componentRequestHandlerKey {
  if (ck == nil)
    ck = [[[self userDefaults] stringForKey:@"WOComponentRequestHandlerKey"]
	   copy];
  return ck;
}

+ (void)setDirectActionRequestHandlerKey:(NSString *)_key {
  [[self userDefaults]
         setObject:_key
         forKey:@"WODirectActionRequestHandlerKey"];
  [dk release]; dk = nil;
}
+ (NSString *)directActionRequestHandlerKey {
  if (dk == nil) {
    dk = [[[self userDefaults] 
      stringForKey:@"WODirectActionRequestHandlerKey"] copy];
  }
  return dk;
}

+ (void)setResourceRequestHandlerKey:(NSString *)_key {
  [[self userDefaults] setObject:_key forKey:@"WOResourceRequestHandlerKey"];
}
+ (NSString *)resourceRequestHandlerKey {
  return [[self userDefaults] stringForKey:@"WOResourceRequestHandlerKey"];
}

/* WODefaultSessionTimeOut */

+ (void)setSessionTimeOut:(NSNumber *)_timeOut {
  [[self userDefaults] setObject:_timeOut forKey:@"WODefaultSessionTimeOut"];
}

+ (NSNumber *)sessionTimeOut {
  NSUserDefaults *ud;
  id o;

  ud = [self userDefaults];
  // Note: the second check is *intended* (Timeout vs TimeOut), it is
  //       required for compatibility but should be phased out in the
  //       long run. I don't know the proper default-name out of my
  //       head (needs to be checked)
  o  = [ud objectForKey:@"WODefaultSessionTimeout"];
  if (o == nil) o = [ud objectForKey:@"WODefaultSessionTimeOut"];
  return [NSNumber numberWithInt:[o intValue]];
}

/* WOCachingEnabled */

+ (BOOL)isCachingEnabled {
  return [[[self userDefaults]
                 objectForKey:@"WOCachingEnabled"]
                 boolValue];
}

/* WODebuggingEnabled */

+ (BOOL)isDebuggingEnabled {
  return [[[self userDefaults]
                 objectForKey:@"WODebuggingEnabled"]
                 boolValue];
}

/* WOCompatibility */

static BOOL directConnectEnabled = YES;

+ (void)setDirectConnectEnabled:(BOOL)_flag {
  directConnectEnabled = _flag;
}
+ (BOOL)isDirectConnectEnabled {
  return directConnectEnabled;
}

+ (void)setCGIAdaptorURL:(NSString *)_url {
  [[self userDefaults] setObject:_url forKey:@"WOCGIAdaptorURL"];
}
+ (NSString *)cgiAdaptorURL {
  return [[self userDefaults] stringForKey:@"WOCGIAdaptorURL"];
}

/* WOAutoOpenInBrowser */

+ (void) setAutoOpenInBrowser:(BOOL)_flag {
  [[self userDefaults] setBool:_flag forKey:@"WOAutoOpenInBrowser"];
}
+ (BOOL)autoOpenInBrowser {
  return [[self userDefaults] boolForKey:@"WOAutoOpenInBrowser"];
}

/* WOApplicationBaseURL */

+ (void)setApplicationBaseURL:(NSString *)_url {
  [[self userDefaults] setObject:_url forKey:@"WOApplicationBaseURL"];
}
+ (NSString *)applicationBaseURL {
  return [[self userDefaults] stringForKey:@"WOApplicationBaseURL"];
}

/* WOFrameworksBaseURL */

+ (void)setFrameworksBaseURL:(NSString *)_url {
  [[self userDefaults] setObject:_url forKey:@"WOFrameworksBaseURL"];
}
+ (NSString *)frameworksBaseURL {
  return [[self userDefaults] stringForKey:@"WOFrameworksBaseURL"];
}

@end /* WOApplication(Defaults) */
