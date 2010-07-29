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

#include "SNSConnection.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOAdaptor.h>
#include <NGObjWeb/WOSession.h>
#include <NGStreams/NGStreams.h>
#include <NGStreams/NGNet.h>
#include "common.h"

#if !LIB_FOUNDATION_LIBRARY
#  include <NGExtensions/NSRunLoop+FileObjects.h>
#endif

// TODO: NEED TO FIX FOR Exception-less IO !!! (safeWrite...)

typedef enum {
  SNSUnregisterInstance = 0,
  SNSRegisterInstance   = 1,
  SNSRegisterSession    = 2,
  SNSExpireSession      = 3,
  SNSTerminateSession   = 4,
  SNSLookupSession      = 50,
  SNSInstanceAlive      = 100
} SNSMessageCode;

@interface SNSConnection(PrivateMethods)

- (void)initWithApplication:(WOApplication *)_application;

- (BOOL)registerWithSessionNameService;
- (void)disconnectFromSessionNameService;

@end

@interface WOAdaptor(SocketAddress)
- (id<NGSocketAddress>)socketAddress;
@end

@implementation SNSConnection

+ (void)initialize {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    NSDictionary *snsDefaults = nil;
    
    isInitialized = YES;

    snsDefaults = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"/tmp/.snsd", @"SNSPort",
                                  @"60",         @"SNSPingInterval",
                                  @"NO",         @"SNSLogActivity",
                                  nil];
    [[NSUserDefaults standardUserDefaults]
                     registerDefaults:snsDefaults];
  }
}

+ (SNSConnection *)defaultSNSConnection {
  static SNSConnection *connection = nil;
  if (connection) return connection;
  connection = [[self alloc] init];
  return connection;
}

- (void)initWithApplication:(WOApplication *)_application {
  NSUserDefaults *ud;
  id<NGSocketAddress> sns = nil;
  int waitCnt = 0;
  
  ud = [NSUserDefaults standardUserDefaults];
    
  self->loggingEnabled = [[ud objectForKey:@"SNSLogActivity"] boolValue];
  
  sns = NGSocketAddressFromString([ud stringForKey:@"SNSPort"]);
  if (sns == nil) {
    [self errorWithFormat:
            @"(%s): Could not create socket address for snsd(port=%@).",
            __PRETTY_FUNCTION__, sns];
    RELEASE(self);
    return;
  }

#if 1
  self->socket = [NGActiveSocket socketInDomain:[sns domain]];
  do {
    if (waitCnt > 0) {
      [self logWithFormat:@"waiting %i seconds for snsd to come up ...",
              waitCnt];
      sleep(waitCnt);
    }
    
    if (![self->socket connectToAddress:sns]) {
      [self logWithFormat:@"  connect failed: %@",
              [self->socket lastException]];
    }
    waitCnt++;
  }
  while (![self->socket isConnected] && (waitCnt < 5));
#else
  NS_DURING {
    self->socket = [NGActiveSocket socketConnectedToAddress:sns];
  }
  NS_HANDLER {
    self->socket = nil;
  }
  NS_ENDHANDLER;
#endif
  
  if (![self->socket isConnected]) {
    [self errorWithFormat:@"Could not connect socket %@ to snsd (port=%@), "
            @"terminating: %@",
            self->socket, sns, [self->socket lastException]];
    ASSIGN(self->socket, (id)nil);
    RELEASE(self);
    [[WOApplication application] terminate];
    return;
  }
  self->socket = RETAIN(self->socket);

  self->io = [NGBufferedStream filterWithSource:self->socket];
  self->io = RETAIN(self->io);
    
  self->application = _application;

  NS_DURING {
    [self registerWithSessionNameService];
  }
  NS_HANDLER {
    RELEASE(self->socket); self->socket = nil;
  }
  NS_ENDHANDLER;
  
  if (self->socket == nil) {
    [self errorWithFormat:@"Could not register with snsd (port=%@).", sns];
    RELEASE(self);
    return;
  }
    [[NSNotificationCenter defaultCenter]
                           addObserver:self selector:@selector(receiveMessage:)
                           name:NSFileObjectBecameActiveNotificationName
                           object:self->socket];
    { // ping
      int interval = [[ud objectForKey:@"SNSPingInterval"] intValue];
      if (interval > 0) {
        self->pingTimer =
          [NSTimer scheduledTimerWithTimeInterval:(NSTimeInterval)interval
                   target:self selector:@selector(pingSNS:)
                   userInfo:nil repeats:YES];
        self->pingTimer = RETAIN(self->pingTimer);
      }
    }
}
- (id)init {
  NSNotificationCenter *nc;
  
  self->loggingEnabled = [[[NSUserDefaults standardUserDefaults]
                                           objectForKey:@"SNSLogActivity"]
                                           boolValue];

  nc = [NSNotificationCenter defaultCenter];

  [nc addObserver:self selector:@selector(appDidFinishLaunching:)
      name:WOApplicationDidFinishLaunchingNotification object:nil];
  [nc addObserver:self selector:@selector(appWillTerminate:)
      name:WOApplicationWillTerminateNotification object:nil];
  
  [nc addObserver:self selector:@selector(sessionDidCreate:)
      name:WOSessionDidCreateNotification object:nil];
  [nc addObserver:self selector:@selector(sessionDidTimeOut:)
      name:WOSessionDidTimeOutNotification object:nil];
  [nc addObserver:self selector:@selector(sessionDidTerminate:)
      name:WOSessionDidTerminateNotification object:nil];

  return self;
}

- (void)dealloc {
  [self disconnectFromSessionNameService];
  [self->pingTimer invalidate];
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self disconnectFromSessionNameService];
  RELEASE(self->pingTimer);
  RELEASE(self->io);
  RELEASE(self->socket);
  [super dealloc];
}

/* notifications */

- (void)appDidFinishLaunching:(NSNotification *)_notification {
  WOApplication *app = [_notification object];
  [self initWithApplication:app];
}
- (void)appWillTerminate:(NSNotification *)_notification {
  [self disconnectFromSessionNameService];
}

- (void)sessionDidCreate:(NSNotification *)_notification {
  WOSession *sn = [_notification object];
  if (sn) [self applicationCreatedSession:[sn sessionID]];
}
- (void)sessionDidTimeOut:(NSNotification *)_notification {
  NSString *sn = [_notification object];
  if (sn) [self sessionExpired:sn];
}
- (void)sessionDidTerminate:(NSNotification *)_notification {
  WOSession *sn = [_notification object];
  if (sn) [self sessionTerminated:[sn sessionID]];
}

/* connection */

- (BOOL)registerWithSessionNameService {
  id<NGSocketAddress> port = nil;
  BOOL      result    = NO;
  NSArray   *adaptors = [self->application adaptors];
  WOAdaptor *adaptor  = nil;

  NSAssert([adaptors count] > 0, @"no adaptors registered for application");
  *(&adaptor) = [adaptors objectAtIndex:0];

  if ([adaptor respondsToSelector:@selector(socketAddress)])
    *(&port) = [adaptor socketAddress];
  if (port == nil)
    return NO;

  *(&result) = YES;

  if (self->loggingEnabled)
    NSLog(@"register instance with snsd.");
  
  {
    NSString      *tmp;
    int           len;
    char          buf[2048];
    unsigned int  i;
    unsigned char c = SNSRegisterInstance;

    if (![self->io safeWriteBytes:&c count:sizeof(c)])
      [[self->io lastException] raise];

    tmp = [self->application name];
    len = [tmp cStringLength];
    NSAssert1(len <= 2000, @"application name to long (%i bytes)..", len);
    [tmp getCString:buf maxLength:2000];
    if (![self->io safeWriteBytes:&len count:sizeof(len)])
      [[self->io lastException] raise];
    if (![self->io safeWriteBytes:buf count:len])
      [[self->io lastException] raise];

    tmp = [self->application path];
    len = [tmp cStringLength];
    NSAssert1(len <= 2000, @"bundle name to long (%i bytes) ..", len);
    [tmp getCString:buf maxLength:2000];
    if (![self->io safeWriteBytes:&len count:sizeof(len)])
      [[self->io lastException] raise];
    if (![self->io safeWriteBytes:buf count:len])
      [[self->io lastException] raise];

    i = getpid();
    if (![self->io safeWriteBytes:&i count:sizeof(i)])
      [[self->io lastException] raise];
    
    { // encode port info
      NSData *data;

      data = [NSArchiver archivedDataWithRootObject:port];
      len = [data length];
      NSAssert1(len <= 2000, @"socket name to long (%i bytes) ..", len);
      if (![self->io safeWriteBytes:&len count:sizeof(len)])
        [[self->io lastException] raise];
      if (![self->io safeWriteBytes:[data bytes] count:len])
        [[self->io lastException] raise];
    }

    if (![self->io flush])
      [[self->io lastException] raise];
  }
  
  if (self->loggingEnabled)
    NSLog(@"registered instance with snsd: %s", result ? "YES" : "NO");
  
  return result;
}

- (void)disconnectFromSessionNameService {
  if (self->socket) {
    if (self->loggingEnabled)
      NSLog(@"disconnecting instance from snsd ..");
  
    NS_DURING {
      unsigned char c = SNSUnregisterInstance;
      
      (void)[self->socket safeWriteBytes:&c count:sizeof(c)];
      (void)[self->socket flush];
      
      if ([self->socket respondsToSelector:@selector(shutdownSendChannel)])
        (void)[(NGActiveSocket *)self->socket shutdownSendChannel];
    }
    NS_HANDLER {}
    NS_ENDHANDLER;
    
    NS_DURING {
      (void)[self->socket shutdown];
    }
    NS_HANDLER {}
    NS_ENDHANDLER;

    RELEASE(self->socket); self->socket = nil;
  }
}

- (void)sendMessage:(unsigned char)_msg {
  if (self->loggingEnabled)
    NSLog(@"send msg %i", _msg);
  if (![self->io safeWriteBytes:&_msg count:1])
    [[self->io lastException] raise];
  if (![self->io flush])
    [[self->io lastException] raise];
}
- (void)sendMessage:(unsigned char)_msg sessionID:(NSString *)_sessionID {
  int  len;
  char buf[2048];

  len = [_sessionID cStringLength];
  NSAssert1((len < 2000) && (len > 0), @"Invalid session id (%i bytes).", len);
  [_sessionID getCString:buf maxLength:2000];

  if (self->loggingEnabled)
    NSLog(@"send msg %i with sessionID %@ (len=%i)", _msg, _sessionID, len);

  if (![self->io safeWriteBytes:&_msg count:1])
    [[self->io lastException] raise];
  if (![self->io safeWriteBytes:&len count:sizeof(len)])
    [[self->io lastException] raise];
  if (![self->io safeWriteBytes:buf count:len])
    [[self->io lastException] raise];
  if (![self->io flush])
    [[self->io lastException] raise];
}

- (void)lostConnectionToNameServer:(NSException *)_exception {
  [self errorWithFormat:@"application lost connection to snsd: %@", _exception];
  [[WOApplication application] terminate];
}
- (void)lostConnectionToNameServer {
  [self lostConnectionToNameServer:nil];
}

- (void)applicationCreatedSession:(NSString *)_sessionID {
  NS_DURING {
    [self sendMessage:SNSRegisterSession sessionID:_sessionID];
  }
  NS_HANDLER {
    [self lostConnectionToNameServer:localException];
  }
  NS_ENDHANDLER;
}

- (void)sessionTerminated:(NSString *)_sessionID {
  NS_DURING {
    [self sendMessage:SNSTerminateSession sessionID:_sessionID];
  }
  NS_HANDLER {
    [self lostConnectionToNameServer:localException];
  }
  NS_ENDHANDLER;
}
- (void)sessionExpired:(NSString *)_sessionID {
  NSLog(@"%s: expired: %@", __PRETTY_FUNCTION__, _sessionID);
  NS_DURING {
    [self sendMessage:SNSExpireSession sessionID:_sessionID];
  }
  NS_HANDLER {
    [self lostConnectionToNameServer:localException];
  }
  NS_ENDHANDLER;
}

- (void)pingSNS:(NSNotification *)_notification {
  NS_DURING {
    [self sendMessage:SNSInstanceAlive];
  }
  NS_HANDLER {
    [self lostConnectionToNameServer:localException];
  }
  NS_ENDHANDLER;
}

// back link from SNS

- (void)receiveMessage:(NSNotification *)_notification {
  unsigned char msgCode;
  
  if ((id)[_notification object] != (id)self->socket)
    return;

  NSLog(@"SNS: receive message from snsd ..");
  [self->io safeReadBytes:&msgCode count:1];
}

@end
