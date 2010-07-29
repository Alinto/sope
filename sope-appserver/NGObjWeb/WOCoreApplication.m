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

#include <NGObjWeb/WOCoreApplication.h>
#include <NGObjWeb/WOAdaptor.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WORequestHandler.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOContext.h>
#import <EOControl/EOControl.h>
#include <NGStreams/NGStreams.h>
#include <NGStreams/NGNet.h>
#include <NGExtensions/NGResourceLocator.h>
#include "WORunLoop.h"
#include "common.h"

#if LIB_FOUNDATION_LIBRARY
#  import <Foundation/UnixSignalHandler.h>
#else
#  include "UnixSignalHandler.h"
#endif

NGObjWeb_DECLARE NSString *WOApplicationDidFinishLaunchingNotification =
  @"WOApplicationDidFinishLaunching";
NGObjWeb_DECLARE NSString *WOApplicationWillFinishLaunchingNotification =
  @"WOApplicationWillFinishLaunching";
NGObjWeb_DECLARE NSString *WOApplicationWillTerminateNotification =
  @"WOApplicationWillTerminate";
NGObjWeb_DECLARE NSString *WOApplicationDidTerminateNotification =
  @"WOApplicationDidTerminate";

@interface WOCoreApplication(PrivateMethods)
+ (id)logger;
- (NSDictionary *)memoryStatistics;
- (WOResponse *)handleException:(NSException *)_exc;
+ (NSString *)findNGObjWebResource:(NSString *)_name ofType:(NSString *)_ext;
@end

#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(KVCWarn)
+ (void)suppressCapitalizedKeyWarning;
- (void)notImplemented:(SEL)cmd;
@end
#endif

@implementation WOCoreApplication

static BOOL     outputValidateOn = NO;
static Class    NSDateClass      = Nil;
static NGLogger *logger          = nil;
static NGLogger *perfLogger      = nil;

+ (int)version {
  return 1;
}

NGObjWeb_DECLARE id WOApp = nil;
static NSMutableArray *activeApps = nil; // THREAD

+ (void)registerUserDefaults {
  NSDictionary *owDefaults = nil;
  NSString     *apath;
  
  apath = [[self class] findNGObjWebResource:@"Defaults" ofType:@"plist"];
  if (apath == nil)
    [self errorWithFormat:@"Cannot find Defaults.plist resource of "
                          @"NGObjWeb library!"];
#if HEAVY_DEBUG
  else
    [self debugWithFormat:@"Note: loading default defaults: %@", apath];
#endif
  
  owDefaults = [NSDictionary dictionaryWithContentsOfFile:apath];
  if (owDefaults) {
    [[NSUserDefaults standardUserDefaults] registerDefaults:owDefaults];
#if HEAVY_DEBUG
    [self debugWithFormat:@"did register NGObjWeb defaults: %@\n%@", 
                          apath, owDefaults];
#endif
  }
  else {
    [self errorWithFormat:@"could not load NGObjWeb defaults: '%@'",
	                        apath];
  }
}

+ (void)initialize
{
  static BOOL initialized = NO;

  if (!initialized) {
    [self registerUserDefaults];
    initialized = YES;
  }
}

+ (id)application {
  if (WOApp == nil) {
    [self warnWithFormat:@"%s: some code called +application without an "
            @"active app !", __PRETTY_FUNCTION__];
#if DEBUG && 0
#  warning REMOVE THAT ABORT IN PRODUCTION CODE !!!
    abort();
#endif
  }
  return WOApp;
}
- (void)activateApplication {
  if (WOApp) {
    if (activeApps == nil)
      activeApps = [[NSMutableArray alloc] init];
    [activeApps addObject:WOApp];
  }
  ASSIGN(WOApp, self);
}
- (void)deactivateApplication {
  unsigned idx;
  
  if (WOApp != self) {
    [self warnWithFormat:
            @"tried to deactivate inactive application !\n"
            @"  self:   %@\n"
            @"  active: %@",
            self, WOApp];
    return;
  }
  [self autorelease];
  WOApp = nil;
  
  if ((idx = [activeApps count]) > 0) {
    idx--;
    WOApp = [[activeApps objectAtIndex:idx] retain];
    [activeApps removeObjectAtIndex:idx];
  }
}

- (id)init {
#if COCOA_Foundation_LIBRARY
  /*
    NSKeyBinding Warning: <Application 0xc1f70> was accessed using a capitalized key
    'NSFileSubject'.  Keys should normally start with a lowercase character.  A
    typographical error like this could cause a crash or an infinite loop.  Use
    +[NSKeyBinding suppressCapitalizedKeyWarning] to suppress this warning.
  */
  [NSClassFromString(@"NSKeyBinding") suppressCapitalizedKeyWarning];
#endif
  
  if ((self = [super init])) {
    NSUserDefaults  *ud;
    NGLoggerManager *lm;

    ud               = [NSUserDefaults standardUserDefaults];
    lm               = [NGLoggerManager defaultLoggerManager];
    logger           = [lm loggerForClass:[self class]];
    perfLogger       = [lm loggerForDefaultKey:@"WOProfileApplication"];
    outputValidateOn = [ud boolForKey:@"WOOutputValidationEnabled"];
    NSDateClass      = [NSDate class];

    [self activateApplication];
    
    if ([[ud objectForKey:@"WORunMultithreaded"] boolValue]) {
      self->lock        = [[NSRecursiveLock alloc] init];
      self->requestLock = [[NSLock alloc] init];
    }
    
    /* handle signals */
#if !defined(__MINGW32__) && !defined(NeXT_Foundation_LIBRARY)
    {
      UnixSignalHandler *us = [UnixSignalHandler sharedHandler];
      
      [us addObserver:self selector:@selector(terminateOnSignal:)
          forSignal:SIGTERM immediatelyNotifyOnSignal:YES];
      [us addObserver:self selector:@selector(terminateOnSignal:)
          forSignal:SIGINT immediatelyNotifyOnSignal:YES];
      [us addObserver:self selector:@selector(terminateOnSignal:)
          forSignal:SIGQUIT immediatelyNotifyOnSignal:YES];
      [us addObserver:self selector:@selector(terminateOnSignal:)
          forSignal:SIGILL immediatelyNotifyOnSignal:YES];
      
      [us addObserver:self selector:@selector(processHupSignal:)
          forSignal:SIGHUP immediatelyNotifyOnSignal:NO];
    }
#endif
    
    controlSocket = nil;
    listeningSocket = nil;
  }
  return self;
}

- (void)dealloc {
#if !defined(__MINGW32__) && !defined(NeXT_Foundation_LIBRARY)
  [[UnixSignalHandler sharedHandler] removeObserver:self];
#endif
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->adaptors    release];
  [self->requestLock release];
  [self->lock        release];
  [self->listeningSocket release];
  [self->controlSocket release];
  [super dealloc];
}

/* Watchdog helpers */
- (void)setControlSocket: (NGActiveSocket *) newSocket
{
  ASSIGN(self->controlSocket, newSocket);
}

- (NGActiveSocket *)controlSocket
{
  return self->controlSocket;
}

- (void)setListeningSocket: (NGPassiveSocket *) newSocket
{
  ASSIGN(self->listeningSocket, newSocket);
}

- (NGPassiveSocket *)listeningSocket
{
  return self->listeningSocket;
}

/* NGLogging */

+ (id)logger {
  return logger;
}

- (id)logger {
  return logger;
}

/* signals */

- (void)processHupSignal:(int)_signal {
  /* this isn't called immediatly */
}

- (void)terminateOnSignal:(int)_signal {
  /* STDIO is forbidden in signal handlers !!! no malloc !!! */
#if 1
  self->cappFlags.isTerminating = 1;
  [self->listeningSocket close];
#else
  static int termCount = 0;
  unsigned pid;
  
#ifdef __MINGW32__
  pid = (unsigned)GetCurrentProcessId();
#else
  pid = (unsigned)getpid();
#endif
  
  if ([self isTerminating]) {
#if 0
    termCount++;
    if (termCount > 2);
#endif
    fflush(stderr);
    fprintf(stderr, "%d: forcing termination because of signal %i\n",
	    pid, _signal);
    fflush(stderr);
    exit(20);
  }
  termCount = 0;
  
  fflush(stderr);
  fprintf(stderr, "%i: terminating because of signal %i\n", pid, _signal);
  fflush(stderr);
  
  [self terminate];
#endif
}

/* adaptors */

- (NSArray *)adaptors {
  return self->adaptors;
}
- (WOAdaptor *)adaptorWithName:(NSString *)_name
  arguments:(NSDictionary *)_args
{
  Class     adaptorClass = Nil;
  WOAdaptor *adaptor     = nil;

  adaptorClass = NSClassFromString(_name);
  if (adaptorClass == Nil) {
    [self errorWithFormat:@"did not find adaptor class %@", _name];
    return nil;
  }

  adaptor = [[adaptorClass allocWithZone:[self zone]]
                           initWithName:_name
                           arguments:_args
                           application:self];
  
  return [adaptor autorelease];
}

- (BOOL)allowsConcurrentRequestHandling {
  return NO;
}
- (BOOL)adaptorsDispatchRequestsConcurrently {
  return NO;
}

/* request recording */

- (void)setRecordingPath:(NSString *)_path {
  [self notImplemented:_cmd];
}
- (NSString *)recordingPath {
  static NSString *rp = nil;
  if (rp == nil) {
    rp = [[[NSUserDefaults standardUserDefaults]
                           stringForKey:@"WORecordingPath"]
                           copy];
  }
  return rp;
}

/* exceptions */

- (NSString *)name {
  return NSStringFromClass([self class]);
}

- (WOResponse *)handleException:(NSException *)_exc
  inContext:(WOContext *)_ctx
{
  WORequest  *rq = [_ctx request];
  WOResponse *r  = nil;
  
  if ([self respondsToSelector:@selector(handleException:)]) {
    [self warnWithFormat:@"calling deprecated -handleException method !"];
    return [self handleException:_exc];
  }
  
#if 0 && DEBUG
  [self errorWithFormat:@"%@: caught (without context):\n  %@.", self, _exc];
  abort();
#endif
  
  if (_ctx == nil) {
    [self errorWithFormat:@"%@: caught (without context):\n  %@.",
      self, _exc];
    [self terminate];
  }
  else if (rq == nil) {
    [self errorWithFormat:@"%@: caught (without request):\n  %@.",
      self, _exc];
    [self terminate];
  }
  else {
    [self logWithFormat:@"%@: caught:\n  %@\nin context:\n  %@.",
            self, _exc, _ctx];
  }
  
  if ((r = [WOResponse responseWithRequest:rq]) == nil)
    [self warnWithFormat:@"could not create response !"];
    
  [r setStatus:500];
  return r;
}

/* multithreading */

- (void)lock {
  [self->lock lock];
}
- (void)unlock {
  [self->lock unlock];
}
- (BOOL)tryLock {
  return [self->lock tryLock];
}

- (void)lockRequestHandling {
  [self->requestLock lock];
}
- (void)unlockRequestHandling {
  [self->requestLock unlock];
}

/* notifications */

- (void)awake {
}
- (void)sleep {
}

/* runloop */

- (void)_loadAdaptors {
  NSMutableArray *ads = nil;
  NSArray *args;
  int     i, count;
      
  args = [[NSProcessInfo processInfo] arguments];
      
  for (i = 0, count = [args count]; i < count; i++) {
    NSString *arg;
        
    arg = [args objectAtIndex:i];
        
    if ([arg isEqualToString:@"-a"] && ((i + 1) < count)) {
      // found adaptor
      NSString            *adaptorName = nil;
      NSMutableDictionary *arguments   = nil;
      WOAdaptor           *adaptor     = nil;

      i++; // skip '-a' option
      adaptorName = [args objectAtIndex:i];
      i++; // skip adaptor name

      if (i < count) { // search for arguments
        NSString *key = nil;
            
        arguments = [NSMutableDictionary dictionaryWithCapacity:10];
        for (; i < count; i++) {
          arg = [args objectAtIndex:i];
          if ([arg isEqualToString:@"-a"] ||
              [arg isEqualToString:@"-c"] ||
              [arg isEqualToString:@"-d"]) {
            i--;
            break;
          }
          if (key == nil)
            key = arg;
          else {
            [arguments setObject:arg forKey:key];
            key = nil;
          }
        }
      }

      adaptor = [self adaptorWithName:adaptorName
                      arguments:[[arguments copy] autorelease]];
      if (adaptor) {
        if (ads == nil) ads = [[NSMutableArray alloc] initWithCapacity:8];
        [ads addObject:adaptor];
      }
    }
  }

  self->adaptors = [ads copy];
  [ads release]; ads = nil;
      
  if ([self->adaptors count] == 0) {
    id      defaultAdaptor;
    NSArray *moreAdaptors;
        
    defaultAdaptor = [[self class] adaptor];
    defaultAdaptor = [self adaptorWithName:defaultAdaptor arguments:nil];
    if (defaultAdaptor) {
      self->adaptors = [[NSArray alloc] initWithObjects:defaultAdaptor, nil];
    }

    moreAdaptors = [[self class] additionalAdaptors];
    if ([moreAdaptors count] > 0) {
      unsigned i, count;
      NSMutableArray *newArray;

      newArray = nil;
      
      for (i = 0, count = [moreAdaptors count]; i < count; i++) {
        WOAdaptor *adaptor;

        adaptor = [self adaptorWithName:[moreAdaptors objectAtIndex:i]
                        arguments:nil];
        if (adaptor == nil) {
          [self warnWithFormat:@"could not find WOAdaptor '%@' !",
                [moreAdaptors objectAtIndex:i]];
          continue;
        }

        if (newArray == nil) {
          newArray = [self->adaptors mutableCopy];
          [newArray addObject:adaptor];
        }
      }
      [self->adaptors release];
      self->adaptors = [newArray shallowCopy];
      [newArray release]; newArray = nil;
    }
  }
}

- (void)_setupAdaptors {
  // register adaptors
  NSEnumerator *ads;
  WOAdaptor    *adaptor;

  if ([self->adaptors count] == 0)
    [self _loadAdaptors];
  
  ads = [self->adaptors objectEnumerator];
  while ((adaptor = [ads nextObject]))
    [adaptor registerForEvents];
}
- (void)_tearDownAdaptors {
  // unregister adaptors
  NSEnumerator *ads;
  WOAdaptor    *adaptor;
  
  ads = [self->adaptors objectEnumerator];
  while ((adaptor = [ads nextObject]))
    [adaptor unregisterForEvents];
  
  [self->adaptors release]; self->adaptors = nil;
}

- (NSRunLoop *)runLoop { // deprecated in WO4
  IS_DEPRECATED;
  return [self mainThreadRunLoop];
}
- (NSRunLoop *)mainThreadRunLoop {
  // wrong, should remove main thread runloop
  return [WORunLoop currentRunLoop];
}

- (BOOL)shouldTerminate {
  return NO;
}
- (void)run {
  [self activateApplication];
  {
    [self _setupAdaptors];
    
    [[NSNotificationCenter defaultCenter]
                           postNotificationName:
                             WOApplicationDidFinishLaunchingNotification
                           object:self];
  }
  [self deactivateApplication];
  
  while (![self isTerminating]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    if ([self shouldTerminate]) {
      /* check whether we should still process requests */
      [self terminate];
    }
    else {
      NSRunLoop *loop;
      NSDate *limitDate = nil;
      
      loop = [self mainThreadRunLoop];
      
      limitDate = [loop limitDateForMode:NSDefaultRunLoopMode];
      
      if ([self isTerminating])
        break;
      
      [self activateApplication];
      [loop runMode:NSDefaultRunLoopMode beforeDate:limitDate];
      [self deactivateApplication];
    }
    
    [pool release];
  }

  [self debugWithFormat:@"application finished runloop."];

  [self activateApplication];
  {
    [[NSNotificationCenter defaultCenter]
                           postNotificationName:
                             WOApplicationWillTerminateNotification
                           object:self];
  
    [self _tearDownAdaptors];
  
    self->cappFlags.isTerminating = 1;

    [[NSNotificationCenter defaultCenter]
                           postNotificationName:
                             WOApplicationDidTerminateNotification
                           object:self];
  }
  [self deactivateApplication];
}

- (void)terminate {
  self->cappFlags.isTerminating = 1;
}
- (BOOL)isTerminating {
  return self->cappFlags.isTerminating ? YES : NO;
}

- (void)_terminateNow:(id)_dummy {
  [self terminate];
}
- (void)terminateAfterTimeInterval:(NSTimeInterval)_interval {
  [[NSRunLoop currentRunLoop] cancelPerformSelector:@selector(_terminateNow:)
                              target:self argument:nil];
  [self performSelector:@selector(_terminateNow:) withObject:nil
        afterDelay:_interval];
}

/* output validation */

- (void)setPrintsHTMLParserDiagnostics:(BOOL)_flag {
  [[NSUserDefaults standardUserDefaults] setBool:_flag 
                                         forKey:@"WOOutputValidationEnabled"];
  outputValidateOn = _flag;
}
- (BOOL)printsHTMLParserDiagnostics {
  return outputValidateOn;
}

- (void)_logWarningOnOutputValidation {
  static BOOL didWarn = NO;

  if (!didWarn) {
    [self warnWithFormat:
            @"output validation is enabled, this will "
            @"slow down request processing!"];
    didWarn = YES;
  }
}

- (BOOL)hideValidationIssue:(NSException *)_issue {
  /* to deal with some non-standard HTML ... */
  return NO;
}

- (void)validateOutputOfResponse:(WOResponse *)_response {
  NSArray      *issues;
  NSEnumerator *e;
  id           issue;
  
  [self _logWarningOnOutputValidation];
  
  if (_response == nil) {
    [self logWithFormat:@"validate-output: no response returned by handler."];
    return;
  }
  
  if (![_response respondsToSelector:@selector(validateContent)]) {
    [self logWithFormat:@"response does not support content validation!"];
    return;
  }
  if ((issues = [_response validateContent]) == nil)
    return;
  
  e = [issues objectEnumerator];
  while ((issue = [e nextObject])) {
    if ([issue isKindOfClass:[NSException class]]) {
      if ([self hideValidationIssue:issue])
        continue;
      [self logWithFormat:@"validate-output[%@]: %@",
              [(NSException *)issue name], [issue reason]];
      continue;
    }
    
    [self logWithFormat:@"validate-output: %@", [issue stringValue]];
  }
}

/* request handling */

- (WORequestHandler *)handlerForRequest:(WORequest *)_request {
  return nil;
}

- (WOResponse *)dispatchRequest:(WORequest *)_request
  usingHandler:(WORequestHandler *)handler
{
  WOResponse     *response = nil;
  NSTimeInterval startDispatch = 0.0;
  
  if (perfLogger)
    startDispatch = [[NSDateClass date] timeIntervalSince1970];
  
  /* let request handler process the request */
  {
    NSTimeInterval startDispatch = 0.0;
    
    if (perfLogger)
      startDispatch = [[NSDateClass date] timeIntervalSince1970];
    
    /* the call ;-) */
    response = [handler handleRequest:_request];
    
    if (perfLogger) {
      NSTimeInterval rt;
      rt = [[NSDateClass date] timeIntervalSince1970] - startDispatch;
      [perfLogger logWithFormat:@"[woapp-rq]: request handler took %4.3fs.",
                                    rt < 0.0 ? -1.0 : rt];
    }
  }
  
  response = [[response retain] autorelease];

  if (outputValidateOn)
    [self validateOutputOfResponse:response];
  
  if (perfLogger) {
    NSTimeInterval rt;
    rt = [[NSDateClass date] timeIntervalSince1970] - startDispatch;
    [perfLogger logWithFormat:@"[woapp]: dispatchRequest took %4.3fs.",
                  rt < 0.0 ? -1.0 : rt];
  }
  
  return response;
}
- (WOResponse *)dispatchRequest:(WORequest *)_request {
  WORequestHandler *handler;
  
  if ([self respondsToSelector:@selector(handleRequest:)]) {
    [self warnWithFormat:
            @"calling deprecated -handleRequest: method .."];
    return [self handleRequest:_request];
  }
  
  /* find request handler for request */
  if ((handler = [self handlerForRequest:_request]) == nil) {
    [self errorWithFormat:@"got no request handler for request: %@ !",
	    _request];
    return nil;
  }
  
  return [self dispatchRequest:_request usingHandler:handler];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: %@>",
                     NSStringFromClass([self class]), self,
                     [self isTerminating] ? @" terminating" : @""
                   ];
}

/* defaults */

+ (int)sopeMajorVersion {
  return SOPE_MAJOR_VERSION;
}
+ (int)sopeMinorVersion {
  return SOPE_MINOR_VERSION;
}
+ (NSString *)ngobjwebShareDirectorySubPath {
  return [NSString stringWithFormat:@"share/sope-%i.%i/ngobjweb/",
                     [self sopeMajorVersion], [self sopeMinorVersion]];
}
+ (NGResourceLocator *)ngobjwebResourceLocator {
#if GNUSTEP_BASE_LIBRARY
  return [NGResourceLocator resourceLocatorForGNUstepPath:
                              @"Libraries/Resources/NGObjWeb"
                            fhsPath:[self ngobjwebShareDirectorySubPath]];
#else
  return [NGResourceLocator resourceLocatorForGNUstepPath:
                              @"Library/Libraries/Resources/NGObjWeb"
                            fhsPath:[self ngobjwebShareDirectorySubPath]];
#endif
}

+ (NSArray *)resourcesSearchPathes {
  // TODO: is this actually used somewhere?
  return [[self ngobjwebResourceLocator] searchPathes];
}

+ (NSString *)findNGObjWebResource:(NSString *)_name ofType:(NSString *)_ext {
#if COMPILE_AS_FRAMEWORK
  NSBundle *bundle;
  
  if ((bundle = [NSBundle bundleForClass:[WOCoreApplication class]]) == nil) {
    NSLog(@"ERROR(%s): did not find NGObjWeb framework bundle!",
	  __PRETTY_FUNCTION__);
    return nil;
  }
  
  return [bundle pathForResource:_name ofType:_ext];
#else
  return [[self ngobjwebResourceLocator] lookupFileWithName:_name 
                                         extension:_ext];
#endif
}

+ (NSUserDefaults *)userDefaults {
  return [NSUserDefaults standardUserDefaults];
}

/* WOAdaptor */

+ (void)setAdaptor:(NSString *)_key {
  [[self userDefaults] setObject:_key forKey:@"WOAdaptor"];
}
+ (NSString *)adaptor {
  return [[self userDefaults] stringForKey:@"WOAdaptor"];
}

+ (void)setAdditionalAdaptors:(NSArray *)_names {
  [[self userDefaults] setObject:_names forKey:@"WOAdditionalAdaptors"];
}
+ (NSArray *)additionalAdaptors {
  return [[self userDefaults] arrayForKey:@"WOAdditionalAdaptors"];
}

/* WOPort */

+ (void)setPort:(NSNumber *)_port {
  [[self userDefaults] setObject:_port forKey:@"WOPort"];
}
+ (NSNumber *)port {
  id woport;
  id addr;
  
  woport = [[self userDefaults] objectForKey:@"p"];
  if (!woport)
    woport = [[self userDefaults] objectForKey:@"WOPort"];
  if ([woport isKindOfClass:[NSNumber class]])
    return woport;
  woport = [woport stringValue];
  if ([woport length] > 0 && isdigit([woport characterAtIndex:0]))
    return [NSNumber numberWithInt:[woport intValue]];
  
  addr   = NGSocketAddressFromString(woport);
  
  if ([addr isKindOfClass:[NGInternetSocketAddress class]])
    return [NSNumber numberWithInt:[(NGInternetSocketAddress *)addr port]];

  [self fatalWithFormat:@"GOT NO PORT FOR ADDR: %@ (%@)", addr, woport];
  return nil;
}

/* WOWorkerThreadCount */

+ (NSNumber *)workerThreadCount {
  static NSNumber *s = nil;
  if (s == nil) {
    int i;
    i = [[self userDefaults] integerForKey:@"WOWorkerThreadCount"];
    s = [[NSNumber numberWithInt:i] retain];
  }
  return s;
}

/* WOListenQueueSize */

+ (NSNumber *)listenQueueSize {
  static NSNumber *s = nil;
  if (s == nil) {
    int i;
    i = [[self userDefaults] integerForKey:@"WOListenQueueSize"];
    s = [[NSNumber numberWithInt:i] retain];
  }
  return s;
}

@end /* WOCoreApplication */
