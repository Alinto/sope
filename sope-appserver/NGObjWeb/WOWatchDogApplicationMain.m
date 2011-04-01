/*
  Copyright (C) 2000-2005 SKYRIX Software AG
  Copyright (C) 2009 Inverse inc.

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

#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSCalendarDate.h>
#import <Foundation/NSData.h>
#import <Foundation/NSException.h>
#import <Foundation/NSFileHandle.h>
#import <Foundation/NSProcessInfo.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSValue.h>

#import <NGObjWeb/WOAdaptor.h>
#import <NGObjWeb/WOApplication.h>
#import <NGExtensions/NSObject+Logs.h>
#import <NGStreams/NGActiveSocket.h>
#import <NGStreams/NGCTextStream.h>
#import <NGStreams/NGInternetSocketAddress.h>
#import <NGStreams/NGNetUtilities.h>
#import <NGStreams/NGPassiveSocket.h>

#import "UnixSignalHandler.h"

#if defined(__CYGWIN32__) || defined(__MINGW32__)

int WOWatchDogApplicationMain
(NSString *appName, int argc, const char *argv[])
{
  /* no watchdog support on Win* */
  return WOApplicationMain(appName, argc, argv);
}

#else

#include <sys/wait.h>
#include <sys/types.h>
#include <unistd.h>
#include <time.h>
#include <string.h>

static NSTimeInterval respawnDelay; /* seconds */
static const char *pidFile = NULL;
NSInteger watchDogRequestTimeout;

typedef enum {
  WOChildStatusDown = 0,
  WOChildStatusSpawning,
  WOChildStatusReady,
  WOChildStatusBusy,
  WOChildStatusExcessive,
  WOChildStatusTerminating,
  WOChildStatusMax
} WOChildStatus;

@class WOWatchDog;

@interface WOWatchDogChild : NSObject <RunLoopEvents>
{
  pid_t pid;
  int counter;
  NGActiveSocket *controlSocket;
  WOChildStatus status;
  NSTimer *killTimer;
  NSUInteger killTimerIteration;
  WOWatchDog *watchDog;
  NSCalendarDate *lastSpawn;
  BOOL loggedNotRespawn;
}

- (void) setWatchDog: (WOWatchDog *) newWatchDog;

- (void) setPid: (int) newPid;
- (int) pid;

- (void) revokeKillTimer;

- (void) handleProcessStatus: (int) status;

- (void) setControlSocket: (NGActiveSocket *) newSocket;
- (NGActiveSocket *) controlSocket;

- (void) setStatus: (WOChildStatus) newStatus;
- (WOChildStatus) status;

- (void) setLastSpawn: (NSCalendarDate *) newLastSpawn;
- (NSCalendarDate *) lastSpawn;
- (NSCalendarDate *) nextSpawn;
- (void) logNotRespawn;

- (BOOL) readMessage;

- (void) notify;
- (void) terminate;

@end

@interface WOWatchDog : NSObject <RunLoopEvents>
{
  NSString *appName;
  int argc;
  const char **argv;

  pid_t pid;
  NSTimer *loopTimer;
  BOOL terminate;
  BOOL willTerminate;
  NSNumber *terminationSignal;
  int pendingSIGHUP;

  NGPassiveSocket *listeningSocket;

  int numberOfChildren;
  NSMutableArray *children;
  NSMutableArray *readyChildren;
  NSMutableArray *downChildren;
}

+ (id) sharedWatchDog;

- (pid_t) pid;

- (void) declareChildReady: (WOWatchDogChild *) readyChild;
- (void) declareChildDown: (WOWatchDogChild *) readyChild;

- (int) run: (NSString *) appName
       argc: (int) argc
       argv: (const char **) argv;

@end

@implementation WOWatchDogChild

+ (void) initialize
{
  watchDogRequestTimeout = [[NSUserDefaults standardUserDefaults]
                             integerForKey: @"WOWatchDogRequestTimeout"];
  if (watchDogRequestTimeout > 0)
    [self logWithFormat: @"watchdog request timeout set to %d minutes",
          watchDogRequestTimeout];
  else
    [self warnWithFormat: @"watchdog request timeout not set"];
}

+ (WOWatchDogChild *) watchDogChild
{
  WOWatchDogChild *newChild;

  newChild = [self new];
  [newChild autorelease];

  return newChild;
}

- (id) init
{
  if ((self = [super init]))
    {
      pid = -1;
      controlSocket = nil;
      status = WOChildStatusDown;
      killTimer = nil;
      killTimerIteration = 0;
      counter = 0;
      lastSpawn = nil;
      loggedNotRespawn = NO;
    }

  return self;
}

- (void) dealloc
{
  // [self logWithFormat: @"-dealloc (pid: %d)", pid];
  [killTimer invalidate];
  [self setControlSocket: nil];
  [lastSpawn release];
  [super dealloc];
}

- (void) setWatchDog: (WOWatchDog *) newWatchDog
{
  watchDog = newWatchDog;
}

- (void) setPid: (int) newPid
{
  pid = newPid;
}

- (int) pid
{
  return pid;
}

- (void) revokeKillTimer
{
  [killTimer invalidate];
  killTimer = nil;
}

- (void) handleProcessStatus: (int) processStatus
{
  int code;

  code = WEXITSTATUS (processStatus);
  if (code == 0)
    [self logWithFormat: @"child %d exited", pid];
  else
    [self logWithFormat: @"child %d exited with code %i", pid, code];
  if (WIFSIGNALED (processStatus))
    [self logWithFormat: @" (terminated due to signal %i%@)",
          WTERMSIG (processStatus),
          WCOREDUMP (processStatus) ? @", coredump" : @""];
  if (WIFSTOPPED (processStatus))
    [self logWithFormat: @" (stopped due to signal %i)",
          WSTOPSIG (processStatus)];
  [self setStatus: WOChildStatusDown];
  [self setControlSocket: nil];
  [self revokeKillTimer];
}

- (void) setControlSocket: (NGActiveSocket *) newSocket
{
  NSRunLoop *runLoop;

  runLoop = [NSRunLoop currentRunLoop];
  if (controlSocket)
    [runLoop removeEvent: (void *) ((long) [controlSocket fileDescriptor])
                    type: ET_RDESC
                 forMode: NSDefaultRunLoopMode
                     all: YES];
  [controlSocket close];
  ASSIGN (controlSocket, newSocket);
  if (controlSocket)
    [runLoop addEvent: (void *) ((long) [controlSocket fileDescriptor])
                 type: ET_RDESC
              watcher: self
              forMode: NSDefaultRunLoopMode];
}

- (NGActiveSocket *) controlSocket
{
  return controlSocket;
}

- (void) setStatus: (WOChildStatus) newStatus
{
  status = newStatus;
}

- (WOChildStatus) status
{
  return status;
}

- (void) setLastSpawn: (NSCalendarDate *) newLastSpawn
{
  ASSIGN (lastSpawn, newLastSpawn);
  loggedNotRespawn = NO;
}

- (NSCalendarDate *) lastSpawn
{
  return lastSpawn;
}

- (NSCalendarDate *) nextSpawn
{
  return [lastSpawn addYear: 0 month: 0 day: 0
                       hour: 0 minute: 0
                     second: respawnDelay];
}

- (void) logNotRespawn
{
  if (!loggedNotRespawn)
    {
      [self logWithFormat:
              @"avoiding to respawn child before %@", [self nextSpawn]];
      loggedNotRespawn = YES;
    }
}

- (void) _safetyBeltIteration: (NSTimer *) aKillTimer
{
  if ([watchDog pid] == getpid ()) {
    killTimerIteration++;
    if (killTimerIteration < watchDogRequestTimeout) {
      [self warnWithFormat:
              @"pid %d has been hanging in the same request for %d minutes",
            pid, killTimerIteration];
    }
    else {
      if (status != WOChildStatusDown) {
        [self warnWithFormat: @"safety belt -- sending KILL signal to pid %d",
              pid];
        kill (pid, SIGKILL);
        [self revokeKillTimer];
      }
    }
  }
  else {
    [self errorWithFormat:
        @"messy processes: safety belt iteration occurring on child: %d",
          pid];
    [self revokeKillTimer];
  }
}

- (void) _kill
{
  if (status != WOChildStatusDown) {
    [self logWithFormat: @"sending terminate signal to pid %d", pid];
    status = WOChildStatusTerminating;
    kill (pid, SIGTERM);
    [self revokeKillTimer];
  }
}

- (BOOL) readMessage
{
  WOChildMessage message;
  BOOL rc;
  NSException *e;

  if ([controlSocket readBytes: &message
                         count: sizeof (WOChildMessage)] == NGStreamError) {
    rc = NO;
    [self errorWithFormat: @"FAILURE receiving status for child %d", pid];
    [self errorWithFormat: @"  socket: %@", controlSocket];
    e = [controlSocket lastException];
    if (e)
      [self errorWithFormat: @"  exception: %@", e];
    [self _kill];
  }
  else {
    rc = YES;
    [self revokeKillTimer];
    if (message == WOChildMessageAccept) {
      status = WOChildStatusBusy;
      if (watchDogRequestTimeout > 0) {
        /* We schedule an X minutes grace period while the child is processing
           the request. This enables long requests to complete while providing
           a safety belt for children gone rogue. */
        killTimer
          = [NSTimer scheduledTimerWithTimeInterval: 60
                                             target: self
                                           selector: @selector (_safetyBeltIteration:)
                                           userInfo: nil
                                            repeats: YES];
        killTimerIteration = 0;
      }
    }
    else if (message == WOChildMessageReady) {
      status = WOChildStatusReady;
      [watchDog declareChildReady: self];
    }
  }

  return rc;
}

- (void) notify
{
  WOChildMessage message;

  counter++;
  message = WOChildMessageAccept;
  if ([controlSocket writeBytes: &message
                          count: sizeof (WOChildMessage)] == NGStreamError
      || ![self readMessage]) {
    [self errorWithFormat: @"FAILURE notifying child %d", pid];
    [self _kill];
  }
}

- (void) terminate
{
  if (status == WOChildStatusDown) {
    [self logWithFormat: @"child is already down"];
  } else {
    [self _kill];
  }
}

- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  if ([controlSocket isAlive])
    [self readMessage];
  else {
    /* This happens when a socket has been closed by the child but the child
       has not terminated yet. */
    [[NSRunLoop currentRunLoop] removeEvent: data
                                       type: ET_RDESC
                                    forMode: NSDefaultRunLoopMode
                                        all: YES];
    [self setControlSocket: nil];
  }
}

@end

@implementation WOWatchDog

+ (id) sharedWatchDog
{
  static WOWatchDog *sharedWatchDog = nil;

  if (!sharedWatchDog)
    sharedWatchDog = [self new];

  return sharedWatchDog;
}

- (id) init
{
  if ((self = [super init]))
    {
      listeningSocket = nil;
      terminate = NO;
      willTerminate = NO;
      terminationSignal = nil;
      pendingSIGHUP = 0;

      numberOfChildren = 0;
      children = [[NSMutableArray alloc] initWithCapacity: 10];
      readyChildren = [[NSMutableArray alloc] initWithCapacity: 10];
      downChildren = [[NSMutableArray alloc] initWithCapacity: 10];
    }

  return self;
}

- (void) _releaseListeningSocket
{
  if (listeningSocket) {
    [[NSRunLoop currentRunLoop] removeEvent: (void *) ((long) [listeningSocket fileDescriptor])
                                       type: ET_RDESC
                                    forMode: NSDefaultRunLoopMode
                                        all: YES];
    [listeningSocket close];
    [listeningSocket release];
    listeningSocket = nil;
  }
}

- (void) dealloc
{
  [self _releaseListeningSocket];
  [terminationSignal release];
  [appName release];
  [children release];
  [super dealloc];
}

- (pid_t) pid
{
  return pid;
}

- (void) _runChildWithControlSocket: (NGActiveSocket *) controlSocket
{
  WOApplication *app;
  extern char **environ;

  [NSProcessInfo initializeWithArguments: (char **) argv
                                   count: argc
                             environment: environ];
  NGInitTextStdio();
  app = [NSClassFromString(appName) new];
  [app autorelease];
  [app setListeningSocket: listeningSocket];
  [app setControlSocket: controlSocket];
  [app run];
}

- (void) receivedEvent: (void*)data
		  type: (RunLoopEventType)type
		 extra: (void*)extra
	       forMode: (NSString*)mode
{
  int nextId;
  WOWatchDogChild *child;
  NSUInteger max;

  max = [readyChildren count];
  if (max > 0) {
    nextId = max - 1;
    child = [readyChildren objectAtIndex: nextId];
    [readyChildren removeObjectAtIndex: nextId];
    [child notify];
  }
}

- (void) _cleanupSignalAndEventHandlers
{
  NSRunLoop *runLoop;

  [[UnixSignalHandler sharedHandler] removeObserver: self];
  [loopTimer invalidate];
  loopTimer = nil;
  runLoop = [NSRunLoop currentRunLoop];
  [runLoop removeEvent: (void *) ((long) [listeningSocket fileDescriptor])
                  type: ET_RDESC
               forMode: NSDefaultRunLoopMode
                   all: YES];
}

- (BOOL) _spawnChild: (WOWatchDogChild *) child
{
  NGActiveSocket *pair[2];
  BOOL isChild;
  int childPid;
  extern char **environ;

  isChild = NO;

  if ([NGActiveSocket socketPair: pair]) {
    childPid = fork ();
    if (childPid == 0) {
      setsid ();
      isChild = YES;
      [self _cleanupSignalAndEventHandlers];

      [child retain];
      [pair[0] retain];

      [children makeObjectsPerformSelector: @selector (revokeKillTimer)];
      [children release];
      children = nil;
      [readyChildren release];
      readyChildren = nil;
      [downChildren release];
      downChildren = nil;

      [[NSAutoreleasePool currentPool] emptyPool];

      [self _runChildWithControlSocket: pair[0]];

      [pair[0] autorelease];
      [child autorelease];
    } else if (childPid > 0) {
      [self logWithFormat: @"child spawned with pid %d", childPid];
      [child setPid: childPid];
      [child setStatus: WOChildStatusSpawning];
      [pair[1] setReceiveTimeout: 1.0];
      [child setControlSocket: pair[1]];
      [child setLastSpawn: [NSCalendarDate date]];
    } else {
      perror ("fork");
    }
  }

  return isChild;
}

- (void) _ensureNumberOfChildren
{
  int currentNumber, delta, count, min, max;
  WOWatchDogChild *child;

  currentNumber = [children count];
  if (currentNumber < numberOfChildren) {
      delta = numberOfChildren - currentNumber;
      for (count = 0; count < delta; count++) {
        child = [WOWatchDogChild watchDogChild];
        [child setWatchDog: self];
        [children addObject: child];
        [downChildren addObject: child];
      }
      [self logWithFormat: @"preparing %d children", delta];
  }
  else if (currentNumber > numberOfChildren) {
    delta = currentNumber - numberOfChildren;
    max = [downChildren count];
    if (max > delta)
      min = max - delta;
    else
      min = 0;
    for (count = max - 1; count >= min; count--) {
      child = [downChildren objectAtIndex: count];
      [downChildren removeObjectAtIndex: count];
      [children removeObject: child];
      delta--;
      [self logWithFormat: @"%d processes purged from pool", delta];
    }

    max = [readyChildren count];
    if (max > delta)
      max -= delta;
    for (count = max - 1; count > -1; count--) {
      child = [readyChildren objectAtIndex: count];
      [readyChildren removeObjectAtIndex: count];
      [child terminate];
      [child setStatus: WOChildStatusExcessive];
      delta--;
    }
    [self logWithFormat: @"%d processes left to terminate", delta];
  }
}

- (void) _noop
{
}

- (BOOL) _ensureChildren
{
  int count, max;
  WOWatchDogChild *child;
  BOOL isChild, delayed;
  NSCalendarDate *now, *nextSpawn;

  isChild = NO;

  if (!willTerminate) {
    [self _ensureNumberOfChildren];
    max = [downChildren count];
    for (count = max - 1; !isChild && count > -1; count--) {
      delayed = NO;
      child = [downChildren objectAtIndex: count];

      if ([child status] == WOChildStatusExcessive)
        [children removeObject: child];
      else {
        now = [NSCalendarDate date];
        nextSpawn = [child nextSpawn];
        if ([nextSpawn earlierDate: now] == nextSpawn)
          isChild = [self _spawnChild: child];
        else {
          delayed = YES;
          [child logNotRespawn];
        }
      }
      if (!(delayed || isChild))
        [downChildren removeObjectAtIndex: count];
    }
  }

  return isChild;
}

/* SOPE on GNUstep does not need to parse the argument line, since the
   arguments will be put in the NSArgumentDomain. I don't know about
   libFoundation but OSX is supposed to act the same way. */
- (NGInternetSocketAddress *) _listeningAddress
{
  NGInternetSocketAddress *listeningAddress;
  NSUserDefaults *ud;
  id port, allow;
  static BOOL warnedAboutAllow = NO;

  listeningAddress = nil;

  ud = [NSUserDefaults standardUserDefaults];
  port = [ud objectForKey:@"p"];
  if (!port) {
    port = [ud objectForKey:@"WOPort"];
    if (!port)
      port = @"auto";
  }
  allow = [ud objectForKey:@"WOHttpAllowHost"];
  if ([allow count] > 0 && !warnedAboutAllow) {
    [self warnWithFormat: @"'WOHttpAllowHost' is ignored in watchdog mode,"
          @" use a real firewall instead"];
    warnedAboutAllow = YES;
  }

  if ([port isKindOfClass: [NSString class]]) {
    if ([port isEqualToString: @"auto"]) {
      listeningAddress
        = [[NGInternetSocketAddress alloc] initWithPort:0 onHost:@"127.0.0.1"];
      [listeningAddress autorelease];
    } else if ([port rangeOfString: @":"].location == NSNotFound) {
      if (allow)
        listeningAddress =
          [NGInternetSocketAddress wildcardAddressWithPort:[port intValue]];
      else
        port = [NSString stringWithFormat: @"127.0.0.1:%d", [port intValue]];
    }
  }
  else {
    if (allow)
      listeningAddress =
        [NGInternetSocketAddress wildcardAddressWithPort:[port intValue]];
    else {
      port = [NSString stringWithFormat: @"127.0.0.1:%@", port];
    }
  }

  if (!listeningAddress)
    listeningAddress = (NGInternetSocketAddress *) NGSocketAddressFromString(port);

  return listeningAddress;
}

- (BOOL) _prepareListeningSocket
{
  NGInternetSocketAddress *addr;
  NSString *address;
  BOOL rc;
  int backlog;

  addr = [self _listeningAddress];
  NS_DURING {
    [listeningSocket release];
    listeningSocket = [[NGPassiveSocket alloc] initWithDomain: [addr domain]];
    [listeningSocket bindToAddress: addr];
    backlog = [[NSUserDefaults standardUserDefaults]
                integerForKey: @"WOListenQueueSize"];
    if (!backlog)
      backlog = 5;
    [listeningSocket listenWithBacklog: backlog];
    address = [addr address];
    if (!address)
      address = @"*";
    [self logWithFormat: @"listening on %@:%d", address, [addr port]];
    [[NSRunLoop currentRunLoop] addEvent: (void *) ((long) [listeningSocket fileDescriptor])
                                    type: ET_RDESC
                                 watcher: self
                                 forMode: NSDefaultRunLoopMode];
    rc = YES;
  }
  NS_HANDLER {
    rc = NO;
  }
  NS_ENDHANDLER;

  return rc;
}

- (WOWatchDogChild *) _childWithPID: (pid_t) childPid
{
  WOWatchDogChild *currentChild, *child;
  int count;

  child = nil;
  for (count = 0; !child && count < numberOfChildren; count++) {
    currentChild = [children objectAtIndex: count];
    if ([currentChild pid] == childPid)
      child = currentChild;
  }

  return child;
}

- (void) _handleSIGPIPE:(NSNumber *)_signal {
  [self logWithFormat: @"received SIGPIPE (ignored)"];
}

- (void) _handleTermination:(NSNumber *)_signal {
  if (!terminationSignal) {
    ASSIGN (terminationSignal, _signal);
    if (pidFile)
      unlink (pidFile);
  }
}

- (void) _handleSIGHUP:(NSNumber *)_signal {
  pendingSIGHUP++;
}

- (void) _setupSignals
{
#if !defined(__MINGW32__) && !defined(NeXT_Foundation_LIBRARY)
  UnixSignalHandler *us;

  us = [UnixSignalHandler sharedHandler];
  [us addObserver:self selector:@selector(_handleSIGPIPE:)
        forSignal:SIGPIPE immediatelyNotifyOnSignal:YES];
  [us addObserver:self selector:@selector(_handleTermination:)
        forSignal:SIGINT immediatelyNotifyOnSignal:YES];
  [us addObserver:self selector:@selector(_handleTermination:)
        forSignal:SIGTERM immediatelyNotifyOnSignal:YES];
  [us addObserver:self selector:@selector(_handleSIGHUP:)
        forSignal:SIGHUP immediatelyNotifyOnSignal:YES];
#endif
}

- (void) declareChildReady: (WOWatchDogChild *) readyChild
{
  [readyChildren addObject: readyChild];
}

- (void) declareChildDown: (WOWatchDogChild *) downChild
{
  if (![downChildren containsObject: downChild])
    [downChildren addObject: downChild];
}

- (void) _ensureWorkersCount
{
  int newNumberOfChildren;
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];
  [ud synchronize];
  newNumberOfChildren = [ud integerForKey: @"WOHttpAdaptorForkCount"];
  if (newNumberOfChildren)
    [self logWithFormat: @"user default 'WOHttpAdaptorForkCount' has been"
          " replaced with 'WOWorkersCount'"];
  else
    newNumberOfChildren = [ud integerForKey: @"WOWorkersCount"];
  if (newNumberOfChildren < 1)
    newNumberOfChildren = 1;
  numberOfChildren = newNumberOfChildren;
}

- (void) _handlePostTerminationSignal
{
  WOWatchDogChild *child;
  int count;

  [self logWithFormat: @"Terminating with signal %@", terminationSignal];
  [self _releaseListeningSocket];
  for (count = 0; count < numberOfChildren; count++) {
    child = [children objectAtIndex: count];
    if ([child status] != WOChildStatusDown
        && [child status] != WOChildStatusTerminating)
      [child terminate];
  }
  [terminationSignal release];
  terminationSignal = nil;
  if ([downChildren count] == numberOfChildren) {
    [self logWithFormat: @"all children exited. We now terminate."];
    terminate = YES;
  }
  else
    willTerminate = YES;
}

- (void) _checkProcessesStatus
{
  int status;
  pid_t childPid;
  WOWatchDogChild *child;

  while ((childPid = waitpid (-1, &status, WNOHANG)) > 0) {
    child = [self _childWithPID: childPid];
    [child handleProcessStatus: status];
    [self declareChildDown: child];
    if (willTerminate && [downChildren count] == numberOfChildren) {
      [self logWithFormat: @"all children exited. We now terminate."];
      terminate = YES;
    }
  }
}

- (int) run: (NSString *) newAppName
       argc: (int) newArgC argv: (const char **) newArgV
{
  NSAutoreleasePool *pool;
  NSRunLoop *runLoop;
  NSDate *limitDate;
  BOOL listening;
  int retries;

  willTerminate = NO;

  ASSIGN (appName, newAppName);

  argc = newArgC;
  argv = newArgV;

  listening = NO;
  retries = 0;
  while (!listening && retries < 5) {
    listening = [self _prepareListeningSocket];
    retries++;
    if (!listening) {
      [self warnWithFormat: @"listening socket: attempt %d failed", retries];
      [NSThread sleepForTimeInterval: 1.0];
    }
  }
  if (listening) {
    pid = getpid ();
    [self logWithFormat: @"watchdog process pid: %d", pid];
    [self _setupSignals];
    [self _ensureWorkersCount];

    // NSLog (@"ready to process requests");
    runLoop = [NSRunLoop currentRunLoop];

    /* This timer ensures the looping of the runloop at reasonable intervals
       for correct processing of signal handlers. */
    loopTimer = [NSTimer scheduledTimerWithTimeInterval: 0.5
                                                 target: self
                                               selector: @selector (_noop)
                                               userInfo: nil
                                                repeats: YES];
    terminate = NO;
    while (!terminate) {
      pool = [NSAutoreleasePool new];

      while (pendingSIGHUP) {
        [self logWithFormat: @"received SIGHUP"];
        [self _ensureWorkersCount];
        pendingSIGHUP--;
      }

      // [self logWithFormat: @"watchdog loop"];
      NS_DURING {
        terminate = [self _ensureChildren];
        if (!terminate) {
          limitDate = [runLoop limitDateForMode:NSDefaultRunLoopMode];
          [runLoop runMode: NSDefaultRunLoopMode beforeDate: limitDate];
        }
      }
      NS_HANDLER {
        terminate = YES;
        [self errorWithFormat:
                @"an exception occured in runloop %@", localException];
      }
      NS_ENDHANDLER;

      if (!terminate) {
        if (terminationSignal)
          [self _handlePostTerminationSignal];
        [self _checkProcessesStatus];
      }

      [pool release];
    }

    [self _cleanupSignalAndEventHandlers];
  }
  else
    [self errorWithFormat: @"unable to listen on specified port,"
          @" check that no other process is already using it"];

  return 0;
}

@end

static BOOL _writePid(NSString *nsPidFile) {
  NSString *pid;
  BOOL rc;

  pid = [NSString stringWithFormat: @"%d", getpid()];
  rc = [pid writeToFile: nsPidFile atomically: NO];

  return rc;
}

int WOWatchDogApplicationMain
(NSString *appName, int argc, const char *argv[])
{
  NSAutoreleasePool *pool;
  NSUserDefaults *ud;
  NSString *logFile, *nsPidFile;
  int rc;
  pid_t childPid;
  NSProcessInfo *processInfo;
  Class WOAppClass;

  pool = [[NSAutoreleasePool alloc] init];

#if LIB_FOUNDATION_LIBRARY || defined(GS_PASS_ARGUMENTS)
  {
    extern char **environ;
    [NSProcessInfo initializeWithArguments:(void*)argv count:argc
                   environment:(void*)environ];
  }
#endif

  /* This invocation forces the class initialization of WOCoreApplication,
     which causes the NSUserDefaults to be initialized as well with
     Defaults.plist. */
  WOAppClass = [NSClassFromString (appName) class];

  ud = [NSUserDefaults standardUserDefaults];
  processInfo = [NSProcessInfo processInfo];

  logFile = [ud objectForKey: @"WOLogFile"];
  if (!logFile)
    logFile = [NSString stringWithFormat: @"/var/log/%@/%@.log",
                        [processInfo processName],
                        [processInfo processName]];
  if (![logFile isEqualToString: @"-"]) {
    freopen([logFile cString], "a", stdout);
    freopen([logFile cString], "a", stderr);
  }
  if ([ud boolForKey: @"WONoDetach"])
    childPid = 0;
  else
    childPid = fork();

  if (childPid) {
    rc = 0;
  }
  else {
    nsPidFile = [ud objectForKey: @"WOPidFile"];
    if (!nsPidFile)
      nsPidFile = [NSString stringWithFormat: @"/var/run/%@/%@.pid",
                            [processInfo processName],
                            [processInfo processName]];
    pidFile = [nsPidFile UTF8String];
    if (_writePid(nsPidFile)) {
      respawnDelay = [ud integerForKey: @"WORespawnDelay"];
      if (!respawnDelay)
        respawnDelay = 5;

      if ([WOAppClass respondsToSelector: @selector (applicationWillStart)])
        [WOAppClass applicationWillStart];

      /* default is to use the watch dog! */
      if ([ud objectForKey:@"WOUseWatchDog"] != nil
          && ![ud boolForKey:@"WOUseWatchDog"])
        rc = WOApplicationMain(appName, argc, argv);
      else
        rc = [[WOWatchDog sharedWatchDog] run: appName argc: argc argv: argv];
    }
    else {
      [ud errorWithFormat: @"unable to open pid file: %@", pidFile];
      rc = -1;
    }
  }

  [pool release];

  return rc;
}
#endif

/* main function which initializes server defaults (usually in /etc) */

@interface NSUserDefaults(ServerDefaults)
+ (id)hackInServerDefaults:(NSUserDefaults *)_ud
         withAppDomainPath:(NSString *)_appDomainPath
          globalDomainPath:(NSString *)_globalDomainPath;
@end

int WOWatchDogApplicationMainWithServerDefaults
(NSString *appName, int argc, const char *argv[],
 NSString *globalDomainPath, NSString *appDomainPath)
{
  NSAutoreleasePool *pool;
  Class defClass;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY || defined(GS_PASS_ARGUMENTS)
  {
    extern char **environ;
    [NSProcessInfo initializeWithArguments:(void*)argv count:argc
                               environment:(void*)environ];
  }
#endif
  
  if ((defClass = NSClassFromString(@"WOServerDefaults")) != nil) {
    NSUserDefaults *ud, *sd;
    
    ud = [NSUserDefaults standardUserDefaults];
    sd = [defClass hackInServerDefaults:ud
                      withAppDomainPath:appDomainPath
                       globalDomainPath:globalDomainPath];

#if 0    
    if (((sd == nil) || (sd == ud)) && (appDomainPath != nil)) {
      NSLog(@"Note: not using server defaults: '%@' "
            @"(not supported on this Foundation)", appDomainPath);
    }
#endif
  }
  
  return WOWatchDogApplicationMain(appName, argc, argv);
}
