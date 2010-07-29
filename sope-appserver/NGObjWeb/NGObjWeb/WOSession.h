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

#ifndef __NGObjWeb_WOSession_H__
#define __NGObjWeb_WOSession_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSDate.h>
#include <NGObjWeb/NGObjWebDecls.h>

@class NSString, NSArray, NSRecursiveLock, NSMutableDictionary, NSDate;
@class WOContext, WOApplication;
@class WORequest, WOResponse, WOContext, WOComponent;

struct WOSessionCacheEntry;

NGObjWeb_EXPORT NSString *WOSessionDidTimeOutNotification;
NGObjWeb_EXPORT NSString *WOSessionDidRestoreNotification;
NGObjWeb_EXPORT NSString *WOSessionDidCreateNotification;
NGObjWeb_EXPORT NSString *WOSessionDidTerminateNotification;

@interface WOSession : NSObject < NSLocking >
{
@private
  NSArray             *wosLanguages;
  BOOL                isTerminating;
  NSRecursiveLock     *wosLock;
  NSString            *wosSessionId;
  NSMutableDictionary *wosVariables;     // session variables
  NSTimeInterval      wosTimeOut;
  id                  wosDefaultEditingContext;
  struct {
    BOOL              storesIDsInURLs:1;
    BOOL              storesIDsInCookies:1;
    BOOL              isAwake:1;
  } wosFlags;

@private
  struct {
    struct WOSessionCacheEntry *entries;
    unsigned short             index;
    unsigned short             size;
  } pageCache;
  struct {
    struct WOSessionCacheEntry *entries;
    unsigned short             index;
    unsigned short             size;
  } permanentPageCache;

@protected // transients (non-retained)
  WOApplication *application;
  WOContext     *context;
}

/* session */

- (NSString *)sessionID;
- (void)setStoresIDsInURLs:(BOOL)_flag;
- (BOOL)storesIDsInURLs;
- (void)setStoresIDsInCookies:(BOOL)_flag;
- (BOOL)storesIDsInCookies;
- (NSString *)domainForIDCookies;
- (NSDate *)expirationDateForIDCookies;

- (void)setDistributionEnabled:(BOOL)_flag;
- (BOOL)isDistributionEnabled;

- (void)setTimeOut:(NSTimeInterval)_timeout;
- (NSTimeInterval)timeOut;
- (void)terminate;
- (BOOL)isTerminating;

- (WOContext *)context;

/* editing context */

- (id)defaultEditingContext;

/* localization */

- (void)setLanguages:(NSArray *)_langs;
- (NSArray *)languages;

/* notifications */

- (void)awake;
- (void)sleep;

/* pages */

- (id)restorePageForContextID:(NSString *)_idx;
- (void)savePage:(WOComponent *)_page;
- (void)savePageInPermanentCache:(WOComponent *)_page; // new in WO4

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_request inContext:(WOContext *)_ctx;
- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx;
- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx;

/* multithreading */

- (void)lock;
- (void)unlock;
- (BOOL)tryLock;

/* session variables */

- (void)setObject:(id)_obj forKey:(NSString *)_key;
- (id)objectForKey:(NSString *)_key;
- (void)removeObjectForKey:(NSString *)_key;

/* statistics */

- (NSArray *)statistics;

@end

@interface WOSession(DeprecatedMethodsInWO4)

- (id)application; // use [WOApplication application] instead

@end

@interface WOSession(PrivateMethods)
- (void)_awakeWithContext:(WOContext *)_ctx;
- (void)_sleepWithContext:(WOContext *)_ctx;
@end

@interface WOSession(NSCoding) < NSCoding >
@end

@interface WOSession(Logging)

- (void)logWithFormat:(NSString *)_format, ...;
- (void)debugWithFormat:(NSString *)_format, ...; // new in WO4

@end

#endif /* __NGObjWeb_WOSession_H__ */
