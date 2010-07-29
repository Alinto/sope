/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#define id _id
#  include <js/jsapi.h>
#  include <js/jsobj.h>
#  include <js/jsutil.h>
#  include <js/jsfun.h>
#  include <js/jsarray.h>
#undef id

#import <Foundation/Foundation.h>
#include <EOControl/EOControl.h>

#if NeXT_RUNTIME || APPLE_RUNTIME
#  include <objc/objc.h>
#  include <objc/objc-class.h>
#endif

#if NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY || \
    COCOA_Foundation_LIBRARY
#  include <NGExtensions/NGObjectMacros.h>
#  if 0 // no FoundationExt
#    include <FoundationExt/objc-runtime.h>
#    include <FoundationExt/MissingMethods.h>
#  endif
#elif LIB_FOUNDATION_LIBRARY
#  include <extensions/objc-runtime.h>
#endif

// TODO: this is true for any gcc 3 ?
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY || GNUSTEP_BASE_LIBRARY
#  define NG_VARARGS_AS_REFERENCE 1
#endif
