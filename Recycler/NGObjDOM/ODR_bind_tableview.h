/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#ifndef __NGObjDOM_Dynamic_tableview_H__
#define __NGObjDOM_Dynamic_tableview_H__

#include <NGObjDOM/ODNodeRenderer.h>

/*

*/

#define ODRTableView_              @"ODRTableView_"
#define ODRTableView_CollectMode   @"ODRTableView_CollectMode"
#define ODRTableView_TitleMode     @"ODRTableView_TitleMode"
#define ODRTableView_ButtonMode    @"ODRTableView_ButtonMode"
#define ODRTableView_HeaderMode    @"ODRTableView_HeaderMode"
#define ODRTableView_DataMode      @"ODRTableView_DataMode"
#define ODRTableView_FooterMode    @"ODRTableView_FooterMode"
#define ODRTableView_GroupMode     @"ODRTableView_GroupMode"

#define ODRTableView_INFOS         @"ODRTableView_INFOS"
#define ODRTableView_SORTEDKEY     @"ODRTableView_SORTEDKEY"
#define ODRTableView_ISDESCENDING  @"ODRTableView_ISDESCENDING"

#define ODRTableView_GroupItems    @"ODRTableView_GroupItems"
#define ODRTableView_GroupName     @"ODRTableView_GroupName"

#define ODRTableView_HasCollapseScript @"ODRTableView_HasCollapseScript"

// config stuff:
#define ODRTableView_titleColor    @"ODRTableView_titleColor"
#define ODRTableView_headerColor   @"ODRTableView_headerColor"
#define ODRTableView_footerColor   @"ODRTableView_footerColor"
#define ODRTableView_groupColor    @"ODRTableView_groupColor"
#define ODRTableView_evenColor     @"ODRTableView_evenColor"
#define ODRTableView_oddColor      @"ODRTableView_oddColor"
#define ODRTableView_fontColor     @"ODRTableView_fontColor"
#define ODRTableView_fontFace      @"ODRTableView_fontFace"
#define ODRTableView_fontSize      @"ODRTableView_fontSize"

// sort icons:
#define ODRTableView_upwardIcon    @"ODRTableView_upwardIcon"
#define ODRTableView_downwardIcon  @"ODRTableView_downwardIcon"
#define ODRTableView_nonSortIcon   @"ODRTableView_nonSortIcon"

// navigation icons
#define ODRTableView_first           @"ODRTableView_first"
#define ODRTableView_first_blind     @"ODRTableView_first_blind"
#define ODRTableView_previous        @"ODRTableView_previous"
#define ODRTableView_previous_blind  @"ODRTableView_previous_blind"
#define ODRTableView_next            @"ODRTableView_next"
#define ODRTableView_next_blind      @"ODRTableView_next_blind"
#define ODRTableView_last            @"ODRTableView_last"
#define ODRTableView_last_blind      @"ODRTableView_last_blind"
#define ODRTableView_openedIcon      @"ODRTableView_openedIcon"
#define ODRTableView_closedIcon      @"ODRTableView_closedIcon"
#define ODRTableView_minusIcon       @"ODRTableView_minusIcon"
#define ODRTableView_plusIcon        @"ODRTableView_plusIcon"
#define ODRTableView_select_all      @"ODRTableView_select_all"
#define ODRTableView_deselect_all    @"ODRTableView_deselect_all"

// labels
#define ODRTableView_ofLabel         @"ODRTableView_ofLabel"
#define ODRTableView_toLabel         @"ODRTableView_toLabel"
#define ODRTableView_firstLabel      @"ODRTableView_firstLabel"
#define ODRTableView_previousLabel   @"ODRTableView_previousLabel"
#define ODRTableView_nextLabel       @"ODRTableView_nextLabel"
#define ODRTableView_lastLabel       @"ODRTableView_lastLabel"
#define ODRTableView_pageLabel       @"ODRTableView_pageLabel"
#define ODRTableView_sortLabel       @"ODRTableView_sortLabel"

@class NSArray, NSDictionary, NSString;

@interface ODR_bind_tableview : ODNodeRenderer
{
  /* caching */
  NSArray             *list;
  NSString            *scriptID; // to unify the JavaScript
  struct {
    unsigned currentBatch;
    unsigned batchSize;
    unsigned firstIndex;
    unsigned lastIndex;
    unsigned batchCount;
    unsigned groupCount;
  } state;
  
  struct {
    BOOL     checkBoxes;
    BOOL     overflow;           // generate overflow-scrolling
    BOOL     scriptScrolling;    // scroll pages per JavaScript
    BOOL     scriptCollapsing;   // collapse groups per JavaScript
    BOOL     batchResizeButtons;
  } use;

  NSDictionary *groupedList;
  NSArray      *indexToGrouppath;
}
- (void)updateStateOfNode:(id)_node inContext:(WOContext *)_ctx;
@end

static inline NSString *ODRTableLabelForKey(NSString *_key, WOContext *_ctx)
     __attribute__((unused));

#include <NGObjWeb/WOContext.h>
#import <Foundation/NSString.h>

static NSString *ODRTableLabelForKey(NSString *_key, WOContext *_ctx) {
  NSString *key;
  key = [NSString stringWithFormat:@"ODRTableView_%@Label", _key];
  return [_ctx objectForKey:key];
}

@interface ODRTableViewInfo: NSObject
{
@public
  unsigned rowSpan;
  BOOL     isGroup;
  BOOL     isEven;
  BOOL     isSorted;
}
@end

@interface ODR_bind_ttitle : ODNodeRenderer
@end

@interface ODR_bind_tbutton : ODNodeRenderer
@end

@interface ODR_bind_tfooter : ODNodeRenderer
@end

@interface ODR_bind_tgroup : ODNodeRenderer
@end


#endif /* __NGObjDOM_Dynamic_tableview_H__ */
