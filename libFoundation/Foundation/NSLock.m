/* 
   NSLock.m

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
#include <Foundation/NSLock.h>

#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <extensions/objc-runtime.h>
#include <config.h>

NSRecursiveLock* libFoundationLock = nil;

/*
 * NSLock - lock of depth limited to 1
 */

@implementation NSLock

- init
{
    mutex = objc_mutex_allocate();
    if (!mutex) {
	RELEASE(self);
	return nil;
    }
    return self;
}

- (void)dealloc
{
    if (mutex)
	objc_mutex_deallocate(mutex);
    [super dealloc];
}

- (void)lock
{
    if (objc_mutex_lock(mutex) > 1) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to lock a simple lock (NSLock) multiple times"] raise];
    }
}

- (BOOL)tryLock
{
    int depth = objc_mutex_trylock(mutex);
    
    if (depth > 1) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to lock a simple lock (NSLock) multiple times"] raise];
    }
    
    return depth == 1 ? YES : NO;
}

- (BOOL)lockBeforeDate:(NSDate *)limit
{
    // TODO: Temporary implementation
    [self lock];
    return YES;
}

- (void)unlock
{
    if (objc_mutex_unlock(mutex) < 0) {
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to unlock a lock not owned by the current thread"] raise];
    }
}

@end /* NSLock */

/*
 * NSLock - lock of unlimited (MAX_INT) depth
 */

@implementation NSRecursiveLock

- init
{
    mutex = objc_mutex_allocate();
    if (!mutex) {
	RELEASE(self);
	return nil;
    }
    return self;
}

- (void)dealloc
{
    if (mutex)
	objc_mutex_deallocate(mutex);
    [super dealloc];
}

- (void)lock
{
    if (objc_mutex_lock(mutex) < 0)
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to lock an invalid lock"] raise];
}

- (BOOL)tryLock
{
    return objc_mutex_trylock(mutex) > 0 ? YES : NO;
}

- (BOOL)lockBeforeDate:(NSDate *)limit
{
    // TODO: Temporary implementation
    [self lock];
    return YES;
}

- (void)unlock
{
    if (objc_mutex_unlock(mutex) < 0)
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to unlock a lock not owned by the current thread"] raise];
}

@end /* NSRecursiveLock:NSObject */

/*
 * Condition lock
 */

@implementation NSConditionLock

- init
{
    return [self initWithCondition:0];
}

- initWithCondition:(int)aCondition
{
    mutex = objc_mutex_allocate();
    if (!mutex) {
	RELEASE(self);
	return nil;
    }
    condition = objc_condition_allocate();
    if (!condition) {
	RELEASE(self);
	return nil;
    }
    value = aCondition;
    return self;
}

- (void)dealloc
{
    if (condition)
	objc_condition_deallocate(condition);
    if (mutex)
	objc_mutex_deallocate(mutex);
    [super dealloc];
}

- (int)condition
{
    return value;
}

- (void)lock
{
    if (objc_mutex_lock(mutex) < 0)
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to lock an invalid lock"] raise];
}

- (void)lockWhenCondition:(int)aCondition
{
    int depth;
    
    // Try to lock the mutex
    depth = objc_mutex_lock(mutex);

    // Return on error
    if (depth == -1)
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to lock an invalid lock"] raise];
	    
    // Error if recursive lock and condition is false 
    if ((depth > 1) && (value != aCondition))
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to lock a condition lock multiple times"
	    @"with a different condition value"] raise];

    // Wait condition
    while (value != aCondition)
	    objc_condition_wait(condition, mutex);
}

- (BOOL)lockBeforeDate:(NSDate *)limit
{
    // TODO: Temporary implementation
    [self lock];
    return YES;
}

- (BOOL)lockWhenCondition:(int)aCondition beforeDate:(NSDate *)limit
{
    // TODO: Temporary implementation
    [self lockWhenCondition:aCondition];
    return YES;
}

- (BOOL)tryLock
{
    return objc_mutex_trylock(mutex) > 0 ? YES : NO;
}

- (BOOL)tryLockWhenCondition:(int)aCondition
{
    if (![self tryLock])
	return NO;
    
    if (value != aCondition) {
	objc_mutex_unlock(mutex);
	return NO;
    }
    
    return YES;
}

- (void)unlock
{
    if (objc_mutex_unlock(mutex) < 0)
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to unlock a lock not owned by the current thread"] raise];
}

- (void)unlockWithCondition:(int)aCondition
{
    int depth;
    
    // Try to lock the mutex again
    depth = objc_mutex_trylock(mutex);
    
    // Another thread has the lock so abort
    if (depth == -1)
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to lock an invalid lock"] raise];
    
    // If the depth is only 1 then we just acquired
    // the lock above, bogus unlock so abort
    if (depth == 1)
	[[[InvalidUseOfMethodException alloc] initWithFormat:
	    @"attempt to unlock with condition a lock "
	    @"not owned by the current thread"] raise];
    
    value = aCondition;
    
    // Wake up threads waiting a condition to happen
    objc_condition_broadcast(condition);
    // This is a valid unlock so set the condition and unlock twice
    objc_mutex_unlock(mutex);
    objc_mutex_unlock(mutex);
}

@end /* NSConditionLock:NSObject */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
