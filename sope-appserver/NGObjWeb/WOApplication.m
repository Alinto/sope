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

#include <NGObjWeb/WOApplication.h>
#include "WOContext+private.h"
#include "WOElement+private.h"
#include "WOComponent+private.h"
#include <NGObjWeb/WOAdaptor.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WORequestHandler.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOSessionStore.h>
#include <NGObjWeb/WOStatisticsStore.h>
#include <NGObjWeb/WODynamicElement.h>
#include <NGObjWeb/WOTemplate.h>
#import <EOControl/EOControl.h>
#include "common.h"
#include <time.h>

#if GNU_RUNTIME && !defined(__GNUSTEP_RUNTIME__)
#  include <objc/sarray.h>
#endif

@interface WOApplication(PrivateMethods)
+ (id)logger;
- (id)_loadComponentDefinitionWithName:(NSString *)_name
  language:(NSArray *)_langs;
- (NSDictionary *)memoryStatistics;
@end

static NSRecursiveLock *classLock           = nil;
static NGLogger        *perfLogger          = nil;
static Class           NSDateClass          = Nil;
static Class           WOTemplateClass      = Nil;
static BOOL            debugOn              = NO;
static NSString        *rapidTurnAroundPath = nil;

@interface WOSessionStore(SnStore)
- (void)performExpirationCheck:(NSTimer *)_timer;
@end

@implementation WOApplication

#if 1 // TODO: why is that? why isn't that set by a default?
static NSString *defaultCompRqHandlerClassName = @"OWViewRequestHandler";
#else
static NSString *defaultCompRqHandlerClassName = @"WOComponentRequestHandler";
#endif

+ (int)version {
  return [super version] + 5 /* v6 */;
}

/* old license checks */

- (NSCalendarDate *)appExpireDate {
  // TODO: can we remove that?
  return nil;
}
- (BOOL)isLicenseExpired {
  // TODO: can we remove that?
  return NO;
}

/* app path */

- (NSString *)_lookupAppPath {
  static NSString *suffix = nil;
  static BOOL    appPathMissing = NO;
  NSUserDefaults *ud;
  NSFileManager  *fm;
  NSString       *cwd;
  NSString       *result;
  
  if (appPathMissing)
    return nil;

  ud = [NSUserDefaults standardUserDefaults];
  
  // Check if appPath has been forced
  result = [ud stringForKey:@"WOProjectDirectory"];
  if(result != nil)
      return result;

  if (suffix == nil)
    suffix = [ud stringForKey:@"WOApplicationSuffix"];
  
  fm  = [NSFileManager defaultManager];
  cwd = [fm currentDirectoryPath];
  
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
  result = [[NGBundle mainBundle] bundlePath];
  //NSLog(@"%s: check path '%@'", __PRETTY_FUNCTION__, result);
#else
  result = cwd;
#endif

  if ([result hasSuffix:suffix]) {
    /* started app inside of .woa directory */
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
    result = [[NGBundle mainBundle] bundlePath];
#else
    result = cwd;
#endif
  }
  else {
    NSString *wrapperName;
    
    wrapperName = [self->name stringByAppendingString:suffix];
    
    /* take a look whether ./AppName.woa exists */
    result = [result stringByAppendingPathComponent:wrapperName];
    if (![fm fileExistsAtPath:result]) {
      /* lookup in process-path */
      NSProcessInfo *pi;
      NSDictionary  *env;
      NSString      *ppath;
      BOOL isFlattened;
      
      pi  = [NSProcessInfo processInfo];
      env = [pi environment];
      if ([[env objectForKey:@"GNUSTEP_SYSTEM_ROOT"] isNotNull]) {
	isFlattened = [[[env objectForKey:@"GNUSTEP_FLATTENED"]
                             lowercaseString] isEqualToString:@"yes"];
      }
      else /* default to flattened if no GNUstep runtime is set */
        isFlattened = YES;
      
      ppath = [[pi arguments] objectAtIndex:0];
      ppath = [ppath stringByDeletingLastPathComponent]; // del exe-name
      
      if (!isFlattened) {
        ppath = [ppath stringByDeletingLastPathComponent]; // lib-combo
        ppath = [ppath stringByDeletingLastPathComponent]; // os
        ppath = [ppath stringByDeletingLastPathComponent]; // cpu
      }
      if ([ppath hasSuffix:suffix])
        result = ppath;
    }
  }
  
  if (![fm fileExistsAtPath:result]) {
    [self debugWithFormat:@"%s: missing path '%@'", 
	    __PRETTY_FUNCTION__, result];
    appPathMissing = YES;
    result = nil;
  }

  return result;
}

+ (NSString *)defaultRequestHandlerClassName {
  return @"WOComponentRequestHandler";
}

- (void)_logDefaults {
  NSUserDefaults *ud;
  NSArray        *keys;
  NSEnumerator   *e;
  NSString       *key;

  ud   = [NSUserDefaults standardUserDefaults];
  keys = [[ud dictionaryRepresentation] allKeys];
  keys = [keys sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];

  e    = [keys objectEnumerator];
  while((key = [e nextObject]) != nil) {
    if ([key hasPrefix:@"WO"] || [key isEqualToString:@"NSProjectSearchPath"])
      [self logWithFormat:@"[default]: %@ = %@",
        key,
        [[ud objectForKey:key] description]];
  }
}

- (id)initWithName:(NSString *)_name {
  if ((self = [super init]) != nil) {
    NSUserDefaults   *ud;
    NGLoggerManager  *lm;
    WORequestHandler *rh;
    NSString         *rk;

    self->name = [_name copy];
    ud         = [NSUserDefaults standardUserDefaults];

    debugOn = [WOApplication isDebuggingEnabled];
    if (!debugOn)
      [[self logger] setLogLevel:NGLogLevelInfo];
    else
      [[self logger] logWithFormat:@"WOApplication debugging is enabled."];
    
    if (classLock == nil) classLock = [[NSRecursiveLock alloc] init];
    
    NSDateClass         = [NSDate class];
    WOTemplateClass     = [WOTemplate class];
    
    rapidTurnAroundPath = [[ud stringForKey:@"WOProjectDirectory"] copy];
    
    lm                  = [NGLoggerManager defaultLoggerManager];
    perfLogger          = [lm loggerForDefaultKey:@"WOProfileApplication"];
    
    
    [self setPageCacheSize:[ud integerForKey:@"WOPageCacheSize"]];
    [self setPermanentPageCacheSize:
            [ud integerForKey:@"WOPermanentPageCacheSize"]];
    
    [self setPageRefreshOnBacktrackEnabled:
            [[ud objectForKey:@"WOPageRefreshOnBacktrack"] boolValue]];
    
    [self setCachingEnabled:[WOApplication isCachingEnabled]];
    
    /* setup request handlers */
    
    self->defaultRequestHandler =
      [[NSClassFromString([[self class] defaultRequestHandlerClassName])
			 alloc] init];
    
    self->requestHandlerRegistry =
      NSCreateMapTable(NSObjectMapKeyCallBacks, NSObjectMapValueCallBacks, 8);
    
    if ((rk = [WOApplication componentRequestHandlerKey]) == nil) {
      [self logWithFormat:
	      @"WARNING: no component request handler key is specified, "
	      @"this probably means that share/ngobjweb/Defaults.plist "
	      @"could not get loaded (permissions?)"];
    }
    rh = [[NSClassFromString(defaultCompRqHandlerClassName) alloc] init];
    if ([rk isNotEmpty] && [rh isNotNull])
      [self registerRequestHandler:rh forKey:rk];
    [rh release]; rh = nil;
    
    rk = [WOApplication directActionRequestHandlerKey];
    rh = [[NSClassFromString(@"WODirectActionRequestHandler") alloc] init];
    if ([rk isNotEmpty] && [rh isNotNull])
      [self registerRequestHandler:rh forKey:rk];
    [rh release]; rh = nil;
    
    if ((rh = [[NSClassFromString(@"WOResourceRequestHandler") alloc] init])) {
      rk = [WOApplication resourceRequestHandlerKey];
      if ([rk isNotEmpty])
        [self registerRequestHandler:rh forKey:rk];
      [self registerRequestHandler:rh forKey:@"WebServerResources"];
#ifdef __APPLE__
      [self registerRequestHandler:rh forKey:@"Resources"];
#endif
      [rh release]; rh = nil;
    }

    /* setup session store */
    
    self->iSessionStore =
      [[NSClassFromString([self sessionStoreClassName]) alloc] init];
    
    /* setup statistics store */
    
    self->iStatisticsStore = [[WOStatisticsStore alloc] init];
    
    /* register timers */
    self->expirationTimer =
      [[NSTimer scheduledTimerWithTimeInterval:
                  [[ud objectForKey:@"WOExpirationTimeInterval"] intValue]
                target:self
                selector:@selector(performExpirationCheck:)
                userInfo:nil
                repeats:YES]
                retain];
    
    if ([ud boolForKey:@"WOLogDefaultsOnStartup"])
      [self _logDefaults];
    
    [[NSNotificationCenter defaultCenter]
                           postNotificationName:
                             WOApplicationWillFinishLaunchingNotification
                           object:self];
  }
  return self;
}

- (id)init {
  return [self initWithName:[[[NSProcessInfo processInfo]
                                             processName]
                                             stringByDeletingPathExtension]];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [self->expirationTimer invalidate];

  if (self->requestHandlerRegistry)
    NSFreeMapTable(self->requestHandlerRegistry);
  
  [self->expirationTimer release];
  [self->resourceManager release];
  [self->iSessionStore   release];
  [self->defaultRequestHandler release];
  [self->path            release];
  [self->name            release];
  [self->instanceNumber  release];
  [super dealloc];
}

- (void)processHupSignal:(int)_signal {
  /* this isn't called immediatly */
  [self logWithFormat:@"terminating on SIGHUP ..."];
  [self terminate];
}

/* accessors */

- (NSString *)name {
  return self->name;
}
- (BOOL)monitoringEnabled {
  return NO;
}
- (NSString *)path {
  static BOOL missingPath = NO;
  if (missingPath)
    return nil;
  
  if (self->path == nil) {
    if ((self->path = [[self _lookupAppPath] copy]) == nil) {
      [self debugWithFormat:@"could not find wrapper of application !"];
      missingPath = YES;
      return nil;
    }
  }
  return self->path;
}

- (NSString *)number {
  if (self->instanceNumber == nil) {
    id num;
      
    if ((num = [[NSUserDefaults standardUserDefaults] objectForKey:@"n"])) {
      self->instanceNumber = [[num stringValue] copy];
    }
    else {
      unsigned pid;
#if defined(__MINGW32__)
      pid = (unsigned)GetCurrentProcessId();
#else                     
      pid = (unsigned)getpid();
#endif
      self->instanceNumber = [[NSString alloc] initWithFormat:@"%d", pid];
    }
  }
  return self->instanceNumber;
}

- (void)_setCurrentContext:(WOContext *)_ctx {
  NSMutableDictionary *info;

  info = [[NSThread currentThread] threadDictionary];
  if (_ctx != nil)
    [info setObject:_ctx forKey:@"WOContext"];
  else
    [info removeObjectForKey:@"WOContext"];
}
- (WOContext *)context {
  // deprecated in WO4
  NSThread     *t;
  NSDictionary *td;
  
  if ((t = [NSThread currentThread]) == nil) {
    [self errorWithFormat:@"missing current thread !!!"];
    return nil;
  }
  if ((td = [t threadDictionary]) == nil) {
    [self errorWithFormat:
            @"missing current thread's dictionary (thread=%@) !!!",
            t];
    return nil;
  }
  
  return [td objectForKey:@"WOContext"];
}

/* request handlers */

- (void)registerRequestHandler:(WORequestHandler *)_hdl
  forKey:(NSString *)_key
{
  [self lock];
  NSMapInsert(self->requestHandlerRegistry, _key, _hdl);
  [self unlock];
}
- (void)removeRequestHandlerForKey:(NSString *)_key {
  if (_key == nil) return;
  [self lock];
  NSMapRemove(self->requestHandlerRegistry, _key);
  [self unlock];
}

- (void)setDefaultRequestHandler:(WORequestHandler *)_hdl {
  [self lock];
  ASSIGN(self->defaultRequestHandler, _hdl);
  [self unlock];
}
- (WORequestHandler *)defaultRequestHandler {
  return self->defaultRequestHandler;
}
- (WORequestHandler *)requestHandlerForKey:(NSString *)_key {
  WORequestHandler *handler;
  
  [self lock];
  handler = [(id)NSMapGet(self->requestHandlerRegistry, _key) retain];
  if (handler == nil)
    handler = [[self defaultRequestHandler] retain];
  [self unlock];
  
  return [handler autorelease];
}

- (NSArray *)registeredRequestHandlerKeys {
  NSMutableArray   *array = [NSMutableArray arrayWithCapacity:16];
  NSMapEnumerator  e;
  NSString         *key;
  WORequestHandler *handler;
  
  [self lock];
  e = NSEnumerateMapTable(self->requestHandlerRegistry);
  while (NSNextMapEnumeratorPair(&e, (void**)&key, (void**)&handler))
    [array addObject:key];
  [self unlock];
  
  return [[array copy] autorelease];
}

- (WORequestHandler *)handlerForRequest:(WORequest *)_request {
  WORequestHandler *handler;
  NSString         *key;
  
  if ((key = [_request requestHandlerKey]) == nil)
    return [self defaultRequestHandler];
  
  handler = NSMapGet(self->requestHandlerRegistry, key);
  return (handler != nil) ? handler : [self defaultRequestHandler];
}

/* sessions */

- (WOSession *)_initializeSessionInContext:(WOContext *)_ctx {
  WOSession *sn;

  sn = [self createSessionForRequest:[_ctx request]];
  [_ctx setNewSession:sn];
  
  if ([sn respondsToSelector:@selector(prepare)]) {
#if DEBUG
    [self debugWithFormat:@"calling -prepare on session .."];
#endif
    [sn performSelector:@selector(prepare)];
  }

  [sn _awakeWithContext:_ctx];
  
  [[NSNotificationCenter defaultCenter]
                         postNotificationName:WOSessionDidCreateNotification
                         object:sn];
  return [sn autorelease];
}

- (NSString *)sessionIDFromRequest:(WORequest *)_request {
  NSString *sessionId;
  
  if (_request == nil) return nil;
  
  /* first look into form values */
  if ((sessionId = [_request formValueForKey:WORequestValueSessionID])!=nil) {
    if ([sessionId isNotEmpty])
      return sessionId;
  }
  
  /* now look into the cookies */
  if ((sessionId = [_request cookieValueForKey:[self name]]) != nil) {
    if ([sessionId respondsToSelector:@selector(objectEnumerator)]) {
      NSEnumerator *e;
      
      e = [(id)sessionId objectEnumerator];
      while ((sessionId = [e nextObject]) != nil) {
        if ([sessionId isNotEmpty] && ![sessionId isEqual:@"nil"])
          return sessionId;
      }
    }
    else {
      if ([sessionId isNotEmpty] && ![sessionId isEqual:@"nil"])
        return sessionId;
    }
  }
  
  return nil;
}

- (NSString *)createSessionIDForSession:(WOSession *)_session {
  /* session id must be 18 chars long for snsd to work ! */
  static unsigned int sessionCount = 0;
  NSString *wosid;
  unsigned char buf[20];
  
  sessionCount++;
  sprintf((char *)buf, "%04X%04X%02X%08X",
          [[self number] intValue], getpid(), sessionCount, 
          (unsigned int)time(NULL));
  wosid = [NSString stringWithCString:(char *)buf];
  return wosid;
}

- (id)createSessionForRequest:(WORequest *)_request {
  if ([self respondsToSelector:@selector(createSession)]) {
    /* call deprecated method */
    [self warnWithFormat:@"calling deprecated -createSession .."];
    return [self createSession];
  }
  else {
    Class snClass = Nil;
    
    if ((snClass = NSClassFromString(@"Session")) == Nil)
      snClass = [WOSession class];
    
    return [[snClass alloc] init];
  }
}

- (id)restoreSessionWithID:(NSString *)_sid inContext:(WOContext *)_ctx {
  WOSession *session;
  
  *(&session) = nil;

  if ([self respondsToSelector:@selector(restoreSession)]) {
    /* call deprecated method */
    [self warnWithFormat:@"calling deprecated -restoreSession .."];
    return [self restoreSession];
  }
  
  SYNCHRONIZED(self) {
    WOSessionStore *store;
    
    if ((store = [self sessionStore]) == nil) {
      [self errorWithFormat:@"missing session store ..."];
    }
    else {
      session = [store restoreSessionWithID:_sid request:[_ctx request]];
      if ([session isNotNull]) {
        [_ctx setSession:session];
        [session _awakeWithContext:_ctx];
      }
      else {
        [self debugWithFormat:@"did not find a session for sid '%@'", _sid];
      }
    }
  }
  END_SYNCHRONIZED;
  
  if (session) {
    [[NSNotificationCenter defaultCenter]
                           postNotificationName:WOSessionDidRestoreNotification
                           object:session];
  }
  else {
    if ([_sid hasPrefix:@"("]) {
      id sid;

      sid = [_sid propertyList];
      
      if ([sid respondsToSelector:@selector(objectEnumerator)]) {
        NSEnumerator *e;
        
        [self errorWithFormat:@"got multiple session IDs !"];
        
        e = [sid objectEnumerator];
        while ((_sid = [e nextObject])) {
          if ([_sid isEqualToString:@"nil"])
            continue;
          
          if ((session = [self restoreSessionWithID:_sid inContext:_ctx]))
            return session;
          
          //[self warnWithFormat:@"did not find session for sid %@", _sid);
        }
      }
    }
  }
  return session;
}
- (void)saveSessionForContext:(WOContext *)_ctx {
  NSTimeInterval startSave = 0.0;

  if (perfLogger)
    startSave = [[NSDateClass date] timeIntervalSince1970];
  
  if ([self respondsToSelector:@selector(saveSession:)]) {
    /* call deprecated method */
    [self warnWithFormat:@"calling deprecated -saveSession: .."];
    [self saveSession:[_ctx session]];
    return;
  }
  
  SYNCHRONIZED(self) {
    WOSession     *sn;
    NSTimeInterval startSnSleep = 0.0, startStore = 0.0;
    
    sn = [_ctx session];

    if (perfLogger)
      startSnSleep = [[NSDateClass date] timeIntervalSince1970];
    
    /* put session to sleep */
    [sn _sleepWithContext:_ctx];
    
    if (perfLogger) {
      NSTimeInterval rt;
      rt = [[NSDateClass date] timeIntervalSince1970] - startSnSleep;
      [perfLogger logWithFormat:@"[woapp]: session -sleep took %4.3fs.",
                                    rt < 0.0 ? -1.0 : rt];
    }
    
    if ([sn isTerminating]) {
      [[NSNotificationCenter defaultCenter]
                             postNotificationName:
                               WOSessionDidTerminateNotification
                             object:sn];
    }
    
    if (perfLogger)
      startStore = [[NSDateClass date] timeIntervalSince1970];
    
    [[self sessionStore] saveSessionForContext:_ctx];
    
    if (perfLogger) {
      NSTimeInterval rt;
      rt = [[NSDateClass date] timeIntervalSince1970] - startStore;
      [perfLogger logWithFormat:@"[woapp]: storing sn in store took %4.3fs.",
                                    rt < 0.0 ? -1.0 : rt];
    }
  }
  END_SYNCHRONIZED;

  if (perfLogger) {
    NSTimeInterval rt;
    rt = [[NSDateClass date] timeIntervalSince1970] - startSave;
    [perfLogger logWithFormat:@"[woapp]: saveSessionForContext took %4.3fs.",
                                  rt < 0.0 ? -1.0 : rt];
  }
}

- (void)refuseNewSessions:(BOOL)_flag {
  self->appFlags.doesRefuseNewSessions = _flag ? 1 : 0;
}
- (BOOL)isRefusingNewSessions {
  return self->appFlags.doesRefuseNewSessions;
}
- (int)activeSessionsCount {
  return [[self sessionStore] activeSessionsCount];
}

- (void)setSessionStore:(WOSessionStore *)_store {
  ASSIGN(self->iSessionStore, _store);
}
- (NSString *)sessionStoreClassName {
  return [[NSUserDefaults standardUserDefaults] stringForKey:@"WOSessionStore"];
}
- (WOSessionStore *)sessionStore {
  return self->iSessionStore;
}

- (void)setMinimumActiveSessionsCount:(int)_minimum {
  self->minimumActiveSessionsCount = _minimum;
}
- (int)minimumActiveSessionsCount {
  return self->minimumActiveSessionsCount;
}

- (void)performExpirationCheck:(NSTimer *)_timer {
  WOSessionStore *ss;

  /* let session store check for expiration ... */
  
  ss = [self sessionStore];
  if ([ss respondsToSelector:@selector(performExpirationCheck:)])
    [ss performExpirationCheck:_timer];
  
  /* check whether application should terminate ... */

  if ([self isRefusingNewSessions] &&
      ([self activeSessionsCount] < [self minimumActiveSessionsCount])) {
    /* check whether the application instance is still valid .. */
    [self debugWithFormat:
            @"application terminates because it refuses new sessions and "
            @"the active session count (%i) is below the minimum (%i).",
            [self activeSessionsCount], [self minimumActiveSessionsCount]];
    [self terminate];
  }
}

- (id)session {
  return [[self context] session];
}

- (WOResponse *)handleSessionCreationErrorInContext:(WOContext *)_ctx {
  WOResponse *response = [_ctx response];
  unsigned pid;
  
#ifdef __MINGW32__
  pid = GetCurrentProcessId();
#else
  pid = getpid();
#endif
  
  if ([self respondsToSelector:@selector(handleSessionCreationError)]) {
    [self warnWithFormat:@"called deprecated -handleSessionCreationError method"];
    return [self handleSessionCreationError];
  }
  
  [self errorWithFormat:@"could not create session for context %@", _ctx];
  
  [response setStatus:200];
  [response appendContentString:@"<h4>Session Creation Error</h4>\n<pre>"];
  [response appendContentString:
              @"Application Instance failed to create session."];
  [response appendContentHTMLString:
              [NSString stringWithFormat:
                          @"   application: %@\n"
                          @"   adaptor:     %@\n"
                          @"   baseURL:     %@\n"
                          @"   contextID:   %@\n"
                          @"   instance:    %i\n"
                          @"   request:     %@\n",
                          [self name],
                          [[_ctx request] adaptorPrefix],
                          [self baseURL],
                          [_ctx contextID],
                          pid,
                          [[_ctx request] description]]];
  [response appendContentString:@"</pre>"];
  return response;
}

- (WOResponse *)handleSessionRestorationErrorInContext:(WOContext *)_ctx {
  if ([self respondsToSelector:@selector(handleSessionRestorationError)]) {
    [self warnWithFormat:@"calling deprecated "
                            @"-handleSessionRestorationError method"];
    return [self handleSessionRestorationError];
  }
  
  // TODO: is it correct to return nil?
  // TODO: we should return a page saying sorry with a cookie + redirect
  [self errorWithFormat:@"could not restore session for context %@", _ctx];
  return nil;
}

/* statistics */

- (void)setStatisticsStore:(WOStatisticsStore *)_statStore {
  ASSIGN(self->iStatisticsStore, _statStore);
}
- (WOStatisticsStore *)statisticsStore {
  return self->iStatisticsStore;
}

- (bycopy NSDictionary *)statistics {
  return [[self statisticsStore] statistics];
}

/* resources */

- (void)_setupDefaultResourceManager {
  NSUserDefaults *ud;
  Class    rmClass;
  NSString *p;
  
  ud = [NSUserDefaults standardUserDefaults];
  p  = [ud stringForKey:@"WODefaultResourceManager"];
  rmClass = [p isNotEmpty]
    ? NSClassFromString(p)
    : [WOResourceManager class];
  
  if (rmClass == Nil) {
    [self errorWithFormat:
            @"failed to locate class of resource manager: '%@'", p];
    return;
  }
  
  if ([rmClass instancesRespondToSelector:@selector(initWithPath:)])
    self->resourceManager = [[rmClass alloc] init];
  else {
    self->resourceManager = 
      [(WOResourceManager *)[rmClass alloc] initWithPath:[self path]];
  }
}

- (void)setResourceManager:(WOResourceManager *)_manager {
  ASSIGN(self->resourceManager, _manager);
}
- (WOResourceManager *)resourceManager {
  if (self->resourceManager == nil)
    [self _setupDefaultResourceManager];
  
  return self->resourceManager;
}

- (NSURL *)baseURL {
  NSString  *n;
  WOContext *ctx = [self context];
  
  n = [[ctx request] applicationName];
  n = [@"/" stringByAppendingString:n ? n : [self name]];
  
  return [NSURL URLWithString:n relativeToURL:[ctx baseURL]];
}

- (NSString *)pathForResourceNamed:(NSString *)_name ofType:(NSString *)_type {
  IS_DEPRECATED;
  return [[self resourceManager] pathForResourceNamed:_name ofType:_type];
}

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_default
{
  IS_DEPRECATED;
  return [[self resourceManager] stringForKey:_key
                                 inTableNamed:_tableName
                                 withDefaultValue:_default
                                 languages:
                                   [(WOSession *)[self session] languages]];
}

/* notifications */

- (void)awake {
}
- (void)sleep {
#if DEBUG && PRINT_NSSTRING_STATISTICS
  if ([NSString respondsToSelector:@selector(printStatistics)])
    [NSString printStatistics];
#endif
  
#if DEBUG && PRINT_OBJC_STATISTICS
extern int __objc_selector_max_index;
  printf("nbuckets=%i, nindices=%i, narrays=%i, idxsize=%i\n",
nbuckets, nindices, narrays, idxsize);
  printf("maxsel=%i\n", __objc_selector_max_index);
#endif
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  if ([_ctx hasSession])
    [[_ctx session] takeValuesFromRequest:_req inContext:_ctx];
  else {
    WOComponent *page;
    
    if ((page = [_ctx page]) != nil) {
      WOContext_enterComponent(_ctx, page, nil);
      [page takeValuesFromRequest:_req inContext:_ctx];
      WOContext_leaveComponent(_ctx, page);
    }
  }
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id result;
  
  if ([_ctx hasSession])
    result = [[_ctx session] invokeActionForRequest:_rq inContext:_ctx];
  else {
    WOComponent *page;
    
    if ((page = [_ctx page])) {
      WOContext_enterComponent(_ctx, page, nil);
      result = [[_ctx page] invokeActionForRequest:_rq inContext:_ctx];
      WOContext_leaveComponent(_ctx, page);
    }
    else
      result = nil;
  }
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([_ctx hasSession])
    [[_ctx session] appendToResponse:_response inContext:_ctx];
  else {
    WOComponent *page;
    
    if ((page = [_ctx page])) {
      WOContext_enterComponent(_ctx, page, nil);
      [page appendToResponse:_response inContext:_ctx];
      WOContext_leaveComponent(_ctx, page);
    }
  }

  if(rapidTurnAroundPath != nil) {
      WOComponent *page;
      
      if((page = [_ctx page])) {
          WOElement *template;
          
          template = [page _woComponentTemplate];
          if([template isKindOfClass:WOTemplateClass]) {
              NSString *_path;
              
              _path = [[(WOTemplate *)template url] path];
              [_response setHeader:_path
                            forKey:@"x-sope-template-path"];
          }

      }
  }
}

// dynamic elements

- (WOElement *)dynamicElementWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  template:(WOElement *)_template
  languages:(NSArray *)_languages
{
  WOElement *element            = nil;
  Class     dynamicElementClass = NSClassFromString(_name);

  if (dynamicElementClass == Nil) {
    [self warnWithFormat:@"did not find dynamic element class %@ !", _name];
    return nil;
  }
  if (![dynamicElementClass isDynamicElement]) {
    [self warnWithFormat:@"class %@ is not a dynamic element class !", _name];
    return nil;
  }
  
  element = [[dynamicElementClass allocWithZone:[_template zone]]
                                  initWithName:_name
                                  associations:_associations
                                  template:_template];
  return element;
}
- (WOElement *)dynamicElementWithName:(NSString *)_name
  associations:(NSDictionary *)_associations
  template:(WOElement *)_template
{
  return [self dynamicElementWithName:_name
               associations:_associations
               template:_template
               languages:[(WOSession *)[self session] languages]];
}

// pages

- (void)setPageRefreshOnBacktrackEnabled:(BOOL)_flag {
  self->appFlags.isPageRefreshOnBacktrackEnabled = _flag ? 1 : 0;
}
- (BOOL)isPageRefreshOnBacktrackEnabled {
  return self->appFlags.isPageRefreshOnBacktrackEnabled ? YES : NO;
}

- (void)setCachingEnabled:(BOOL)_flag {
  self->appFlags.isCachingEnabled = _flag ? 1 : 0;
}
- (BOOL)isCachingEnabled {
  // component definition caching
  return self->appFlags.isCachingEnabled ? YES : NO;
}

- (void)setPageCacheSize:(int)_size {
  self->pageCacheSize = _size;
}
- (int)pageCacheSize {
  return self->pageCacheSize;
}
- (void)setPermanentPageCacheSize:(int)_size {
  self->permanentPageCacheSize = _size;
}
- (int)permanentPageCacheSize {
  return self->permanentPageCacheSize;
}

- (id)pageWithName:(NSString *)_name {
  // deprecated in WO4
  return [self pageWithName:_name inContext:[self context]];
}

- (WOComponent *)_pageWithName:(NSString *)_name inContext:(WOContext *)_ctx {
  /*
    OSX profiling: 3.4% of dispatchRequest?
      3.0%  rm -pageWithName..
        1.5%  def instantiate
          1.3% initWithName:...
            0.76% initWithContent:.. (0.43 addobserver)
        0.76% rm  defForComp (0.43% touch)
        0.54% pool
      0.11% ctx -component
      0.11% pool
  */
  NSArray           *languages;
  WOComponent       *page;
  NSAutoreleasePool *pool;
  WOResourceManager *rm;

#if MEM_DEBUG
  NSDictionary *start, *stop;
  start = [self memoryStatistics];
#endif
  
  pool      = [[NSAutoreleasePool alloc] init];
  
  languages = [_ctx resourceLookupLanguages];

  if ((rm = [[_ctx component] resourceManager]) == nil)
    rm = [self resourceManager];
  
  /*  TODO:
   *  the following ignores the fact that the passed context may be different
   *  from that of WOApplication. During the course of template instantiation
   *  WOApplication's current context gets attached to page which is definitely
   *  wrong. We workaround this problem by using the private API of WOComponent
   *  to explicitly set it. However all accompanied methods should be
   *  extended to pass the correct context where needed.
   */
  page      = [rm pageWithName:(_name != nil ? _name : (NSString *)@"Main")
                  languages:languages];
  [page _setContext:_ctx];
  [page ensureAwakeInContext:_ctx];
  
  page = [page retain];
  [pool release];

#if MEM_DEBUG
  {
    int rss, vmsize, lib;
    stop = [self memoryStatistics];
    rss    = [[stop objectForKey:@"VmRSS"] intValue] -
             [[start objectForKey:@"VmRSS"] intValue];
    vmsize = [[stop objectForKey:@"VmSize"] intValue] -
             [[start objectForKey:@"VmSize"] intValue];
    lib    = [[stop objectForKey:@"VmLib"] intValue] -
             [[start objectForKey:@"VmLib"] intValue];
    [self debugWithFormat:@"loaded component %@; rss=%i vm=%i lib=%i.",
            _name, rss,vmsize,lib];
  }
#endif
  
  return [page autorelease];
}
- (id)pageWithName:(NSString *)_name inContext:(WOContext *)_ctx {
  return [self _pageWithName:_name inContext:_ctx];
}
- (id)pageWithName:(NSString *)_name forRequest:(WORequest *)_req {
  WOResourceManager *rm;

  if ((rm = [self resourceManager]) == nil)
    return nil;
  
  return [rm pageWithName:(_name != nil) ? _name : (NSString *)@"Main"
             languages:[_req browserLanguages]];
}

- (void)savePage:(WOComponent *)_page {
  IS_DEPRECATED;
  [[[self context] session] savePage:_page];
}
- (id)restorePageForContextID:(NSString *)_ctxId {
  IS_DEPRECATED;
  return [[[self context] session] restorePageForContextID:_ctxId];
}

- (WOResponse *)handlePageRestorationErrorInContext:(WOContext *)_ctx {
  [self errorWithFormat:
          @"could not restore page for context-id %@\n  in context %@",
          [_ctx currentElementID], _ctx];
  
  /* return main page ... */
  return [[self pageWithName:nil inContext:_ctx] generateResponse];
}
- (WOResponse *)handlePageRestorationError {
  IS_DEPRECATED;
  return [self handlePageRestorationErrorInContext:[self context]];
}

/* exceptions */

- (WOResponse *)handleException:(NSException *)_exc
  inContext:(WOContext *)_ctx
{
  WORequest  *rq = [_ctx request];
  WOResponse *r  = nil;
  
  if ([self respondsToSelector:@selector(handleException:)]) {
    [self warnWithFormat:@"calling deprecated -handleException method !"];
    return [self handleException:_exc];
  }
  
#if DEBUG
  {
    static int doCore = -1;
    if (doCore == -1) {
      doCore = [[NSUserDefaults standardUserDefaults] 
		 boolForKey:@"WOCoreOnApplicationException"]
	? 1 : 0;
    }
    if (doCore) {
      [self fatalWithFormat:@"%@: caught (ctx=%@):\n  %@.",
              self, _ctx, _exc];
      abort();
    }
  }
#endif
  
  if (_ctx == nil) {
    [self fatalWithFormat:@"%@: caught (without context):\n  %@.",
            self, _exc];
    [self terminate];
  }
  else if (rq == nil) {
    [self fatalWithFormat:@"%@: caught (without request):\n  %@.",
            self, _exc];
    [self terminate];
  }
  else {
    static NSString *pageFormat =
      @"Application Server caught exception:\n\n"
      @"  session:   %@\n"
      @"  element:   %@\n"
      @"  context:   %@\n"
      @"  request:   %@\n\n"
      @"  class:     %@\n"
      @"  name:      %@\n"
      @"  reason:    %@\n"
      @"  info:\n    %@\n"
      @"  backtrace:\n%@\n";
    NSString *str = nil;
    NSString *bt  = nil;
    
    [self errorWithFormat:@"%@: caught:\n  %@\nin context:\n  %@.",
            self, _exc, _ctx];

#if LIB_FOUNDATION_LIBRARY
    if ([NSException respondsToSelector:@selector(backtrace)])
      bt = [NSException backtrace];
#endif
    
    if ((r = [WOResponse responseWithRequest:rq]) == nil)
      [self errorWithFormat:@"could not create response !"];
    
    [r setHeader:@"text/html" forKey:@"content-type"];
    [r setHeader:@"no-cache" forKey:@"cache-control"];
    if (rapidTurnAroundPath != nil) {
        NSURL *templateURL;
        
        templateURL = [[_exc userInfo] objectForKey:@"templateURL"];
        if(templateURL != nil)
            [r setHeader:[templateURL path] forKey:@"x-sope-template-path"];
    }

    str = [NSString stringWithFormat:pageFormat,
                      [_ctx hasSession] 
                        ? [[_ctx session] sessionID]
		        : (NSString *)@"[no session]",
                      [_ctx elementID],
                      [_ctx description],
                      [rq description],
                      NSStringFromClass([_exc class]),
                      [_exc name],
                      [_exc reason],
                      [[_exc userInfo] description],
                      bt];
    
    [r appendContentString:@"<html><head><title>Caught exception</title></head><body><pre>\n"];
    [r appendContentHTMLString:str];
    [r appendContentString:@"</pre></body></html>\n"];
  }
  return r;
}

/* runloop */

- (BOOL)shouldTerminate {
  if (![self isRefusingNewSessions])
    return NO;
  if ([self activeSessionsCount] >= [self minimumActiveSessionsCount])
    return NO;

  /* check whether the application instance is still valid .. */
  [self debugWithFormat:
	  @"application terminates because it refuses new sessions and "
	  @"the active session count (%i) is below the minimum (%i).",
	  [self activeSessionsCount], [self minimumActiveSessionsCount]];
  return YES;
}

- (void)terminate {
  [self debugWithFormat:
          @"application terminates:\n"
          @"  %i active sessions\n"
          @"  %i minimum active sessions\n"
          @"  refuses new session: %s",
          [self activeSessionsCount],
          [self minimumActiveSessionsCount],
          [self isRefusingNewSessions] ? "yes" : "no"];
  [super terminate];
}

/* logging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}
- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"|%@%@|", 
                     [self name],
                     [self isTerminating] ? @" terminating" : @""];
}

/* KVC */

#if !LIB_FOUNDATION_LIBRARY
- (id)valueForUndefinedKey:(NSString *)_key {
  [self warnWithFormat:@"tried to access undefined KVC key: '%@'",
	  _key];
  return nil;
}
#endif

/* configuration */

+ (Class)eoEditingContextClass {
  static Class eoEditingContextClass = Nil;
  static BOOL  lookedUpForEOEditingContextClass = NO;
  
  if (!lookedUpForEOEditingContextClass) {
    if ((eoEditingContextClass = NSClassFromString(@"EOEditingContext")) ==nil)
      eoEditingContextClass = NSClassFromString(@"NSManagedObjectContext");
    lookedUpForEOEditingContextClass = YES;
  }
  return eoEditingContextClass;
}

+ (BOOL)implementsEditingContexts {
  return [self eoEditingContextClass] != NULL ? YES : NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: name=%@%@>",
                     NSStringFromClass([self class]), self,
                     [self name],
                     [self isTerminating] ? @" terminating" : @""
                   ];
}

@end /* WOApplication */
