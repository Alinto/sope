/* 
   NSRunLoop.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
           Helge Hess <helge.hess@mdlink.de>

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

#include <sys/types.h>
#if HAVE_SYS_ERRNO_H
#include <sys/errno.h>
#endif
#include <errno.h>

#if HAVE_SYS_TIME_H
# include <sys/time.h>	/* for struct timeval */
#endif

#if HAVE_STRING_H
# include <string.h>
#endif

#if HAVE_MEMORY_H
# include <memory.h>
#endif

#if !HAVE_MEMCPY
# define memcpy(d, s, n)       bcopy((s), (d), (n))
# define memmove(d, s, n)      bcopy((s), (d), (n))
#endif

#if HAVE_LIBC_H
# include <libc.h>
#else
# include <unistd.h>
#endif

#if HAVE_WINDOWS_H
# include <windows.h>
#endif

#if HAVE_SYS_SELECT_H
# include <sys/select.h>
#endif

#include <Foundation/NSRunLoop.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSException.h>
#include <Foundation/NSPosixFileDescriptor.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/UnixSignalHandler.h>

#include <extensions/objc-runtime.h>

NSString* NSDefaultRunLoopMode = @"NSDefaultRunLoopMode";
NSString* NSConnectionReplyMode = @"NSConnectionReplyMode";
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

@interface NSRunLoopFileObjectInfo : NSObject
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

@implementation NSRunLoopFileObjectInfo

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
      NSLog(@"ERROR: do not use init with NSRunLoopFileObjectInfo ..");
      self = AUTORELEASE(self);
      return nil;
}

- (void)dealloc
{
    RELEASE(self->fileObject);
    [super dealloc];
}

- (BOOL)isEqual:(id)otherInfo
{
    if (otherInfo == nil)
	return NO;
    if (*(Class *)self != *(Class *)otherInfo) /* check class */
	return NO;
    
    return [self->fileObject isEqual:
		    ((NSRunLoopFileObjectInfo *)otherInfo)->fileObject];
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
#if 0
    NSLog(@"%s:%i: FileObject %@ became active ..", __PRETTY_FUNCTION__,__LINE__,
          self->fileObject);
#endif
    
    if ([self->fileObject isKindOfClass:[NSPosixFileDescriptor class]]) {
        if (_activity & NSPosixReadableActivity) {
            [[self->fileObject delegate]
                               activity:NSPosixReadableActivity
                               posixFileDescriptor:self->fileObject];
        }
        if (_activity & NSPosixWritableActivity) {
            [[self->fileObject delegate]
                               activity:NSPosixWritableActivity
                               posixFileDescriptor:self->fileObject];
        }
        if (_activity & NSPosixExceptionalActivity) {
            [[self->fileObject delegate]
                               activity:NSPosixExceptionalActivity
                               posixFileDescriptor:self->fileObject];
        }
    }
    else {
        [[NSNotificationCenter defaultCenter]
                               postNotificationName:
                                 NSFileObjectBecameActiveNotificationName
                               object:self->fileObject];
    }
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

@interface NSRunLoopTimerInfo : NSObject
{
    NSTimer* timer;
    NSDate* fireDate;
}

+ (NSRunLoopTimerInfo*)infoWithTimer:(NSTimer*)timer;
- (void)recomputeFireDate;
- (NSComparisonResult)compare:(NSRunLoopTimerInfo*)anObject;
- (NSTimer*)timer;
- (NSDate*)fireDate;
@end

@implementation NSRunLoopTimerInfo

+ (NSRunLoopTimerInfo *)infoWithTimer:(NSTimer*)aTimer
{
    NSRunLoopTimerInfo *info = [self new];
    
    info->timer    = RETAIN(aTimer);
    info->fireDate = RETAIN([aTimer fireDate]);
    return AUTORELEASE(info);
}

- (void)dealloc
{
    RELEASE(self->timer);
    RELEASE(self->fireDate);
    [super dealloc];
}

- (void)recomputeFireDate
{
  if ([self->timer isValid]) {
    id tmp = [self->timer fireDate];
    ASSIGN(self->fireDate, tmp);
  }
}

- (NSComparisonResult)compare:(NSRunLoopTimerInfo*)anObject
{
    return [self->fireDate compare:anObject->fireDate];
}

- (NSTimer *)timer   { return self->timer;    }
- (NSDate *)fireDate { return self->fireDate; }

@end

@interface NSRunLoopActionHolder : NSObject
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

@implementation NSRunLoopActionHolder

+ (id)objectWithTarget:(id)_target
  argument:(id)_argument
  selector:(SEL)_action
  order:(int)_order
{
    NSRunLoopActionHolder* holder = AUTORELEASE([self alloc]);

    holder->target   = RETAIN(_target);
    holder->argument = RETAIN(_argument);
    holder->action   = _action;
    holder->order    = _order;

    return holder;
}

- (unsigned)hash
{
  return [(NSObject *)self->target hash];
}

- (BOOL)isEqual:(id)otherObject
{
    NSRunLoopActionHolder *anotherHolder;
    
    if ((anotherHolder = otherObject) == nil)
	return NO;
    if (![anotherHolder isKindOfClass:[NSRunLoopActionHolder class]])
	return NO;
    
    return [self->target isEqual:anotherHolder->target]
	    && [argument isEqual:anotherHolder->argument]
	    && SEL_EQ(self->action, anotherHolder->action);
}

- (void)execute
{
    [self->target performSelector:self->action withObject:self->argument];
}

- (NSComparisonResult)compare:(NSRunLoopActionHolder*)anotherHolder
{
    return (order - anotherHolder->order);
}

@end /* NSRunLoopActionHolder */


@interface NSRunLoopInputManager : NSObject
{
    NSMutableArray *fileObjects;
    NSMutableArray *timers;
    NSMutableArray *otherOperations;
}

- (void)addFileObject:(id)_fileObject
  activities:(NSPosixFileActivities)_activities;
- (void)removeFileObject:(id)_fileObject;

- (void)addPosixFileDescriptor:(NSPosixFileDescriptor*)fileDescriptor;
- (void)removePosixFileDescriptor:(NSPosixFileDescriptor*)fileDescriptor;

- (void)addTimer:(NSTimer*)aTimer;

- (NSMutableArray*)fileObjects;
- (NSMutableArray*)timers;

- (void)addOperation:(NSRunLoopActionHolder*)holder;
- (void)removeOperation:(NSRunLoopActionHolder*)holder;
- (void)performAdditionalOperations;
@end


@implementation NSRunLoopInputManager

- (id)init
{
    NSZone *z = [self zone];
    self->fileObjects     = [[NSMutableArray allocWithZone:z] init];
    self->timers          = [[NSMutableArray allocWithZone:z] init];
    self->otherOperations = [[NSMutableArray allocWithZone:z] init];
    return [super init];
}

- (void)dealloc
{
    RELEASE(self->fileObjects);
    RELEASE(self->timers);
    RELEASE(self->otherOperations);
    [super dealloc];
}

- (void)addFileObject:(id)_fileObject
  activities:(NSPosixFileActivities)_activities
{
    NSRunLoopFileObjectInfo *info = nil;
    //NSAssert(_activities, @"no activity to watch ?!");
    info = [[NSRunLoopFileObjectInfo allocWithZone:[self zone]]
                                     initWithFileObject:_fileObject
                                     activities:_activities];
    [self->fileObjects addObject:info];
    //NSLog(@"file objects now: %@", self->fileObjects);
    RELEASE(info); info = nil;
}
- (void)removeFileObject:(id)_fileObject
{
    NSRunLoopFileObjectInfo *info = nil;
    info = [[NSRunLoopFileObjectInfo allocWithZone:[self zone]]
                                     initWithFileObject:_fileObject
                                     activities:0];
    [self->fileObjects removeObject:info];
    //NSLog(@"file objects now: %@", self->fileObjects);
    RELEASE(info); info = nil;
}

- (void)addPosixFileDescriptor:(NSPosixFileDescriptor*)fileDescriptor
{
    [self addFileObject:fileDescriptor
          activities:[fileDescriptor fileActivity]];
}

- (void)removePosixFileDescriptor:(NSPosixFileDescriptor*)fileDescriptor
{
    [self removeFileObject:fileDescriptor];
}

- (void)addTimer:(NSTimer*)aTimer
{
    [self->timers addObject:[NSRunLoopTimerInfo infoWithTimer:aTimer]];
}

- (void)addOperation:(NSRunLoopActionHolder*)holder
{
    [self->otherOperations addObject:holder];
    [self->otherOperations sortUsingSelector:@selector(compare:)];
}

- (void)removeOperation:(NSRunLoopActionHolder*)holder
{
    [self->otherOperations removeObject:holder];
}

- (void)performAdditionalOperations
{
    [self->otherOperations makeObjectsPerform:@selector(execute)];
}

- (NSMutableArray *)fileObjects
{
    return self->fileObjects;
}
- (NSMutableArray *)timers
{
    return self->timers;
}

@end /* NSRunLoopInputManager */


@implementation NSRunLoop

extern NSRecursiveLock* libFoundationLock;

/* Class variable */
static NSMutableDictionary* runLoopsDictionary = nil;
static NSRunLoop* currentRunLoop = nil;
static BOOL taskIsMultithreaded = NO;

/*
+ (void)initialize
{
    [[NSNotificationCenter defaultCenter]
	addObserver:self
	selector:@selector(taskNowMultiThreaded:)
	name:NSWillBecomeMultiThreadedNotification
	object:nil];
}
*/

+ (NSRunLoop *)currentRunLoop
{
    if (taskIsMultithreaded) {
	NSRunLoop* currentLoop;
	NSThread* currentThread;

	[libFoundationLock lock];

	currentThread = [NSThread currentThread];
	currentLoop = [runLoopsDictionary objectForKey:currentThread];
	if (!currentLoop) {
	    currentLoop = AUTORELEASE([self new]);
	    [runLoopsDictionary setObject:currentLoop forKey:currentThread];
	}

	[libFoundationLock unlock];

	return currentLoop;
    }
    else {
	if (!currentRunLoop)
	    currentRunLoop = [self new];
	return currentRunLoop;
    }
}

+ (void)taskNowMultiThreaded:(NSNotification *)notification
{
    taskIsMultithreaded = YES;
    runLoopsDictionary = [NSMutableDictionary new];

    if (currentRunLoop) {
	NSThread* currentThread = [NSThread currentThread];

	[runLoopsDictionary setObject:currentRunLoop forKey:currentThread];
	RELEASE(currentRunLoop);
	currentRunLoop = nil;
    }
}

- init
{
    self = [super init];
    self->inputsForMode =
        [[NSMutableDictionary allocWithZone:[self zone]] init];
    self->mode = RETAIN(NSDefaultRunLoopMode);
    return self;
}

- (void)dealloc
{
    RELEASE(self->inputsForMode);
    RELEASE(self->mode);
    [super dealloc];
}

- (NSString*)currentMode
{
    return mode;
}

static inline NSRunLoopInputManager*
_getInputManager(NSRunLoop *self, NSString *_mode)
{
    NSRunLoopInputManager* inputManager;

    inputManager = [self->inputsForMode objectForKey:_mode];
    if (inputManager == nil) {
        inputManager = [[NSRunLoopInputManager alloc] init];
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
    NSString       *format =
        @"%s: During NSTimer:-fire, caught exception %@ with reason %@ ";
    NSMutableArray *timers = [[inputsForMode objectForKey:aMode] timers];
    volatile int   i, count;
    NSMutableArray *copyOfTimers;

    ASSIGN(mode, aMode);

    /* Remove invalid timers */
    for(count = [timers count], i = count - 1; i >= 0; i--) {
        if(![[[timers objectAtIndex:i] timer] isValid]) {
            [timers removeObjectAtIndex:i];
	    count--;
        }
    }
    
    /* Currently only timers have limit dates associated with them */
    if(!count)
        return nil;

    copyOfTimers = [timers mutableCopy];

    /* Sort the timers based on their fire date */
    [copyOfTimers sortUsingFunction:compare_fire_dates context:NULL];

    /* Fire all the timers with their fire date expired */
    for(i = 0; i < count; i++) {
        NSRunLoopTimerInfo* timerInfo = [copyOfTimers objectAtIndex:i];
        NSDate* fireDate = [timerInfo fireDate];
        NSDate* currentDate = [NSDate date];

        if([fireDate earlierDate:currentDate] == fireDate
	   || [fireDate isEqualToDate:currentDate]) {
            NSTimer* timer = [timerInfo timer];
            NS_DURING {
	      [timer fire];
            }
            NS_HANDLER {
              NSLog(format, "NSRunLoop(-limitDateForMode:)",
                    [localException name], [localException reason]);
            }
            NS_ENDHANDLER;
	    
            if(![timer repeats])
                [timer invalidate];
        }
    }

    RELEASE(copyOfTimers);

    /* Recompute the fire dates for this cycle */
    [timers makeObjectsPerform:@selector(recomputeFireDate)];

    /* Sort the timers based on their fire date */
    [timers sortUsingFunction:compare_fire_dates context:NULL];

    return [timers count] > 0
	? [[timers objectAtIndex:0] fireDate] : (NSDate *)nil;
}

- (void)addTimer:(NSTimer *)aTimer forMode:(NSString *)aMode
{
    [_getInputManager(self, aMode) addTimer:aTimer];
}

- (BOOL)runMode:(NSString *)aMode beforeDate:(NSDate *)limitDate
{
    id      inputManager, fileObjects;
    NSArray *timers;
    NSDate  *date;
    
    /* Retain the limitDate so it doesn't get released by limitDateForMode:
	if it fires a timer that has as fireDate the limitDate.
	(bug report from Benhur Stein <Benhur-de-Oliveira.Stein@imag.fr>)
      */
    (void)RETAIN(limitDate);

    inputManager = [self->inputsForMode objectForKey:aMode];
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
- (void)acceptInputForMode:(NSString *)aMode beforeDate:(NSDate *)limitDate
{
    id              inputManager, fileObjects;
    struct timeval  tp = { 0, 0 };
    struct timeval* timeout = NULL;
    NSTimeInterval  delay = 0;
    fd_set          readSet, writeSet, exceptionsSet;
    volatile int    i, r, count;

    ASSIGN(self->mode, aMode);

    if(limitDate == nil) { // delay = 0
	limitDate = [NSDate distantFuture];
    }
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
    
    [NSNotificationQueue runLoopASAP];
    
    ASSIGN(self->mode, aMode);
    
    FD_ZERO(&readSet);
    FD_ZERO(&writeSet);
    FD_ZERO(&exceptionsSet);

    do {
        count = [fileObjects count];
        for (i = 0; i < count; i++) {
            NSRunLoopFileObjectInfo *info = [fileObjects objectAtIndex:i];
            NSPosixFileActivities   fileActivity;
            int                     fd;

            if (![info isAlive])
                continue;

            fileActivity = [info watchedActivities];
            fd           = [info fileDescriptor];
            
            if (fd >= 0) {
#if !defined(__MINGW32__) /* on Windows descriptors can be BIG */
                if (fd >= FD_SETSIZE) {
                    NSLog(@"%s: fd %i of %@ exceeds select size %i",
                          "NSRunLoop(-acceptInputForMode:beforeDate:)",
                          fd, info, FD_SETSIZE);
                    continue;
                }
#endif

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
        
        /* ???: errno = 0; What is this good for ? */
	r = select(FD_SETSIZE, &readSet, &writeSet, &exceptionsSet, timeout);
	if (r == -1) {
	    if (errno == EINTR) {
		/* Interrupt occured; break the loop to give a chance to
		   UnixSignalHandler to handle the signals. */
                //printf("%s: GOT EINTR ...\n", __PRETTY_FUNCTION__);
		errno = 0;
		break;
	    }
	    else {
		NSLog(@"%s: select() error: '%s'",
                      "NSRunLoop(-acceptInputForMode:beforeDate:)",
                      strerror (errno));
                break;
            }
	    errno = 0;
	}
    } while (r == -1);

    if (r > 0) {
        id fileObjectsCopy;

        *(&fileObjectsCopy) = nil;

	{
            // made copy, so that modifications in the delegate don't
            // alter the loop
            fileObjectsCopy = [fileObjects copyWithZone:[self zone]];
            count           = [fileObjectsCopy count];
            
            for (i = 0; (i < count) && (r > 0); i++) {
                NSRunLoopFileObjectInfo *info;
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
#if 0
            if (r > 0) {
                NSLog(@"WARNING: did not resolve all activities (%i) ..", r);
            }
#endif
	}

	RELEASE(fileObjectsCopy); fileObjectsCopy = nil;
    }
    
    [inputManager performAdditionalOperations];
    [NSNotificationQueue runLoopASAP];
    [inputManager performAdditionalOperations];
}

- (void)runUntilDate:(NSDate *)limitDate
{
    BOOL shouldContinue = YES;
    
    if (limitDate == nil)
	limitDate = [NSDate distantFuture];
    else {
	/* If limitDate is in the past return */
	if ([limitDate timeIntervalSinceNow] < 0)
	    return;
    }

    while (shouldContinue) {
        CREATE_AUTORELEASE_POOL(pool);
        
        if ([limitDate laterDate:[NSDate date]] == limitDate) {
	    if ([self runMode:NSDefaultRunLoopMode beforeDate:limitDate] == NO)
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
    id holder = [NSRunLoopActionHolder objectWithTarget:target
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
    id holder = [NSRunLoopActionHolder objectWithTarget:target
					argument:anArgument
					selector:aSelector
					order:0];
    id enumerator = [inputsForMode keyEnumerator];
    id aMode;

    while ((aMode = [enumerator nextObject]))
	[[inputsForMode objectForKey:aMode] removeOperation:holder];
}

/* Monitoring file descriptors */

- (void)addPosixFileDescriptor:(NSPosixFileDescriptor *)fileDescriptor
  forMode:(NSString *)aMode
{
    [_getInputManager(self, aMode) addPosixFileDescriptor:fileDescriptor];
}

- (void)removePosixFileDescriptor:(NSPosixFileDescriptor *)fileDescriptor
  forMode:(NSString *)aMode
{
    [_getInputManager(self, aMode) removePosixFileDescriptor:fileDescriptor];
}

/* Monitoring file objects */

- (void)addFileObject:(id)_fileObject
  activities:(unsigned int)_activities /* NSPosixFileActivities */
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

/* Ports */

- (void)addPort:(NSPort *)_port forMode:(NSString *)_mode
{
    [self notImplemented:_cmd];
}

- (void)removePort:(NSPort *)_port forMode:(NSString *)_mode
{
    [self notImplemented:_cmd];
}

/* Server operation */

- (void)configureAsServer
{
    /* What is special about a server ?, maybe register as service in Win32 */
}

@end /* NSRunLoop */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
