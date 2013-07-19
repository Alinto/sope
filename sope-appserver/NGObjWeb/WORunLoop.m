/*
  Copyright (C) 2000-2005 SKYRIX Software AG

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

#include "WORunLoop.h"
#include "common.h"

// TODO: not used anymore?

#if 0
#if !LIB_FOUNDATION_LIBRARY && !APPLE_Foundation_LIBRARY && !NeXT_Foundation_LIBRARY

#ifndef CREATE_AUTORELEASE_POOL
#  define CREATE_AUTORELEASE_POOL(pool) \
            id pool = [[NSAutoreleasePool alloc] init]
#endif

#include <sys/types.h>
#include <sys/errno.h>
#include <errno.h>

#include <sys/time.h>	/* for struct timeval */
#include <string.h>
#include <memory.h>
#include <libc.h>
#include <unistd.h>
#include <sys/select.h>

#include "WORunLoop.h"
#import <Foundation/Foundation.h>

#if NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY
#  include <FoundationExt/objc-runtime.h>
#else
#  include <extensions/objc-runtime.h>
#endif

#if 0
#warning breaks AppKit, should *extend* NSRunLoop on MacOSX
@implementation NSRunLoop(Override)
+ (NSRunLoop *)currentRunLoop {
  return [WORunLoop currentRunLoop];
}
@end
#endif

#if 0
typedef enum {
  NSPosixNoActivity = 0,
  NSPosixReadableActivity = 1,
  NSPosixWritableActivity = 2,
  NSPosixExceptionalActivity = 4
} NSPosixFileActivities;
#endif

NSString* NSFileObjectBecameActiveNotificationName =
  @"NSFileObjectBecameActiveNotificationName";

static char *activityDesc[8] = {
  "---", // 0
  "--R", // 1
  "-W-", // 2
  "-WR", // 3
  "E--", // 4
  "E-R", // 5
  "EW-", // 6
  "EWR"  // 7
};

@interface WORunLoopFileObjectInfo : NSObject
{
  id                    fileObject;
  NSPosixFileActivities watchedActivities;
  BOOL                  canCheckAlive;
}

- (id)initWithFileObject:(id)_fileObject
  activities:(NSPosixFileActivities)_activities;

- (BOOL)isAlive;
- (int)fileDescriptor;
- (NSPosixFileActivities)watchedActivities;

- (void)activity:(NSPosixFileActivities)_activity onDescriptor:(int)_fd;

@end

@implementation WORunLoopFileObjectInfo

- (id)initWithFileObject:(id)_fileObject
  activities:(NSPosixFileActivities)_activities
{
  self->fileObject        = RETAIN(_fileObject);
  self->watchedActivities = _activities;
  self->canCheckAlive     = [_fileObject respondsToSelector:@selector(isAlive)];
  return self;
}
- (id)init
{
  [self errorWithFormat:@"do not use init with WORunLoopFileObjectInfo .."];
  AUTORELEASE(self);
  return nil;
}

- (void)dealloc
{
  RELEASE(self->fileObject); self->fileObject = nil;
  [super dealloc];
}

- (BOOL)isEqual:(WORunLoopFileObjectInfo*)otherInfo
{
  return [self->fileObject isEqual:otherInfo->fileObject];
}

- (BOOL)isAlive {
  return (self->canCheckAlive) ? [self->fileObject isAlive] : YES;
}
- (int)fileDescriptor
{
  return [self->fileObject fileDescriptor];
}

- (NSPosixFileActivities)watchedActivities
{
  return self->watchedActivities;
}

- (void)activity:(NSPosixFileActivities)_activity onDescriptor:(int)_fd
{
  //NSLog(@"FileObject %@ was active ..", self->fileObject);
    
  [[NSNotificationCenter defaultCenter]
                         postNotificationName:
                           NSFileObjectBecameActiveNotificationName
                         object:self->fileObject];
}

- (NSString *)description
{
  return [NSString stringWithFormat:
                     @"<%@[0x%p]: object=%@ actitivity=%s>",
                     NSStringFromClass([self class]), self,
                     self->fileObject,
                     activityDesc[self->watchedActivities]
                   ];
}

@end

@interface WORunLoopTimerInfo : NSObject
{
    NSTimer* timer;
    NSDate* fireDate;
}

+ (WORunLoopTimerInfo*)infoWithTimer:(NSTimer*)timer;
- (void)recomputeFireDate;
- (NSComparisonResult)compare:(WORunLoopTimerInfo*)anObject;
- (NSTimer*)timer;
- (NSDate*)fireDate;
@end

@implementation WORunLoopTimerInfo

+ (WORunLoopTimerInfo*)infoWithTimer:(NSTimer*)aTimer
{
    WORunLoopTimerInfo* info = [self new];

    info->timer    = RETAIN(aTimer);
    info->fireDate = RETAIN([aTimer fireDate]);
    return AUTORELEASE(info);
}

- (void)dealloc
{
    RELEASE(timer);
    RELEASE(fireDate);
    [super dealloc];
}

- (void)recomputeFireDate
{
  if ([timer isValid]) {
    id tmp = [timer fireDate];
    ASSIGN(fireDate, tmp);
  }
}

- (NSComparisonResult)compare:(WORunLoopTimerInfo*)anObject
{
    return [fireDate compare:anObject->fireDate];
}

- (NSTimer*)timer			{ return timer; }
- (NSDate*)fireDate			{ return fireDate; }

@end

@interface WORunLoopActionHolder : NSObject
{
    id target;
    id argument;
    SEL action;
    int order;
}
+ objectWithTarget:(id)target
  argument:(id)argument
  selector:(SEL)action
  order:(int)order;
- (BOOL)isEqual:(id)anotherHolder;
- (void)execute;
@end

@implementation WORunLoopActionHolder

+ objectWithTarget:(id)_target
  argument:(id)_argument
  selector:(SEL)_action
  order:(int)_order
{
    WORunLoopActionHolder* holder = AUTORELEASE([self alloc]);

    holder->target = RETAIN(_target);
    holder->argument = RETAIN(_argument);
    holder->action = _action;
    holder->order = _order;

    return holder;
}

- (unsigned)hash
{
  return [(NSObject*)target hash];
}

- (BOOL)isEqual:(WORunLoopActionHolder*)anotherHolder
{
    return [target isEqual:anotherHolder->target]
	    && [argument isEqual:anotherHolder->argument]
	    && SEL_EQ(action, anotherHolder->action);
}

- (void)execute
{
    [target performSelector:action withObject:argument];
}

- (NSComparisonResult)compare:(WORunLoopActionHolder*)anotherHolder
{
    return order - anotherHolder->order;
}

@end


@interface WORunLoopInputManager : NSObject
{
    NSMutableArray* fileObjects;
    NSMutableArray* timers;
    NSMutableArray* otherOperations;
}

- (void)addFileObject:(id)_fileObject
  activities:(NSPosixFileActivities)_activities;
- (void)removeFileObject:(id)_fileObject;

- (void)addTimer:(NSTimer*)aTimer;

- (NSMutableArray*)fileObjects;
- (NSMutableArray*)timers;

- (void)addOperation:(WORunLoopActionHolder*)holder;
- (void)removeOperation:(WORunLoopActionHolder*)holder;
- (void)performAdditionalOperations;
@end


@implementation WORunLoopInputManager

- init
{
    fileObjects     = [NSMutableArray new];
    timers          = [NSMutableArray new];
    otherOperations = [NSMutableArray new];
    return [super init];
}

- (void)dealloc
{
    RELEASE(fileObjects);
    RELEASE(timers);
    RELEASE(otherOperations);
    [super dealloc];
}

- (void)addFileObject:(id)_fileObject
  activities:(NSPosixFileActivities)_activities
{
    WORunLoopFileObjectInfo *info = nil;
    //NSAssert(_activities, @"no activity to watch ?!");
    info = [[WORunLoopFileObjectInfo allocWithZone:[self zone]]
                                     initWithFileObject:_fileObject
                                     activities:_activities];
    [self->fileObjects addObject:info];
    //NSLog(@"file objects now: %@", self->fileObjects);
    RELEASE(info); info = nil;
}
- (void)removeFileObject:(id)_fileObject
{
    WORunLoopFileObjectInfo *info = nil;
    info = [[WORunLoopFileObjectInfo allocWithZone:[self zone]]
                                     initWithFileObject:_fileObject
                                     activities:0];
    [self->fileObjects removeObject:info];
    //NSLog(@"file objects now: %@", self->fileObjects);
    RELEASE(info); info = nil;
}

- (void)addTimer:(NSTimer*)aTimer
{
    [timers addObject:[WORunLoopTimerInfo infoWithTimer:aTimer]];
}

- (void)addOperation:(WORunLoopActionHolder*)holder
{
    [otherOperations addObject:holder];
    [otherOperations sortUsingSelector:@selector(compare:)];
}

- (void)removeOperation:(WORunLoopActionHolder*)holder
{
    [otherOperations removeObject:holder];
}

- (void)performAdditionalOperations
{
    [otherOperations makeObjectsPerformSelector:@selector(execute)];
}

- (NSMutableArray*)fileObjects { return fileObjects; }
- (NSMutableArray*)timers      { return timers; }

@end /* WORunLoopInputManager */

@implementation WORunLoop

/* Class variable */
static WORunLoop *currentRunLoop = nil;
static BOOL      taskIsMultithreaded = NO;

+ (void)error:(id)_o {
  NSLog(@"ERROR:");
  NSLog(@"  %@", _o);
}

+ (NSRunLoop *)currentRunLoop
{
  if (taskIsMultithreaded) {
    NSLog(@"WORunLoop does not work multithreaded, exit ..");
    return nil;
  }
  else {
    if (!currentRunLoop)
	    currentRunLoop = [[self alloc] init];
    return currentRunLoop;
  }
}

- (id)init {
  self->inputsForMode = [[NSMutableDictionary allocWithZone:[self zone]] init];
  self->mode = RETAIN(NSDefaultRunLoopMode);
  return self;
}

- (void)dealloc {
  RELEASE(self->inputsForMode);
  RELEASE(self->mode);
  [super dealloc];
}

- (NSString *)currentMode {
    return self->mode;
}

static inline WORunLoopInputManager*
_getInputManager(WORunLoop *self, NSString *_mode)
{
  WORunLoopInputManager* inputManager;

  inputManager = [self->inputsForMode objectForKey:_mode];
  if (inputManager == nil) {
    inputManager = [WORunLoopInputManager new];
    [self->inputsForMode setObject:inputManager forKey:_mode];
    RELEASE(inputManager);
  }
  return inputManager;
}

static int compare_fire_dates(id timer1, id timer2, void* userData)
{
  return [[timer1 fireDate] compare:[timer2 fireDate]];
}

- (NSDate*)limitDateForMode:(NSString*)aMode
{
    NSString       *format = @"%s: Caught exception %@ with reason %@ ";
    NSMutableArray *timers = [[inputsForMode objectForKey:aMode] timers];
    volatile int   i, count;
    NSMutableArray *copyOfTimers;

    ASSIGN(mode, aMode);

    /* Remove invalid timers */
    for(count = [timers count], i = count - 1; i >= 0; i--)
        if(![[[timers objectAtIndex:i] timer] isValid]) {
            [timers removeObjectAtIndex:i];
	    count--;
        }

    /* Currently only timers have limit dates associated with them */
    if(!count)
        return nil;

    copyOfTimers = [timers mutableCopy];

    /* Sort the timers based on their fire date */
    [copyOfTimers sortUsingFunction:compare_fire_dates context:NULL];

    /* Fire all the timers with their fire date expired */
    for(i = 0; i < count; i++) {
        WORunLoopTimerInfo* timerInfo = [copyOfTimers objectAtIndex:i];
        NSDate* fireDate = [timerInfo fireDate];
        NSDate* currentDate = [NSDate date];

        if([fireDate earlierDate:currentDate] == fireDate
	   || [fireDate isEqualToDate:currentDate]) {
            NSTimer* timer = [timerInfo timer];
            NS_DURING
	      [timer fire];
            NS_HANDLER
	      NSLog(format, __PRETTY_FUNCTION__,
                    [localException name], [localException reason]);
            NS_ENDHANDLER;

#if 0
#warning no repeated timers !
            if(![timer repeats])
#endif
                [timer invalidate];
        }
    }

    RELEASE(copyOfTimers);

    /* Recompute the fire dates for this cycle */
    [timers makeObjectsPerformSelector:@selector(recomputeFireDate)];

    /* Sort the timers based on their fire date */
    [timers sortUsingFunction:compare_fire_dates context:NULL];

    return [timers count] ? [[timers objectAtIndex:0] fireDate] : nil;
}

- (void)addTimer:(NSTimer*)aTimer
	forMode:(NSString*)aMode
{
    [_getInputManager(self, aMode) addTimer:aTimer];
}

- (BOOL)runMode:(NSString*)aMode
	beforeDate:(NSDate*)limitDate
{
    id inputManager, fileObjects;
    NSArray* timers;
    NSDate* date;

    /* Retain the limitDate so it doesn't get released by limitDateForMode:
	if it fires a timer that has as fireDate the limitDate.
	(bug report from Benhur Stein <Benhur-de-Oliveira.Stein@imag.fr>)
      */
    (void)RETAIN(limitDate);

    inputManager = [inputsForMode objectForKey:aMode];
    timers       = [inputManager timers];
    fileObjects  = [inputManager fileObjects];

    if (([timers count] != 0) || ([fileObjects count] != 0)) {
	CREATE_AUTORELEASE_POOL(pool);

	date = [self limitDateForMode:aMode];
	date = date ? [date earlierDate:limitDate] : limitDate;
	[self acceptInputForMode:aMode beforeDate:date];
	RELEASE(pool);
	RELEASE(limitDate);
	return YES;
    }

    RELEASE(limitDate);
    return NO;
}

/*  Runs the loop until limitDate or until the earliest limit date for input
    sources in the specified mode. */
- (void)acceptInputForMode:(NSString*)aMode
	beforeDate:(NSDate*)limitDate
{
    id              inputManager, fileObjects;
    struct timeval  tp = { 0, 0 };
    struct timeval* timeout = NULL;
    NSTimeInterval  delay = 0;
    fd_set          readSet, writeSet, exceptionsSet;
    volatile int    i, r, count;

    ASSIGN(mode, aMode);

    if(limitDate == nil) // delay = 0
	limitDate = [NSDate distantFuture];
    else {
	delay = [limitDate timeIntervalSinceNow];
	    /* delay > 0 means a future date */

	/* If limitDate is in the past return */
	if(delay < 0)
	    return;
    }

    inputManager = [inputsForMode objectForKey:aMode];
    fileObjects  = [inputManager fileObjects];

    /* Compute the timeout for select */
    if([limitDate isEqual:[NSDate distantFuture]])
	timeout = NULL;
    else {
	tp.tv_sec = delay;
	tp.tv_usec = (delay - (NSTimeInterval)tp.tv_sec) * 1000000.0;
	timeout = &tp;
    }

    ASSIGN(mode, aMode);

    FD_ZERO(&readSet);
    FD_ZERO(&writeSet);
    FD_ZERO(&exceptionsSet);

    do {
        count = [fileObjects count];
        for (i = 0; i < count; i++) {
            WORunLoopFileObjectInfo *info;
            NSPosixFileActivities   fileActivity;
            int                     fd;

            info = [fileObjects objectAtIndex:i];
            if (![info isAlive])
                continue;

            fileActivity = [info watchedActivities];
            fd           = [info fileDescriptor];
            
            if (fd >= 0) {
#if !defined(__MINGW32__) /* on Windows descriptors can be BIG */
                if (fd >= FD_SETSIZE) {
                    NSLog(@"%s: fd %i of %@ exceeds select size %i",
                          __PRETTY_FUNCTION__,
                          fd, info, FD_SETSIZE);
                    continue;
                }
#endif /* !defined(__MINGW32__) */

                //NSLog(@"registering activity %s for fd %i ..",
                //      activityDesc[fileActivity], fd);

                if (fileActivity & NSPosixReadableActivity)
                    FD_SET(fd, &readSet);
                if (fileActivity & NSPosixWritableActivity)
                    FD_SET(fd, &writeSet);
                if (fileActivity & NSPosixExceptionalActivity)
                    FD_SET(fd, &exceptionsSet);
            }
        }

        // ???: errno = 0; What is this good for ?
	r = select(FD_SETSIZE, &readSet, &writeSet, &exceptionsSet, timeout);
	if (r == -1) {
	    if (errno == EINTR) {
		/* Interrupt occured; break the loop to give a chance to
		   UnixSignalHandler to handle the signals. */
		errno = 0;
		break;
	    }
	    else {
		NSLog(@"%s: select() error: '%s'",
                      __PRETTY_FUNCTION__, strerror (errno));
                break;
            }
	    errno = 0;
	}
    } while (r == -1);

    if(r > 0) {
        id fileObjectsCopy;
	NSString* format = @"%s: Caught exception %@ with reason %@ ";

        *(&fileObjectsCopy) = nil;

	NS_DURING {
            // made copy, so that modifications in the delegate don't
            // alter the loop
            fileObjectsCopy = [fileObjects copyWithZone:[self zone]];
            count           = [fileObjectsCopy count];
            
            for (i = 0; (i < count) && (r > 0); i++) {
                WORunLoopFileObjectInfo *info;
                NSPosixFileActivities   activity = 0;
                int fd;

                info = [fileObjectsCopy objectAtIndex:i];
                fd   = [info fileDescriptor];

                if (fd >= 0) {
                    //NSLog(@"checking activity for %i info %@ ..", fd, info);
                
                    if (FD_ISSET(fd, &readSet)) {
                        activity |= NSPosixReadableActivity;
                        r--;
                    }
                    if (FD_ISSET(fd, &writeSet)) {
                        activity |= NSPosixWritableActivity;
                        r--;
                    }
                    if (FD_ISSET(fd, &exceptionsSet)) {
                        activity |= NSPosixExceptionalActivity;
                        r--;
                    }

                    if (activity != 0)
                        [info activity:activity onDescriptor:fd];
                }
            }
            if (r > 0) {
              [self warnWithFormat:@"could not resolve all activities (%i) ..",
                      r);
            }
	}
        NS_HANDLER {
          [self errorWithFormat:format, __PRETTY_FUNCTION__,
                  [localException name], [localException reason]];
	}
        NS_ENDHANDLER;

	RELEASE(fileObjectsCopy); fileObjectsCopy = nil;
    }

    [inputManager performAdditionalOperations];
#if !NeXT_Foundation_LIBRARY
    [NSNotificationQueue runLoopASAP];
#endif
}

- (void)runUntilDate:(NSDate*)limitDate
{
    BOOL shouldContinue = YES;

    if(!limitDate)
	limitDate = [NSDate distantFuture];
    else {
	/* If limitDate is in the past return */
	if([limitDate timeIntervalSinceNow] < 0)
	    return;
    }

    while (shouldContinue) {
        CREATE_AUTORELEASE_POOL(pool);

        if ([limitDate laterDate:[NSDate date]] == limitDate) {
	    if([self runMode:NSDefaultRunLoopMode beforeDate:limitDate] == NO)
		shouldContinue = NO;
        }
	else
	    shouldContinue = NO;
        RELEASE(pool);
    }
}

- (void)run
{
    [self runUntilDate:[NSDate distantFuture]];
}

- (void)performSelector:(SEL)aSelector
  target:(id)target
  argument:(id)anArgument
  order:(unsigned)order
  modes:(NSArray*)modes
{
    id holder = [WORunLoopActionHolder objectWithTarget:target
					argument:anArgument
					selector:aSelector
					order:order];
    int i, count = [modes count];

    for (i = 0; i < count; i++)
	[[inputsForMode objectForKey:[modes objectAtIndex:i]]
	    addOperation:holder];
}

- (void)cancelPerformSelector:(SEL)aSelector
  target:(id)target
  argument:(id)anArgument
{
    id holder = [WORunLoopActionHolder objectWithTarget:target
					argument:anArgument
					selector:aSelector
					order:0];
    id enumerator = [inputsForMode keyEnumerator];
    id aMode;

    while ((aMode = [enumerator nextObject]))
	[[inputsForMode objectForKey:aMode] removeOperation:holder];
}

/* Monitoring file objects */

- (void)addFileObject:(id)_fileObject
  activities:(NSPosixFileActivities)_activities
  forMode:(NSString *)_mode
{
    [_getInputManager(self, _mode) addFileObject:_fileObject
                                   activities:_activities];
}

- (void)removeFileObject:(id)_fileObject
  forMode:(NSString *)_mode
{
    [_getInputManager(self, _mode) removeFileObject:_fileObject];
}

@end /* WORunLoop */

#endif /* !LIB_FOUNDATION_LIBRARY */
#endif // 0
