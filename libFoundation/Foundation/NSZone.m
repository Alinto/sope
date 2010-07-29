/* 
   NSZone.m

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

#include <Foundation/common.h>

#if HAVE_STDLIB_H
# include <stdlib.h>
#endif

#if HAVE_LIBC_H
# include <libc.h>
#else
# include <unistd.h>
#endif

#include "lfmemory.h"

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSUtilities.h>

#include <extensions/NSException.h>
#include <extensions/objc-runtime.h>

#include <Foundation/NSDefaultZone.h>
#include <Foundation/NSAllocDebugZone.h>

static id defaultZone = nil;

NSZone *_lfDefaultZone(void)
{
    return defaultZone;
}

#if LIB_FOUNDATION_BOEHM_GC
LF_DECLARE NSString *_gcDefaultZoneName = @"Default garbage collector zone";
#endif

/* The NSZone class keeps a linked list of zones. The default zone should be
   the last zone in this list because the implementation of NSDefaultZone
   implements the -pointerInZone: method to return YES no matter what is the
   value of its argument. This because we cannot assume anything about how the
   system malloc library, especially if it has a function that tells us if
   a pointer was allocated using malloc(). */

typedef struct ZoneListNode {
    struct ZoneListNode* next;
    NSZone* zone;
} ZoneListNode;

static ZoneListNode* zones = NULL;

/* Remove the zone node from the zones list and return the node. */
static ZoneListNode* removeZoneFromList (NSZone* aZone)
{
    if (!zones)
	return NULL;

    /* Try to see if the zone is the first one in list. */
    if (zones->zone == aZone) {
	ZoneListNode* node = zones;
	zones = zones->next;
	node->next = NULL;
	return node;
    }
    else {
	ZoneListNode* prev = zones;
	ZoneListNode* curr = zones->next;

	/* Iterate on the zones list until we find the zone */
	while (curr && curr->zone != aZone) {
	    prev = curr;
	    curr = curr->next;
	}

	/* curr should not be NULL, but who knows... */
	NSCAssert1(curr, @"curr zone node ptr is NULL (prev=0x%p)", prev);

	prev->next = curr->next;
	curr->next = NULL;
	return curr;
    }
}

@implementation NSZone

#if !LIB_FOUNDATION_BOEHM_GC
+ (void)initialize
{
    static BOOL initialized = NO;

    if(!initialized) {
	initialized = YES;
	// alloc is redefined in NSDefaultZone to return memory for this
	// class from malloc; this is because alloc in NSObject calls
	// NSAllocateObject(class, 0, defaultZone) and defaultZone is 
	// uninitialized yet
	// So for zones we have special allocation method allocZoneInstance
	// and we redefine all refcounting methods and keep an ivar refCount

        {
            char* str = getenv("ALLOCDEBUG");

            if (str && *str)
                defaultZone = [[NSAllocDebugZone alloc] init];
            else
                defaultZone = [[NSDefaultZone alloc] init];
        }
    }
}
#endif

+ (id)alloc
{
    return defaultZone;
}

+ (id)allocWithZone:(NSZone*)zone
{
    return defaultZone;
}

+ (void)setDefaultZone:(NSZone*)zone
{
    ZoneListNode *node, *zoneNode;

    defaultZone = zone;

    /* Remove the zone from the list of zones */
    zoneNode = removeZoneFromList (zone);

    /* Setup the new zone to be the last zone in the list of zones */
    if (!zones)
	zones = zoneNode;
    else {
	for (node = zones; node->next; node = node->next)
	    /* nothing */;
	node->next = zoneNode;
    }
}

+ (NSZone *)defaultZone
{
    return defaultZone;
}

+ (NSZone*)zoneFromPointer:(void*)pointer
{
    ZoneListNode* node = zones;

    while(node && ![node->zone pointerInZone:pointer])
	node = node->next;

    if (node)
	return node->zone;

    return defaultZone;
}

+ (BOOL)checkZone
{
    return [defaultZone checkZone];
}

- (id)initForSize:(unsigned)startSize granularity:(unsigned)granularity
    canFree:(BOOL)canFree
{
    [self subclassResponsibility:_cmd];
    return self;
}

- (void*)malloc:(unsigned)size
{
    [self subclassResponsibility:_cmd];
    return NULL;
}

- (void*)mallocAtomic:(unsigned)size
{
  return [self malloc:size];
}

- (void*)calloc:(unsigned)numElems byteSize:(unsigned)byteSize
{
    [self subclassResponsibility:_cmd];
    return NULL;
}

- (void*)callocAtomic:(unsigned)numElems byteSize:(unsigned)byteSize
{
  return [self calloc:numElems byteSize:byteSize];
}

- (void*)realloc:(void*)pointer size:(unsigned)size
{
    [self subclassResponsibility:_cmd];
    return NULL;
}

- (void)recycle
{
    [self subclassResponsibility:_cmd];
}

- (BOOL)pointerInZone:(void*)pointer
{
    [self subclassResponsibility:_cmd];
    return NO;
}

- (void)freePointer:(void*)pointer
{
    [self subclassResponsibility:_cmd];
}

- (void)setName:(NSString*)newName
{
    ASSIGN(name, newName);
}

- (NSString*)name
{
    return name;
}

- (BOOL)checkZone
{
    return YES;
}

/* Refcounting is special to NSZone */

+ (id)allocZoneInstance
{
    struct myzone {
	@defs(NSZone);
    }*	theZone;
    Class class = (Class)self;
    ZoneListNode* node;

    theZone = objc_calloc(1, class->instance_size);
    
    theZone->isa = self;
    theZone->refCount = 1;

    /* Enter this zone into the zones list */
    node = objc_malloc(sizeof(ZoneListNode));
    node->next = zones;
    node->zone = (NSZone*)theZone;
    zones = node;

    return (id)theZone;
}

- autorelease
{
#if !LIB_FOUNDATION_BOEHM_GC
    [NSAutoreleasePool addObject:self];
#endif
    return self;
}

- (void)dealloc
{
    /* Remove the zone node from the zones list. */
    ZoneListNode* node = removeZoneFromList (self);

    /* If the zone is the default zone setup a new default zone */
    if (defaultZone == self) {
	ZoneListNode* listNode = zones;

	NSAssert (zones, @"at least one zone should be available");

	/* Find out the last zone */
	while (listNode->next)
	    listNode = listNode->next;
	defaultZone = listNode->zone;
    }

    objc_free(node);
    objc_free(self);
    
    /* this is to please gcc 4.1 which otherwise issues a warning (and we
       don't know the -W option to disable it, let me know if you do ;-)*/
    if (0) [super dealloc];
}

- (oneway void)release
{
#if !LIB_FOUNDATION_BOEHM_GC
    if (!refCount || !--refCount)
	[self dealloc];
#endif
}

#if LIB_FOUNDATION_BOEHM_GC
- (void)gcFinalize
{
    [self dealloc];
}
#endif

- (id)retain
{
#if !LIB_FOUNDATION_BOEHM_GC
    refCount++;
#endif
    return self;
}

- (unsigned int)retainCount
{
    return refCount;
}

@end /* NSZone */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

