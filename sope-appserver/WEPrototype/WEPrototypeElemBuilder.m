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

#include <NGObjWeb/WOxElemBuilder.h>

/*
  This builder builds various elements from the WEPrototype library.
  
  All tags are mapped into the <var:> namespace (XMLNS_OD_BIND).

  Supported tags:
    var:live-link => WELiveLink
*/

@interface WEPrototypeElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include "common.h"

@implementation WEPrototypeElemBuilder

- (Class)classForElement:(id<DOMElement>)_element {
  NSString *tagName;
  unsigned tl;
  unichar c1;
  
  if (![[_element namespaceURI] isEqualToString:XMLNS_OD_BIND])
    return Nil;
  
  tagName = [_element tagName];
  if ((tl = [tagName length]) < 2)
    return Nil;

  c1 = [tagName characterAtIndex:0];
  
  switch (c1) {
  case 'p':
    if ([tagName isEqualToString:@"prototype-script"])
      return NSClassFromString(@"WEPrototypeScript");
  case 'l':
    if ([tagName isEqualToString:@"live-link"])
      return NSClassFromString(@"WELiveLink");
  default:
    return Nil;
  }
}

@end /* WEPrototypeElemBuilder */
