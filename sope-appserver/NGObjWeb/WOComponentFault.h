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

#ifndef __NGObjWeb_WOComponentFault_H__
#define __NGObjWeb_WOComponentFault_H__

/*
  This is a private stand-in class for a sub-component that isn't used yet.
  This is required to be able to support recursive component nesting (otherwise
  component instantiation would loop).
*/

#import <Foundation/NSObject.h>
#include <NGObjWeb/WOComponent.h>

@class NSString, NSArray, NSDictionary;
@class WOComponent, WOContext, WOResourceManager;

@interface WOComponentFault : NSObject < NSCoding >
{
@private
  WOContext         *ctx;
  WOResourceManager *resourceManager;
  NSString          *pageName;
  NSArray           *languages;
  NSDictionary      *bindings;
}

- (id)initWithResourceManager:(WOResourceManager *)_rm
  pageName:(NSString *)_name
  languages:(NSArray *)_langs
  bindings:(NSDictionary *)_bindings;

// delayed notifications

- (void)ensureAwakeInContext:(WOContext *)_ctx;
- (void)_sleepWithContext:(WOContext *)_ctx;

// resolving

- (WOComponent *)resolveWithParent:(WOComponent *)_parent;

// typing

- (BOOL)isComponentFault;

@end

@interface WOComponent(WOComponentFault)
- (BOOL)isComponentFault;
@end

#endif /* __NGObjWeb_WOComponentFault_H__ */
