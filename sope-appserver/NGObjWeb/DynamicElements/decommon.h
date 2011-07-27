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

#ifndef __NGObjWeb_DynElem_common_H__
#define __NGObjWeb_DynElem_common_H__

#import <Foundation/Foundation.h>

#if !LIB_FOUNDATION_LIBRARY && !GNUSTEP_BASE_LIBRARY
#  import <NGExtensions/NGObjectMacros.h>
#  import <NGExtensions/NSString+Ext.h>
#endif /* NeXT_Foundation_LIBRARY */

#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(MethodsRequiredByDynamicElements)
- (void)subclassResponsibility:(SEL)_cmd;
@end
#endif

#include <NGExtensions/NGExtensions.h>
#include "WOResponse+private.h"
#include <NGObjWeb/WOContext.h>

static inline void WOResponse_AddEmptyCloseParens(WOResponse *r, WOContext *c) 
{
  if (c->wcFlags.xmlStyleEmptyElements) {
    WOResponse_AddCString(r, " />");
  }
  else {
    WOResponse_AddChar(r, '>');
  }
}

#endif /* __NGObjWeb_DynElem_common_H__ */
