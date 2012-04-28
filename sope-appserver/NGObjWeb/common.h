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

#ifndef __NGObjWeb_common_H__
#define __NGObjWeb_common_H__

// common include files

#if !defined(__MINGW32__)
#  include <strings.h>
#endif

#include <unistd.h>
#include <sys/stat.h>

#if NeXT_Foundation_LIBRARY
#  include <NGExtensions/NGObjectMacros.h>
#  include <NGExtensions/NSString+Ext.h>
#  include <NGExtensions/NSRunLoop+FileObjects.h>
#endif

#if !LIB_FOUNDATION_LIBRARY
#  include <NGExtensions/NGPropertyListParser.h>
#endif


#import <Foundation/Foundation.h>
#import <Foundation/NSDateFormatter.h>
#import <Foundation/NSNumberFormatter.h>
#import <Foundation/NSHost.h>

#include <NGExtensions/NGExtensions.h>
#include <NGExtensions/NGLogging.h>
#include <NGStreams/NGStreams.h>

#if NeXT_RUNTIME || APPLE_RUNTIME
#  ifndef sel_get_name
#    define sel_get_name(__XXX__)    sel_getName(__XXX__)
#    define sel_get_any_uid(__XXX__) sel_getUid(__XXX__)
#  endif
#endif

#define IS_DEPRECATED \
  [self warnWithFormat:@"used deprecated method: %s:%i.", \
          __PRETTY_FUNCTION__, __LINE__];

#if PROFILE
#  define BEGIN_PROFILE \
     { NSTimeInterval __ti = [[NSDate date] timeIntervalSince1970],__last=__ti;

#  define END_PROFILE \
     __ti = [[NSDate date] timeIntervalSince1970] - __ti;\
     if (__ti > 0.05) \
       printf("***PROF[%s]: %0.3fs\n", __PRETTY_FUNCTION__, __ti);\
     else if (__ti > 0.005) \
       printf("PROF[%s]: %0.3fs\n", __PRETTY_FUNCTION__, __ti);\
     }

#  define PROFILE_CHECKPOINT(__key__) \
     {\
       NSTimeInterval __new = [[NSDate date] timeIntervalSince1970];\
       printf("---PROF[%s] CP %s: %0.3fs %0.3fs\n", __PRETTY_FUNCTION__,\
              __key__, __new - __ti, __new - __last);\
       __last=__new; \
     }

#else
#  define BEGIN_PROFILE {
#  define END_PROFILE   }
#  define PROFILE_CHECKPOINT(__key__)
#endif

@interface NSException(setUserInfo)
- (id)setReason:(NSString *)_reason;
- (id)setUserInfo:(NSDictionary *)_userInfo;
@end

#endif /* __NGObjWeb_common_H__ */
