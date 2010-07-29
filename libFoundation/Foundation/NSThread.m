/* 
   NSThread.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include <Foundation/common.h>

#include <time.h>

#if HAVE_SYS_TIME_H
# include <sys/time.h>	/* for struct timeval */
#endif

#if HAVE_LIBC_H
# include <libc.h>
#else
# include <unistd.h>
#endif

#if HAVE_SYS_SELECT_H
# include <sys/select.h>
#endif

#if defined(__MINGW32__)
# include <windows.h>
#endif

#include <Foundation/common.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSNotificationQueue.h>

#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include <extensions/objc-runtime.h>
#include "PrivateThreadData.h"

/*
    NSAutoreleasePool must be changed to return a default pool from 
    the current thread autorelease stack and to operate on that stack
    when pools are allocated and deallocated. The overhead is one more
    method call in +[NSAutoreleasePool defaultPool] to 
    +[NSThread currentThread].

    NSExceptions && exception handlers must be changed to use current
    thread top-level handler instead of internal static variable. The
    overhead is not important since handler are not pushed/extracted
    too often.
 */

@interface NSException(UsedPrivates)
+ (void)taskNowMultiThreaded:(NSNotification *)_notification;
@end

@interface NSNotificationCenter(UsedPrivates)
+ (void)taskNowMultiThreaded:(NSNotification *)_notification;
@end

/* NSThread notifications */

LF_DECLARE NSString* NSWillBecomeMultiThreadedNotification = 
	@"NSWillBecomeMultiThreadedNotification";
LF_DECLARE NSString* NSThreadWillExitNotification =
	@"NSThreadWillExitNotification";

/* Global thread variables */

static BOOL     isMultiThreaded = NO;
static NSThread *mainThread = nil;

@implementation NSThread

/*
 * Instance Methods
 */

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector argument:(id)anArgument
{
    // Not yet running
    isRunning = NO;

    // Set running parameters
    target = RETAIN(aTarget);
    selector = aSelector;
    arg = RETAIN(anArgument);

    // Thread dictionary
    threadDictionary = [NSMutableDictionary new];
    privateThreadData = [PrivateThreadData new];
    
    return self;
}

- (void)run
{
    // Set current thread data (must be done before the autorelease pool is
    // created)
    objc_thread_set_data(self);
    {
        CREATE_AUTORELEASE_POOL(pool);

        [privateThreadData threadWillStart];

        // Run
        [target performSelector:selector withObject:arg];

        // pool cleanup
        RELEASE(pool);
    }
}

- (void)exit
{
    [privateThreadData threadExit];
    objc_thread_exit();
}

- (NSMutableDictionary*)threadDictionary
{
    return threadDictionary;
}

- (void)dealloc
{
    if (isRunning) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"cannot deallocate NSThread for running thread"] raise];
    }
    RELEASE(target);
    RELEASE(arg);
    RELEASE(threadDictionary);
    RELEASE(privateThreadData);
    [super dealloc];
}

- (id)_privateThreadData
{
    return privateThreadData;
}

/*
 * Class Methods
 */

+ (void)initialize
{
    // We are still in non-multithread state
    if (mainThread == nil) {
	mainThread = [NSThread alloc];
	mainThread->threadDictionary  = [NSMutableDictionary new];
	mainThread->privateThreadData = [PrivateThreadData new];;
	objc_thread_set_data(mainThread);
    }
}

#if HAVE_OBJC_THREAD_CREATE
static void nsThreadStartThread(id thread)
{
    [thread run];
//    [thread exit];
    RELEASE(thread); thread = nil;
}
#else
+ (void)_runThread:(NSThread*)thread
{
    [thread run];
//    [thread exit];
    RELEASE(thread); thread = nil;
}
#endif

+ (void)detachNewThreadSelector:(SEL)aSelector 
  toTarget:(id)aTarget withObject:(id)anArgument
{
    id thread = [[self alloc] 
	initWithTarget:aTarget selector:aSelector argument:anArgument];
    
    if (!isMultiThreaded) {
	[NSAutoreleasePool     taskNowMultiThreaded:nil];
	[NSException           taskNowMultiThreaded:nil];
	[NSRunLoop             taskNowMultiThreaded:nil];
	[NSNotificationQueue   taskNowMultiThreaded:nil];
	[NSNotificationCenter  taskNowMultiThreaded:nil];
	[[NSNotificationCenter defaultCenter]
	    postNotificationName:NSWillBecomeMultiThreadedNotification
	    object:nil userInfo:nil];
	isMultiThreaded = YES;
    }
    
#if HAVE_OBJC_THREAD_CREATE
    objc_thread_create((void(*)(void*arg))nsThreadStartThread, thread);
#else
    if (objc_thread_detach(@selector(_runThread:), self, thread) == NULL) {
        // thread creation failed
        RELEASE(thread); thread = nil;
        [NSException raise:@"NSThreadCreationFailedException"
                     format:@"creation of Objective-C thread failed."];
    }
#endif
}

+ (NSThread *)currentThread
{
    return isMultiThreaded ? (NSThread *)objc_thread_get_data() : mainThread;
}

+ (void)exit
{
    [[NSNotificationCenter defaultCenter]
	postNotificationName:NSThreadWillExitNotification
	object:self userInfo:nil];
    [[self currentThread] exit];
}

+ (BOOL)isMultiThreaded
{
    return isMultiThreaded;
}

+ (void)sleepUntilDate:(NSDate*)aDate
{
    NSTimeInterval delay = 0;
    
    if (!aDate) return;
    if([aDate earlierDate:[NSDate date]] == aDate) return;
    delay = [aDate timeIntervalSinceNow];

#if defined(__MINGW32__)
    Sleep((DWORD)(delay * 1000.0));
#else
    {
        struct timeval tp = { 0, 0 };
        struct timeval *timeout = NULL;
        fd_set set;

        tp.tv_sec = delay;
        tp.tv_usec = (delay - (NSTimeInterval)tp.tv_sec) * 1000000.0;
        timeout = &tp;

        FD_ZERO(&set);
        select(FD_SETSIZE, &set, NULL, NULL, timeout);
    }
#endif
}

/* registering external threads (GNUstep extension) */

+ (BOOL)registerCurrentThread
{
    return NO;
}
+ (void)unregisterCurrentThread
{
}

NSThread *GSCurrentThread(void)
{
    /* for GNUstep compatibility */
    return [NSThread currentThread];
}

NSString *NSThreadDidStartNotification =
	@"NSThreadDidStartNotification";

@end /* NSThread */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
