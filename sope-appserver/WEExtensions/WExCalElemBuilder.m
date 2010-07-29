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
  This builder builds various calendaring elements from the WEExtensions
  library.

  All tags are mapped into the <var:> namespace (XMLNS_OD_BIND).

  Supported tags:
    <var:month-overview .../> to WEMonthOverview
    <var:month-label    .../> to WEMonthLabel
    <var:month-title    .../> to WEMonthTitle
    <var:month-info     .../> to WEMonthOverviewInfoMode
    <var:month          .../> to WEMonthOverviewContentMode

    <var:week-overview  .../> to WEWeekOverview
    <var:week-title     .../> to WEWeekOverviewTitleMode
    <var:week-info      .../> to WEWeekOverviewInfoMode
    <var:week-pminfo    .../> to WEWeekOverviewPMInfoMode
    <var:week           .../> to WEWeekOverviewContentMode
    <var:week-header    .../> to WEWeekOverviewHeaderMode
    <var:week-footer    .../> to WEWeekOverviewFooterMode

    <var:weekcol-view   .../> to WEWeekColumnView
    <var:weekcol-title  .../> to WEWeekColumnViewTitleMode
    <var:weekcol-info   .../> to WEWeekColumnViewInfoMode
    <var:weekcol        .../> to WEWeekColumnViewContentMode
*/

@interface WExCalElemBuilder : WOxTagClassElemBuilder
{
}

@end

#include <SaxObjC/XMLNamespaces.h>
#include "common.h"

@implementation WExCalElemBuilder

- (Class)classForElement:(id<DOMElement>)_element {
  NSString *tagName;
  unsigned tl;
  unichar  c1;
  
  if (![[_element namespaceURI] isEqualToString:XMLNS_OD_BIND])
    return Nil;
  
  tagName = [_element tagName];
  if ((tl = [tagName length]) < 4)
    return Nil;

  c1 = [tagName characterAtIndex:0];

  if (c1 == 'm') {
    /* month stuff */

    if (![tagName hasPrefix:@"month"])
      return Nil;
    
    switch (tl) {
      case 5:
        return NSClassFromString(@"WEMonthOverviewContentMode");

      case 10:
        if ([tagName isEqualToString:@"month-info"])
          return NSClassFromString(@"WEMonthOverviewInfoMode");
        break;
        
      case 11:
        if ([tagName isEqualToString:@"month-label"])
          return NSClassFromString(@"WEMonthLabel");
        if ([tagName isEqualToString:@"month-title"])
          return NSClassFromString(@"WEMonthTitle");
        break;
        
      case 14:
        if ([tagName isEqualToString:@"month-overview"])
          return NSClassFromString(@"WEMonthOverview");
        break;
    }
  }
  else if (c1 == 'w') {
    /* week stuff */
    
    if (![tagName hasPrefix:@"week"])
      return Nil;
    
    switch (tl) {
      case 4:
        return NSClassFromString(@"WEWeekOverviewContentMode");
        
      case 7:
        if ([tagName isEqualToString:@"weekcol"])
          return NSClassFromString(@"WEWeekColumnViewContentMode");
        break;

      case 9:
        if ([tagName isEqualToString:@"week-info"])
          return NSClassFromString(@"WEWeekOverviewInfoMode");
        break;
        
      case 10:
        if ([tagName isEqualToString:@"week-title"])
          return NSClassFromString(@"WEWeekOverviewTitleMode");
        break;
        
      case 11:
        if ([tagName isEqualToString:@"week-header"])
          return NSClassFromString(@"WEWeekOverviewHeaderMode");
        if ([tagName isEqualToString:@"week-footer"])
          return NSClassFromString(@"WEWeekOverviewFooterMode");
        if ([tagName isEqualToString:@"week-pminfo"])
          return NSClassFromString(@"WEWeekOverviewPMInfoMode");
        break;

      case 12:
        if ([tagName isEqualToString:@"weekcol-view"])
          return NSClassFromString(@"WEWeekColumnView");
        if ([tagName isEqualToString:@"weekcol-info"])
          return NSClassFromString(@"WEWeekColumnViewInfoMode");
        break;

      case 13:
        if ([tagName isEqualToString:@"weekcol-title"])
          return NSClassFromString(@"WEWeekColumnViewTitleMode");
        if ([tagName isEqualToString:@"week-overview"])
          return NSClassFromString(@"WEWeekOverview");
        break;
    }
  }
  
  return Nil;
}

@end /* WExCalElemBuilder */
