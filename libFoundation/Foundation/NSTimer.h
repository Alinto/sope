/* 
   NSTimer.h

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

#ifndef __NSTimer_h__
#define __NSTimer_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSDate.h>

@class NSDate;
@class NSInvocation;

/*
 * NSTimer class
 */

@interface NSTimer : NSObject
{
    NSTimeInterval	timeInterval;
    NSDate*		fireDate;
    NSInvocation*	invocation;
    id			userInfo;
    BOOL		repeats;
    BOOL		isValid;
}

+ (NSTimer*)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds
  invocation:(NSInvocation*)anInvocation repeats:(BOOL)repeats;

+ (NSTimer*)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds
  target:(id)anObject selector:(SEL)aSelector
  userInfo:(id)anArgument repeats:(BOOL)repeats;

+ (NSTimer*)timerWithTimeInterval:(NSTimeInterval)seconds
  invocation:(NSInvocation*)anInvocation repeats:(BOOL)repeats;

+ (NSTimer*)timerWithTimeInterval:(NSTimeInterval)seconds
  target:(id)anObject selector:(SEL)aSelector
  userInfo:(id)anArgument repeats:(BOOL)repeats; 

/* Firing the Timer */
- (void)fire;

/* Stopping the Timer */
- (void)invalidate;

/* Getting Information About the NSTimer */
- (NSDate*)fireDate;

- (id)userInfo;

- (BOOL)isValid;
- (BOOL)repeats;

- (NSTimeInterval)timeInterval;

@end

/*
 * NSTimer implementation messages
 */
 
@interface NSTimer(NSTimerImplementation)
- (id)initWith:(NSTimeInterval)seconds invocation:(NSInvocation*)anInvocation
  userInfo:(id)anObject repeat:(BOOL)repeats;
@end

#endif /* __NSTimer_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
