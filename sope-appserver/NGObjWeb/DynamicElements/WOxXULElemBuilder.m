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

#import <NGObjWeb/WOxElemBuilder.h>

/*
  This builder builds all standard elements which are defined in the 
  XUL namespace.

  Supported tags:
    - all other tags are represented using either WOGenericElement or
      WOGenericContainer, so this builder is "final destination" for
      all XUL related tags.
  
    <iframe .../>     maps to WOIFrame
    <entity .../>     maps to WOEntity
*/

@interface WOxXULElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include "decommon.h"
#include <SaxObjC/XMLNamespaces.h>

@implementation WOxXULElemBuilder

- (Class)classForElement:(id<DOMElement>)_element {
  NSString *nsuri;
  NSString *tag;
  unsigned tl;

  if ((nsuri = [_element namespaceURI]) == nil)
    return Nil;
  
  if (![nsuri isEqualToString:XMLNS_XUL])
    return Nil;
  
  tag = [_element tagName];
  
  if ((tl = [tag length]) == 0)
    return Nil;
  
  switch (tl) {
    default:
      if ([tag isEqualToString:@"iframe"])
        return NSClassFromString(@"WOIFrame");
      if ([tag isEqualToString:@"entity"])
        return NSClassFromString(@"WOEntity");
      break;
  }
  
  if ([_element hasChildNodes])
    return NSClassFromString(@"WOGenericContainer");
  else
    return NSClassFromString(@"WOGenericElement");
}

@end /* WOxXULElemBuilder */
