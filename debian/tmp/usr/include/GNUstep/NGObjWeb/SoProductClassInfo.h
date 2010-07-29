/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#ifndef __SoObjects_SoProductClassInfo_H__
#define __SoObjects_SoProductClassInfo_H__

#import <Foundation/NSObject.h>

/*
  SoProductClassInfo

  This class represents a class entry in the product manifest. It parses the
  following class keys:
    
    protectedBy            string       [eg "<public>" or "view"]
    defaultAccess          string       [eg "allow"]
    defaultRoles           dict         [eg {View = Anonymous;Edit=Owner}]
    extension / extensions string|array [eg "gif"]
    exactFilenames         array        [eg "ChangeLog"]
    methods
    slots

  Slots Keys:
    value       required
    valueClass  optional

  Method Keys:
    pageName              creates a SoPageInvocation
    actionName  optional  (used in conjunction with pageName)
    selector              creates a SoSelectorInvocation
    actionClass           create a SoActionInvocation
    directActionName      (used in conjunction with actionClass)
*/

@class NSString, NSDictionary, NSMutableDictionary, NSArray;
@class SoClassRegistry, SoProduct;

@interface SoProductSlotSetInfo : NSObject
{
  NSString            *className;
  NSString            *protectedBy;
  NSString            *defaultAccess;
  NSDictionary        *roleInfo;
  NSArray             *extensions;
  NSArray             *exactFilenames;
  SoProduct           *product; /* non-retained ! */
  
  NSMutableDictionary *slotValues;
  NSMutableDictionary *slotProtections;
}

- (id)initWithName:(NSString *)_name 
  manifest:(NSDictionary *)_dict
  product:(SoProduct *)_product;

- (void)applyOnRegistry:(SoClassRegistry *)_registry;

@end

@interface SoProductClassInfo : SoProductSlotSetInfo
@end

@interface SoProductCategoryInfo : SoProductSlotSetInfo
@end

#endif /* __SoObjects_SoProductClassInfo_H__ */
