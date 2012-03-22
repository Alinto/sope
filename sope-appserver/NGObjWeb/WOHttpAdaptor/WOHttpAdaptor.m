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

#include <NGObjWeb/WOAdaptor.h>
#include <NGObjWeb/WOCoreApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOCookie.h>

#include "common.h"
#include "WORunLoop.h"
#include "NGHttp+WO.h"

//#define USE_POOLS 1

#if USE_POOLS
#  warning extensive pools are enabled ...
#endif

#include "WOHttpAdaptor.h"
#include "WORecordRequestStream.h"
#include "WOHttpTransaction.h"

#include <string.h>
#include <unistd.h>
#include <sys/wait.h>

void handle_SIGPIPE(int signum)
{
  NSLog(@"caught SIGPIPE - ignoring!");
}

@interface WOHttpAdaptor(Server)

/* accessors */

- (id<NGPassiveSocket>)socket;
- (id<NGSocketAddress>)serverAddress;

- (void)setSendTimeout:(NSTimeInterval)_timeout;
- (NSTimeInterval)sendTimeout;
- (void)setReceiveTimeout:(NSTimeInterval)_timeout;
- (NSTimeInterval)receiveTimeout;

@end /* WOHttpAdaptor */

@interface WOCoreApplication(Port)
- (NSNumber *)port;
@end

@implementation WOHttpAdaptor

static NGLogger *logger                      = nil;
static NGLogger *perfLogger                  = nil;
static BOOL     WOCoreOnHTTPAdaptorException = NO;
static int      WOHttpAdaptorSendTimeout     = 10;
static int      WOHttpAdaptorReceiveTimeout  = 10;
static BOOL     debugOn                      = NO;

+ (BOOL)optionLogPerf {
  return perfLogger != nil ? YES : NO;
}

+ (int)version {
  return [super version] + 1 /* v2 */;
}
+ (void)initialize {
  NSUserDefaults  *ud;
  NGLoggerManager *lm;
  static BOOL     didInit = NO;

  if (didInit) return;
  didInit = YES;

  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  ud = [NSUserDefaults standardUserDefaults];
  lm = [NGLoggerManager defaultLoggerManager];
  
  logger     = [lm loggerForClass:self];
  perfLogger = [lm loggerForDefaultKey:@"WOProfileHttpAdaptor"];

  WOCoreOnHTTPAdaptorException = 
    [[ud objectForKey:@"WOCoreOnHTTPAdaptorException"] boolValue] ? 1 : 0;
  
  WOHttpAdaptorSendTimeout    = 
    [ud integerForKey:@"WOHttpAdaptorSendTimeout"];
  WOHttpAdaptorReceiveTimeout = 
    [ud integerForKey:@"WOHttpAdaptorReceiveTimeout"];
  
  if (WOCoreOnHTTPAdaptorException)
    [logger warnWithFormat:@"will dump core on HTTP adaptor exception!"];
}

- (id)autoBindAddress {
  NGInternetSocketAddress *addr;
  addr = [[NGInternetSocketAddress alloc] initWithPort:0 onHost:@"127.0.0.1"];
  return [addr autorelease];
}

- (void)_registerForSignals {
  signal(SIGPIPE, handle_SIGPIPE);
}

- (id<NGSocketAddress>)addressFromDefaultsOfApplication:(WOCoreApplication*)_a{
  id                  woport;
  id<NGSocketAddress> lAddress = nil;
  const char *cstr;
  
  woport = [[NSUserDefaults standardUserDefaults] stringForKey:@"WOPort"];
  if ([woport isEqualToString:@"auto"]) {
    if ((lAddress = [self autoBindAddress]) != nil)
      return lAddress;
  }
  
  if ((cstr = [woport cString]) != NULL) {
    if (isdigit(*cstr) && index(cstr, ':') == NULL) {
      NSNumber *p;
          
      p = [(WOCoreApplication *)[_a class] port];
      if (p == nil) p = (id)woport;
          
      lAddress =
	[NGInternetSocketAddress wildcardAddressWithPort:[p intValue]];
      if (lAddress != nil)
	return lAddress;
    }
  }
  
  return NGSocketAddressFromString(woport);
}

- (id<NGSocketAddress>)addressFromArguments:(NSDictionary *)_args {
  id<NGSocketAddress> lAddress = nil;
  NSString *arg = nil;
  const char *cstr;
      
  if ((arg = [_args objectForKey:@"-p"]) != nil)
    return [NGInternetSocketAddress wildcardAddressWithPort:[arg intValue]];
  
  if ((arg = [_args objectForKey:@"-WOPort"]) == nil)
    return nil;
  
  lAddress = nil;
  if ([arg isEqualToString:@"auto"])
    lAddress = [self autoBindAddress];
        
  if ((lAddress == nil) && (cstr = [arg cString])) {
    if (isdigit(*cstr)) {
      lAddress =
	[NGInternetSocketAddress wildcardAddressWithPort:[arg intValue]];
    }
  }
  if (lAddress == nil)
    lAddress = NGSocketAddressFromString(arg);
  return lAddress;
}

- (id)initWithName:(NSString *)_name
  arguments:(NSDictionary *)_args
  application:(WOCoreApplication *)_application
{
  if ((self = [super initWithName:_name
                     arguments:_args
                     application:_application])) {
    id arg = nil;
    
    [self _registerForSignals];
    if (![_application controlSocket]) {
      if ([_args count] < 1)
        self->address = [self addressFromDefaultsOfApplication:_application];
      else
        self->address = [self addressFromArguments:_args];
    
      self->address = [self->address retain];
    
      if (self->address == nil) {
        [_application errorWithFormat:
                        @"got no address for HTTP server (using arg '%@')", arg];
        [self release];
        return nil;
      }
    
      [_application logWithFormat:@"%@ listening on address %@",
                    NSStringFromClass([self class]),
                    [(id)self->address stringValue]];
    }
    
    self->lock = [[NSRecursiveLock alloc] init];
      
    self->maxThreadCount = [[WOCoreApplication workerThreadCount] intValue];
    
    [self setSendTimeout:WOHttpAdaptorSendTimeout];
    [self setReceiveTimeout:WOHttpAdaptorReceiveTimeout];
  }
  return self;
}

- (void)dealloc {
  signal(SIGPIPE, SIG_DFL);
    
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->lock    release];
  [self->socket  release];
  [self->controlSocket release];
  [self->address release];
  [super dealloc];
}

/* accessors */

- (id<NGSocketAddress>)socketAddress {
  /* used by sns */
  return self->address;
}

/* events */
- (void)registerForEvents {
  int backlog;
  WOChildMessage message;

  controlSocket = [[WOCoreApplication application] controlSocket];
  if (controlSocket) {
    [controlSocket retain];
    ASSIGN(self->socket, [[WOCoreApplication application] listeningSocket]);
    [[NSNotificationCenter defaultCenter]
                         addObserver:self
                            selector:@selector(acceptControlMessage:)
                                name:NSFileObjectBecameActiveNotificationName
                              object:nil];
    [(WORunLoop *)[WORunLoop currentRunLoop]
              addFileObject:controlSocket
              activities:NSPosixReadableActivity
              forMode:NSDefaultRunLoopMode];
    message = WOChildMessageReady;
    [controlSocket safeWriteBytes: &message
                            count: sizeof (WOChildMessage)];
    // [self logWithFormat: @"notified the watchdog that we are ready"];
  }
  else {
    backlog = [[WOCoreApplication listenQueueSize] intValue];
  
    if (backlog == 0)
      backlog = 5;
  
    [self->socket release]; self->socket = nil;
  
    self->socket =
      [[NGPassiveSocket alloc] initWithDomain:[self->address domain]];
  
    [self->socket bindToAddress:self->address];
  
    if ([[self->address domain] isEqual:[NGInternetSocketDomain domain]]) {
      if ([(NGInternetSocketAddress *)self->address port] == 0) {
        /* let the kernel choose an IP address */
      
        [self debugWithFormat:@"bound to wildcard: %@", self->address];
        [self debugWithFormat:@"got local: %@", [self->socket localAddress]];
      
        self->address = [[self->socket localAddress] retain];
      
        [self logWithFormat:@"bound to kernel assigned address %@: %@",
              self->address, self->socket];
      }
    }
  
    [self->socket listenWithBacklog:backlog];
  
    [[NSNotificationCenter defaultCenter]
                         addObserver:self selector:@selector(acceptConnection:)
                                name:NSFileObjectBecameActiveNotificationName
                              object:self->socket];

    [(WORunLoop *)[WORunLoop currentRunLoop]
              addFileObject:self->socket
              activities:NSPosixReadableActivity
              forMode:NSDefaultRunLoopMode];
  }
}

- (void)unregisterForEvents {
  [(WORunLoop *)[WORunLoop currentRunLoop]
              removeFileObject:self->socket forMode:NSDefaultRunLoopMode];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [self->lock   release]; self->lock   = nil;
  [self->socket release]; self->socket = nil;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: address=%@>",
                     NSStringFromClass([self class]), self,
                     self->address];
}

/* Server */

/* accessors */

- (id<NGPassiveSocket>)socket {
  return self->socket;
}
- (id<NGSocketAddress>)serverAddress {
  return [self->socket localAddress];
}

- (void)setSendTimeout:(NSTimeInterval)_timeout {
  self->sendTimeout = _timeout;
}
- (NSTimeInterval)sendTimeout {
  return self->sendTimeout;
}

- (void)setReceiveTimeout:(NSTimeInterval)_timeout {
  self->receiveTimeout = _timeout;
}
- (NSTimeInterval)receiveTimeout {
  return self->receiveTimeout;
}

- (void)setMaxThreadCount:(int)_count {
  self->maxThreadCount = _count;
}
- (int)maxThreadCount {
  return self->maxThreadCount;
}

/* run-loop */

- (void)_serverCatched:(NSException *)_exc {
  [self errorWithFormat:@"http server caught: %@", _exc];
  if (WOCoreOnHTTPAdaptorException) abort();
}

- (BOOL)runConnection:(id<NGActiveSocket>)_socket {
  WOHttpTransaction *tx;
  
  if (_socket == nil) {
    [self errorWithFormat:@"got no socket for transaction ??"];
    return NO;
  }
  
  tx = [[WOHttpTransaction alloc] initWithSocket:_socket
                                  application:self->application];
  
  if (![tx run])
    [self _serverCatched:[tx lastException]];
  
  [tx release];
  
  if ([self->application isTerminating])
    self->isTerminated = YES;
  
  return YES;
}

- (void)_handleAcceptedConnection:(NGActiveSocket *)_connection {
#if USE_POOLS
  NSAutoreleasePool *pool = nil;
#endif
  NSTimeInterval t;
  
  if (perfLogger)
    *(&t) = [[NSDate date] timeIntervalSince1970];
  
  [self->lock lock];
  self->activeThreadCount++;
  [self->lock unlock];
  
#if USE_POOLS
  pool = [[NSAutoreleasePool alloc] init];
#endif
  {
    [*(&_connection) autorelease];
    
    NS_DURING {
      [_connection setReceiveTimeout:self->receiveTimeout];
      [_connection setSendTimeout:self->sendTimeout];
      
      [self runConnection:_connection];
    }
    NS_HANDLER {
      [self _serverCatched:localException];
    }
    NS_ENDHANDLER;
  }
#if USE_POOLS
  [pool release]; pool = nil;
#endif

  [self->lock lock];
  self->activeThreadCount--;
  [self->lock unlock];

  if (perfLogger) {
    t = [[NSDate date] timeIntervalSince1970] - t;
    [perfLogger logWithFormat:@"handling of request took %4.3fs.",
                  t < 0.0 ? -1.0 : t];
  }
}
- (void)_handleAcceptedConnectionInThread:(NGActiveSocket *)_connection {
  /* ensure that the top-level pool is properly setup */
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  [self _handleAcceptedConnection:_connection];
  [pool release];
}

- (NGActiveSocket *)_accept {
  NGActiveSocket *connection;
  id<NGSocketAddress> remote;

  NS_DURING {
    connection = [self->socket accept];
    if (!connection)
      [self _serverCatched:[self->socket lastException]];
    else {
      if ((remote = [connection remoteAddress]) != nil)
        [self debugWithFormat:@"accepted connection: %@", connection];
      else {
        [self errorWithFormat:@"missing remote address for connection: %@",
              connection];
        connection = nil;
      }
    }
  }
  NS_HANDLER {
    connection = nil;
    [self _serverCatched:localException];
  }
  NS_ENDHANDLER;

  return connection;
}

- (void)_handleConnection:(NGActiveSocket *)connection {
  if (connection != nil) {
    if (self->maxThreadCount <= 1) {
      NS_DURING
        [self _handleAcceptedConnection:[connection retain]];
      NS_HANDLER
        [self _serverCatched:localException];
      NS_ENDHANDLER;
    }
    else {
      [NSThread detachNewThreadSelector:
                  @selector(_handleAcceptedConnectionInThread:)
                               toTarget:self
                             withObject:[connection retain]];
      [self logWithFormat:@"detached new thread for request."];
      //[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    }
    connection = nil;
  }
}

- (void) acceptControlMessage: (NSNotification *) aNotification
{
  NGActiveSocket *notificationSocket, *connection;
  WOChildMessage message;
  NSAutoreleasePool *pool;

  // NSLog (@"received control message");
  notificationSocket = [aNotification object];
  if (notificationSocket == controlSocket) {
    // [self logWithFormat:@"child accepting message from socket: %@", controlSocket];
    while (![controlSocket safeReadBytes: &message
                                   count: sizeof (WOChildMessage)])
      [self errorWithFormat:
              @"failure reading watchdog message (retrying...): %@",
            [controlSocket lastException]];
    if (message == WOChildMessageAccept) {
      pool = [NSAutoreleasePool new];
      connection = [self _accept];
      if (![controlSocket safeWriteBytes: &message
                                  count: sizeof (WOChildMessage)])
        [self errorWithFormat: @"failure notifying watchdog we are busy: %@",
              [controlSocket lastException]];
      [self _handleConnection: connection];
      message = WOChildMessageReady;
      if (![controlSocket safeWriteBytes: &message
                                  count: sizeof (WOChildMessage)])
        [self errorWithFormat: @"failure notifying watchdog we are ready: %@",
              [controlSocket lastException]];
      [pool release];
    }
    else if (message == WOChildMessageShutdown) {
      [controlSocket safeWriteBytes: &message
                              count: sizeof (WOChildMessage)];
      [[WOCoreApplication application] terminate];
    }
  }
}

- (void)acceptConnection:(id)_notification {
#if USE_POOLS
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
#endif
  [self _handleConnection: [self _accept]];
#if USE_POOLS
  [pool release]; pool = nil;
#endif

  if (self->isTerminated) {
    if (self->socket) {
      [[NSNotificationCenter defaultCenter]
                             removeObserver:self
                             name:NSFileObjectBecameActiveNotificationName
                             object:self->socket];
      [self->socket close];
      [self->socket release]; self->socket = nil;
    }
    [self logWithFormat:@"adaptor stops application: %@ ...",
            self->application];
    exit(0);
  }
}

@end /* WOHttpAdaptor */
