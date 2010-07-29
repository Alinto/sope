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
  This builder builds various elements from the WOExtensions library.

  All tags are mapped into the <var:> namespace (XMLNS_OD_BIND).

  Supported tags:
    <var:js-alert-panel     .../> maps to JSAlertPanel
    <var:js-confirm-panel   .../> maps to JSConfirmPanel
    <var:js-img-flyover     .../> maps to JSImageFlyover
    <var:js-text-flyover    .../> maps to JSTextFlyover
    <var:js-modal-window    .../> maps to JSModalWindow
    <var:js-validated-field .../> maps to JSValidatedField

    <var:threshold-colored-number .../> maps to WOThresholdColoredNumber

    <var:collapsible .../>  maps to WOCollapsibleComponentContent
    <var:checkbox-matrix../>maps to WOCheckBoxMatrix
    <var:radio-matrix .../> maps to WORadioButtonMatrix
    
    <var:foreach-key .../>  maps to WODictionaryRepetition
    <var:if-key      .../>  maps to WOKeyValueConditional

    <var:tab-panel   .../>  maps to WOTabPanel

    <var:table        .../> maps to WOTable
    <var:table-header  ../> maps to WOTableHeader
    <var:table-content ../> maps to WOTableContent
    <var:table-ctx-key ../> maps to WOTableContextKey
    
    //JSKeyHandler : WODynamicElement
*/

@interface WOxExtElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include "common.h"

@implementation WOxExtElemBuilder

- (Class)classForElement:(id<DOMElement>)_element {
  NSString *tagName;
  unsigned tl;
  unichar  c1;
  
  if (![[_element namespaceURI] isEqualToString:XMLNS_OD_BIND])
    return Nil;
  
  tagName = [_element tagName];
  if ((tl = [tagName length]) < 3)
    return Nil;

  c1 = [tagName characterAtIndex:0];
  switch (c1) {
    case 'c':
      if (tl > 10) {
        if ([tagName isEqualToString:@"collapsible"])
          return NSClassFromString(@"WOCollapsibleComponentContent");
        if ([tagName isEqualToString:@"checkbox-matrix"])
          return NSClassFromString(@"WOCheckBoxMatrix");
      }
      break;

    case 'f':
      if (tl > 10) {
        if ([tagName isEqualToString:@"foreach-key"])
          return NSClassFromString(@"WODictionaryRepetition");
      }
      break;

    case 'i':
      if (tl == 6) {
        if ([tagName isEqualToString:@"if-key"])
          return NSClassFromString(@"WOKeyValueConditional");
      }
      break;
      
    case 'j':
      if (tl > 13 && [tagName hasPrefix:@"js-"]) {
        if ([tagName isEqualToString:@"js-alert-panel"])
          return NSClassFromString(@"JSAlertPanel");
        if ([tagName isEqualToString:@"js-confirm-panel"])
          return NSClassFromString(@"JSConfirmPanel");
        if ([tagName isEqualToString:@"js-img-flyover"])
          return NSClassFromString(@"JSImageFlyover");
        if ([tagName isEqualToString:@"js-text-flyover"])
          return NSClassFromString(@"JSTextFlyover");
        if ([tagName isEqualToString:@"js-modal-window"])
          return NSClassFromString(@"JSModalWindow");
        if ([tagName isEqualToString:@"js-validated-field"])
          return NSClassFromString(@"JSValidatedField");
      }
      break;

    case 'r':
      if (tl > 10) {
        if ([tagName isEqualToString:@"radio-matrix"])
          return NSClassFromString(@"WORadioButtonMatrix");
      }
      break;

    case 't':
      if (tl > 20) {
        if ([tagName isEqualToString:@"threshold-colored-number"])
          return NSClassFromString(@"WOThresholdColoredNumber");
      }
      if (tl > 8) {
        if ([tagName isEqualToString:@"tab-panel"])
          return NSClassFromString(@"WOTabPanel");
      }
      if (tl > 4) {
        if ([tagName hasPrefix:@"table"]) {
          if (tl == 5)
            return NSClassFromString(@"WOTable");
          
          if (tl > 11) {
            if ([tagName isEqualToString:@"table-content"])
              return NSClassFromString(@"WOTableContent");
            if ([tagName isEqualToString:@"table-header"])
              return NSClassFromString(@"WOTableHeader");
            if ([tagName isEqualToString:@"table-ctx-key"])
              return NSClassFromString(@"WOTableContextKey");
          }
        }
      }
      break;
  }
  return Nil;
}

@end /* WOxExtElemBuilder */
