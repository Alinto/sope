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

#ifndef __NGExtensions_common_h__
#define __NGExtensions_common_h__

#import <Foundation/Foundation.h>
#import <Foundation/NSMapTable.h>

#include <NGExtensions/AutoDefines.h>

#if defined(WIN32)
#  include <windows.h>
#elif defined(NeXT) || NeXT_Foundation_LIBRARY
#  include <netinet/in.h>
#else
#  include <netinet/in.h>
#  include <arpa/inet.h>
#endif

#if !defined(WIN32)
#include <unistd.h>
#endif

#if GNU_RUNTIME
#if __GNU_LIBOBJC__ == 20100911
#  include <objc/runtime.h>
#else
#  import <objc/objc-api.h>
#  import <objc/objc.h>
#  import <objc/encoding.h>
#endif
#endif

#if LIB_FOUNDATION_LIBRARY
#  include <time.h>
#  import <extensions/objc-runtime.h>
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

#if LIB_FOUNDATION_LIBRARY
#  define NoZone nil
#else
#  define NoZone NULL
#endif

#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifndef __MINGW32__
#include <strings.h>
#endif

#if defined(WIN32)
static inline const char *index(const char *str, char c) __attribute__((unused));

static const char *index(const char *str, char c) {
  while ((*str != '\0') && (*str != c)) str++;
  if (*str == '\0') return NULL;
  else return str;
}
#endif

#if PROFILE
#  define BEGIN_PROFILE \
     { NSTimeInterval __ti = [[NSDate date] timeIntervalSince1970];

#  define END_PROFILE \
     __ti = [[NSDate date] timeIntervalSince1970] - __ti;\
     if (__ti > 0.05) \
       printf("***PROF[%s]: %0.3fs\n", __PRETTY_FUNCTION__, __ti);\
     else if (__ti > 0.005) \
       printf("PROF[%s]: %0.3fs\n", __PRETTY_FUNCTION__, __ti);\
     }

#  define PROFILE_CHECKPOINT(__key__) \
       printf("---PROF[%s] CP %s: %0.3fs\n", __PRETTY_FUNCTION__, __key__,\
              [[NSDate date] timeIntervalSince1970] - __ti)

#else
#  define BEGIN_PROFILE {
#  define END_PROFILE   }
#  define PROFILE_CHECKPOINT(__key__)
#endif

#endif
