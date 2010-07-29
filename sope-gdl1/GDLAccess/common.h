/* 
   EOAdaptorChannel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#ifndef __common_h__
#define __common_h__

#include <string.h>
#include <stdlib.h>

#ifndef __WIN32__
#  include <unistd.h>
#  include <pwd.h>
#endif

#include <sys/types.h>
#include <stdarg.h>
#include <ctype.h>

#import <Foundation/NSZone.h>
#import <Foundation/Foundation.h>

#if !(COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY || GNUSTEP_BASE_LIBRARY)
#  import <Foundation/NSUtilities.h>
#endif

#import <Foundation/NSObjCRuntime.h>

#if NeXT_RUNTIME || APPLE_RUNTIME
#  define sel_eq(sela,selb) (sela==selb?YES:NO)
#endif

#if LIB_FOUNDATION_LIBRARY
#  import <extensions/objc-runtime.h>
#else
#  include <NGExtensions/NGObjectMacros.h>
#  include <NGExtensions/NSString+Ext.h>
#endif


// ******************** common functions ********************

static inline void *Malloc(int) __attribute__((unused));
static inline void *Calloc(int, int) __attribute__((unused));
static inline void *Realloc(void*, int) __attribute__((unused));
static inline void Free(void*) __attribute__((unused));

static inline int Strlen(const char*) __attribute__((unused));
static inline char* Strdup(const char*) __attribute__((unused));
static inline char* Strcpy (char*, const char*) __attribute__((unused));
static inline char* Strncpy (char*, const char*, unsigned)
    __attribute__((unused));
static inline char* Strcat (char*, const char*) __attribute__((unused));
static inline char* Strncat (char*, const char*, unsigned)
    __attribute__((unused));
static inline int Strcmp(const char*, const char*) __attribute__((unused));
static inline int Strncmp(const char*, const char*, unsigned)
    __attribute__((unused));
static inline int Atoi(const char*) __attribute__((unused));
static inline long Atol(const char*) __attribute__((unused));

static inline void *Malloc(int size) {
  return malloc(size);
}

static inline void *MallocAtomic(int size) {
  return malloc(size);
}

static inline void Free(void* p) {
  if (p) free(p);
}

static inline void *Calloc(int elem, int size) {
  return calloc(elem, size);
}

static inline void *CallocAtomic(int elem, int size) {
  return calloc(elem, size);
}

static inline void *Realloc(void* p, int size) {
  return realloc(p, size);
}

static inline int Strlen(const char* s) {
  return s ? strlen(s) : 0;
}

static inline char* Strdup(const char* s) {
  return s ? strcpy(Malloc(strlen(s) + 1), s) : NULL;
}

static inline char* Strcpy (char* d, const char* s) {
  return s && d ? strcpy(d, s) : d;
}

static inline char* Strncpy (char* d, const char* s, unsigned size) {
  return s && d ? strncpy(d, s, size) : d;
}

static inline char* Strcat (char* d, const char* s) {
  return s && d ? strcat(d, s) : d;
}

static inline char* Strncat (char* d, const char* s , unsigned size) {
  return s && d ? strncat(d, s , size) : d;
}

static inline int Strcmp(const char* p, const char* q) {
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

static inline int Strncmp(const char* p, const char* q, unsigned size) {
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

#ifndef MAX
#define MAX(a, b) \
    ({typedef _ta = (a), _tb = (b);   \
	_ta _a = (a); _tb _b = (b);     \
	_a > _b ? _a : _b; })
#endif

#ifndef MIN
#define MIN(a, b) \
    ({typedef _ta = (a), _tb = (b);   \
	_ta _a = (a); _tb _b = (b);     \
	_a < _b ? _a : _b; })
#endif

#if !LIB_FOUNDATION_LIBRARY

#ifndef CREATE_AUTORELEASE_POOL
#define CREATE_AUTORELEASE_POOL(pool) \
  id pool = [[NSAutoreleasePool alloc] init]
#endif

#endif /* ! LIB_FOUNDATION_LIBRARY */


#if !LIB_FOUNDATION_LIBRARY

static inline char *Ltoa(long nr, char *str, int base)
{
    char buff[34], rest, is_negative;
    int ptr;

    ptr = 32;
    buff[33] = '\0';
    if(nr < 0) {
	is_negative = 1;
	nr = -nr;
    }
    else
	is_negative = 0;

    while(nr != 0) {
	rest = nr % base;
	if(rest > 9)
	    rest += 'A' - 10;
	else
	    rest += '0';
	buff[ptr--] = rest;
	nr /= base;
    }
    if(ptr == 32)
	buff[ptr--] = '0';
    if(is_negative)
	buff[ptr--] = '-';

    Strcpy(str, &buff[ptr+1]);

    return(str);
}
#endif

#if !LIB_FOUNDATION_LIBRARY

@interface NSObject(FoundationExtGDLAccess)
- (void)subclassResponsibility:(SEL)sel;
- (void)notImplemented:(SEL)sel;
@end

#endif

#if !GNU_RUNTIME
#  ifndef SEL_EQ
#    define SEL_EQ(__A__,__B__) (__A__==__B__ ? YES : NO)
#  endif
#else
#  ifndef SEL_EQ
#    include <objc/objc.h>
#    define SEL_EQ(__A__,__B__) sel_eq(__A__,__B__)
#  endif
#endif

#endif /* __common_h__ */
