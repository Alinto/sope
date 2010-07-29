/*
   UnixSignalHandler.m

   Copyright (C) 1995, 1996, 1997 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

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

#include <config.h>

#include <signal.h>
#include <errno.h>

#include <Foundation/common.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/UnixSignalHandler.h>

static NSString* UnixSignalPendingNotification
    = @"UnixSignalPendingNotification";

#if HAVE_SIGSETMASK
#  define BSD_SIGNALS 1
#elif HAVE_SIGHOLD
#  define SYSV_SIGNALS 1
#else
#  if defined(__MINGW32__)
#    warning "Don't know how to handle signals on Mingw32 !"
#  elif defined(__CYGWIN32__)
#    warning "Don't know how to handle signals on Cygwin32 !"
#  else
#    error "Don't know how to handle signals!"
#  endif
#endif

#if !defined(sigmask)
# define sigmask(m)	(1 << ((m)-1))
#endif

static RETSIGTYPE signalHandlerFunction (int signum);

typedef RETSIGTYPE (*PTSignalFunction)(int);

@interface UnixSignalHandlerListItem : NSObject
{
@public
  id   observer;
  SEL  selector;
  BOOL immediatelyNotifyOnSignal;
  UnixSignalHandlerListItem *nextItem;
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

- (id)removeObserver:(id)anObserver
{
  if (self->observer == anObserver) {
    (void)AUTORELEASE(self);
    return self->nextItem;
  }
  else {
    self->nextItem = [self->nextItem removeObserver:anObserver];
    return self;
  }
}

- (void)invokeForSignal:(int)signum
{
  [self->observer
       performSelector:self->selector
       withObject:[NSNumber numberWithInt:signum]];
}

@end /* UnixSignalHandlerListItem */


@interface UnixSignalHandlerList : NSObject
{
@public
  UnixSignalHandlerListItem *firstItem;
  PTSignalFunction          oldSignalHandler;
  BOOL                      signalsPending;
}

- (void)addObserver:(id)observer
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
    UnixSignalHandlerListItem *newItem = [UnixSignalHandlerListItem new];
  
    newItem->nextItem = self->firstItem;
    [newItem initWithObserver:anObserver
             selector:aSelector
             immediatelyNotifyOnSignal:flag];
    self->firstItem = newItem;
}

- (void)removeObserver:(id)observer
{
    self->firstItem = [self->firstItem removeObserver:observer];
}

- (void)invokeIfCalledImmediatelyIs:(BOOL)flag signal:(int)signum
{
    UnixSignalHandlerListItem *item = self->firstItem;
    BOOL missed = NO;
    
    flag = flag ? YES : NO;
    
    if (self->signalsPending) {
        while (item) {
            if (item->immediatelyNotifyOnSignal == flag)
                [item invokeForSignal:signum];
            else
                missed = YES;
            item = item->nextItem;
        }
        
        if (!missed) /* all signals were processed */
            self->signalsPending = NO;
    }
}

@end /* UnixSignalHandlerList */


@interface UnixSignalHandler (private)
- (void)_pendingSignal:(int)signum;
@end

@implementation UnixSignalHandler

static NSNotification    *notification = nil;
static UnixSignalHandler *sharedHandler = nil;

static int DebugSigHandler = -1;
BOOL UnixSignalHandlerIsProcessing = NO;

static RETSIGTYPE signalHandlerFunction (int signum)
{
    /* note: no malloc is allowed in signal handlers !!! */
    int savedErrno; 
    
    /* Temporary disable the signals */
    [sharedHandler blockAllSignals];
    if (UnixSignalHandlerIsProcessing) {
        /* nested processing ??? (we are not really allowed to call print) */
        fprintf(stderr, "%s: detected nested call ...\n",
                __PRETTY_FUNCTION__);
        fflush(stderr);
    }
    
    UnixSignalHandlerIsProcessing = YES;
    savedErrno = errno; /* save errno, see Stevens */
    {
        NSNotificationQueue   *queue =
            [NSNotificationQueue defaultQueue];
        UnixSignalHandlerList *handlers =
            sharedHandler->signalHandlers[signum];
      
        handlers->signalsPending = YES;
        sharedHandler->signalsPending = YES;
        
        [queue enqueueNotification:notification
               postingStyle:NSPostASAP
               /* no coalescing (prev coalesce, but this broke in free()) */
               coalesceMask:NSNotificationNoCoalescing
               forModes:nil];
        [sharedHandler _pendingSignal:signum];
    }
    errno = savedErrno; /* restore errno */
    UnixSignalHandlerIsProcessing = NO;
    [sharedHandler enableAllSignals];
}

+ (void)initialize
{
  static BOOL initialized = NO;
  
  if (!initialized) {
    initialized = YES;
    
    if (DebugSigHandler == -1) {
        DebugSigHandler =
            [[NSUserDefaults standardUserDefaults]
                             boolForKey:@"DebugUnixSignalHandler"] ? 1 : 0;
    }
    
    sharedHandler = [[self alloc] init];
    
    notification =
        [[NSNotification notificationWithName:UnixSignalPendingNotification
                         object:sharedHandler]
                         retain];
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
  
  for (i = 0; i < NSIG; i++) {
      self->signalHandlers[i] = [[UnixSignalHandlerList alloc] init];
      //NSLog(@"handler 0x%p %i: %@", self, i, self->signalHandlers[i]);
  }
  
#if BSD_SIGNALS
  self->currentSigmask = sigblock(0);
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
  /* note: no malloc is allowed in signal handlers !!! */
  [self->signalHandlers[signum] invokeIfCalledImmediatelyIs:YES signal:signum];
}

+ (void)_dispatch:(NSNotification *)notification
{
    /* Notify all the handlers that have requested to be called after the
       current NSRunLoop cycle has finished. The others were already called
       when the signal occurred. */
    
    if (sharedHandler->signalsPending) {
        int i;
      
        for (i = 0; i < NSIG; i++) {
            UnixSignalHandlerList *handler = sharedHandler->signalHandlers[i];

            if (handler->signalsPending) {
                //NSLog(@"pending sigs for %i on handler: %@", i, handler);
                [handler invokeIfCalledImmediatelyIs:NO
                         signal:i];
            }
        }
        sharedHandler->signalsPending = NO;
    }
}

- (BOOL)signalsPending
{
    return self->signalsPending;
}

- (void)addObserver:(id)observer
  selector:(SEL)selector
  forSignal:(int)signum
  immediatelyNotifyOnSignal:(BOOL)flag
{
    UnixSignalHandlerList *handler = self->signalHandlers[signum];
    BOOL shouldInstall = (handler->firstItem == NULL);
    
    [self blockSignal:signum];
    {
        [handler addObserver:observer
                 selector:selector
                 immediatelyNotifyOnSignal:flag];
        
        if (shouldInstall)
#if HAVE_SIGACTION && !defined(__alpha__)
            {
                /* this is used on Linux */
                struct sigaction act, oldact;
        
                act.sa_handler = (PTSignalFunction)signalHandlerFunction;
                sigemptyset (&act.sa_mask);
                act.sa_flags = 0;
                sigaction (signum, &act, &oldact);
                handler->oldSignalHandler = oldact.sa_handler;
            }
#elif HAVE_SIGSET
        handler->oldSignalHandler =
            (PTSignalFunction)sigset(signum, signalHandlerFunction);
#else
        handler->oldSignalHandler =
            (PTSignalFunction)signal(signum, signalHandlerFunction);
#endif
    }
    [self enableSignal:signum];
}

- (void)removeObserver:(id)observer forSignal:(int)signum
{
    [self blockSignal:signum];
    {
        UnixSignalHandlerList *handler = self->signalHandlers[signum];
      
        [handler removeObserver:observer];
        
        if (handler->firstItem == NULL) {
#if HAVE_SIGSET && !HAVE_SIGACTION
            sigset(signum, handler->oldSignalHandler);
#else
            signal(signum, handler->oldSignalHandler);
#endif
        }
    }
    [self enableSignal:signum];
}

- (void)removeObserver:(id)observer
{
  int i;
  
  for (i = 0; i < NSIG; i++)
    [self removeObserver:observer forSignal:i];
}


#if BSD_SIGNALS
#  if __linux__
//#    warning using BSD signal functions on Linux ??? (should be SYSV ?)
#    if SYSV_SIGNALS
#      warning SYSV signals are also enabled ...
#    endif
#  endif

- (void)blockAllSignals
{
    if (DebugSigHandler) printf("block all signals\n");
    sigsetmask((unsigned)-1);
}
- (void)enableAllSignals
{
    if (DebugSigHandler) printf("enable all signals\n");
    sigsetmask(self->currentSigmask);
}

- (void)blockSignal:(int)signum
{
    if (DebugSigHandler) printf("block signal %i\n", signum);
    self->currentSigmask |= sigmask(signum);
    sigsetmask(self->currentSigmask);
}
- (void)enableSignal:(int)signum
{
    if (DebugSigHandler) printf("enable signal %i\n", signum);
    self->currentSigmask &= ~(sigmask(signum));
    sigsetmask(self->currentSigmask);
}

- (void)waitForSignal:(int)signum
{
    if (DebugSigHandler) printf("wait for signal %i\n", signum);
    sigpause(sigmask (signum));
}

#elif SYSV_SIGNALS

- (void)blockAllSignals
{
  int i;
  
  for (i = 0; i < NSIG; i++)
    sighold(i);
}

- (void)enableAllSignals
{
  int i;

  for (i = 0; i < NSIG; i++) {
      if ((self->currentSigmask & sigmask(i)))
	  sigrelse(i);
  }
}

- (void)blockSignal:(int)signum
{
  self->currentSigmask |= sigmask(signum);
  sighold(signum);
}
- (void)enableSignal:(int)signum
{
  self->currentSigmask &= ~(sigmask(signum));
  sigrelse(signum);
}

- (void)waitForSignal:(int)signum
{
  sigpause(signum);
}

#else
#warning cannot handle signals on this platform ...

- (void)blockSignal:(int)signum
{
    [self notImplemented:_cmd];
}
- (void)enableSignal:(int)signum
{
    [self notImplemented:_cmd];
}
- (void)waitForSignal:(int)signum
{
    [self notImplemented:_cmd];
}

#endif

@end /* UnixSignalHandler */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
