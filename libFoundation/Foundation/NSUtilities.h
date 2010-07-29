/* 
   NSUtilities.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Mircea Oancea <mircea@jupiter.elcom.pub.ro>
	   Florin Mihaila <phil@pathcom.com>
	   Bogdan Baliuc <stark@protv.ro>

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

#ifndef __NSUtilities_h__
#define __NSUtilities_h__

#include <Foundation/NSObject.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSHashTable.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSEnumerator.h>

#include <objc/objc.h>
#include <stdarg.h>

@class NSObject;
@class NSString;
@class NSZone;
@class NSArray;

/*
 * Virtual Memory Management 
 */

/* Get the Virtual Memory Page Size */
LF_EXPORT unsigned NSPageSize(void);
LF_EXPORT unsigned NSLogPageSize(void);
LF_EXPORT unsigned NSRoundDownToMultipleOfPageSize(unsigned byteCount);
LF_EXPORT unsigned NSRoundUpToMultipleOfPageSize(unsigned byteCount);

/* Allocate or Free Virtual Memory */
LF_EXPORT void* NSAllocateMemoryPages(unsigned byteCount);
LF_EXPORT void NSDeallocateMemoryPages(void* pointer, unsigned byteCount);
LF_EXPORT void NSCopyMemoryPages(const void* source, void* destination, unsigned byteCount);

/*
 * Allocate or Free an Object
 */

LF_EXPORT NSObject* NSAllocateObject(Class aClass, unsigned extraBytes, NSZone* zone);
LF_EXPORT NSObject* NSCopyObject(NSObject* anObject, unsigned extraBytes, NSZone* zone);
LF_EXPORT void NSDeallocateObject(NSObject* anObject);
LF_EXPORT NSZone* NSZoneFromObject(NSObject* anObject);
LF_EXPORT BOOL NSShouldRetainWithZone(NSObject* anObject, NSZone* requestedZone);

/*
 * Message log on console/stderr
 */

LF_EXPORT void NSLog(NSString* format, ...);
LF_EXPORT void NSLogv(NSString* format, va_list args);

/*
 * Manipulate the Number of References to an Object
 */

LF_EXPORT BOOL NSDecrementExtraRefCountWasZero(id anObject);
LF_EXPORT void NSIncrementExtraRefCount(id anObject);
LF_EXPORT unsigned NSExtraRefCount(id anObject);

/*
 * Convenience functions to deal with Hash and Map Table
 */

LF_EXPORT unsigned __NSHashObject(void* table, const void* anObject);
LF_EXPORT unsigned __NSHashPointer(void* table, const void* anObject);
LF_EXPORT unsigned __NSHashInteger(void* table, const void* anObject);
LF_EXPORT unsigned __NSHashCString(void* table, const void* anObject);
LF_EXPORT BOOL __NSCompareObjects(void* table, 
	const void* anObject1, const void* anObject2);
LF_EXPORT BOOL __NSComparePointers(void* table, 
	const void* anObject1, const void* anObject2);
LF_EXPORT BOOL __NSCompareInts(void* table, 
	const void* anObject1, const void* anObject2);
LF_EXPORT BOOL __NSCompareCString(void* table, 
	const void* anObject1, const void* anObject2);
LF_EXPORT void __NSRetainNothing(void* table, const void* anObject);
LF_EXPORT void __NSRetainObjects(void* table, const void* anObject);
LF_EXPORT void __NSReleaseNothing(void* table, void* anObject);
LF_EXPORT void __NSReleaseObjects(void* table, void* anObject);
LF_EXPORT void __NSReleasePointers(void* table, void* anObject);
LF_EXPORT NSString* __NSDescribeObjects(void* table, const void* anObject);
LF_EXPORT NSString* __NSDescribePointers(void* table, const void* anObject);
LF_EXPORT NSString* __NSDescribeInts(void* table, const void* anObject);

/* Some allocation macros */
#define OBJC_MALLOC(pointer, type, elements) \
	(pointer = calloc (sizeof(type), elements))

#define OBJC_FREE(pointer) \
	if (pointer) free(pointer)

#endif /* __NSUtilities_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
