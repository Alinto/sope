/* 
   NSZone.h

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

#ifndef __NSZone_h__
#define __NSZone_h__

#include <Foundation/NSObject.h>

@class NSString;

#if (__GNUC__ == 2) && (__GNUC_MINOR__ <= 6) && !defined(__attribute__)
#  define __attribute__(x)
#endif

@interface NSZone : NSObject
{
    unsigned	refCount;
    NSString	*name;
}

+ (void)setDefaultZone:(NSZone*)zone;
+ (NSZone*)defaultZone;

+ (NSZone*)zoneFromPointer:(void*)pointer;
+ (BOOL)checkZone;
+ (id)allocZoneInstance;

- initForSize:(unsigned)startSize granularity:(unsigned)granularity
	canFree:(BOOL)canFree;
- (void*)malloc:(unsigned)size;
- (void*)mallocAtomic:(unsigned)size;
- (void*)calloc:(unsigned)numElems byteSize:(unsigned)byteSize;
- (void*)callocAtomic:(unsigned)numElems byteSize:(unsigned)byteSize;
- (void*)realloc:(void*)pointer size:(unsigned)size;
- (void)recycle;
- (BOOL)pointerInZone:(void*)pointer;
- (void)freePointer:(void*)pointer;
- (void)setName:(NSString*)name;
- (NSString*)name;
- (BOOL)checkZone;
@end

/* OpenStep functions. The NSAtomic* functions are useful only when
   libFoundation is compiled with support for Boehm's garbage collector;
   otherwise they are equivalent with the normal functions. */

static inline NSZone *NSCreateZone(unsigned, unsigned, BOOL)
    __attribute__((unused));

static inline NSZone *NSDefaultMallocZone(void) __attribute__((unused));

static inline NSZone *NSZoneFromPointer(void *) __attribute__((unused));

static inline void *NSZoneMalloc(NSZone*, unsigned) __attribute__((unused));
static inline void *NSZoneMallocAtomic(NSZone*, unsigned)
	__attribute__((unused));

static inline void *NSZoneCalloc(NSZone*, unsigned, unsigned)
    __attribute__((unused));
static inline void *NSZoneCallocAtomic(NSZone*, unsigned, unsigned)
    __attribute__((unused));

static inline void *NSZoneRealloc(NSZone*, void*, unsigned)
    __attribute__((unused));

static inline void NSRecycleZone(NSZone*) __attribute__((unused));
static inline void NSZoneFree(NSZone*, void*) __attribute__((unused));
static inline void NSSetZoneName(NSZone*, NSString*) __attribute__((unused));
static inline NSString *NSZoneName(NSZone*) __attribute__((unused));

extern Class lfNSZoneClass; /* cache NSZone class (in NSObject) */

#if !(LIB_FOUNDATION_BOEHM_GC)

LF_EXPORT NSZone *_lfDefaultZone(void);

static inline
NSZone *NSCreateZone(unsigned startSize, unsigned granularity, BOOL canFree)
{
    return [[lfNSZoneClass alloc] initForSize:startSize
			    granularity:granularity canFree:canFree];
}

static inline
NSZone *NSDefaultMallocZone(void)
{
    return [lfNSZoneClass defaultZone];
}

static inline
NSZone *NSZoneFromPointer(void *pointer)
{
    return [lfNSZoneClass zoneFromPointer:pointer];
}

static inline
void *NSZoneMalloc(NSZone *zone, unsigned size)
{
    return zone
        ? [zone malloc:size] 
        : [_lfDefaultZone() malloc:size];
}

static inline
void *NSZoneMallocAtomic(NSZone *zone, unsigned size)
{
    return zone
        ? [zone mallocAtomic:size] 
        : [_lfDefaultZone() mallocAtomic:size];
}

static inline
void *NSZoneCalloc(NSZone *zone, unsigned numElems, unsigned byteSize)
{
    return zone
        ? [zone calloc:numElems byteSize:byteSize]
        : [_lfDefaultZone() calloc:numElems byteSize:byteSize];

}

static inline
void *NSZoneCallocAtomic(NSZone *zone, unsigned numElems, unsigned byteSize)
{
    return zone
        ? [zone callocAtomic:numElems byteSize:byteSize]
        : [_lfDefaultZone() callocAtomic:numElems byteSize:byteSize];

}

static inline
void *NSZoneRealloc(NSZone *zone, void *pointer, unsigned size)
{
    return zone
        ? [zone realloc:pointer size:size]
        : [_lfDefaultZone() realloc:pointer size:size];
}

static inline
void NSRecycleZone(NSZone *zone)
{
    zone ? [zone recycle] : [_lfDefaultZone() recycle];
}

static inline
void NSZoneFree(NSZone *zone, void *pointer)
{
    zone ? [zone freePointer:pointer]
        : [_lfDefaultZone() freePointer:pointer];
}

static inline
void NSSetZoneName(NSZone *zone, NSString *name)
{
    zone ? [zone setName:name]  : [_lfDefaultZone() setName:name];
}

static inline
NSString *NSZoneName(NSZone *zone)
{
    return zone ? [zone name] : [_lfDefaultZone() name];
}

#else /* LIB_FOUNDATION_BOEHM_GC */

/* When working with Boehm's garbage collector there are no zones
   involved. */

void __raiseMemoryException (void* pointer, int size);

static inline
NSZone *NSCreateZone(unsigned startSize, unsigned granularity, BOOL canFree)
{
    return nil;
}

static inline
NSZone *NSDefaultMallocZone(void)
{
    return nil;
}

static inline
NSZone *NSZoneFromPointer(void *pointer)
{
    return nil;
}

static inline
void *NSZoneMalloc(NSZone *zone, unsigned size)
{
    void* p = (void *)GC_MALLOC (size);
    if (!p)
        __raiseMemoryException (&p, size);
    return p;
}

static inline
void *NSZoneMallocAtomic(NSZone *zone, unsigned size)
{
    void* p = (void*)GC_MALLOC_ATOMIC (size);
    if(!p)
        __raiseMemoryException (&p, size);
    return p;
}

static inline
void *NSZoneCalloc(NSZone *zone, unsigned numElems, unsigned byteSize)
{
    int howMuch = numElems * byteSize;
    void* p = (void*)GC_MALLOC (howMuch);

    if(!p)
        __raiseMemoryException (&p, howMuch);
    memset (p, 0, howMuch);
    return p;
}

static inline
void *NSZoneCallocAtomic(NSZone *zone, unsigned numElems, unsigned byteSize)
{
    int howMuch = numElems * byteSize;
    void* p = (void*)GC_MALLOC_ATOMIC (howMuch);

    if(!p)
        __raiseMemoryException (&p, howMuch);
    memset (p, 0, howMuch);
    return p;
}

static inline
void *NSZoneRealloc(NSZone *zone, void *pointer, unsigned size)
{
    void* new_p = GC_REALLOC (pointer, size);

    if(!new_p)
        __raiseMemoryException (&new_p, size);
    return new_p;
}

static inline
void NSRecycleZone(NSZone *zone)
{}

static inline
void NSZoneFree(NSZone *zone, void *pointer)
{
#if 0
    if (pointer) {
        fprintf(stderr, "%s: EXPLICIT FREE !!\n", __PRETTY_FUNCTION__);
        GC_FREE(pointer);
    }
#endif
    pointer = NULL;
}

static inline
void NSSetZoneName(NSZone *zone, NSString *name)
{}

static inline
NSString *NSZoneName(NSZone *zone)
{
    LF_EXPORT NSString* _gcDefaultZoneName;

    return _gcDefaultZoneName;
}

#endif /* LIB_FOUNDATION_BOEHM_GC */


#endif /* __NSZone_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
