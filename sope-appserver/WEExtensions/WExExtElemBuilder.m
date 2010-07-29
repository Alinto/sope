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
  This builder builds various elements from the WEExtensions library.
  Note that there are other builders for WEExtensions elements as well !!

  All tags are mapped into the <var:> namespace (XMLNS_OD_BIND).

  Supported tags:
    <var:js-clipboard .../> maps to JSClipboard
    <var:js-menu .../>      maps to JSMenu
    <var:js-menu-item .../> maps to JSMenuItem
    <var:js-shiftclick ../> maps to JSShiftClick
    <var:js-stringtable ../>maps to JSStringTable

    <var:rich-string .../>  maps to WERichString
    <var:we-browser .../>   maps to WEBrowser
    <var:cal-field .../>    maps to WECalendarField
    <var:date-field .../>   maps to WEDateField
    <var:time-field .../>   maps to WETimeField
    
    <var:script-datefield/> maps to WEDateFieldScript
    
    <var:tableview .../>    maps to WETableView
    <var:tbutton   .../>    maps to WETableViewButtonMode
    <var:ttitle    .../>    maps to WETableViewTitleMode
    <var:tfooter   .../>    maps to WETableViewFooterMode
    <var:tgroup    .../>    maps to WETableViewGroupMode
    <var:td        .../>    maps to WETableData
    <var:th        .../>    maps to WETableHeader
    
    <var:tabview   .../>    maps to WETabView
    <var:tab       .../>    maps to WETabItem

    <var:pageview  .../>    maps to WEPageView
    <var:page      .../>    maps to WEPageItem
    <var:pagelink  .../>    maps to WEPageLink
    
    <var:we-collapsible .../>  maps to WECollapsibleComponentContent
    <var:we-collapsible-action .../> maps to WECollapsibleAction
    <var:we-collapsible-title  .../> maps to WECollapsibleTitleMode
    <var:we-collapsible-content  .../> maps to WECollapsibleContentMode

    <var:switch    .../>    maps to WESwitch
    <var:case      .../>    maps to WECase
    <var:default   .../>    maps to WEDefaultCase

    <var:treeview  .../>    maps to WETreeView
    <var:tree-header .../>  maps to WETreeHeader
    <var:tree-data   .../>  maps to WETreeData

    <var:hspan-matrix .../> maps to WEHSpanTableMatrix
    <var:vspan-matrix .../> maps to WEVSpanTableMatrix
    <var:matrix-cell  .../> maps to WETableMatrixContent
    <var:matrix-empty .../> maps to WETableMatrixNoContent
    <var:matrix-label .../> maps to WETableMatrixLabel

    <var:if-ctx-key   .../> maps to WEContextConditional
    <var:ctx-key      .../> maps to WEContextKey
    <var:if-qualifier .../> maps to WEQualifierConditional

    <var:redirect    .../>  maps to WERedirect
    
    WEComponentValue : WODynamicElement
*/

@interface WExExtElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include "common.h"

@implementation WExExtElemBuilder

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
    case 'c': /* starting with 'c' */
      if (tl > 8) {
        if ([tagName isEqualToString:@"cal-field"])
          return NSClassFromString(@"WECalendarField");
      }
      else if (tl > 3) {
        if ([tagName isEqualToString:@"case"])
          return NSClassFromString(@"WECase");
        if ([tagName isEqualToString:@"ctx-key"])
          return NSClassFromString(@"WEContextKey");
      }
      break;

    case 'd':
      if (tl > 8) {
        if ([tagName isEqualToString:@"date-field"])
          return NSClassFromString(@"WEDateField");
      }
      else if (tl > 6) {
        if ([tagName isEqualToString:@"default"])
          return NSClassFromString(@"WEDefaultCase");
      }
      break;

    case 'h':
      if (tl == 12) {
        if ([tagName isEqualToString:@"hspan-matrix"])
          return NSClassFromString(@"WEHSpanTableMatrix");
      }
      break;

    case 'i':
      if (tl == 10) {
        if ([tagName isEqualToString:@"if-ctx-key"])
          return NSClassFromString(@"WEContextConditional");
      }
      if (tl == 12) {
        if ([tagName isEqualToString:@"if-qualifier"])
          return NSClassFromString(@"WEQualifierConditional");
      }
      break;
      
    case 'j': /* starting with 'j' */
      if ([tagName hasPrefix:@"js-"]) {
        if (tl < 6) return Nil;
        
        if (tl == 12 && [tagName isEqualToString:@"js-clipboard"])
          return NSClassFromString(@"JSClipboard");
        if (tl ==  7 && [tagName isEqualToString:@"js-menu"])
          return NSClassFromString(@"JSMenu");
        if (tl == 12 && [tagName isEqualToString:@"js-menu-item"])
          return NSClassFromString(@"JSMenuItem");
        
        if (tl == 12 && [tagName isEqualToString:@"js-shiftclick"])
          return NSClassFromString(@"JSShiftClick");
	
        if (tl == 14 && [tagName isEqualToString:@"js-stringtable"])
          return NSClassFromString(@"JSStringTable");
      }
      break;

    case 'm':
      if (tl == 11) {
        if ([tagName isEqualToString:@"matrix-cell"])
          return NSClassFromString(@"WETableMatrixContent");
      }
      else if (tl == 12) {
        if ([tagName isEqualToString:@"matrix-empty"])
          return NSClassFromString(@"WETableMatrixNoContent");
        if ([tagName isEqualToString:@"matrix-label"])
          return NSClassFromString(@"WETableMatrixLabel");
      }
      break;
      
    case 'p':
      if (tl > 3) {
        if (tl == 8 && [tagName isEqualToString:@"pagelink"])
          return NSClassFromString(@"WEPageLink");
        if (tl == 4 && [tagName isEqualToString:@"page"])
          return NSClassFromString(@"WEPageItem");
        if (tl == 8 && [tagName isEqualToString:@"pageview"])
          return NSClassFromString(@"WEPageView");
      }
      break;

    case 'r': /* starting with 'r' */
      if (tl > 8) {
        if ([tagName isEqualToString:@"rich-string"])
          return NSClassFromString(@"WERichString");
      }
      if (tl == 8) {
        if ([tagName isEqualToString:@"redirect"])
          return NSClassFromString(@"WERedirect");
      }
      break;
      
    case 's': /* starting with 's' */
      if (tl > 10) {
        if ([tagName isEqualToString:@"script-datefield"])
          return NSClassFromString(@"WEDateFieldScript");
      }
      else if (tl > 5) {
        if ([tagName isEqualToString:@"switch"])
          return NSClassFromString(@"WESwitch");
      }
      break;

    case 't': { /* starting with 't' */
      unichar c2;
      
      c2 = [tagName characterAtIndex:1];
      
      if (tl == 2) {
        if (c2 == 'd') return NSClassFromString(@"WETableData");
        if (c2 == 'h') return NSClassFromString(@"WETableHeader");
      }
      if (tl == 3 && c2 == 'a') {
        if ([tagName characterAtIndex:2] == 'b')
          return NSClassFromString(@"WETabItem");
      }

      if (tl > 5) {
        if (c2 == 'a') {
          if ([tagName isEqualToString:@"tableview"])
            return NSClassFromString(@"WETableView");
        
          if ([tagName isEqualToString:@"tabview"])
            return NSClassFromString(@"WETabView");
        }
        if (c2 == 'r' && tl > 7) {
          if ([tagName isEqualToString:@"tree-data"])
            return NSClassFromString(@"WETreeData");
          if ([tagName isEqualToString:@"treeview"])
            return NSClassFromString(@"WETreeView");
          if ([tagName isEqualToString:@"tree-header"])
            return NSClassFromString(@"WETreeHeader");
        }
        
        if ([tagName isEqualToString:@"tbutton"])
          return NSClassFromString(@"WETableViewButtonMode");
        if ([tagName isEqualToString:@"ttitle"])
          return NSClassFromString(@"WETableViewTitleMode");
        if ([tagName isEqualToString:@"tfooter"])
          return NSClassFromString(@"WETableViewFooterMode");
        if ([tagName isEqualToString:@"tgroup"])
          return NSClassFromString(@"WETableViewGroupMode");

        if ([tagName isEqualToString:@"time-field"])
          return NSClassFromString(@"WETimeField");
      }
      break;
    }

    case 'v':
      if (tl == 12) {
        if ([tagName isEqualToString:@"vspan-matrix"])
          return NSClassFromString(@"WEVSpanTableMatrix");
      }
      break;

    case 'w':
      if (tl > 8) {
        if ([tagName isEqualToString:@"we-browser"])
          return NSClassFromString(@"WEBrowser");
        
        if ([tagName hasPrefix:@"we-collapsible"]) {
          if (tl == 14)
            return NSClassFromString(@"WECollapsibleComponentContent");
          
          if ([tagName isEqualToString:@"we-collapsible-action"])
            return NSClassFromString(@"WECollapsibleAction");
          if ([tagName isEqualToString:@"we-collapsible-title"])
            return NSClassFromString(@"WECollapsibleTitleMode");
          if ([tagName isEqualToString:@"we-collapsible-content"])
            return NSClassFromString(@"WECollapsibleContentMode");
        }
      }
      break;
  }
  
  return Nil;
}

@end /* WExExtElemBuilder */
