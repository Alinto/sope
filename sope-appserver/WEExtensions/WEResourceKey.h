/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#ifndef __WEExtensions_OGoResourceKey_H__
#define __WEExtensions_OGoResourceKey_H__

#import <Foundation/NSObject.h>

/*
  WEResourceKey
  
  TODO: explain

  This class is used internally by WEResourceManager.
*/

@class NSString;

@interface WEResourceKey : NSObject < NSCopying >
{
@public
  unsigned hashValue;
  NSString *frameworkName;
  NSString *name;
  NSString *language;
  struct {
    int retainsValues:1;
    int reserved:31;
  } flags;
}

- (id)initCachedKey;
- (id)duplicate;

@end

#endif /* __WEExtensions_OGoResourceKey_H__ */
