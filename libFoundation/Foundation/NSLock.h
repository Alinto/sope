/* 
   NSLock.h

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

#ifndef __NSLock_h__
#define __NSLock_h__

#include <Foundation/NSObject.h>

@class NSDate;

/* Protocol for thread/task locks */

@protocol NSLocking
- (void)lock;
- (void)unlock;    
@end

/* Lock that can be locked only once (maximum depth one) */

@interface NSLock : NSObject <NSLocking> 
{
    struct objc_mutex* mutex;
}
- (BOOL)tryLock;
- (BOOL)lockBeforeDate:(NSDate *)limit;
       
@end

/* Lock that can be locked multiple times by the same process */

@interface NSRecursiveLock : NSObject <NSLocking>
{
    struct objc_mutex* mutex;
}
- (BOOL)tryLock;
- (BOOL)lockBeforeDate:(NSDate *)limit;
@end

/* Condition lock is a lock-ed access to a condition variable */

@interface NSConditionLock : NSObject <NSLocking>
{
    struct objc_mutex* mutex;
    struct objc_condition* condition;
    volatile int value;
}
- (id)initWithCondition:(int)aCondition;
- (int)condition;
- (void)lockWhenCondition:(int)aCondition;
- (BOOL)lockBeforeDate:(NSDate *)limit;
- (BOOL)lockWhenCondition:(int)aCondition beforeDate:(NSDate *)limit;
- (BOOL)tryLock;
- (BOOL)tryLockWhenCondition:(int)aCondition;
- (void)unlockWithCondition:(int)aCondition;
@end

#endif /* __NSLock_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
