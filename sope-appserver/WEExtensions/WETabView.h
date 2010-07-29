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

#ifndef __WETabView_H__
#define __WETabView_H__

/*
  This is a library private header!
*/

#include <NGObjWeb/WODynamicElement.h>

/*
  Note: Does not support tab-head-creation from nested components!
  Why:  => because selection is manipulated in sub-elements
  
  WETabView creates element-IDs like

    .h.*.$key.  for the tab-items   (head-mode)
    .b.$key...  for the tab-content (content-mode) (new, hh)
  
  Note: the WETabView JavaScript mode cannot handle duplicate tab-keys.
*/

@interface WETabView : WODynamicElement
{
  WOAssociation *selection;

  /* config: */
  WOAssociation *bgColor;
  WOAssociation *nonSelectedBgColor;
  WOAssociation *leftCornerIcon;
  WOAssociation *rightCornerIcon;
  
  WOAssociation *tabIcon;
  WOAssociation *leftTabIcon;
  WOAssociation *selectedTabIcon;
  
  WOAssociation *asBackground;
  WOAssociation *width;
  WOAssociation *height;
  WOAssociation *activeBgColor;
  WOAssociation *inactiveBgColor;
  
  WOAssociation *disabledTabKeys;
  
  WOAssociation *fontColor;
  WOAssociation *fontSize;
  WOAssociation *fontFace;
  
  id            template;
}

@end

@interface WETabItem : WODynamicElement
{
  WOAssociation *key;
  WOAssociation *icon;
  WOAssociation *label;
  WOAssociation *action;
  WOAssociation *isScript;
  WOAssociation *href;
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  
  /* config: */
  WOAssociation *tabIcon;
  WOAssociation *leftTabIcon;
  WOAssociation *selectedTabIcon;

  WOAssociation *asBackground;
  WOAssociation *width;
  WOAssociation *height;
  WOAssociation *activeBgColor;
  WOAssociation *inactiveBgColor;
  
  id            template;
}

@end

@interface WETabItemInfo : NSObject
{
@public
  NSString *label;
  NSString *icon;
  NSString *key;
  NSString *uri;
  NSString *tabIcon;
  NSString *leftIcon;
  NSString *selIcon;

  int      asBackground; // 0 -> not set, 1 -> YES, else -> NO
  NSString *width;
  NSString *height;
  NSString *activeBg;
  NSString *inactiveBg;

  BOOL     isScript;
}
@end

#endif /* __WETabView_H__ */
