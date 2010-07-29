/*
   PrivateThreadData.h

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
#ifndef __PrivateThreadData_h__
#define __PrivateThreadData_h__

#include <Foundation/common.h>
#include <Foundation/NSException.h>

/* Fast access to per-thread-global variables */

@class NSAutoreleasePool;
@class NSNotificationCenter;
@class NSNotificationQueue;
@class NSRunLoop;

@interface PrivateThreadData : NSObject
{
    id autoreleaseStack;
    void* exceptionStack;
#ifdef BROKEN_COMPILER
    NSUncaughtExceptionHandler* uncaughtExceptionHandler;
#endif
    NSRunLoop* runLoop;
    struct _InstanceList* notificationQueues;
    NSNotificationQueue* defaultQueue;
    NSNotificationCenter* defaultCenter;
    id temporaryStringsPool;
    id temporaryMutableStringsPool;
}

- (void)threadWillStart;
- (void)threadExit;

/* NSAutoreleasePool */
- (NSAutoreleasePool*)threadDefaultAutoreleasePool;
- (void)setThreadDefaultAutoreleasePool:(NSAutoreleasePool*)pool;

/* NSException */
- (void*)threadDefaultExceptionHandler;
- (void)setThreadDefaultExceptionHandler:(void*)handler;
- (void)setUncaughtExceptionHandler:(NSUncaughtExceptionHandler*)handler;
- (NSUncaughtExceptionHandler*)uncaughtExceptionHandler;
#ifdef BROKEN_COMPILER
- (void)invokeUncaughtExceptionHandlerWithException:(NSException*)exception;
#endif

/* NSRunLoop */
- (NSRunLoop*)threadRunLoop;
- (void)setThreadRunLoop:(NSRunLoop*)aLoop;

/* NSNotificationQueue */
- (struct _InstanceList*)threadNotificationQueues;
- (void)setThreadNotificationQueues:(struct _InstanceList*)theQueues;
- (NSNotificationQueue*)defaultNotificationQueue;
- (void)setDefaultNotificationQueue:(NSNotificationQueue*)aQueue;

/* NSNotificationCenter */
- (NSNotificationCenter*)defaultNotificationCenter;
- (void)setDefaultNotificationCenter:(NSNotificationCenter*)center;

/* NSString */
- (id)temporaryString;
- (void)addTemporaryString:(id)anObject;
- (void)setTemporaryStringsPool:(id)anObject;

/* NSMutableString */
- (id)temporaryMutableString;
- (void)addTemporaryMutableString:(id)anObject;
- (void)setTemporaryMutableStringsPool:(id)anObject;

@end

#endif /* __PrivateThreadData_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
