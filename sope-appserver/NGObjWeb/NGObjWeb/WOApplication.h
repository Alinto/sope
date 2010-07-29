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

#ifndef __NGObjWeb_WOApplication_H__
#define __NGObjWeb_WOApplication_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#include <NGObjWeb/NGObjWebDecls.h>
#include <NGObjWeb/WOCoreApplication.h>

@class NSString, NSRunLoop, NSArray, NSTimer, NSException, NSNumber, NSURL;
@class NSMutableDictionary, NSDictionary;
@class WOResourceManager, WOComponent, WOContext, WOSession;
@class WORequest, WOResponse, WOAdaptor, WORequestHandler;
@class WOSessionStore, WODynamicElement, WOElement, WOStatisticsStore;

@interface WOApplication : WOCoreApplication
{
@private
  int                 minimumActiveSessionsCount;
  NSString            *name;
  NSString            *path;
  WORequestHandler    *defaultRequestHandler;
  NSMapTable          *requestHandlerRegistry;
  WOSessionStore      *iSessionStore;
  WOStatisticsStore   *iStatisticsStore;
  WOResourceManager   *resourceManager;
  void                *_unused;
  NSTimer             *expirationTimer;
  NSString            *instanceNumber;
  short               pageCacheSize;
  short               permanentPageCacheSize;

  struct {
    BOOL doesRefuseNewSessions:1;
    BOOL isPageRefreshOnBacktrackEnabled:1;
    BOOL isCachingEnabled:1;
  } appFlags;
}

/* accessors */

- (NSString *)name;
- (BOOL)monitoringEnabled;
- (NSString *)path;
- (NSString *)number;

/* request handlers */

- (void)registerRequestHandler:(WORequestHandler *)_hdl forKey:(NSString *)_key;
- (void)removeRequestHandlerForKey:(NSString *)_key;
- (void)setDefaultRequestHandler:(WORequestHandler *)_hdl;
- (WORequestHandler *)defaultRequestHandler;
- (NSArray *)registeredRequestHandlerKeys;

/* sessions */

- (id)createSessionForRequest:(WORequest *)_request;
- (id)restoreSessionWithID:(NSString *)_id inContext:(WOContext *)_ctx;
- (void)saveSessionForContext:(WOContext *)_ctx;

- (void)setSessionStore:(WOSessionStore *)_store;
- (WOSessionStore *)sessionStore;
- (NSString *)sessionStoreClassName;
- (void)refuseNewSessions:(BOOL)_flag;
- (BOOL)isRefusingNewSessions;
- (int)activeSessionsCount;

- (void)setMinimumActiveSessionsCount:(int)_minimum;
- (int)minimumActiveSessionsCount;

- (WOResponse *)handleSessionCreationErrorInContext:(WOContext *)_context;
- (WOResponse *)handleSessionRestorationErrorInContext:(WOContext *)_context;
- (WOResponse *)handlePageRestorationErrorInContext:(WOContext *)_context;

/* statistics */

- (void)setStatisticsStore:(WOStatisticsStore *)_statStore;
- (WOStatisticsStore *)statisticsStore;
- (bycopy NSDictionary *)statistics;

/* resources */

- (void)setResourceManager:(WOResourceManager *)_manager;
- (WOResourceManager *)resourceManager;
- (NSURL *)baseURL;
- (NSString *)pathForResourceNamed:(NSString *)_name ofType:(NSString *)_type;

/* notifications */

- (void)awake;
- (void)sleep;

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_req  inContext:(WOContext *)_ctx;
- (id)invokeActionForRequest:(WORequest *)_req   inContext:(WOContext *)_ctx;
- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx;

/* dynamic elements */

- (WOElement *)dynamicElementWithName:(NSString *)_name // element class name
  associations:(NSDictionary *)_associations            // bindings
  template:(WOElement *)_template                       // child elements
  languages:(NSArray *)_languages;

/* pages */

- (void)setPageRefreshOnBacktrackEnabled:(BOOL)_flag;
- (BOOL)isPageRefreshOnBacktrackEnabled;
- (void)setCachingEnabled:(BOOL)_flag;
- (BOOL)isCachingEnabled;
- (void)setPageCacheSize:(int)_size;
- (int)pageCacheSize;
- (void)setPermanentPageCacheSize:(int)_size;
- (int)permanentPageCacheSize;

- (id)pageWithName:(NSString *)_name inContext:(WOContext *)_ctx;
- (id)pageWithName:(NSString *)_name forRequest:(WORequest *)_req;

/* exceptions */

- (WOResponse *)handleException:(NSException *)_exc
  inContext:(WOContext *)_ctx;

@end

@interface WOApplication(DeprecatedMethodsInWO4)

- (id)session;
- (WOContext *)context;

- (id)createSession;
- (id)restoreSession;
- (void)saveSession:(WOSession *)_session;

- (WOResponse *)handleSessionCreationError;
- (WOResponse *)handleSessionRestorationError;
- (WOResponse *)handlePageRestorationError;

- (void)savePage:(WOComponent *)_page;
- (id)restorePageForContextID:(NSString *)_ctxId;

- (id)pageWithName:(NSString *)_name;

- (WOResponse *)handleException:(NSException *)_exception;
- (WOResponse *)handleRequest:(WORequest *)_request;

- (WOElement *)dynamicElementWithName:(NSString *)_name // element class name
  associations:(NSDictionary *)_associations            // bindings
  template:(WOElement *)_template;                      // child elements

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_default;

@end

@interface WOApplication(NonWOMethods)

- (WORequestHandler *)requestHandlerForKey:(NSString *)_key;

- (NSString *)sessionIDFromRequest:(WORequest *)_request;
- (NSString *)createSessionIDForSession:(WOSession *)_session;

+ (Class)eoEditingContextClass;
+ (BOOL)implementsEditingContexts;

@end

@interface WOApplication(Defaults)

/* WOComponentRequestHandlerKey */
+ (void)setComponentRequestHandlerKey:(NSString *)_key;
+ (NSString *)componentRequestHandlerKey;

/* WODirectActionRequestHandlerKey */
+ (void)setDirectActionRequestHandlerKey:(NSString *)_key;
+ (NSString *)directActionRequestHandlerKey;

/* WOResourceRequestHandlerKey */
+ (void)setResourceRequestHandlerKey:(NSString *)_key;
+ (NSString *)resourceRequestHandlerKey;

/* WODefaultSessionTimeOut */
+ (void)setSessionTimeOut:(NSNumber *)_timeOut;
+ (NSNumber *)sessionTimeOut;

/* WOCachingEnabled */
+ (BOOL)isCachingEnabled;

/* WODebuggingEnabled */
+ (BOOL)isDebuggingEnabled;

+ (BOOL)isDirectConnectEnabled;
+ (void)setCGIAdaptorURL:(NSString *)_url;
+ (NSString *)cgiAdaptorURL;

@end

@interface WOApplication(WODebugging)
/* implemented in NGExtensions */

- (void)debugWithFormat:(NSString *)_format, ...;
- (void)logWithFormat:(NSString *)_format, ...;

@end

#endif /* __NGObjWeb_WOApplication_H__ */
