/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __EOControl_COMMON_H__
#define __EOControl_COMMON_H__

#include <stdlib.h>
#include <string.h>
#include <objc/Protocol.h>

#import <Foundation/Foundation.h>
#import <Foundation/NSObjCRuntime.h>

#if NeXT_RUNTIME || APPLE_RUNTIME
#  define objc_free(__mem__)    free(__mem__)
#  define objc_malloc(__size__) malloc(__size__)
#  define objc_calloc(__cnt__, __size__) calloc(__cnt__, __size__)
#  define objc_realloc(__ptr__, __size__) realloc(__ptr__, __size__)
#  ifndef sel_eq
#    define sel_eq(sela,selb) (sela==selb?YES:NO)
#  endif
#endif

#ifndef ASSIGN
#  define ASSIGN(object, value) \
       ({id __object = (id)object;    \
         id __value = (id)value;      \
         if (__value != __object) { if (__value) [__value retain]; \
          if (__object) [__object release]; \
          object = __value;}})
#endif
#ifndef ASSIGNCOPY
#  define ASSIGNCOPY(object, value) \
       ({id __object = (id)object;    \
         id __value = (id)value;      \
         if (__value != __object) { if (__value) __value = [__value copy];   \
          if (__object) [__object release]; \
          object = __value;}})
#endif

// ******************** common functions ********************

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

#define Malloc  malloc
#define Calloc  calloc
#define Realloc realloc
#define Free(__p__)  if(__p__) { free(__p__); __p__ = NULL; }

#define Strlen(__s__) (__s__?strlen(__s__):0)

static inline char *Strdup(const char *s) {
  return s ? strcpy(Malloc(strlen(s) + 1), s) : NULL;
}
static inline char* Strcpy (char *d, const char *s) {
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
  if(p == NULL) {
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

static inline int Atoi(const char* str) {
  return str ? atoi(str) : 0;
}
static inline long Atol(const char *str) {
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

static inline char *Ltoa(long nr, char *str, int base) {
  char buff[34], rest, is_negative;
  int ptr;

  ptr = 32;
  buff[33] = '\0';
  if (nr < 0) {
    is_negative = 1;
    nr = -nr;
  }
  else
    is_negative = 0;

  while (nr != 0) {
    rest = nr % base;
    if (rest > 9)
      rest += 'A' - 10;
    else
      rest += '0';
    buff[ptr--] = rest;
    nr /= base;
  }
  if (ptr == 32)
    buff[ptr--] = '0';
  if (is_negative)
    buff[ptr--] = '-';

  Strcpy(str, &buff[ptr+1]);

  return(str);
}

#endif /* __EOControl_COMMON_H__ */
