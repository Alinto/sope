/* 
   GCObject.m

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

#include <config.h>

#include <stdio.h>

#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSUtilities.h>

#include <extensions/GCObject.h>
#include <extensions/GarbageCollector.h>
#include <extensions/objc-runtime.h>


@implementation GCObject

+ allocWithZone:(NSZone*)zone
{
    id newObject = [super allocWithZone:zone];
    [GarbageCollector addObject:newObject];
    ((GCObject*)newObject)->gcFlags.refCount = 1;
    return newObject;
}

- copyWithZone:(NSZone*)zone
{
    id newObject = NSCopyObject(self, 0, zone);
    [GarbageCollector addObject:newObject];
    ((GCObject*)newObject)->gcFlags.refCount = 1;
    return newObject;
}

- (oneway void)release
{
#if LIB_FOUNDATION_VERSION
    extern BOOL __autoreleaseEnableCheck;

    // check if retainCount is Ok
    if (__autoreleaseEnableCheck) {
	int toCome = [NSAutoreleasePool autoreleaseCountForObject:self];
	if (toCome && toCome + 1 > [self retainCount]) {
	    NSLog(@"Release[%p] release check for object %@ "
                  @"has %d references and %d pending calls to "
                  @"release in autorelease pools\n", 
		  self, self, [self retainCount], toCome);
	    return;
	}
    }
#endif /* LIB_FOUNDATION_VERSION */

    if(gcFlags.refCount > 0 && --gcFlags.refCount == 0) {
	[GarbageCollector objectWillBeDeallocated:self];
	[self dealloc];
    }
}

- retain
{
    gcFlags.refCount++;
    return self;
}

- (unsigned int)retainCount
{
    return gcFlags.refCount;
}

- gcSetNextObject:(id)anObject
{
    gcNextObject = anObject;
    return self;
}

- gcSetPreviousObject:(id)anObject
{
    gcPreviousObject = anObject;
    return self;
}

- (id)gcNextObject		{ return gcNextObject; }
- (id)gcPreviousObject		{ return gcPreviousObject; }

- (BOOL)gcAlreadyVisited
{
    return gcFlags.gcVisited;
}

- (void)gcSetVisited:(BOOL)flag
{
    gcFlags.gcVisited = flag;
}

- (void)gcDecrementRefCountOfContainedObjects
{
}

- (BOOL)gcIncrementRefCountOfContainedObjects
{
    if(gcFlags.gcVisited)
	return NO;
    gcFlags.gcVisited = YES;
    return YES;
}

- (BOOL)isGarbageCollectable
{
    return YES;
}

- (void)gcIncrementRefCount
{
   gcFlags.refCount++;
}

- (void)gcDecrementRefCount
{
   gcFlags.refCount--;
}

+ error:(const char *)aString, ...
{
    va_list ap;

    va_start(ap, aString);
    vfprintf(stderr, aString, ap);
    va_end(ap);
    return self;
}

- doesNotRecognize:(SEL)aSelector
{
    return [isa error:"%s does not recognize selector %s\n",
	    object_get_class_name(self),
	    sel_get_name(aSelector)];
}

@end /* GCObject */

@implementation NSObject (GarbageCollecting)

- (BOOL)isGarbageCollectable
{
    return NO;
}

@end /* NSObject (GarbageCollecting) */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

