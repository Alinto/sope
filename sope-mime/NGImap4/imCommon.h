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

#ifndef __NGImap4_common_H__
#define __NGImap4_common_H__

#import <Foundation/Foundation.h>

#if NeXT_Foundation_LIBRARY
#  import <NGExtensions/NGObjectMacros.h>
#  import <NGExtensions/NSString+Ext.h>
#endif

#include <EOControl/EOControl.h>
#include <NGExtensions/NGExtensions.h>
#include <NGStreams/NGStreams.h>
#include <NGStreams/NGNet.h>

#include <NGMime/NGMime.h>
#include <NGMail/NGMail.h>

#if NeXT_RUNTIME || APPLE_RUNTIME
#  ifndef sel_eq
#    define sel_eq(__A__,__B__) (__A__==__B__)
#  endif
#endif

@interface NSObject(NGImap4_OSXHacks)
- (void)subclassResponsibility:(SEL)_acmd;
- (void)notImplemented:(SEL)_acmd;
@end

@interface NSException (NGImap4_setUserInfo)
- (id)setUserInfo:(NSDictionary *)_info;
@end

#endif /* __NGImap4_common_H__ */
