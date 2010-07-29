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

#include <NGObjWeb/WOxElemBuilder.h>

/*
  This builder builds drag&drop elements from the WEExtensions library.
  Note that there are other builders for WEExtensions elements as well !!

  All tags are mapped into the <var:> namespace (XMLNS_OD_BIND).

  Supported tags:
    <var:js-drag .../>      maps to WEDragContainer
    <var:js-drop .../>      maps to WEDropContainer
    <var:script-drag/>      maps to WEDragScript
    <var:script-drop/>      maps to WEDropScript
*/

@interface WExDnDElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include "common.h"

@implementation WExDnDElemBuilder

- (Class)classForElement:(id<DOMElement>)_element {
  NSString *tagName;
  unsigned tl;
  unichar c1;
  
  if (![[_element namespaceURI] isEqualToString:XMLNS_OD_BIND])
    return Nil;
  
  tagName = [_element tagName];
  if ((tl = [tagName length]) < 7)
    return Nil;
  
  c1 = [tagName characterAtIndex:0];

  switch (c1) {
    case 'j': /* starting with 'j' */
      if (tl == 7) {
        if ([tagName hasPrefix:@"js-dr"]) {
          if ([tagName isEqualToString:@"js-drag"])
            return NSClassFromString(@"WEDragContainer");
          if ([tagName isEqualToString:@"js-drop"])
            return NSClassFromString(@"WEDropContainer");
        }
      }
      break;
      
    case 's': /* starting with 's' */
      if (tl == 11) {
        if ([tagName hasPrefix:@"script-"]) {
          if ([tagName isEqualToString:@"script-drag"])
            return NSClassFromString(@"WEDragScript");
          if ([tagName isEqualToString:@"script-drop"])
            return NSClassFromString(@"WEDropScript");
        }
      }
      break;
  }
  return Nil;
}

@end /* WExDnDElemBuilder */
