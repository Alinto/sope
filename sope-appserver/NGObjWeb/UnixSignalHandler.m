/*
   UnixSignalHandler.m

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: November 1997

   Based on a similar class written by Mircea Oancea in July 1995.

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#if !LIB_FOUNDATION_LIBRARY

//#include <config.h>
#define HAVE_SIGSETMASK 1
#define RETSIGTYPE      void

#include <signal.h>

//#include "NSObjectMacros.h"
#include "common.h"
#import <Foundation/NSValue.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSNotificationQueue.h>
#include "UnixSignalHandler.h"

static NSString* UnixSignalPendingNotification
    = @"UnixSignalPendingNotification";

#if HAVE_SIGSETMASK
#  define BSD_SIGNALS 1
#elif HAVE_SIGHOLD
#  define SYSV_SIGNALS 1
#elif defined(__MINGW32__)
#  warning "Don't know how to handle signals on Mingw32 !"
#else
#  error "Don't know how to handle signals!"
#endif

#if !defined(sigmask)
# define sigmask(m)	(1 << ((m)-1))
#endif

static RETSIGTYPE signalHandlerFunction (int signum);

typedef RETSIGTYPE (*PTSignalFunction)(int);

@interface UnixSignalHandlerListItem : NSObject
{
@public
  id observer;
  SEL selector;
  BOOL immediatelyNotifyOnSignal;
  UnixSignalHandlerListItem* nextItem;
}
- (id)initWithObserver:observer
  selector:(SEL)selector
  immediatelyNotifyOnSignal:(BOOL)flag;
- (id)removeObserver:observer;
- (void)invokeForSignal:(int)signum;
@end


@implementation UnixSignalHandlerListItem

- (id)initWithObserver:anObserver
  selector:(SEL)aSelector
  immediatelyNotifyOnSignal:(BOOL)flag
{
  self->observer = anObserver;
  self->selector = aSelector;
  self->immediatelyNotifyOnSignal = flag;
  return self;
}

- (id)removeObserver:anObserver
{
  if (observer == anObserver) {
    (void)AUTORELEASE(self);
    return nextItem;
  }
  else {
    nextItem = [nextItem removeObserver:anObserver];
    return self;
  }
}

- (void)invokeForSignal:(int)signum
{
  [observer performSelector:selector
            withObject:[NSNumber numberWithLong:signum]];
}

@end


@interface UnixSignalHandlerList : NSObject
{
@public
  UnixSignalHandlerListItem* firstItem;
  PTSignalFunction oldSignalHandler;
  BOOL signalsPending;
}

- (void)addObserver:observer
  selector:(SEL)selector
  immediatelyNotifyOnSignal:(BOOL)flag;
- (void)removeObserver:observer;
- (void)invokeIfCalledImmediatelyIs:(BOOL)flag signal:(int)signum;

@end


@implementation UnixSignalHandlerList

- (void)addObserver:anObserver
  selector:(SEL)aSelector
  immediatelyNotifyOnSignal:(BOOL)flag
{
  UnixSignalHandlerListItem* newItem = [UnixSignalHandlerListItem new];

  newItem->nextItem = firstItem;
  [newItem initWithObserver:anObserver
	   selector:aSelector
	   immediatelyNotifyOnSignal:flag];
  firstItem = newItem;
}

- (void)removeObserver:observer
{
  firstItem = [firstItem removeObserver:observer];
}

- (void)invokeIfCalledImmediatelyIs:(BOOL)flag signal:(int)signum
{
  UnixSignalHandlerListItem* item = firstItem;

  if (signalsPending) {
    while (item) {
      if (item->immediatelyNotifyOnSignal == flag)
	[item invokeForSignal:signum];
      item = item->nextItem;
    }
    signalsPending = NO;
  }
}

@end /* UnixSignalHandlerList */



@interface UnixSignalHandler (private)
- (void)_pendingSignal:(int)signum;
@end

@implementation UnixSignalHandler

static NSNotification* notification = nil;
static UnixSignalHandler* sharedHandler = nil;

static RETSIGTYPE signalHandlerFunction (int signum)
{
  /* Temporary disable the signals */
  [sharedHandler blockAllSignals];

  ((UnixSignalHandlerList*)(sharedHandler->signalHandlers[signum]))
      ->signalsPending = YES;
  sharedHandler->signalsPending = YES;

  [[NSNotificationQueue defaultQueue]
	  enqueueNotification:notification
	  postingStyle:NSPostASAP];
  [sharedHandler _pendingSignal:signum];

  [sharedHandler enableAllSignals];
}

+ (void)initialize
{
  static BOOL initialized = NO;

  if (!initialized) {
    initialized = YES;
    sharedHandler = [self new];
    notification = RETAIN([NSNotification
                            notificationWithName:UnixSignalPendingNotification
                            object:sharedHandler]);
    [[NSNotificationCenter defaultCenter]
	  addObserver:self
	  selector:@selector(_dispatch:)
	  name:UnixSignalPendingNotification
	  object:nil];
  }
}

+ (id)sharedHandler
{
    return sharedHandler;
}

- (id)init
{
  int i;

  for (i = 0; i < NSIG; i++)
    signalHandlers[i] = [UnixSignalHandlerList new];

#if BSD_SIGNALS
  currentSigmask = sigblock (0);
#endif

  return self;
}

- (void)_pendingSignal:(int)signum
{
  /* Notify all the handlers that listen for the signal signum immediately.
     Only those handlers that have requested an immediate notification on
     signal are invoked here. Those that want to be called after the signal
     occured are invoked at a later time, when the current NSRunLoop finishes
     the current cycle. */
  [signalHandlers[signum] invokeIfCalledImmediatelyIs:YES signal:signum];
}

+ (void)_dispatch:(NSNotification *)notification
{
  int i;

  /* Notify all the handlers that have requested to be called after the current
     NSRunLoop cycle has finished. The others were already called when the
     signal occurred. */
  
  if (sharedHandler->signalsPending) {
    for (i = 0; i < NSIG; i++)
      [sharedHandler->signalHandlers[i] 
		    invokeIfCalledImmediatelyIs:NO signal:i];
    sharedHandler->signalsPending = NO;
  }
}

- (BOOL)signalsPending
{
    return signalsPending;
}

- (void)addObserver:(id)observer
  selector:(SEL)selector
  forSignal:(int)signum
  immediatelyNotifyOnSignal:(BOOL)flag
{
  BOOL shouldInstall = (signalHandlers[signum]->firstItem == NULL);

  [self blockSignal:signum];
  [signalHandlers[signum] addObserver:observer
			  selector:selector
			  immediatelyNotifyOnSignal:flag];
  if (shouldInstall)
#if HAVE_SIGSET
    signalHandlers[signum]->oldSignalHandler
	= (PTSignalFunction)sigset (signum, signalHandlerFunction);
#elif HAVE_SIGACTION && !defined(__alpha__)
    {
	struct sigaction act, oldact;

	act.sa_handler = (PTSignalFunction)signalHandlerFunction;
	sigemptyset (&act.sa_mask);
	act.sa_flags = 0;
	sigaction (signum, &act, &oldact);
	signalHandlers[signum]->oldSignalHandler = oldact.sa_handler;
    }
#else
    signalHandlers[signum]->oldSignalHandler
	= (PTSignalFunction)signal (signum, signalHandlerFunction);
#endif
  [self enableSignal:signum];
}

- (void)removeObserver:(id)observer
{
  int i;

  for (i = 0; i < NSIG; i++)
    [self removeObserver:observer forSignal:i];
}

- (void)removeObserver:(id)observer
  forSignal:(int)signum
{
  [self blockSignal:signum];
  [signalHandlers[signum] removeObserver:observer];
  if (signalHandlers[signum]->firstItem == NULL)
#if HAVE_SIGSET
    sigset (signum, signalHandlers[signum]->oldSignalHandler);
#else
    signal (signum, signalHandlers[signum]->oldSignalHandler);
#endif
  [self enableSignal:signum];
}

- (void)blockAllSignals
{
#if BSD_SIGNALS
  sigsetmask ((unsigned)-1);
#elif SYSV_SIGNALS
  int i;

  for (i = 0; i < NSIG; i++)
    sighold (i);
#endif
}

- (void)enableAllSignals
{
#if BSD_SIGNALS
  sigsetmask (currentSigmask);
#elif SYSV_SIGNALS
  int i;

  for (i = 0; i < NSIG; i++)
      if ((currentSigmask & sigmask(i)))
	  sigrelse (i);
#endif
}

- (void)blockSignal:(int)signum
{
  currentSigmask |= sigmask (signum);
#if BSD_SIGNALS
  sigsetmask (currentSigmask);
#elif SYSV_SIGNALS
  sighold (signum);
#endif
}

- (void)enableSignal:(int)signum
{
  currentSigmask &= ~(sigmask (signum));
#if BSD_SIGNALS
  sigsetmask (currentSigmask);
#elif SYSV_SIGNALS
  sigrelse (signum);
#endif
}

- (void)waitForSignal:(int)signum
{
#if BSD_SIGNALS
  sigpause (sigmask (signum));
#elif SYSV_SIGNALS
  sigpause (signum);
#endif
}

@end

#endif /* !LIB_FOUNDATION_LIBRARY */
