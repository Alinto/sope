/* 
   NSAllocDebugZone.m

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

#include <config.h>

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

#if HAVE_STDLIB_H
# include <stdlib.h>
#else
extern void* malloc();
extern void* calloc();
extern void* realloc();
extern void free();
extern atoi();
extern atol();
#endif

#ifdef HAVE_LIBC_H
#include <libc.h>
#else
#include <unistd.h>
#endif
#include <signal.h>
#include <stdarg.h>

#if HAVE_PROCESS_H
#include <process.h>
#endif

#include <extensions/objc-runtime.h>

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAllocDebugZone.h>

static void  initDebugger();
static void* debugMalloc(unsigned size);
static void* debugCalloc(unsigned elem, unsigned size);
static void* debugRealloc(void* p, unsigned size);
static void  debugFree(void* p);
static BOOL  doConsistencyCheck();
static BOOL  pointerInZone(void* p);

@implementation NSAllocDebugZone

+ (id)alloc
{
    return [self allocZoneInstance];
}

- (id)init
{
    return [self initForSize:0 granularity:0 canFree:YES];
}

- (id)initForSize:(unsigned)startSize granularity:(unsigned)granularity
    canFree:(BOOL)canFree
{
    name = @"Alloc Debug zone";
    initDebugger(); 
    return self;
}

- (void*)malloc:(unsigned)size
{
    return debugMalloc(size);
}

- (void*)calloc:(unsigned)count byteSize:(unsigned)size
{
    return debugCalloc(count, size);
}

- (void*)realloc:(void*)p size:(unsigned)size
{
    return debugRealloc(p, size);
}

- (void)freePointer:(void*)p
{
    debugFree(p);
}

- (void)recycle
{
}

- (BOOL)checkZone
{
    return doConsistencyCheck();
}

- (BOOL)pointerInZone:(void*)pointer
{
    return pointerInZone(pointer);
}

@end /* NSAllocDebugZone */

/* 
 * Alloc-debug internals 
 */
 
#ifdef NeXT
#define SYSEM_MALLOC_CHECK() NXMallocCheck()
#else
#define SYSEM_MALLOC_CHECK()
#endif

#define HASHSIZE 25013

#define MOVEPTR(p,s) ((void*)((unsigned long)(p)+(s)))
#define PTRSIZE(s) ((s)+upperHeader+lowerHeader)
#define USER2REAL(p) MOVEPTR(p,-upperHeader)
#define REAL2USER(p) MOVEPTR(p,+upperHeader)
#define HOLD2REAL(p) MOVEPTR(p,-1)
#define REAL2HOLD(p) MOVEPTR(p,+1)
#define USER2HOLD(p) MOVEPTR(p,-upperHeader+1)
#define HOLD2USER(p) MOVEPTR(p,+upperHeader-1)

typedef struct _AllocDebugRecord {
	void*	pointer;	/* The Pointer */
	int	size;		/* The Pointer allocated size */
	unsigned	mark;		/* Index of allocation */
	struct _AllocDebugRecord *next;	/* Next entry in list */
} AllocDebugRecord;

static unsigned	allocationMark;		/* allocation counter */
static unsigned	allocationStop;		/* where to stop in allocator */
static unsigned	allocationSignal;	/* whether to stop in allocator */
	
static AllocDebugRecord	**nodesTable;	/* pointers hashtable */
static unsigned	nodesSize;		/* pointers hashtable size */
static unsigned	nodesCount;		/* pointers in hashtable */
	
static unsigned	secureCheckCount;	/* calls to secure check */
static unsigned	secureCheckTime;	/* number of calls to check */
	
static unsigned	upperHeader;		/* used for consistency check */
static unsigned	lowerHeader;		/* used for consistency check */

static void stopProgram();
static void error(BOOL isWarning, char* format, ...);
static void consistencyCheck();
static void setMarkers(AllocDebugRecord* info);
static BOOL checkMarkers(AllocDebugRecord* info);
static void addHash(AllocDebugRecord* info);
static void removeHash(AllocDebugRecord* info);
static AllocDebugRecord* searchHash(void* p);
static AllocDebugRecord* newInfo(void* p, unsigned size);
static void freeInfo(AllocDebugRecord* info);

/*
 * Internal functions
 */

static void initDebugger()
{
    char* str;

    nodesTable = objc_calloc(HASHSIZE, sizeof(AllocDebugRecord*));
    nodesSize = HASHSIZE;
    nodesCount = 0;
    allocationMark = 1;

    str = getenv("ALLOCDEBUG_MARK");
    allocationStop = str ? atoi(str) : 0;

    str = getenv("ALLOCDEBUG_STOP");
    allocationSignal = str ? atoi(str) : 0;

    str = getenv("ALLOCDEBUG_COUNT");
    secureCheckTime = secureCheckCount = str ? atoi(str) : 0;

    str = getenv("ALLOCDEBUG_UPPER");
    upperHeader = str ? atoi(str) : 0;
    str = getenv("ALLOCDEBUG_LOWER");
    lowerHeader = str ? atoi(str) : 0;
    
    fprintf(stderr, "AllocDebug[00000]:Stop at %d, Check time %d, "
	    "Upper header %d, Lower header %d\n", allocationStop,
	    secureCheckTime, upperHeader, lowerHeader);
}

static void* debugMalloc(unsigned size)
{
    void* p;
    AllocDebugRecord* info; 

    p = objc_malloc(PTRSIZE(size));
    memset(p, 1, PTRSIZE(size));
    info = newInfo(REAL2HOLD(p), size);
    info->mark = allocationMark++;
    setMarkers(info);
    addHash(info);
    consistencyCheck();
    return REAL2USER(p);
}

static void* debugCalloc(unsigned elem, unsigned size)
{
    void* p;
    AllocDebugRecord* info; 

    p = objc_malloc(PTRSIZE(size*elem));
    memset(p, 0, PTRSIZE(size*elem));
    info = newInfo(REAL2HOLD(p), size*elem);
    info->mark = allocationMark++;
    setMarkers(info);
    addHash(info);
    consistencyCheck();
    return REAL2USER(p);
}

static void* debugRealloc(void* p, unsigned size)
{
    AllocDebugRecord* info; 

    if (p)
	info = searchHash(USER2HOLD(p));
    else 
	    info = NULL;
    
    if (p && !info) {
	error( NO, "AllocDebug[%05d]: "
		"Attempt to realloc pointer %p not registered. "
		    "Will use realloc()\n", allocationMark, p);
	consistencyCheck();
	return objc_realloc(p, size);
    }
    
    if (info) {
	checkMarkers(info);
	removeHash(info);
	p = HOLD2REAL(info->pointer);
	p = objc_realloc(p,PTRSIZE(size));
    }
    else {
	p = objc_malloc(PTRSIZE(size));
	memset(p, 1, PTRSIZE(size));
    }
    
    info = newInfo(REAL2HOLD(p),size);
    info->mark = allocationMark++;
    setMarkers(info);
    addHash(info);
    consistencyCheck();
    return REAL2USER(p);
}

static void  debugFree(void* p)
{
    AllocDebugRecord* info; 

    if (!p)
	return;
    
    info = searchHash(USER2HOLD(p));
    if (!info) {
	error(NO, "AllocDebug[%05d]: "
		"Attempt to free unregistered pointer %p. "
		"Will not free anything.\n", allocationMark, p);
	return;
    }
    
    checkMarkers(info);
    removeHash(info);
    objc_free(HOLD2REAL(info->pointer));
    freeInfo(info);
    consistencyCheck();
}

static BOOL  pointerInZone(void* p)
{
    if (!p)
	return NO;
    
    return searchHash(USER2HOLD(p)) != NULL;
}

static void stopProgram()
{
#if HAVE_KILL
    kill(getpid(), SIGINT);
#elif HAVE_RAISE
    raise( SIGINT );
#else
#warning No kill and no raise
#endif
}

static void error(BOOL isWarning, char* format, ...)
{
    va_list va;
    
    va_start(va, format);
    vfprintf(stderr, format, va);
    va_end(va);
    
    if (isWarning)
	return;
    if (allocationSignal)
	stopProgram();
}

static void consistencyCheck()
{
    if (secureCheckTime && !--secureCheckCount) {
	doConsistencyCheck();
	secureCheckCount = secureCheckTime;
    }
}

static BOOL doConsistencyCheck()
{
    unsigned i;
    AllocDebugRecord* info;
    BOOL ok = YES;
    
    for(i=0; i<nodesSize; i++)
	for(info=nodesTable[i]; info; info=info->next)
	    ok = ok && checkMarkers(info);
    return ok;
}

static void setMarkers(AllocDebugRecord* info)
{
    char* p = (char*)HOLD2REAL(info->pointer);
    unsigned size = info->size;

    if (upperHeader) {
	memset(p, 0x88, upperHeader);
    }
    if (lowerHeader) {
	memset(p+upperHeader+size, 0x88, lowerHeader);
    }
}

static BOOL checkMarkers(AllocDebugRecord* info)
{
    char *q, *p = (char*)HOLD2REAL(info->pointer);
    unsigned size = info->size;
    BOOL ok = YES;

    if (upperHeader) {
	BOOL bad = NO;
	for (q=p; q<p+upperHeader; q++)
	    if (*q != (char)0x88)
		bad = YES;
	if (bad) {
	    error(NO, "AllocDebug[%05d]: "
		    "Upper marker for pointer %p is damaged\n",
		    info->mark, REAL2USER(p));
	    ok = NO;
	}
    }

    if (lowerHeader) {
	BOOL bad = NO;
	for (q=p+upperHeader+size; q<p+upperHeader+size+lowerHeader; q++)
	    if (*q != (char)0x88)
		bad = YES;
	if (bad) {
	    error(NO, "quit[%05d]: "
		    "Lower marker for pointer %p is damaged\n",
		    info->mark, REAL2USER(p));
	    ok = NO;
	}
    }
    return ok;
}

static void addHash(AllocDebugRecord* info)
{
    AllocDebugRecord *buck;
    void *ptr = info->pointer;
    unsigned long index = (unsigned long)(ptr) % nodesSize;
    
    /* first check if not present */
    for(buck=nodesTable[index]; buck; buck=buck->next) 
	if (buck->pointer == ptr) {
	    error(YES, "AllocDebug[%05d]: "
		    "Pointer %p was freed by free() directly before.\n",
		    allocationMark, HOLD2USER(ptr));
	    break;
	}

    /* insert */
    info->next=nodesTable[index];
    nodesTable[index]=info;
    nodesCount++;

    if (info->mark == allocationStop) {
	error(NO, "AllocDebug[%05d]: "
		"Stoped at requested mark, pointer.\n",
		allocationStop, HOLD2USER(ptr));
    }
}

static void removeHash(AllocDebugRecord* info)
{
    AllocDebugRecord *buck, *del;
    void *ptr = info->pointer;
    unsigned long index = (unsigned long)(ptr) % nodesSize;

    del = buck = nodesTable[index];
    if(buck == info) 
	    nodesTable[index] = buck->next;
    else 
	for( ; buck->next; buck=buck->next)
	    if (buck->next == info) {
		buck->next = buck->next->next;
		break;
	    }
    nodesCount--;
}

static AllocDebugRecord* searchHash(void* p)
{
    AllocDebugRecord *buck;
    void *ptr = p;
    unsigned index = (unsigned long)(ptr) % nodesSize;

    /* find it */
    for(buck=nodesTable[index]; buck; buck=buck->next)
	if (buck->pointer==ptr)
		return buck;
    return NULL;
}

static AllocDebugRecord* newInfo(void* p, unsigned size)
{
    AllocDebugRecord* info = objc_calloc(1, sizeof(AllocDebugRecord));
    
    info->pointer = p;
    info->size = size;

    return info;
}

static void freeInfo(AllocDebugRecord* info)
{
    objc_free(info);
}

/*
 * Public debugger functions
 */

void debuggerStopMark(unsigned mark)
{
    allocationStop = mark;
}

void debuggerCheckTime(unsigned count)
{
    secureCheckTime = count;
}

void debuggerCheckPointer(unsigned long ptr)
{
    AllocDebugRecord* info; 
    void *p = (void*)ptr;
    int sav = allocationSignal;
    allocationSignal = 0;
    
    if (!p)
	return;
    
    info = searchHash(USER2HOLD(p));
    if (!info) {
	error(NO, "AllocDebug[%05d]: "
		"Attempt to check unregistered pointer %p.\n", 
		allocationMark, p);
	return;
    }
    
    checkMarkers(info);
    allocationSignal = sav;
}

void debuggerDescription(id obj)
{
    NSString* desc = [obj description];
    fprintf(stderr, "Object %p description:\n%s\n", obj, [desc cString]);
}

void debuggerPerform(id obj, char* sel)
{
    SEL selector = sel_get_any_uid(sel);
    if (selector) 
	[obj performSelector:selector];
    else
	fprintf(stderr, "Object %p does not respond to '%s'\n", obj, sel);
}

void debuggerPerformWith(id obj, char* sel, id arg)
{
    SEL selector = sel_get_any_uid(sel);
    if (selector) 
	[obj performSelector:selector withObject:arg];
    else
	fprintf(stderr, "Object %p does not respond to '%s'\n", obj, sel);
}

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

