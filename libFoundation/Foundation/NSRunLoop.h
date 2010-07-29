/* 
   NSRunLoop.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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

#ifndef __NSRunLoop_h__
#define __NSRunLoop_h__

#include <Foundation/NSObject.h>

@class NSString, NSDate, NSTimer, NSNotification;
@class NSPosixFileDescriptor;
@class NSMutableArray, NSMutableDictionary;
@class NSPort;

LF_EXPORT NSString *NSDefaultRunLoopMode;
LF_EXPORT NSString *NSConnectionReplyMode;

LF_EXPORT NSString *NSFileObjectBecameActiveNotificationName; // not OpenStep

@interface NSRunLoop : NSObject
{
    NSMutableDictionary *inputsForMode;
    NSString            *mode;
}

/* Accessing the Current Run Loop */
+ (NSRunLoop*)currentRunLoop;
- (NSString*)currentMode;
- (NSDate*)limitDateForMode:(NSString*)mode;

/* Adding Timers */
- (void)addTimer:(NSTimer*)aTimer
	forMode:(NSString*)mode;

/* Running a Run Loop */
- (void)acceptInputForMode:(NSString*)mode
	beforeDate:(NSDate*)limitDate;
- (void)run;
- (BOOL)runMode:(NSString*)mode
	beforeDate:(NSDate*)limitDate;
- (void)runUntilDate:(NSDate*)limitDate;

/* Delayed perform of an action */
- (void)performSelector:(SEL)aSelector
  target:(id)target
  argument:(id)anArgument
  order:(unsigned)order
  modes:(NSArray*)modes;
- (void)cancelPerformSelector:(SEL)aSelector
  target:(id)target
  argument:(id)anArgument;

/* Monitoring file descriptors */
- (void)addPosixFileDescriptor:(NSPosixFileDescriptor*)fileDescriptor
  forMode:(NSString*)mode;
- (void)removePosixFileDescriptor:(NSPosixFileDescriptor*)fileDescriptor
  forMode:(NSString*)mode;

/* Monitoring file objects */
- (void)addFileObject:(id)_fileObject
  activities:(unsigned int)_activities
  forMode:(NSString *)_mode;
- (void)removeFileObject:(id)_fileObject
  forMode:(NSString *)_mode;

/* Ports */
- (void)addPort:(NSPort *)_port forMode:(NSString *)_mode;
- (void)removePort:(NSPort *)_port forMode:(NSString *)_mode;

/* Server operation */
- (void)configureAsServer;

/* Private methods */
+ (void)taskNowMultiThreaded:(NSNotification *)notification;

@end

@interface NSObject(RunloopFileObject)

- (int)fileDescriptor;

@end

#endif /* __NSRunLoop_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
