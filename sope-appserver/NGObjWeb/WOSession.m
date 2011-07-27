/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include <NGObjWeb/WOSession.h>
#include "WOContext+private.h"
#include "NSObject+WO.h"
#include "WOComponent+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOStatisticsStore.h>
#import <EOControl/EONull.h>
#include "common.h"
#include <string.h>

#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
#  define sel_get_name sel_getName
#endif

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (id)notImplemented:(SEL)cmd;
@end
#endif

struct WOSessionCacheEntry {
  NSString    *contextID;
  unsigned    ctxIdHash;
  WOComponent *page;
};

NGObjWeb_DECLARE
  NSString *WOSessionDidTimeOutNotification   = @"WOSessionDidTimeOut";
NGObjWeb_DECLARE
  NSString *WOSessionDidRestoreNotification   = @"WOSessionDidRestore";
NGObjWeb_DECLARE
  NSString *WOSessionDidCreateNotification    = @"WOSessionDidCreate";
NGObjWeb_DECLARE
  NSString *WOSessionDidTerminateNotification = @"WOSessionDidTerminate";

@implementation WOSession

+ (int)version {
  return 5;
}

static int   profileComponents = -1;
static int   logPageCache      = -1;
static Class NSDateClass = Nil;

+ (void)initialize {
  if (NSDateClass == Nil)
    NSDateClass = [NSDate class];
}

- (id)init {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if (NSDateClass == Nil)
    NSDateClass = [NSDate class];
  
  if (profileComponents == -1) {
    profileComponents = 
      [[ud objectForKey:@"WOProfileComponents"] boolValue] ? 1 : 0;
  }
  if (logPageCache == -1)
    logPageCache = [[ud objectForKey:@"WOLogPageCache"] boolValue] ? 1 : 0;
  
  if ((self = [super init])) {
    WOApplication *app = [WOApplication application];

    if ([[ud objectForKey:@"WORunMultithreaded"] boolValue])
      self->wosLock = [[NSRecursiveLock allocWithZone:[self zone]] init];
    
    /* setup page cache */

    [self setStoresIDsInURLs:YES];
    [self setStoresIDsInCookies:YES];
    
    self->pageCache.index = 0;
    self->pageCache.size = [app pageCacheSize];

    if (self->pageCache.size > 0) {
      self->pageCache.entries =
        NGMalloc(sizeof(struct WOSessionCacheEntry) * self->pageCache.size);
      memset(self->pageCache.entries, 0,
             sizeof(struct WOSessionCacheEntry) * self->pageCache.size);
    }
    
    self->permanentPageCache.index = 0;
    self->permanentPageCache.size = [app permanentPageCacheSize];

    if (self->permanentPageCache.size > 0) {
      self->permanentPageCache.entries =
        NGMalloc(sizeof(struct WOSessionCacheEntry) *
                    self->permanentPageCache.size);
      memset(self->permanentPageCache.entries, 0,
             sizeof(struct WOSessionCacheEntry) *
             self->permanentPageCache.size);
    }

    /* setup misc */

    self->wosLanguages  = [[ud arrayForKey:@"WODefaultLanguages"] copy];
    self->isTerminating = NO;
    
    [self setTimeOut:[[WOApplication sessionTimeOut] intValue]];
    
    /* setup session ID */
    
    self->wosSessionId =
      [[[WOApplication application] createSessionIDForSession:self] copy];
    
    if (self->wosSessionId == nil) {
      /* session-id creation failed ... */
      [self release];
      return nil;
    }
    
    /* misc logging */
    
    if (profileComponents)
      [self logWithFormat:@"Component profiling is on."];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter]
                         postNotificationName:@"WOSessionWillDeallocate"
                         object:self];
  [self->wosVariables release];
  [self->wosSessionId release];
  [self->wosLock      release];
  [self->wosLanguages release];
  [super dealloc];
}

/* session */

- (NSString *)sessionID {
  return self->wosSessionId;
}

- (void)setStoresIDsInURLs:(BOOL)_flag {
  self->wosFlags.storesIDsInURLs = _flag ? 1 : 0;
}
- (BOOL)storesIDsInURLs {
  return self->wosFlags.storesIDsInURLs ? YES : NO;
}

- (void)setStoresIDsInCookies:(BOOL)_flag {
  self->wosFlags.storesIDsInCookies = _flag ? 1 : 0;
}
- (BOOL)storesIDsInCookies {
  return self->wosFlags.storesIDsInCookies ? YES : NO;
}

- (NSString *)domainForIDCookies {
  return nil;
}
- (NSDate *)expirationDateForIDCookies {
  return [self isTerminating]
    ? [NSDate dateWithTimeIntervalSinceNow:-15.0]
    : [NSDate dateWithTimeIntervalSinceNow:([self timeOut] - 5.0)];
}

- (void)setDistributionEnabled:(BOOL)_flag {
  [self notImplemented:_cmd];
}
- (BOOL)isDistributionEnabled {
  return NO;
}

- (void)setTimeOut:(NSTimeInterval)_timeout {
  self->wosTimeOut = _timeout;
}
- (NSTimeInterval)timeOut {
  return self->wosTimeOut;
}

- (void)terminate {
  self->isTerminating = YES;
}
- (BOOL)isTerminating {
  return self->isTerminating;
}

- (id)application {
  if (self->application == nil)
    self->application = [WOApplication application];
  return self->application;
}
- (WOContext *)context {
  if (self->context == nil) {
    if (self->application == nil)
      self->application = [WOApplication application];
    self->context = [self->application context];
  }
  return self->context;
}

/* editing context */

- (id)defaultEditingContext {
  if (![WOApplication implementsEditingContexts])
    return nil;
  
  if (self->wosDefaultEditingContext == nil) {
    self->wosDefaultEditingContext = 
      [[[WOApplication eoEditingContextClass] alloc] init];
  }
  return self->wosDefaultEditingContext;
}

/* pages */

- (id)restorePageForContextID:(NSString *)_contextID {
  unsigned short i;
  unsigned       ctxHash;
  WOComponent    *page = nil;
  
  ctxHash = [_contextID hash];
  
  /* first scan permanent cache */

  for (i = 0, page = nil;
       (page == nil) && (i < self->permanentPageCache.size); i++) {
    struct WOSessionCacheEntry *entry;

    entry = &(self->permanentPageCache.entries[i]);
    
    if (ctxHash == entry->ctxIdHash) {
      if ([_contextID isEqualToString:entry->contextID]) {
        page = entry->page;
        if (logPageCache) {
          [self debugWithFormat:@"restored permanent page %@ for ctx %@",
                  page       != nil ? [page name] : (NSString *)@"<nil>",
		  _contextID != nil ? _contextID  : (NSString *)@"<nil>"];
        }
        break;
      }
    }
  }

  if (page)
    return [[page retain] autorelease];
  
  /* now scan regular cache */
  
  for (i = 0, page = nil; (page == nil) && (i < self->pageCache.size); i++) {
    struct WOSessionCacheEntry *entry;

    entry = &(self->pageCache.entries[i]);
    
    if (ctxHash == entry->ctxIdHash) {
      if ([_contextID isEqualToString:entry->contextID]) {
        page = entry->page;
        if (logPageCache) {
          [self debugWithFormat:@"restored page %@<0x%p> for ctx %@",
                  [page name], page, _contextID];
        }
        break;
      }
    }
  }
  return [[page retain] autorelease];
}

- (void)savePage:(WOComponent *)_page {
  NSString *cid;
  struct WOSessionCacheEntry *entry;
  
  cid = [[self context] contextID];
  if (logPageCache)
    [self debugWithFormat:@"storing page %@ for ctx %@", [_page name], cid];
    
  /* go to next (fixed) queue entry */
  self->pageCache.index++;
  if (self->pageCache.index >= self->pageCache.size)
    self->pageCache.index = 0;

  entry = &(self->pageCache.entries[self->pageCache.index]);
  
  /* reset old queue entry */
  entry->ctxIdHash = 0;
  [entry->contextID release];
  [entry->page      release];

  /* assign new values */
  entry->contextID = [cid copyWithZone:[self zone]];
  entry->ctxIdHash = [entry->contextID hash];
  entry->page = [_page retain];
}

- (void)savePageInPermanentCache:(WOComponent *)_page {
  NSString *cid;
  struct WOSessionCacheEntry *entry;
    
  cid = [[self context] contextID];
  if (logPageCache) {
    [self debugWithFormat:
            @"permanently storing page %@ for ctx %@", [_page name], cid];
  }
    
  /* go to next (fixed) queue entry */
  self->permanentPageCache.index++;
  if (self->permanentPageCache.index >= self->permanentPageCache.size)
    self->permanentPageCache.index = 0;

  entry = &(self->permanentPageCache.entries[self->permanentPageCache.index]);

  /* reset old queue entry */
  entry->ctxIdHash = 0;
  [entry->contextID release];
  [entry->page      release];
  
  /* assign new values */
  entry->contextID = [cid copyWithZone:[self zone]];
  entry->ctxIdHash = [entry->contextID hash];
  entry->page = [_page retain];
}

// localization

- (void)languageArrayDidChange {
}

- (void)setLanguages:(NSArray *)_langs {
  if (![self->wosLanguages isEqual:_langs]) { // check whether they really differ
    [self->wosLanguages release]; self->wosLanguages = nil;
    self->wosLanguages = [_langs copyWithZone:[self zone]];
    [self languageArrayDidChange];
  }
}
- (NSArray *)languages {
  return self->wosLanguages;
}

/* notifications */

- (void)awake {
}
- (void)sleep {
}

- (void)_awakeWithContext:(WOContext *)_ctx {
  if (self->context == nil)
    self->context = _ctx;
  if (self->application == nil)
    self->application = [WOApplication application];

  if (!self->wosFlags.isAwake) {
    [self awake];
    self->wosFlags.isAwake = 1;
  }
}
- (void)_sleepWithContext:(WOContext *)_ctx {
  if (self->wosFlags.isAwake) {
    [self sleep];
    self->wosFlags.isAwake = 0;
  }
  self->context     = nil;
  self->application = nil;
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *senderID;
  NSString *reqCtxId;
  
  self->context     = _ctx;
  self->application = [WOApplication application];

  senderID = [_ctx senderID];

  if ([senderID length] == 0) {
    /* no element URL is available */
    WOComponent *page;

    if ((page = [_ctx page]) != nil) {
      /* 
	 But we do have a page set in the context. This usually means that the
	 -takeValues got triggered by the WODirectActionRequestHandler in
	 combination with a WOComponent being the DirectAction object.
      */
      NSTimeInterval st = 0.0;
      
      WOContext_enterComponent(_ctx, page, nil);
      
      if (profileComponents)
        st = [[NSDateClass date] timeIntervalSince1970];
      
      [page takeValuesFromRequest:_request inContext:_ctx];
      
      if (profileComponents) {
        NSTimeInterval diff;
        
        diff = [[NSDateClass date] timeIntervalSince1970] - st;
        printf("prof[%s %s]: %0.3fs\n",
               [[(WOComponent *)page name] cString], sel_get_name(_cmd), diff);
      }
      
      WOContext_leaveComponent(_ctx, page);
    }
    
    return;
  }

  if ([[_request method] isEqualToString:@"GET"]) {
    NSRange r;
    
    r = [[_request uri] rangeOfString:@"?"];
    if (r.length == 0) {
      /* no form content to apply */
      // TODO: we should run the takeValues nevertheless to clear values?
      return;
    }
  }

  if ((reqCtxId = [_ctx currentElementID]) == nil)
    reqCtxId = @"0";
  
  [_ctx appendElementIDComponent:reqCtxId];
  {
    WOComponent *page;

    if ((page = [_ctx page]) != nil) {
      NSTimeInterval st = 0.0;
      
      WOContext_enterComponent(_ctx, page, nil);
      
      if (profileComponents)
        st = [[NSDateClass date] timeIntervalSince1970];
      
      [page takeValuesFromRequest:_request inContext:_ctx];
      
      if (profileComponents) {
        NSTimeInterval diff;
        
        diff = [[NSDateClass date] timeIntervalSince1970] - st;
        printf("prof[%s %s]: %0.3fs\n",
               [[(WOComponent *)page name] cString], sel_get_name(_cmd), diff);
      }
      
      WOContext_leaveComponent(_ctx, page);
    }
  }
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  NSString *reqCtxId;
  BOOL     returnResult = NO;
  id       result       = nil;
  
  self->context     = _ctx;
  self->application = [WOApplication application];
  
  if ((reqCtxId = [_ctx currentElementID]) == nil)
    /* no sender element ID */
    return nil;
  
  [_ctx appendElementIDComponent:reqCtxId];
  {
    WOComponent *page;

    if ((page = [_ctx page])) {
      /*
        -consumeElementID consumes the context id and returns the
        id of the next element.
        If there was no next element, the request wasn't active.
      */
      if (([_ctx consumeElementID])) {
        NSTimeInterval st = 0.0;
        
        returnResult = YES;
        WOContext_enterComponent(_ctx, page, nil);
        
        if (profileComponents)
          st = [[NSDateClass date] timeIntervalSince1970];
        
        result = [page invokeActionForRequest:_request inContext:_ctx];
      
        if (profileComponents) {
          NSTimeInterval diff;
          
          diff = [[NSDateClass date] timeIntervalSince1970] - st;
          printf("prof[%s %s]: %0.3fs\n",
                 [[page name] cString], sel_get_name(_cmd), diff);
                 //[page name], sel_get_name(_cmd), diff);
        }
      
        WOContext_leaveComponent(_ctx, page);
      }
    }
  }
  [_ctx deleteLastElementIDComponent];
  return returnResult ? result : [_ctx page];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  self->context     = _ctx;
  self->application = [WOApplication application];
  
  /* HTTP/1.1 caching directive, prevents browser from caching dynamic pages */
  if ([self->application isPageRefreshOnBacktrackEnabled]) {
    NSString *ctype;
    
    if ((ctype = [_response headerForKey:@"content-type"])) {
      if ([ctype rangeOfString:@"html"].length > 0)
	// profiling OSX: 3.1% of append...
	[_response disableClientCaching];
    }
  }
  
  [_ctx deleteAllElementIDComponents];
  [_ctx appendElementIDComponent:[_ctx contextID]];
  {
    WOComponent *page;

    if ((page = [_ctx page])) {
      /* let the page append it's content */
      NSTimeInterval st = 0.0;
      
      WOContext_enterComponent(_ctx, page, nil);
      
      if (profileComponents)
        st = [[NSDateClass date] timeIntervalSince1970];
      
      [page appendToResponse:_response inContext:_ctx];
      
      if (profileComponents) {
        NSTimeInterval diff;
        
        diff = [[NSDateClass date] timeIntervalSince1970] - st;
        printf("prof[%s %s]: %0.3fs\n",
               [[page name] cString], sel_get_name(_cmd), diff);
      }
      
      WOContext_leaveComponent(_ctx, page);
    }
    else {
      [self logWithFormat:@"missing page in context for -appendToResponse: !"];
    }
  }
  [_ctx deleteLastElementIDComponent];

  /* generate statistics */
  // profiling OSX: 3.1% of append... (seems to be NSDate!)
  [[[self application] statisticsStore]
          recordStatisticsForResponse:_response
          inContext:_ctx];
}

// multithreading

- (void)lock {
  [self->wosLock lock];
}
- (void)unlock {
  [self->wosLock unlock];
}

- (BOOL)tryLock {
  return [self->wosLock tryLock];
}

/* session variables */

- (void)setObject:(id)_obj forKey:(NSString *)_key {
  if (_key == nil) {
    [self warnWithFormat:@"%s: got no key for extra variable.",
	    __PRETTY_FUNCTION__];
    return;
  }

  if (self->wosVariables == nil)
    self->wosVariables = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  if (_obj != nil)
    [self->wosVariables setObject:_obj forKey:_key];
  else
    [self->wosVariables removeObjectForKey:_key];
}

- (id)objectForKey:(NSString *)_key {
  return _key != nil ? [self->wosVariables objectForKey:_key] : nil;
}

- (void)removeObjectForKey:(NSString *)_key {
  if (_key == nil) {
    [self warnWithFormat:@"%s: got no key of extra variable to be removed.",
	    __PRETTY_FUNCTION__];
    return;
  }

  [self->wosVariables removeObjectForKey:_key];
}

- (NSDictionary *)variableDictionary {
  return self->wosVariables;
}

#if LIB_FOUNDATION_LIBRARY /* only override on libFoundation */

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  if (WOSetKVCValueUsingMethod(self, _key, _value))
    // method is used
    return;
  else if (WOGetKVCGetMethod(self, _key) == NULL) {
    if (self->wosVariables == nil)
      self->wosVariables = [[NSMutableDictionary alloc] initWithCapacity:16];
    
    if (_value) [self->wosVariables setObject:_value forKey:_key];
    return;
  }
  else
    // only a 'get' method is defined for _key !
    [self handleTakeValue:_value forUnboundKey:_key];
}
- (id)valueForKey:(NSString *)_key {
  id value;
  
  if ((value = WOGetKVCValueUsingMethod(self, _key)))
    return value;
  
  return [self->wosVariables objectForKey:_key];
}

#else /* use fallback methods on other Foundation libraries */

- (void)setValue:(id)_value forUndefinedKey:(NSString *)_key {
  [self setObject:_value forKey:_key];
}
- (id)valueForUndefinedKey:(NSString *)_key {
  return [self->wosVariables objectForKey:_key];
}

- (void)handleTakeValue:(id)_value forUnboundKey:(NSString *)_key {
  // deprecated: pre-Panther method
  [self setValue:_value forUndefinedKey:_key];
}
- (id)handleQueryWithUnboundKey:(NSString *)_key {
  // deprecated: pre-Panther method
  return [self valueForUndefinedKey:_key];
}

#endif

/* statistics */

- (NSArray *)statistics {
  return [NSArray array];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: id=%@>",
                     NSStringFromClass([self class]), self,
                     [self sessionID]];
}

@end /* WOSession */

@implementation WOSession(NSCoding)

- (void)encodeWithCoder:(NSCoder *)_coder {
  unsigned short i;
  BOOL t;
  
  [_coder encodeObject:self->wosLanguages];
  [_coder encodeObject:[self sessionID]];
  [_coder encodeObject:self->wosVariables];
  [_coder encodeValueOfObjCType:@encode(NSTimeInterval) at:&(self->wosTimeOut)];
  t = [self storesIDsInURLs];
  [_coder encodeValueOfObjCType:@encode(BOOL) at:&t];
  t = [self storesIDsInCookies];
  [_coder encodeValueOfObjCType:@encode(BOOL) at:&t];

  /* store page caches */
  
  [_coder encodeValueOfObjCType:@encode(unsigned short)
          at:&(self->pageCache.index)];
  [_coder encodeValueOfObjCType:@encode(unsigned short)
          at:&(self->pageCache.size)];
  for (i = 0; i < self->pageCache.size; i++) {
    [_coder encodeValueOfObjCType:@encode(unsigned)
            at:&(self->pageCache.entries[i].ctxIdHash)];
    [_coder encodeObject:self->pageCache.entries[i].contextID];
    [_coder encodeObject:self->pageCache.entries[i].page];
  }

  [_coder encodeValueOfObjCType:@encode(unsigned short)
          at:&(self->permanentPageCache.index)];
  [_coder encodeValueOfObjCType:@encode(unsigned short)
          at:&(self->permanentPageCache.size)];
  for (i = 0; i < self->permanentPageCache.size; i++) {
    [_coder encodeValueOfObjCType:@encode(unsigned)
            at:&(self->permanentPageCache.entries[i].ctxIdHash)];
    [_coder encodeObject:self->permanentPageCache.entries[i].contextID];
    [_coder encodeObject:self->permanentPageCache.entries[i].page];
  }
}

- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super init])) {
    unsigned short i;
    BOOL t;
    
    self->wosLanguages = [[_coder decodeObject] retain];
    self->wosSessionId = [[_coder decodeObject] copyWithZone:[self zone]];
    self->wosVariables = [[_coder decodeObject] copyWithZone:[self zone]];
    [_coder decodeValueOfObjCType:@encode(NSTimeInterval) 
	    at:&(self->wosTimeOut)];
    [_coder decodeValueOfObjCType:@encode(BOOL) at:&t];
    [self setStoresIDsInURLs:t];
    [_coder decodeValueOfObjCType:@encode(BOOL) at:&t];
    [self setStoresIDsInCookies:t];

    /* restore page caches */
    
    [_coder decodeValueOfObjCType:@encode(unsigned short)
            at:&(self->pageCache.index)];
    [_coder decodeValueOfObjCType:@encode(unsigned short)
            at:&(self->pageCache.size)];
    self->pageCache.entries =
      NGMalloc(sizeof(struct WOSessionCacheEntry) * self->pageCache.size);
    for (i = 0; i < self->pageCache.size; i++) {
      [_coder decodeValueOfObjCType:@encode(unsigned)
              at:&(self->pageCache.entries[i].ctxIdHash)];
      self->pageCache.entries[i].contextID = [[_coder decodeObject] retain];
      self->pageCache.entries[i].page      = [[_coder decodeObject] retain];
    }

    [_coder decodeValueOfObjCType:@encode(unsigned short)
            at:&(self->permanentPageCache.index)];
    [_coder decodeValueOfObjCType:@encode(unsigned short)
            at:&(self->permanentPageCache.size)];
    self->permanentPageCache.entries =
      NGMalloc(sizeof(struct WOSessionCacheEntry) *
                  self->permanentPageCache.size);
    for (i = 0; i < self->permanentPageCache.size; i++) {
      [_coder decodeValueOfObjCType:@encode(unsigned)
              at:&(self->permanentPageCache.entries[i].ctxIdHash)];
      self->permanentPageCache.entries[i].contextID =
        [[_coder decodeObject] retain];
      self->permanentPageCache.entries[i].page = [[_coder decodeObject] retain];
    }
    
    self->wosLock = [[NSRecursiveLock allocWithZone:[self zone]] init];
  }
  return self;
}

@end /* WOSession(NSCoding) */

@implementation WOSession(Logging2)

- (BOOL)isDebuggingEnabled {
  static char showDebug = 2;
  
  if (showDebug == 2)
    showDebug = [WOApplication isDebuggingEnabled] ? 1 : 0;
  return showDebug ? YES : NO;
}
- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"(%@)", [self sessionID]];
}

@end /* WOSession(Logging) */

NSString *OWSessionLanguagesDidChangeNotificationName =
  @"OWSnLanguagesDidChangeNotification";

@implementation WOSession(Misc)

- (void)languageArrayDidChange {
  WOComponent *c;

  c = [[self context] page];
  if ([c respondsToSelector:@selector(languageArrayDidChange)])
    [(id)c languageArrayDidChange];
  
  [[NSNotificationCenter defaultCenter]
                         postNotificationName:
                           OWSessionLanguagesDidChangeNotificationName
                         object:self];
}

@end /* WOSession(Misc) */
