/* 
   NSAutoreleasePool.m

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
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSThread.h>
#include <Foundation/NSLock.h>

#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include "PrivateThreadData.h"

//#define LOG_RELEASE       1
//#define LOG_RELEASE_COUNT 1

@implementation NSAutoreleasePool

/* 
 * Autorelease default parameters
 */

enum { CHUNK_SIZE = 1024 };

/*
 * Static variables
 */

// default pool (this should be per thread variable)
static NSAutoreleasePool* defaultPool = nil;
static BOOL isMultithreaded = NO;

// call trash when adding object multiple of non 0 trashLimit
static unsigned	trashLimit = 0;

// really send release to objects in pools
BOOL __autoreleaseEnableRelease = YES;

// checks at add time if object is too many times in autorelease pools
BOOL __autoreleaseEnableCheck   = NO;
BOOL __autoreleaseEnableWarning = YES;

/* 
 * Instance initialization 
 */

+ (void)taskNowMultiThreaded:notification
{
    NSThread* thread = [NSThread currentThread];
    PrivateThreadData* threadData = [thread _privateThreadData];
    NSAutoreleasePool* pool;
    
    for (pool = defaultPool; pool; pool = pool->parentPool)
	pool->ownerThread = thread;
    
    [threadData setThreadDefaultAutoreleasePool:defaultPool];
    defaultPool = nil;
    isMultithreaded = YES;
}

- (id)init
{
    if (isMultithreaded) {
	PrivateThreadData* threadData;

	ownerThread = [NSThread currentThread];
	threadData = [ownerThread _privateThreadData];
	parentPool = [threadData threadDefaultAutoreleasePool];
	[threadData setThreadDefaultAutoreleasePool:self];
    }
    else {
	parentPool = defaultPool;
	defaultPool = self;
	ownerThread = nil;
    }
    countOfObjects = 0;
    firstChunk = currentChunk = NULL;
    return self;
}

/* 
 * Instance deallocation 
 */

- (void)dealloc
{
    int i;
    NSAutoreleasePoolChunk *ch;
    NSAutoreleasePool      *pool;
    PrivateThreadData      *threadData = nil;
    
    // What happens if someone pushes a pool in release ?
    // One idea would be to add a pool in its parent and
    // to extract if on deallocation but this would be inefficient
    // Another would be to check again to release child pools after
    // releasing all the objects in current pool
    
    // first release from top of autorelease stack to self
    while (YES) {
	if (isMultithreaded) {
	    if (ownerThread != [NSThread currentThread]) {
		[[[InvalidUseOfMethodException alloc] initWithFormat:
		    @"cannot release a NSAutoreleasePool in a different "
		    @"thread than that it was initialized in"] raise];
	    }
	    threadData = [ownerThread _privateThreadData];
	    pool = [threadData threadDefaultAutoreleasePool];
	}
	else
	    pool = defaultPool;
	
	if (pool != self) {
#if LOG_RELEASE_COUNT
	    NSLog(@"auto release child pool 0x%p ..", pool);
#endif
	    RELEASE(pool);
	    continue;
	}
	else
	    break;
    }
    
    // send release to objects in pool
    if (__autoreleaseEnableRelease)
    {
	register SEL   sel       = @selector(release);
	register Class lastClass = Nil;
	register IMP   release   = NULL;
#if LOG_RELEASE
	FILE *fh;
	fh = fopen("/temp/autorelease.log", "a+");
#endif
	
	for (ch = firstChunk, i = 0; ch; ch = ch->next)
	    i += ch->used;
#if LOG_RELEASE
	fprintf(fh, "releasing %i objects\n", i);
#endif
#if LOG_RELEASE_COUNT
	printf("releasing %i objects\n", i);
#endif
	
	// first empty the pools (this may add new pools)
	for (ch = firstChunk; ch; ch = ch->next) {
	    for (i = 0; i < ch->used; i++) {
		// warning: this may add objects in current pool
		// what happens if someone pushes a pool ?
		// one idea would be to add a pool in its parent and
		// to extract if on deallocation but this would be inefficient
		register id    obj;
		register Class oc;
		
		obj = ch->objects[i];
		if (obj == NULL) continue;
		oc  = *(Class *)obj;
		ch->objects[i] = NULL;

#if LOG_RELEASE
		fprintf(fh, "%-30s 0x%p %2i - ",
			oc->name, obj, [obj retainCount]);
#endif
		
		if (lastClass != oc) {
		    lastClass = oc;
		    release = objc_msg_lookup(obj, sel);
#if LOG_RELEASE
		    fprintf(fh, "cache miss");
#endif
        	}
#if LOG_RELEASE
		else
		    fprintf(fh, "cache hit");
#endif
#if LOG_RELEASE
#if 0
		if ([obj isKindOfClass:[NSString class]]) {
		    char buf[202];

		    [obj getCString:buf maxLength:200];
		    buf[200] = '\0';
		    fprintf(fh, "%i '%s'", [obj cStringLength], buf);
		}
#endif
		fprintf(fh, "\n");
#endif
		
		release(obj, sel);
	    }
	}
#if LOG_RELEASE
	fclose(fh);
#endif
	// now pools are invalid an we should free them 
	// should we maintain a cache of allocated pools ?
	for (ch = firstChunk; ch;)
	{
	    NSAutoreleasePoolChunk* tmp = ch->next;
	    lfFree(ch);
	    ch = tmp;
	}
    }
    
    // set default pool
    if (isMultithreaded) {
	if (!threadData)
	    threadData = [ownerThread _privateThreadData];
	[threadData setThreadDefaultAutoreleasePool:parentPool];
    }
    else
	defaultPool = parentPool;
    
    [super dealloc];
}

/* 
 * Notes that aObject should be released when the pool 
 * at the current top of the stack is freed 
 * This is called by NSObject -autorelease.
 */


/* 
 * Notes that aObject must be released when pool is freed 
 */

inline void NSAutoreleasePool_AddObject(NSAutoreleasePool *self, id aObject)
{
    // try to add in current chunk and alloc new chunk if neceessary
    if (!self->firstChunk ||
        (self->currentChunk->used >= self->currentChunk->size))
    {
	NSAutoreleasePoolChunk* ch;
	
	ch = Calloc(sizeof(NSAutoreleasePoolChunk)+CHUNK_SIZE*sizeof(id*), 1);
	ch->size = CHUNK_SIZE;
	ch->used = 0;
	ch->next = NULL;
	
	if (!self->firstChunk)
	    self->firstChunk = self->currentChunk = ch;
	else {
	    self->currentChunk->next = ch, self->currentChunk = ch;
        }
    }
    // add in currentChunk
    self->currentChunk->objects[(self->currentChunk->used)++] = aObject;
    self->countOfObjects++;
    
    // check threshold
    if (trashLimit) {
	if (self->countOfObjects % trashLimit == 0) 
	    [self trash];
    }
}
inline void NSAutoreleasePool_AutoreleaseObject(id aObject)
{
    NSAutoreleasePool *pool;
    
    pool = isMultithreaded
	? [[[NSThread currentThread] _privateThreadData]
                      threadDefaultAutoreleasePool]
	: defaultPool;
    
#if 0
    // check if there is a pool in effect
    if (pool == nil && __autoreleaseEnableWarning) {
	fprintf(stderr, 
	    "Autorelease[0x%08x] with no pool in effect\n", 
	    (int)aObject);
    }
#endif
    
    // check if retainCount is Ok
    if (__autoreleaseEnableCheck) {
	unsigned int toCome =
            [[NSAutoreleasePool class] autoreleaseCountForObject:aObject];
        
	if (toCome+1 > [aObject retainCount]) {
	    fprintf(stderr, 
                    "Autorelease[%p<%s>] release check for object %s has %d "
                    "references and %d pending calls to "
                    "release in autorelease\n", 
                    aObject, [NSStringFromClass([aObject class]) cString],
                    [[aObject description] cString],
                    [aObject retainCount], toCome);
	    return;
	}
    }
    if (pool)
        NSAutoreleasePool_AddObject(pool, aObject);
    else {
        fprintf(stderr,
                "called -autorelease on object 0x%p<%s> with no "
                "autorelease pool in place, "
                "will leak that memory !\n",
                aObject,
                (*(struct objc_class **)aObject)->name);
    }
}

- (void)addObject:(id)aObject
{
    NSAutoreleasePool_AddObject(self, aObject);
}

+ (void)addObject:(id)aObject
{
    NSAutoreleasePool_AutoreleaseObject(aObject);
}

/* 
 * Default pool 
 */

+ (id)defaultPool
{
    return (isMultithreaded 
	? [[[NSThread currentThread] _privateThreadData]
	    threadDefaultAutoreleasePool]
	: defaultPool);
}

/*
 * METHODS FOR DEBUGGING
 */

/* 
 * Counts how many times aObject willl receive -release due to all 
 * NSAutoreleasePools 
 */

+ (unsigned)autoreleaseCountForObject:(id)aObject
{
    int count = 0;
    NSAutoreleasePool *pool;
    for (pool = [self defaultPool]; pool; pool = pool->parentPool) {
	count += [pool autoreleaseCountForObject:aObject];
    }
    return count;
}

/* 
 * Counts how many times aObject willl receive -release due to this pool  
 */

- (unsigned)autoreleaseCountForObject:(id)anObject
{
    int i, count = 0;
    NSAutoreleasePoolChunk*	ch;

    for (ch = firstChunk; ch; ch = ch->next)
	for (i = 0; i < ch->used; i++)
	    if (ch->objects[i] == anObject)
		count++;
    return count;
}

/*
 * Counts how many autorelease calls are made in thise pool
 */
- (unsigned)autoreleaseCount
{
    int i, count = 0;
    NSAutoreleasePoolChunk*	ch;

    for (ch = firstChunk; ch; ch = ch->next)
	for (i = 0; i < ch->used; i++)
	    if (ch->objects[i])
		count++;
    return count;
}

/* 
 * When enabled, -release and -autorelease calls are checking whether 
 * this object has been released too many times. This is done by searching 
 * all the pools, and makes programs run very slowly; 
 * It is off by default 
 */

+ (void)enableDoubleReleaseCheck:(BOOL)enable
{
    __autoreleaseEnableCheck = enable;
}

/* 
 * When disabled, nothing added to pools is really released; 
 * By default is enabled 
 */

+ (void)enableRelease:(BOOL)enable
{
    __autoreleaseEnableRelease = enable;
}

/* 
 * When enables call -trash on add if countToBeReleased % trashLimit = 0 
 */

+ (void)setPoolCountThreshhold:(unsigned int)trash
{
    trashLimit = trash;
}

/* 
 * Called on exceding trashLimit 
 */

- (id)trash
{
    return self;
}

@end /* NSAutoreleasePool */

/*
 * Class that handles C pointers realease sending them Free()
 */

@implementation NSAutoreleasedPointer

// THREADING
#define AP_CACHE_SIZE 64
static NSAutoreleasedPointer *ptrcache[AP_CACHE_SIZE] = {
    nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil,
    nil, nil, nil, nil, nil, nil, nil, nil,
};

+ (id)autoreleasePointer:(void*)address
{
    NSAutoreleasedPointer *tmp;
    register int i;

    /* first look in cache */
    for (i = 0, tmp = nil; (i < AP_CACHE_SIZE) && (tmp == nil); i++) {
        if (ptrcache[i] != nil) {
            tmp = ptrcache[i];
            ptrcache[i] = nil;
        }
    }
    
    /* did not find instance in cache */
    if (tmp == nil) {
        tmp = [self alloc];
    }

    [tmp initWithAddress:address];
    
    return AUTORELEASE(tmp);
}

- (id)initWithAddress:(void*)address
{
    self->theAddress = address;
    return self;
}

- (void)dealloc
{
    register int i;
    lfFree(self->theAddress);
    
    /* place in cache if slot is available */
    for (i = 0; i < AP_CACHE_SIZE; i++) {
        if (ptrcache[i] == nil) {
            ptrcache[i] = self;
            return;
        }
    }
    
    /* cache is full, dealloc */
    [super dealloc];
}

@end /* NSAutoreleasedPointer */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
