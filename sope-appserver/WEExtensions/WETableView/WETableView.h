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

#ifndef __WETableView_H__
#define __WETableView_H__

#include <NGObjWeb/WODynamicElement.h>

/*
  
  WETableView attributes:
    
    list          - list to iterate through                          (NSArray)
    batchSize     - size of a page                                   (unsigned)
    currentBatch  - current page                                     (unsigned)
    
    item          - current item                                     (id)
    index         - current item index                               (unsigned)
    identifier    - unique id for element                            (id)
    previousItem  - previous item       // used to calculate groupBy (id)
    previousIndex - previous item index // used to calculate groupBy (unsigned)
    
    indexOfFirst  - index of first item of current page              (unsigned)
    indexOfLast   - index of last  item of current page              (unsigend)
    
    sortedKey     -                                                  (NSString)
    isDescending  - sort descending                                  (BOOL)
    groups        -                                                  (id)
    showGroup     -                                                  (BOOL)

    collapseOnClient       - use JavaScript for collapsing (only IE) (BOOL)
    scrollOnClient         - use JavaScript for scrolling  (only IE) (BOOL)
    autoScroll             - use overflow-scrolling        (only IE) (int)
    showBatchResizeButtons - default = YES                           (BOOL)

  WETableHeader attributes:
   
    sortKey       - unique key; if set, a sorticon will be displayed (NSString) 
    negateSortDir - if YES, default sort dir is NSDescending         (BOOL)
    bgColor       - background color                                 (NSString)
    

  WETableData attributes:
  
    sortKey       - unique key; if set, a sorticon will be displayed (NSString)
    negateSortDir - if YES, default sort dir is NSDescending         (BOOL)
    bgColor       - background color                                 (NSString)
    title         - title of header -> no header cell is needed      (NSString)
    isGroup       -
  
  WETableView config attributes:

    titleColor
    headerColor
    footerColor
    evenColor
    oddColor
    fontColor
    fontFace
    fontSize

    nonSortIcon
    downwardSortIcon
    upwardSortIcon
  
    firstIcon
    firstBlindIcon
    previousIcon
    previousBlindIcon
    nextIcon
    nextBlindIcon
    lastIcon
    lastBlindIcon

    plusResizeIcon
    minusResizeIcon

    groupOpenedIcon
    groupClosedIcon
 
    ofLabel
    toLabel
    firstLabel
    previousLabel
    nextLabel
    lastLabel
    pageLabel
    sortLabel

    border
    cellpadding
    cellspacing
   
  WETableHeader, WETableData config attributes:
  
    upwardSortIcon;
    downwardSortIcon;
    nonSortIcon;
    sortLabel;
*/

@class WETableViewLabelConfig, WETableViewIconConfig;
@class WETableViewColorConfig, WETableViewIconConfig;
@class WETableViewState;

@interface WETableView : WODynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation  *list;           // list of objects
  WOAssociation  *batchSize;      // batch size
  WOAssociation  *currentBatch;   // index of the displayed batch
  
  WOAssociation  *item;           // current item in the array
  WOAssociation  *index;          // current index
  WOAssociation  *identifier;     // unique id for element
  WOAssociation  *previousItem;   // predecessor of item  (used by isGroup)
  WOAssociation  *previousIndex;  // predecessor of index (used by isGroup)

  WOAssociation  *indexOfFirst;   // index of first displayed object
  WOAssociation  *indexOfLast;    // index of last  displayed object
  
  WOAssociation  *sortedKey;      // 
  WOAssociation  *isDescending;   //
  WOAssociation  *groups;         //
  WOAssociation  *showGroup;      //

  WOAssociation  *selection;      // 

  WOAssociation  *collapseOnClient; // use JS for collapsing default = NO
  WOAssociation  *scrollOnClient;   // use JS for scrolling  default = NO
  WOAssociation  *autoScroll;       // use overflow-scrolling (only IE)
  WOAssociation  *showBatchResizeButtons; // 
  
  WOAssociation  *sortAction;     // called if sort     button is clicked
  WOAssociation  *firstAction;    // called if first    button is clicked
  WOAssociation  *previousAction; // called if previous button is clicked
  WOAssociation  *nextAction;     // called if next     button is clicked
  WOAssociation  *lastAction;     // called if last     button is clicked

  // config stuff:
  WETableViewColorConfig *colors;
  WOAssociation  *groupColor;
  WOAssociation  *fontColor;
  WOAssociation  *fontFace;
  WOAssociation  *fontSize;

  WETableViewIconConfig *icons;
  WOAssociation  *groupOpenedIcon;
  WOAssociation  *groupClosedIcon;

  WETableViewLabelConfig *labels;
  
  WOAssociation  *border;
  WOAssociation  *cellspacing;
  WOAssociation  *cellpadding;

  WOAssociation  *showGroupTitle;
  
  // private stuff:
  NSArray          *allObjects;
  BOOL             doScript;       // generate JavaScript
  NSString         *scriptID;      // to unify the JavaScript
  WETableViewState *state;
  WOElement        *template;
}

- (void)_appendHeader:(WOResponse *)_response inContext:(WOContext *)_ctx;
- (void)_appendData:(WOResponse *)_response inContext:(WOContext *)_ctx;
- (void)_appendFooter:(WOResponse *)_response inContext:(WOContext *)_ctx;

- (void)updateStateInContext:(WOContext *)_ctx; // returns isAutoScroll

@end /* WETableView */

#include "WETableViewDefines.h"
#include "WETableViewState.h"
#include "WETableViewInfo.h"

static inline NSString *WETableLabelForKey(NSString *_key, WOContext *_ctx)
     __attribute__((unused));

#include <NGObjWeb/WOContext.h>
#import <Foundation/NSString.h>

static NSString *WETableLabelForKey(NSString *_key, WOContext *_ctx) {
  NSString *key;
  id tmp;
  
  key = [[NSString alloc] initWithFormat:@"WETableView_%@Label", _key];
  tmp = [_ctx objectForKey:key];
  [key release];
  return tmp;
}

@interface WETableView(Private)
- (void)_appendBatchResizeButtons:(WOResponse *)_response
  rowSpan:(unsigned int)_rowSpan
  actionUrl:(NSString *)_actionUrl
  inContext:(WOContext *)_ctx;
@end /* WETableView(Private) */

#endif /* __WETableView_H__ */
