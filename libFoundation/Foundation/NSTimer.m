/* 
   NSTimer.m

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

#include <stdio.h>
#include <math.h>

#include <Foundation/common.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSRunLoop.h>

#include <extensions/objc-runtime.h>

@implementation NSTimer
+ (NSTimer*)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds
    invocation:(NSInvocation*)anInvocation
    repeats:(BOOL)_repeats
{
    id timer = [self timerWithTimeInterval:seconds
			invocation:anInvocation
			repeats:_repeats];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    return timer;
}

+ (NSTimer*)scheduledTimerWithTimeInterval:(NSTimeInterval)seconds
    target:(id)anObject
    selector:(SEL)aSelector
    userInfo:(id)anArgument
    repeats:(BOOL)_repeats
{
    id timer = [self timerWithTimeInterval:seconds
			target:anObject
			selector:aSelector
			userInfo:anArgument
			repeats:_repeats];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    return timer;
}

+ (NSTimer*)timerWithTimeInterval:(NSTimeInterval)seconds
    invocation:(NSInvocation*)anInvocation
    repeats:(BOOL)_repeats
{
    id timer = AUTORELEASE([[self alloc]
                               initWith:seconds invocation:anInvocation
                               userInfo:nil repeat:_repeats]);
    return timer;
}

+ (NSTimer*)timerWithTimeInterval:(NSTimeInterval)seconds
    target:(id)anObject
    selector:(SEL)aSelector
    userInfo:(id)anArgument
    repeats:(BOOL)_repeats
{
    id anInvocation = [NSInvocation invocationWithMethodSignature:
			[anObject methodSignatureForSelector:aSelector]];
    id timer = AUTORELEASE([[self alloc]
                               initWith:seconds invocation:anInvocation
                               userInfo:anArgument repeat:_repeats]);
    [anInvocation setTarget:anObject];
    [anInvocation setSelector:aSelector];
    if ([[anInvocation methodSignature] numberOfArguments] > 2)
	[anInvocation setArgument:&timer atIndex:2];
    [anInvocation retainArguments];

    return timer;
}

- (void)dealloc
{
    RELEASE(fireDate);
    RELEASE(invocation);
    RELEASE(userInfo);
    [super dealloc];
}

- (NSString *)description
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[1024];
    NSDate *fd;

    fd = [self fireDate];

    sprintf (buffer,
	    "<%s %p fireDate: %s selector: %s repeats: %s isValid: %s>",
	    (char*)object_get_class_name(self),
	    self,
	    fd ? [[fd description] cString] : "nil",
	    [invocation selector]
		? [NSStringFromSelector([invocation selector]) cString]
		: "nil",
	    repeats ? "YES" : "NO",
	    isValid ? "YES" : "NO");

    return [NSString stringWithCString:buffer];
}

- (void)fire
{
    if(self->isValid)
	[self->invocation invoke];
    
    if(self->repeats) {
        NSTimeInterval ellapsedTimeSinceCreated;
        NSTimeInterval nextTime;
	NSDate         *newDate;

        ellapsedTimeSinceCreated = -[fireDate timeIntervalSinceNow];
        nextTime = ceil(ellapsedTimeSinceCreated / timeInterval) * timeInterval;
	newDate  = [fireDate addTimeInterval:nextTime];
        
	ASSIGN(self->fireDate, newDate);
    }
}

- (NSDate *)fireDate
{
    if(!self->repeats)
	return [self->fireDate addTimeInterval:self->timeInterval];
    else {
	NSTimeInterval ellapsedTimeSinceCreated, nextTime;

        ellapsedTimeSinceCreated = -[fireDate timeIntervalSinceNow];
        nextTime = ceil(ellapsedTimeSinceCreated / timeInterval) * timeInterval;
	return [self->fireDate addTimeInterval:nextTime];
    }
}

- (void)invalidate
{
    if (self->isValid) {
#if 0
        /*hh: why was this ??? */
	[self->invocation invalidate];
#endif
	self->isValid = NO;
    }
}

- (id)userInfo
{
    return self->userInfo;
}
- (BOOL)isValid
{
    return self->isValid;
}
- (BOOL)repeats
{
    return self->repeats;
}

- (NSTimeInterval)timeInterval
{
    return self->timeInterval;
}

@end

/*
 * NSTimer implementation messages
 */
 
@implementation NSTimer(NSTimerImplementation)
- initWith:(NSTimeInterval)seconds invocation:(NSInvocation*)anInvocation
    userInfo:(id)anObject repeat:(BOOL)_repeats
{
    timeInterval = seconds;
    fireDate = RETAIN([NSDate date]);
    invocation = RETAIN(anInvocation);
    userInfo = RETAIN(anObject);
    repeats = _repeats;
    isValid = YES;
    return self;
}

@end
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

