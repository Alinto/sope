/* 
   NSThread.h

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

#ifndef __NSThread_h__
#define __NSThread_h__

#include <Foundation/NSObject.h>

@class NSDate;
@class NSString;
@class NSMutableDictionary;

enum {
    NSInteractiveThreadPriority,
    NSBackgroundThreadPriority,
    NSLowThreadPriority
};

@interface NSThread : NSObject
{
    /* global thread info */
    id   threadDictionary;
    BOOL isRunning;
    id   target;
    SEL  selector;
    id   arg;
    id   privateThreadData;
}

+ (NSThread*)currentThread;
+ (void)exit;
+ (BOOL)isMultiThreaded;
+ (void)sleepUntilDate:(NSDate*)aDate;
+ (void)detachNewThreadSelector:(SEL)aSelector 
  toTarget:(id)aTarget withObject:(id)anArgument;
- (NSMutableDictionary*)threadDictionary;

/* Private method */
- (id)_privateThreadData;

@end /* NSThread */

/* Thead notifications */

LF_EXPORT NSString *NSWillBecomeMultiThreadedNotification;
LF_EXPORT NSString *NSThreadWillExitNotification;

/* GNUstep compatibility */

@interface NSThread(GNUstepCompatibility)

+ (BOOL)registerCurrentThread;
+ (void)unregisterCurrentThread;

LF_EXPORT NSThread *GSCurrentThread(void);
LF_EXPORT NSString *NSThreadDidStartNotification;

@end

#endif /* __NSThread_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
