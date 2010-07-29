/* 
   NSDefaultZone.m

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

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include <extensions/objc-runtime.h>

#include "NSDefaultZone.h"

#if DEBUG
extern FILE *logAlloc;
#endif

@implementation NSDefaultZone

static inline void _memoryExhausted(void **p, unsigned size)
{
    static unsigned memErrorCount = 0;

    fprintf(stderr,
            "WARNING: memory exhausted (%i bytes could not be allocated)\n",
            size);
    
    memErrorCount++;
    [[RETAIN(memoryExhaustedException) setPointer:p memorySize:size] raise];
}

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
    RELEASE(name);
    name = @"Default zone";
    return self;
}

- (void*)malloc:(unsigned)size
{
    void *p = objc_malloc(size);

#if DEBUG
    if ((logAlloc != (void*)-1) && (logAlloc != NULL)) {
        fprintf(logAlloc,
                "zmalloc: 0x%p size=%d zone=0x%p\n",
                p, size, self);
    }
#endif
    
    if (p == NULL) _memoryExhausted(&p, size);
    return p;
}

- (void*)mallocAtomic:(unsigned)size
{
    void* p = objc_malloc(size);

#if DEBUG
    if ((logAlloc != (void*)-1) && (logAlloc != NULL)) {
        fprintf(logAlloc,
                "zmalloc-a: 0x%p size=%d zone=0x%p\n", p, size, self);
    }
#endif
    
    if (p == NULL) _memoryExhausted(&p, size);
    return p;
}

- (void*)calloc:(unsigned)count byteSize:(unsigned)size
{
    void* p = objc_calloc(count, size);

#if DEBUG
    if ((logAlloc != (void*)-1) && (logAlloc != NULL)) {
        fprintf(logAlloc,
                "zcalloc: 0x%p size=%d (%d * %d) zone=0x%p\n",
                p, count*size, count, size, self);
    }
#endif
    
    if (p == NULL) _memoryExhausted(&p, size);
    return p;
}

- (void*)callocAtomic:(unsigned)count byteSize:(unsigned)size
{
    void* p = objc_calloc(count, size);

#if DEBUG
    if ((logAlloc != (void*)-1) && (logAlloc != NULL)) {
        fprintf(logAlloc,
                "zcalloc-a: 0x%p size=%d (%d * %d) zone=0x%p\n",
                p, count*size, count, size, self);
    }
#endif
    
    if (p == NULL) _memoryExhausted(&p, size);
    return p;
}

- (void*)realloc:(void*)p size:(unsigned)size
{
    void* new_p;
    
    if (size == 0) return p;
    
    new_p = p ? objc_realloc(p, size) : objc_malloc (size);
    
#if DEBUG
    if ((logAlloc != (void*)-1) && (logAlloc != NULL)) {
        fprintf(logAlloc,
                "zrealloc: 0x%p->0x%p size=%d zone=0x%p\n",
                p, new_p, size, self);
    }
#endif
    
    if (new_p == NULL) _memoryExhausted(&new_p, size);
    return new_p;
}

- (void)recycle
{
}

- (void)freePointer:(void*)p
{
    if (p) {
#if DEBUG
        if ((logAlloc != (void*)-1) && (logAlloc != NULL)) {
            fprintf(logAlloc, "zfree: 0x%p zone=0x%p\n", p, self);
        }
#endif
	objc_free(p);
        p = NULL;
    }
}

- (BOOL)checkZone
{
    return YES;
}

- (BOOL)pointerInZone:(void*)pointer
{
    return YES;
}

@end /* NSDefaultZone */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

