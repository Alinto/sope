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

// TODO: multiselection should set the "multiple" binding?

/*
  This builder builds control flow elements, eg conditionals and
  repetitions.
  
  Supported tags:
    <var:string .../>              maps to WOString
    <var:component-content/>       maps to WOComponentContent
    <var:entity .../>              maps to WOEntity
    <var:nbsp .../>                maps to WOEntity
    <var:popup ../>                maps to WOPopUpButton
    <var:singleselection ../>      maps to WOBrowser
    <var:multiselection .../>      maps to WOBrowser
    <var:radio-button-list .../>   maps to WORadioButtonList
    <var:checkbox-list .../>       maps to WOCheckBoxList
*/

@interface WOxMiscElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include "decommon.h"

@implementation WOxMiscElemBuilder

- (Class)classForElement:(id<DOMElement>)_element {
  NSString *nsuri;
  NSString *tag;
  unsigned tl;

  if (_element == nil) return nil;
  
  nsuri = [_element namespaceURI];
  if (![nsuri isEqualToString:XMLNS_OD_BIND])
    return Nil;
  
  tag = [_element tagName];
  tl  = [tag length];

  if (tl < 5)
    return Nil;
  
  switch ([tag characterAtIndex:0]) {
    case 'c':
      if ([tag isEqualToString:@"component-content"])
        return NSClassFromString(@"WOComponentContent");
      if ([tag isEqualToString:@"checkbox-list"])
        return NSClassFromString(@"WOCheckBoxList");
      break;
      
    case 'e':
      if ([tag isEqualToString:@"entity"])
        return NSClassFromString(@"WOEntity");
      break;

    case 'm':
      if ([tag isEqualToString:@"multiselection"])
        return NSClassFromString(@"WOBrowser");
      break;
      
    case 'n':
      if ([tag isEqualToString:@"nbsp"]) {
        [self warnWithFormat:@"%s: found <var:nbsp/>, "
                @"use <var:entity name='nbsp'/> !",
                __PRETTY_FUNCTION__];
        return NSClassFromString(@"WOEntity");
      }
      break;

    case 'p':
      if ([tag isEqualToString:@"popup"])
        return NSClassFromString(@"WOPopUpButton");
      break;
      
    case 'r':
      if ([tag isEqualToString:@"radio-button-list"])
        return NSClassFromString(@"WORadioButtonList");
      break;
      
    case 's':
      if ([tag isEqualToString:@"string"])
        return NSClassFromString(@"WOString");
      if ([tag isEqualToString:@"singleselection"])
        return NSClassFromString(@"WOBrowser");
      if ([tag isEqualToString:@"set-header"])
        return NSClassFromString(@"WOSetHeader");
      break;
  }
  return Nil;
}

@end /* SxMiscElemBuilder */
