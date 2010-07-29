/*
   PrivateThreadData.m

   Copyright (C) 1995, 1996, 1997, 1998 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@net-community.com>
   Date: February 1998

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
#include "PrivateThreadData.h"
#include "NSConcreteString.h"
#include <Foundation/NSNotification.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSRunLoop.h>

#include <extensions/PrintfFormatScanner.h>
#include <extensions/PrintfScannerHandler.h>

@implementation PrivateThreadData

- init
{
    extern void _default_exception_handler(NSException* exception);
    extern void _init_first_exception_handler(NSHandler* handler);

    // Autorelease pool is nil
    autoreleaseStack = nil;
    // No exception handler
    exceptionStack = Malloc (sizeof (NSHandler));
    _init_first_exception_handler (exceptionStack);
#ifdef BROKEN_COMPILER
    uncaughtExceptionHandler = _default_exception_handler;
#endif
    return self;
}

- (void)dealloc
{
    RELEASE(defaultQueue);
    RELEASE(runLoop);
    lfFree(exceptionStack);
    [super dealloc];
}

- (void)threadWillStart
{
    // Make thread's top-level autorelease pool
    runLoop = [NSRunLoop new];
}

- (void)threadExit
{
#if !LIB_FOUNDATION_BOEHM_GC
    // Clear autorelease for current thread
    while (autoreleaseStack)
	RELEASE(autoreleaseStack);
#endif
}

- (NSAutoreleasePool*)threadDefaultAutoreleasePool
{
    return autoreleaseStack;
}

- (void)setThreadDefaultAutoreleasePool:(NSAutoreleasePool*)pool
{
    autoreleaseStack = pool;
}

- (void*)threadDefaultExceptionHandler
{
    return exceptionStack;
}

- (void)setThreadDefaultExceptionHandler:(void*)handler
{
    exceptionStack = handler;
}

- (NSUncaughtExceptionHandler *)uncaughtExceptionHandler
{
#ifdef BROKEN_COMPILER
    return uncaughtExceptionHandler;
#else
    NSHandler* ex = exceptionStack;

    while (ex->previousHandler)
        ex = ex->previousHandler;
    return (NSUncaughtExceptionHandler *)ex->handler;
#endif
}

- (void)setUncaughtExceptionHandler:(NSUncaughtExceptionHandler*)handler
{
#ifdef BROKEN_COMPILER
    uncaughtExceptionHandler = handler;
#else
    NSHandler* ex = exceptionStack;

    while (ex->previousHandler)
        ex = ex->previousHandler;
    ex->handler = (THandlerFunction)handler;
#endif
}

#ifdef BROKEN_COMPILER
- (void)invokeUncaughtExceptionHandlerWithException:(NSException*)exception
{
    uncaughtExceptionHandler (exception);
}
#endif

- (NSRunLoop*)threadRunLoop
{
    return runLoop;
}

- (void)setThreadRunLoop:(NSRunLoop*)aLoop
{
    runLoop = RETAIN(aLoop);
}

- (struct _InstanceList*)threadNotificationQueues
{
    return notificationQueues;
}

- (void)setThreadNotificationQueues:(struct _InstanceList*)theQueues
{
    notificationQueues = theQueues;
}

- (NSNotificationQueue*)defaultNotificationQueue
{
    if (!defaultQueue)
        defaultQueue = [[NSNotificationQueue alloc] init];
    return defaultQueue;
}

- (void)setDefaultNotificationQueue:(NSNotificationQueue*)aQueue
{
    defaultQueue = RETAIN(aQueue);
}

- (NSNotificationCenter*)defaultNotificationCenter
{
    if (!defaultCenter)
        defaultCenter = [[NSNotificationCenter alloc] init];
    return defaultCenter;
}

- (void)setDefaultNotificationCenter:(NSNotificationCenter*)center
{
    defaultCenter = RETAIN(center);
}

- (id)temporaryString
{
    struct String {
	@defs (NSTemporaryString);
    } *string = (void*)temporaryStringsPool;

    if (string) {
	temporaryStringsPool = string->next;
	string->next = nil;
    }
    return (id)string;
}

- (void)addTemporaryString:(id)anObject
{
    struct String {
	@defs (NSTemporaryString);
    } *string = (void*)anObject;

    if ((void*)string != temporaryStringsPool)
	string->next = temporaryStringsPool;
    temporaryStringsPool = anObject;
}

- (void)setTemporaryStringsPool:(id)anObject
{
    temporaryStringsPool = anObject;
}

- (id)temporaryMutableString
{
    struct String {
	@defs (NSMutableTemporaryString);
    } *string = (void*)temporaryMutableStringsPool;

    if (string) {
	temporaryMutableStringsPool = string->next;
	string->next = nil;
    }
    return (id)string;
}

- (void)addTemporaryMutableString:(id)anObject
{
    struct String {
	@defs (NSMutableTemporaryString);
    } *string = (void*)anObject;

    if ((void*)string != temporaryMutableStringsPool)
	string->next = temporaryMutableStringsPool;
    temporaryMutableStringsPool = anObject;
}

- (void)setTemporaryMutableStringsPool:(id)anObject
{
    temporaryMutableStringsPool = anObject;
}

@end /* PrivateThreadData */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
