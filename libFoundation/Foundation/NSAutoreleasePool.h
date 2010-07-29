/* 
   NSAutoreleasePool.h

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

#ifndef __NSAutoreleasePool_h__
#define __NSAutoreleasePool_h__

#include <Foundation/NSObject.h>

typedef struct __NSAutoreleasePoolChunk {
    int size;
    int used;
    struct __NSAutoreleasePoolChunk* next;
    id objects[0];
} NSAutoreleasePoolChunk;

@interface NSAutoreleasePool : NSObject
{
@protected
    NSAutoreleasePool      *parentPool;    // next pool up on stack 
    int                    countOfObjects; // objects in pool
    NSAutoreleasePoolChunk *firstChunk;	   // first chunk of objects
    NSAutoreleasePoolChunk *currentChunk;  // current chunk to add in
    id                     ownerThread;    // thread that owns the pool
}

/* Class Initialization */
+ (void)taskNowMultiThreaded:notification;

/* Instance initialization */
- (id)init;

/* Instance deallocation */
- (void)dealloc;

/* Notes that anObject should be released when the pool 
   at the current top of the stack is freed */
+ (void)addObject:anObject;

/* Notes that anObject must be released when pool is freed */
- (void)addObject:anObject;

/* Default pool */
+ (id)defaultPool;

/*
 * METHODS FOR DEBUGGING
 */

// Counts how many times anObject will receive 
// -release due to all NSAutoreleasePools in current thread
+ (unsigned)autoreleaseCountForObject:anObject;

// Counts how many times anObject will receive -release due to this pool
- (unsigned)autoreleaseCountForObject:anObject;

/* 
 * When enabled, -release and -autorelease calls are checking whether 
 * this object has been released too many times. This is done by searching 
 * all the pools, and makes programs run very slowly; It is off by default 
 */
+ (void)enableDoubleReleaseCheck:(BOOL)enable;
        
// When disabled, nothing added to pools is really released; 
// By default is enabled
+ (void)enableRelease:(BOOL)enable;

// When enables call -trash on add if countToBeReleased % trashLimit = 0
+ (void)setPoolCountThreshhold:(unsigned int)trash;

// Called on exceding trashLimit
- (id)trash;

@end

/*
 * Class that handles C pointers release sending them Free()
 */

@interface NSAutoreleasedPointer : NSObject
{
    void *theAddress;
}
+ (id)autoreleasePointer:(void*)address;
- (id)initWithAddress:(void*)address;
@end

#endif /* __NSAutoreleasePool_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
