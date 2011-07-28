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

#ifndef __NGStreams_common_H__
#define __NGStreams_common_H__

// common include files

#include  <Foundation/Foundation.h>

// configuration

#include "config.h"

#if defined(WIN32)
#  include <windows.h>
#  include <winsock.h>
#endif

#if LIB_FOUNDATION_BOEHM_GC
#  include <gc.h>
#endif

#ifdef GNU_RUNTIME
#if __GNU_LIBOBJC__ == 20100911
#  include <objc/runtime.h>
#else
#  include <objc/objc-api.h>
#  include <objc/objc.h>
#  include <objc/encoding.h>
#endif
#endif

#if WITH_FOUNDATION_EXT
#if NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY
#  import <FoundationExt/objc-runtime.h>
#  import <FoundationExt/DefaultScannerHandler.h>
#  import <FoundationExt/PrintfFormatScanner.h>
#  import <FoundationExt/GeneralExceptions.h>
#  import <FoundationExt/MissingMethods.h>
#  import <FoundationExt/NSException.h>
#  import <FoundationExt/NSObjectMacros.h>
#endif
#endif

#if !LIB_FOUNDATION_LIBRARY && !NeXT_Foundation_LIBRARY
#  define NSWillBecomeMultiThreadedNotification NSBecomingMultiThreaded
#endif

#ifndef ASSIGN
#  define ASSIGN(object, value) \
       ({id __object = (id)object;    \
         id __value = (id)value;      \
         if (__value != __object) { if (__value) [__value retain]; \
          if (__object) [__object release]; \
          object = __value;}})
#endif

#include <NGExtensions/NGExtensions.h>

/* system config */

#if !defined(__CYGWIN32__)
#  ifdef HAVE_WINDOWS_H
#    include <windows.h>
#  endif
#  ifdef HAVE_WINSOCK_H
#    include <winsock.h>
#  endif
#endif

#ifdef HAVE_STRING_H
#  include <string.h>
#endif
#ifdef HAVE_STRINGS_H
#  include <strings.h>
#endif

#if HAVE_SYS_TYPES_H
#  include <sys/types.h>
#endif

#ifndef __MINGW32__
#  include <netinet/in.h>
#endif

#ifdef HAVE_SYS_SOCKET_H
#  include <sys/socket.h>
#endif
#ifdef HAVE_NETDB_H
#  include <netdb.h>
#endif

#if !defined(WIN32) || defined(__CYGWIN32__)
#  include <netinet/in.h>
#  include <arpa/inet.h>
#  include <sys/un.h>
#endif

#ifndef AF_LOCAL
#  define AF_LOCAL AF_UNIX
#endif

#if !defined(SHUT_RD)
#  define SHUT_RD   0
#endif
#if !defined(SHUT_WR)
#  define SHUT_WR   1
#endif
#if !defined(SHUT_RDWR)
#  define SHUT_RDWR 2
#endif

// local common's

#include <NGStreams/NGStreamExceptions.h>

@interface NSObject(OSXHacks)
- (void)subclassResponsibility:(SEL)_acmd;
- (void)notImplemented:(SEL)_acmd;
@end

#endif /* __NGStreams_common_H__ */
