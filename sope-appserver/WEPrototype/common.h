/*
  Copyright (C) 2005 Helge Hess

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

#ifndef __WEPrototype_common_H__
#define __WEPrototype_common_H__

#import <Foundation/Foundation.h>

#include <NGExtensions/NGExtensions.h>
#include <NGObjWeb/NGObjWeb.h>

#if NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY
#  include <NGExtensions/NGObjectMacros.h>
#endif

static inline id WEPExtGetProperty(NSDictionary *_set, NSString *_name) {
  id propValue = [_set objectForKey:_name];

  if (propValue != nil) {
    propValue = [propValue retain];
    [(NSMutableDictionary *)_set removeObjectForKey:_name];
  }
  return propValue;
}

#endif /* __WEPrototype_common_H__ */
