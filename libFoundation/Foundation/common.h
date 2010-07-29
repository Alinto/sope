/* 
   common.h

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

#ifndef __common_h__
#define __common_h__

#include <config.h>
#include <Foundation/NSString.h>

#if HAVE_STRING_H
# include <string.h>
#endif

#if HAVE_STRINGS_H
# include <strings.h>
#endif

#if HAVE_MEMORY_H
# include <memory.h>
#endif

#if !HAVE_MEMCPY
# define memcpy(d, s, n)       bcopy((s), (d), (n))
# define memmove(d, s, n)      bcopy((s), (d), (n))
#endif

#include <ctype.h>

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

#if HAVE_LIBC_H
# define NSObject AppleNSObject
# include <libc.h>
# undef NSObject
#else
# include <unistd.h>
#endif

#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <limits.h>
#include <fcntl.h>                     

#if HAVE_PWD_H
# include <pwd.h>
#endif
#include <stdarg.h>

#if HAVE_PROCESS_H
#include <process.h>
#endif

#ifdef __WIN32__
#define sleep(x) Sleep(x*1000)
#endif

#include "lfmemory.h"

#if (__GNUC__ == 2) && (__GNUC_MINOR__ <= 6) && !defined(__attribute__)
#  define __attribute__(x)
#endif


@class NSString;
@class NSData;

#define MAYBE_UNUSED __attribute__((unused))

static inline void *Malloc(int) __attribute__((unused));
static inline void *MallocAtomic(int) __attribute__((unused));
static inline void lfFree(void*) __attribute__((unused));
static inline void *Calloc(int, int) __attribute__((unused));
static inline void *CallocAtomic(int, int) __attribute__((unused));
static inline void *Realloc(void*, int) __attribute__((unused));
static inline int Strlen(const char*) __attribute__((unused));
static inline char* Strdup(const char*) __attribute__((unused));
static inline char* Strcpy (char*, const char*) __attribute__((unused));
static inline char* Strncpy (char*, const char*, unsigned)
     MAYBE_UNUSED;
static inline char* Strcat (char*, const char*) __attribute__((unused));
static inline char* Strncat (char*, const char*, unsigned)
     MAYBE_UNUSED;
static inline int Strcmp(const char*, const char*) __attribute__((unused));
static inline int Strncmp(const char*, const char*, unsigned)
     MAYBE_UNUSED;
static inline int Atoi(const char*) __attribute__((unused));
static inline long Atol(const char*) __attribute__((unused));

static inline BOOL lf_isPlistBreakChar(unsigned char c) MAYBE_UNUSED;
static inline NSString *lf_quoteString (const char *cString, int length)
     MAYBE_UNUSED;


#include <Foundation/NSObject.h>

/* Windows Support */

#if defined(__MINGW32__)
#  include <windows.h>
LF_EXPORT NSString *NSWindowsWideStringToString(LPWSTR _wstr);
LF_EXPORT LPWSTR    NSStringToWindowsWideString(NSString *_str);
#endif

/* File reading */

LF_EXPORT void *NSReadContentsOfFile(NSString *_path,
                                  unsigned _extraCapacity,
                                  unsigned *len);

/* Non OpenStep useful things */

#if LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC

LF_EXPORT void __raiseMemoryException (void* pointer, int size);


static inline void *Malloc(int size)
{
    void* p = (void*)GC_MALLOC (size);
    if(!p)
        __raiseMemoryException (&p, size);
    return p;
}

static inline void *MallocAtomic(int size)
{
    void* p = (void*)GC_MALLOC_ATOMIC (size);
    if(!p)
        __raiseMemoryException (&p, size);
    return p;
}

static inline void lfFree(void* p)
{
    //if (p) GC_FREE(p);
}

static inline void *Calloc(int elem, int size)
{
    int howMuch = elem * size;
    void* p = (void*)GC_MALLOC (howMuch);

    if(!p)
        __raiseMemoryException (&p, howMuch);
    memset (p, 0, howMuch);
    return p;
}

static inline void *CallocAtomic(int elem, int size)
{
    int howMuch = elem * size;
    void* p = (void*)GC_MALLOC_ATOMIC (howMuch);

    if(!p)
        __raiseMemoryException (&p, howMuch);
    memset (p, 0, howMuch);
    return p;
}

static inline void *Realloc(void* p, int size)
{
    void* new_p = GC_REALLOC (p, size);

    if(!new_p)
        __raiseMemoryException (&new_p, size);
    return new_p;
}

#else /* !LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC */

#if !WITHOUT_ZONES

#include <Foundation/NSZone.h>

// TODO: can't we cache the defaultZone somewhere? (or at least the class?)

static inline void *Malloc(int size)
{
    return [[NSZone defaultZone] malloc:size];
}

static inline void *MallocAtomic(int size)
{
    return [[NSZone defaultZone] mallocAtomic:size];
}

static inline void lfFree(void* p)
{
    return [[NSZone zoneFromPointer:p] freePointer:p];
}

static inline void *Calloc(int elem, int size)
{
    return [[NSZone defaultZone] calloc:elem byteSize:size];
}

static inline void *CallocAtomic(int elem, int size)
{
    return [[NSZone defaultZone] callocAtomic:elem byteSize:size];
}

static inline void *Realloc(void* p, int size)
{
    return [[NSZone zoneFromPointer:p] realloc:p size:size];
}

#else

static inline void *Malloc(int size)
{
    return objc_malloc(size);
}
static inline void *MallocAtomic(int size)
{
    return objc_malloc(size);
}

static inline void lfFree(void* p)
{
    if (p) objc_free(p);
}

static inline void *Calloc(int elem, int size)
{
    return objc_calloc(elem, size);
}
static inline void *CallocAtomic(int elem, int size)
{
    return objc_calloc(elem, size);
}

static inline void *Realloc(void* p, int size)
{
    return p ? objc_realloc(p, size) : objc_malloc (size);
}

#endif

#endif /* !LIB_FOUNDATION_BOEHM_GC || LIB_FOUNDATION_LEAK_GC*/

static inline BOOL lf_isPlistBreakChar(unsigned char c)
{
    if (!isalnum(c)) return YES;
    
    switch (c) {
        case '_': case '@': case '#': case '$':
        case '.': case '=': case ';': case ',':
        case '{': case '}': case '(': case ')':
        case '<': case '>': case '/': case '\\':
        case '"':
            return YES;
            
        default:
            return NO;
    }
}

static NSString *lf_quoteString (const char *cString, int length)
{
    unsigned char buf[length * 2 + 4];
    register int i, j;

    buf[0] = '"';
    for (i = 0, j = 1; i < length; i++, j++) {
#if 0
        if ((cString[i] < 33) || (cString[i] == '"') || (cString[i] == '\\')) {
            buf[j] = '\\'; j++;
            buf[j] = cString[i];
        }
#endif
        switch (cString[i]) {
            case '"':
                buf[j] = '\\'; j++;
                buf[j] = cString[i];
                break;
            case '\n':
                buf[j] = '\\'; j++;
                buf[j] = 'n';
                break;
            case '\\':
                buf[j] = '\\'; j++;
                buf[j] = '\\';
                break;
            default:
                buf[j] = cString[i];
                break;
        }
    }
    buf[j] = '"'; j++;
    buf[j] = '\0';
    
    return [NSString stringWithCString:(char *)buf length:j];
}

static inline int Strlen(const char* s)
{
    return s ? strlen(s) : 0;
}

static inline char* Strdup(const char* s)
{
    return s ? strcpy(MallocAtomic(strlen(s) + 1), s) : NULL;
}

static inline char* Strcpy (char* d, const char* s)
{
    return s && d ? strcpy(d, s) : d;
}

static inline char* Strncpy (char* d, const char* s, unsigned size)
{
    return s && d ? strncpy(d, s, size) : d;
}

static inline char* Strcat (char* d, const char* s)
{
    return s && d ? strcat(d, s) : d;
}

static inline char* Strncat (char* d, const char* s , unsigned size)
{
    return s && d ? strncat(d, s , size) : d;
}

static inline int Strcmp(const char* p, const char* q)
{
    if(!p) {
        if(!q)
            return 0;
        else return -1;
    }
    else {
        if(!q)
            return 1;
        else return strcmp(p, q);
    }
}

static inline int Strncmp(const char* p, const char* q, unsigned size)
{
    if(!p) {
        if(!q)
            return 0;
        else return -1;
    }
    else {
        if(!q)
            return 1;
        else return strncmp(p, q, size);
    }
}

static inline int Atoi(const char* str)
{
    return str ? atoi(str) : 0;
}

static inline long Atol(const char *str)
{
    return str ? atol(str) : 0;
}

LF_EXPORT char*	Ltoa(long nr, char *str, int base);
LF_EXPORT void	vaRelease(id obj, ...);

/* Hash function used by NSString */
LF_EXPORT unsigned hashjb(const char* name, int len);

LF_EXPORT NSString* Asprintf(NSString* format, ...);
LF_EXPORT NSString* Avsprintf(NSString* format, va_list args);

LF_EXPORT BOOL writeToFile(NSString* path, NSData* data, BOOL atomically);

LF_EXPORT char* Tmpnam(char* s);

#ifndef MAX
#define MAX(a, b) \
    ({typeof(a) _a = (a); typeof(b) _b = (b);     \
	_a > _b ? _a : _b; })
#endif

#ifndef MIN
#define MIN(a, b) \
    ({typeof(a) _a = (a); typeof(b) _b = (b);	\
	_a < _b ? _a : _b; })
#endif

/* varargs macros, required to be able to handle powerpc64 (eg iSeries) */

/* va_list needs not be a scalar type on all archs, so to be portable
 * one cannot use simple assignment, but must copy it. */

#ifndef lfCopyVA
#  if defined(__va_copy) || defined(__linux__)
#    define lfCopyVA(__lvar__, __avar__) __va_copy(__lvar__, __avar__);
#  elif VA_LIST_IS_ARRAY
#    define lfCopyVA(__lvar__, __avar__) \
              memcpy(__lvar__,__avar__,sizeof(va_list));
#  else
#    define lfCopyVA(__lvar__, __avar__) __lvar__ = __avar__;
#  endif
#endif

#endif /* __common_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
