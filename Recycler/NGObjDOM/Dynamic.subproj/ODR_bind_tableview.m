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

#include "ODR_bind_tableview.h"
#include "ODR_bind_tableview+Private.h"
#include "ODR_bind_groupings.h"

//#define PROFILE 1

#import <EOControl/EOControl.h>
#ifdef __APPLE__
#include <NGObjWeb/WEClientCapabilities.h>
#else
#include <WEExtensions/WEClientCapabilities.h>
#endif
#include <NGObjDOM/ODNamespaces.h>
#include <DOM/EDOM.h>
#include "common.h"
#include "ODR_bind_groupings.h"
#include "ODR_bind_sortorderings.h"

@interface NSDictionary(ODR_bind_tableview)

- (NSArray *)flattenedArrayWithHint:(unsigned int)_hint
  andOrderedKeys:(NSArray *)_keys;

/* attributesWithHint:... returns an array of arrays !!! */
- (NSArray *)attributesWithHint:(unsigned int)_hint
  andOrderedKeys:(NSArray *)_keys;
- (NGBitSet *)bitSetWithHint:(unsigned int)_hint;

@end

@implementation ODR_bind_tableview

/* selector caching for ctx */

static Class lastCtxClass = Nil;
static IMP   setObjForKey = NULL;
static IMP   remObjForKey = NULL;

static inline void _updateCtxCache(WOContext *_ctx) {
  if (_ctx == nil) return;
  if (lastCtxClass != *(Class *)_ctx) {
    lastCtxClass = *(Class *)_ctx;
    setObjForKey = [_ctx methodForSelector:@selector(setObject:forKey:)];
    remObjForKey = [_ctx methodForSelector:@selector(removeObjectForKey:)];
  }
}
static inline void ctxSet(WOContext *_ctx, NSString *_key, NSString *_value) {
  if (_ctx == nil) return;
  _updateCtxCache(_ctx);
  if (setObjForKey)
    setObjForKey(_ctx, @selector(setObject:forKey:), _value, _key);
  else
    [_ctx setObject:_value forKey:_key];
}
static inline void ctxDel(WOContext *_ctx, NSString *_key) {
  if (_ctx == nil) return;
  _updateCtxCache(_ctx);
  if (remObjForKey)
    remObjForKey(_ctx, @selector(removeObjectForKey:), _key);
  else
    [_ctx removeObjectForKey:_key];
}

/* initialization */

- (id)init {
  if ((self = [super init])) {
    self->list                 = nil;
    self->scriptID             = nil;
    self->groupedList          = nil;
    self->indexToGrouppath     = nil; // mapping index     -> group path
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->list);
  RELEASE(self->scriptID);
  RELEASE(self->indexToGrouppath);
  RELEASE(self->groupedList);
  
  [super dealloc];
}
#endif

- (BOOL)requiresFormForNode:(id)_node inContext:(WOContext *)_ctx {
  if ([self hasAttribute:@"selection" node:_node ctx:_ctx])
    return YES;

  return [self requiresFormForChildNodes:[_node childNodes] inContext:_ctx];
}

- (void)updateStateOfNode:(id)_node inContext:(WOContext *)_ctx {
  WEClientCapabilities *ccaps;
  BOOL                 isAutoScroll;
  NSArray              *array;
  NSArray              *groupings = nil;
  unsigned             batchIdx, size, cnt;
  BEGIN_PROFILE;

  //ccaps        = [[_ctx request] clientCapabilities];
  ccaps = nil;
  isAutoScroll = [ccaps doesSupportCSSOverflow];
  self->use.scriptScrolling  = [ccaps isInternetExplorer];
  self->use.scriptCollapsing = [ccaps isInternetExplorer];

  if (self->use.scriptCollapsing) {
    self->use.scriptCollapsing =
      [self boolFor:@"collapseonclient" node:_node ctx:_ctx];
  }
  
  if ([self intFor:@"overflowscroll" node:_node ctx:_ctx] < 10)
    isAutoScroll = NO;
  else if (isAutoScroll)
    self->use.scriptScrolling = NO;
  
  /* use JavaScript on InternetExplorer only */
  self->use.scriptScrolling = (self->use.scriptScrolling)
    ? (self->state.batchCount > 1)
    : NO;

  self->use.scriptScrolling = (self->use.scriptScrolling)
    ? [self boolFor:@"scrollonclient" node:_node ctx:_ctx]
    : NO;

  array = [self _sortedArrayOfNode:_node inContext:_ctx fetch:YES];

  batchIdx = [self   intFor:@"currentbatch" node:_node ctx:_ctx];
  size     = [self   intFor:@"batchsize"    node:_node ctx:_ctx];
  cnt      = [array count];
  size     = (isAutoScroll) ? cnt : size;
  batchIdx = (batchIdx) ? batchIdx : 1;
  batchIdx = ((batchIdx * size) < (cnt+size)) ? batchIdx : 1;

  // get groupings
  [_ctx setObject:@"YES" forKey:ODR_GroupingContainerMode];
  [self appendChildNodes:ODRLookupQueryPath(_node, @"-groupings")
        toResponse:nil
        inContext:_ctx];
  [_ctx removeObjectForKey:ODR_GroupingContainerMode];
  
  groupings = [_ctx objectForKey:ODR_GroupingContainer];
  ctxDel(_ctx, ODR_GroupingContainer);

  if ([groupings count] > 0) {
    EOGrouping   *grouping;

    grouping = [groupings lastObject];
    [grouping setDefaultName:@"default"];
    //    [grouping setSortOrderings:[fetchSpec sortOrderings]];

    RELEASE(self->groupedList);
    self->groupedList = [array arrayGroupedBy:grouping];
    RETAIN(self->groupedList);
   
    RELEASE(self->indexToGrouppath);
    self->indexToGrouppath =
      [self->groupedList attributesWithHint:[array count]
                         andOrderedKeys:[self->groupedList allKeys]];
    RETAIN(self->indexToGrouppath);

    array = [self->groupedList flattenedArrayWithHint:[array count]
                               andOrderedKeys:[self->groupedList allKeys]];
  }
  else {
    RELEASE(self->groupedList);      self->groupedList      = nil;
    RELEASE(self->indexToGrouppath); self->indexToGrouppath = nil;
  }

  ASSIGN(self->list, array);
  
  self->state.currentBatch = batchIdx;
  self->state.batchSize    = size;
  
  self->state.batchCount = (!size) ? 1 :(cnt / size) + ((cnt % size) ? 1 : 0);
  self->state.firstIndex = (batchIdx - 1) * size;
  self->state.lastIndex  = (size==0 || !((self->state.firstIndex+size) < cnt))
    ? cnt-1
    : self->state.firstIndex + size - 1;


  self->use.checkBoxes = [self hasAttribute:@"selection" node:_node ctx:_ctx];
  self->use.overflow   = isAutoScroll;
  END_PROFILE;
}


- (void)_setConfigDefaults:(id)_node inContext:(WOContext *)_ctx {
  BEGIN_PROFILE;
  ctxSet(_ctx, ODRTableView_toLabel,       @"-" );
  ctxSet(_ctx, ODRTableView_ofLabel,       @"/" );
  ctxSet(_ctx, ODRTableView_firstLabel,    @"<<");
  ctxSet(_ctx, ODRTableView_previousLabel, @"<" );
  ctxSet(_ctx, ODRTableView_nextLabel,     @">" );
  ctxSet(_ctx, ODRTableView_lastLabel,     @">>");
  END_PROFILE;
}

static void
_SetConfigInContext(ODR_bind_tableview *self, id _node, WOContext *_ctx,
                    NSString *_attr_, NSString *_key_)
{
  register NSString *tmp;

  if ((tmp = [self stringFor:_attr_ node:_node ctx:_ctx]))
    ctxSet(_ctx, _key_, tmp);
}

- (void)updateConfig:(id)_node inContext:(WOContext *)_ctx {
  BEGIN_PROFILE;

  [self _setConfigDefaults:_node inContext:_ctx];
  
  PROFILE_CHECKPOINT("config defaults");
  
#define SetConfigInContext(_attr_,_key_) \
  _SetConfigInContext(self,_node,_ctx,_attr_,_key_)
  
  SetConfigInContext(@"titleColor",      ODRTableView_titleColor);
  SetConfigInContext(@"headerColor",     ODRTableView_headerColor);
  SetConfigInContext(@"footerColor",     ODRTableView_footerColor);
  SetConfigInContext(@"evenColor",       ODRTableView_evenColor);
  SetConfigInContext(@"oddColor",        ODRTableView_oddColor);
  SetConfigInContext(@"fontColor",       ODRTableView_fontColor);
  SetConfigInContext(@"fontFace",        ODRTableView_fontFace);
  SetConfigInContext(@"fontSize",        ODRTableView_fontSize);

  PROFILE_CHECKPOINT("configs");
  
  SetConfigInContext(@"downwardIcon",    ODRTableView_downwardIcon);
  SetConfigInContext(@"upwardIcon",      ODRTableView_upwardIcon);
  SetConfigInContext(@"nonSortIcon",     ODRTableView_nonSortIcon);
  
  SetConfigInContext(@"firstIcon",       ODRTableView_first);
  SetConfigInContext(@"firstBlind",      ODRTableView_first_blind);
  SetConfigInContext(@"previousIcon",    ODRTableView_previous);
  SetConfigInContext(@"previousBlind",   ODRTableView_previous_blind);
  SetConfigInContext(@"nextIcon",        ODRTableView_next);
  SetConfigInContext(@"nextBlind",       ODRTableView_next_blind);
  SetConfigInContext(@"lastIcon",        ODRTableView_last);
  SetConfigInContext(@"lastBlind",       ODRTableView_last_blind);

  SetConfigInContext(@"openedIcon",      ODRTableView_openedIcon);
  SetConfigInContext(@"closedIcon",      ODRTableView_closedIcon);

  SetConfigInContext(@"minusResizeIcon", ODRTableView_minusIcon);
  SetConfigInContext(@"plusResizeIcon",  ODRTableView_plusIcon);
  
  SetConfigInContext(@"selectAllIcon",   ODRTableView_select_all);
  SetConfigInContext(@"deselectAllIcon", ODRTableView_deselect_all);

  PROFILE_CHECKPOINT("icons");
  
  SetConfigInContext(@"ofLabel",         ODRTableView_ofLabel);
  SetConfigInContext(@"toLabel",         ODRTableView_toLabel);
  SetConfigInContext(@"firstLabel",      ODRTableView_firstLabel);
  SetConfigInContext(@"previousLabel",   ODRTableView_previousLabel);
  SetConfigInContext(@"nextLabel",       ODRTableView_nextLabel);
  SetConfigInContext(@"lastLabel",       ODRTableView_lastLabel);
  SetConfigInContext(@"pageLabel",       ODRTableView_pageLabel);
  SetConfigInContext(@"sortLabel",       ODRTableView_sortLabel);
  
#undef SetConfigInContext
  END_PROFILE;
}

- (void)updateScriptIdInContext:(WOContext *)_ctx {
  NSArray  *tmp;
  NSString *str;
  
  tmp = [[_ctx elementID] componentsSeparatedByString:@"."];
  str = [tmp componentsJoinedByString:@"_"];
  
  ASSIGNCOPY(self->scriptID, str);
}

- (void)removeConfigInContext:(WOContext *)_ctx {
  BEGIN_PROFILE;
  ctxDel(_ctx,ODRTableView_titleColor);
  ctxDel(_ctx,ODRTableView_headerColor);
  ctxDel(_ctx,ODRTableView_footerColor);
  ctxDel(_ctx,ODRTableView_evenColor);
  ctxDel(_ctx,ODRTableView_oddColor);
  ctxDel(_ctx,ODRTableView_fontColor);
  ctxDel(_ctx,ODRTableView_fontFace);
  ctxDel(_ctx,ODRTableView_fontSize);
  
  ctxDel(_ctx,ODRTableView_downwardIcon);
  ctxDel(_ctx,ODRTableView_upwardIcon);
  ctxDel(_ctx,ODRTableView_nonSortIcon);

  ctxDel(_ctx,ODRTableView_first);
  ctxDel(_ctx,ODRTableView_first_blind);
  ctxDel(_ctx,ODRTableView_previous);
  ctxDel(_ctx,ODRTableView_previous_blind);
  ctxDel(_ctx,ODRTableView_next);
  ctxDel(_ctx,ODRTableView_next_blind);
  ctxDel(_ctx,ODRTableView_last);
  ctxDel(_ctx,ODRTableView_last_blind);
  ctxDel(_ctx,ODRTableView_select_all);
  ctxDel(_ctx,ODRTableView_deselect_all);

  ctxDel(_ctx,ODRTableView_ofLabel);
  ctxDel(_ctx,ODRTableView_toLabel);
  ctxDel(_ctx,ODRTableView_firstLabel);
  ctxDel(_ctx,ODRTableView_previousLabel);
  ctxDel(_ctx,ODRTableView_nextLabel);
  ctxDel(_ctx,ODRTableView_lastLabel);
  ctxDel(_ctx,ODRTableView_pageLabel);
  ctxDel(_ctx,ODRTableView_sortLabel);
  END_PROFILE;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  int            i, firstBatch, lastBatch;
  NSString       *eid;
  NSMutableArray *selArray = nil;
  BEGIN_PROFILE;

  [self updateStateOfNode:_node inContext:_ctx];

  eid = [_ctx elementID];

  // handle "data" section
  if (self->use.checkBoxes) {
    selArray = [self valueFor:@"selection" node:_node ctx:_ctx];
    selArray = (selArray == nil)
      ? [[NSMutableArray allocWithZone:[self zone]] init]
      : [selArray mutableCopyWithZone:[self zone]];
  }

  firstBatch = (self->use.scriptScrolling) ? 1 : self->state.currentBatch;
  
  lastBatch  = (self->use.scriptScrolling)
    ? self->state.batchCount
    : self->state.currentBatch;

  [_ctx appendElementIDComponent:@"data"];

  for (i = firstBatch; i <= lastBatch; i++) {    
    self->state.currentBatch = i;
    [self forceSetInt:i for:@"currentbatch" node:_node ctx:_ctx];
    [self updateStateOfNode:_node inContext:_ctx];

    [self takeValuesForNode:_node
          fromRequest:_request
          forBatch:i
          selections:selArray
          inContext:_ctx];
  }

  [_ctx deleteLastElementIDComponent]; // delete "data"

  if (self->use.checkBoxes) {
    [self setValue:selArray for:@"selection" node:_node ctx:_ctx];
    [selArray release];
  }

  {
    // handle header (sort buttons, ...)
    ctxSet(_ctx, ODRTableView_HeaderMode, @"YES");
    [_ctx appendElementIDComponent:@"header"];
  
    for (i = 1; i <= (int)self->state.batchCount; i++) {
      [_ctx appendElementIDComponent:[NSString stringWithFormat:@"%d", i]];
      [self takeValuesForChildNodes:[_node childNodes]
            fromRequest:_request
            inContext:_ctx];
      [_ctx deleteLastElementIDComponent]; // delete batchNumber
    }

    [_ctx deleteLastElementIDComponent]; // delete "header"
    ctxDel(_ctx, ODRTableView_HeaderMode);
  }

  // handle title
  ctxSet(_ctx, ODRTableView_TitleMode, @"YES");
  [_ctx appendElementIDComponent:@"title"];
  [self takeValuesForChildNodes:ODRLookupQueryPath(_node, @"-ttitle")
        fromRequest:_request
        inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete "title"
  ctxDel(_ctx, ODRTableView_TitleMode);
  
  // handle buttons
  ctxSet(_ctx, ODRTableView_ButtonMode, @"YES");
  [_ctx appendElementIDComponent:@"button"];
  [self takeValuesForChildNodes:ODRLookupQueryPath(_node, @"-tbutton")
        fromRequest:_request
        inContext:_ctx];
  [_ctx deleteLastElementIDComponent]; // delete "button"
  ctxDel(_ctx, ODRTableView_ButtonMode);

  // handle footer
  [_ctx appendElementIDComponent:@"footer"];

  // reset autoScrollHeight
  if ([_request formValueForKey:
                [eid stringByAppendingString:@".footer.pp.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".pp"]];
  }
  else if ([_request formValueForKey:
                     [eid stringByAppendingString:@".footer.mm.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".mm"]];
  }

  ctxSet(_ctx, ODRTableView_FooterMode, @"YES");
  [self takeValuesForChildNodes:ODRLookupQueryPath(_node, @"-tfooter")
        fromRequest:_request
        inContext:_ctx];
  ctxDel(_ctx, ODRTableView_FooterMode);
  [_ctx deleteLastElementIDComponent]; // delete "footer"

  if ([_request formValueForKey:[eid stringByAppendingString:@".first.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".first"]];
  }
  if ([_request formValueForKey:[eid stringByAppendingString:@".next.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".next"]];
  }
  if ([_request formValueForKey:[eid stringByAppendingString:@".last.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".last"]];
  }
  if ([_request formValueForKey:[eid stringByAppendingString:@".previous.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".previous"]];
  }

  END_PROFILE;
}

- (id)invokeDataActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *idxId;
  NSString *bn;
  id result = nil;
    
#if DEBUG && 0
  NSLog(@"%s:   data section eid=%@, sid=%@",
        __PRETTY_FUNCTION__, [_ctx elementID], [_ctx senderID]);
#endif
    
  bn = [_ctx currentElementID];
  [self forceSetInt:[bn intValue] for:@"currentbatch" node:_node ctx:_ctx];
  
  [_ctx consumeElementID];            // consume batchNumber
  [_ctx appendElementIDComponent:bn]; // append batch
  
#if DEBUG && 0
  NSLog(@"%s:   did data-batch section eid=%@, sid=%@",
        __PRETTY_FUNCTION__, [_ctx elementID], [_ctx senderID]);
#endif
  
  if ((idxId = [_ctx currentElementID])) {
    [_ctx consumeElementID];               // consume index-id
    [_ctx appendElementIDComponent:idxId]; // append index-id

#if DEBUG && 0
    NSLog(@"%s:   did data-index section (idx=%@) eid=%@, sid=%@",
          __PRETTY_FUNCTION__, idxId, [_ctx elementID], [_ctx senderID]);
#endif
    
    /* reset batchSize */
    if ([idxId isEqualToString:@"pp"])
      result = [self increaseBatchSize:_node inContext:_ctx];
    else if ([idxId isEqualToString:@"mm"])
      result = [self decreaseBatchSize:_node inContext:_ctx];
    else {
      if (![self hasAttribute:@"identifier" node:_node ctx:_ctx]) {
        unsigned idx;
      
        idx   = [idxId unsignedIntValue];
        if (idx < [self->list count] && idx >= 0)
          [self _applyItemForIndex:idx node:_node ctx:_ctx];
        else
          NSLog(@"%s: index is out of range!", __PRETTY_FUNCTION__);
      }
      else
        [self _applyIdentifier:idxId node:_node ctx:_ctx];

      result = [self _invokeGrouping:_node
                     fromRequest:_request
                     inContext:_ctx];
    }
    [_ctx deleteLastElementIDComponent]; // delete index-id
  }
#if DEBUG
  else {
    NSLog(@"%s:   missing idx section eid=%@, sid=%@",
          __PRETTY_FUNCTION__, [_ctx elementID], [_ctx senderID]);
  }
#endif
    
  [_ctx deleteLastElementIDComponent]; // delete batchNumber

  return result;
}

- (id)invokeHeaderActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  id  result = nil;
  int bn;

  if ([self isSettable:@"currentbatch" node:_node ctx:_ctx]) {
    bn = [[_ctx currentElementID] intValue];
    [self setInt:bn for:@"currentbatch" node:_node ctx:_ctx];
  }
  [_ctx appendElementIDComponent:[_ctx currentElementID]]; // batchNumber
  [_ctx consumeElementID];                         // consume batchNumber

  // handle selectAllCheckBoxes:
  if ([[_ctx currentElementID] isEqualToString:@"_sa"]) {
    NSMutableArray *selArray;
        
    selArray = [self->list mutableCopyWithZone:[self zone]];
    // ??? [self->selection setValue:selArray inComponent:cmp];
    RELEASE(selArray);
  }
  // handle deselectAllCheckBoxes:
  else if ([[_ctx currentElementID] isEqualToString:@"_dsa"]) {
    ; // ???[self->selection setValue:[NSMutableArray array] inComponent:cmp];
  }
  else {
    ctxSet(_ctx, ODRTableView_HeaderMode, @"YES");
    result = [self invokeActionForChildNodes:[_node childNodes]
                   fromRequest:_request inContext:_ctx];
    ctxDel(_ctx, ODRTableView_HeaderMode);
  } 
  [_ctx deleteLastElementIDComponent]; // delete batchNumber
  
  return result;
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *eid;
  NSArray  *children;
  id       result;

#if DEBUG && 0
  NSLog(@"%s: node=%@, eid=%@, sid=%@",
        __PRETTY_FUNCTION__, _node, [_ctx elementID], [_ctx senderID]);
#endif
  
  [self updateStateOfNode:_node inContext:_ctx];

  eid = [_ctx currentElementID];

  if ([eid isEqual:@"first"])
    return [self _handleFirstButton:_node inContext:_ctx];
  else if ([eid isEqual:@"previous"])
    return [self _handlePreviousButton:_node inContext:_ctx];
  else if ([eid isEqual:@"next"])
    return [self _handleNextButton:_node inContext:_ctx];
  else if ([eid isEqual:@"last"])
    return [self _handleLastButton:_node inContext:_ctx];
  else if ([eid isEqual:@"data"]) {
    [_ctx consumeElementID];             // consume "data"
    [_ctx appendElementIDComponent:eid]; // append  "data"
    
    result = [self invokeDataActionForNode:_node
                   fromRequest:_request
                   inContext:_ctx];
    
    [_ctx deleteLastElementIDComponent]; // delete "data"
  }
  else if ([eid isEqual:@"header"]) {
    [_ctx consumeElementID];             // consume "header"
    [_ctx appendElementIDComponent:eid]; // append  "header"
    
    result = [self invokeHeaderActionForNode:_node
                   fromRequest:_request
                   inContext:_ctx];
    
    [_ctx deleteLastElementIDComponent]; // delete "header"

    [self _handleSortAction:_node inContext:_ctx];
    
    ctxDel(_ctx, ODRTableView_SORTEDKEY);
    ctxDel(_ctx, ODRTableView_ISDESCENDING);
  }
  else if ([eid isEqual:@"title"]) {
    children = ODRLookupQueryPath(_node, @"-ttitle");
    
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:@"title"];

    eid = [_ctx currentElementID];
    ctxSet(_ctx, ODRTableView_TitleMode, @"YES");
    result = [self invokeActionForChildNodes:children
                   fromRequest:_request inContext:_ctx];
    ctxDel(_ctx, ODRTableView_TitleMode);
    
    [_ctx deleteLastElementIDComponent];
  }
  else if ([eid isEqual:@"button"]) {
    children = ODRLookupQueryPath(_node, @"-tbutton");
    
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:@"button"];

    eid = [_ctx currentElementID];
    ctxSet(_ctx, ODRTableView_ButtonMode, @"YES");
    result = [self invokeActionForChildNodes:children
                   fromRequest:_request inContext:_ctx];
    ctxDel(_ctx, ODRTableView_ButtonMode);
    
    [_ctx deleteLastElementIDComponent];
  }
  else if ([eid isEqual:@"footer"]) {
    children = ODRLookupQueryPath(_node, @"-tfooter");
    
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:@"footer"];

    eid = [_ctx currentElementID];
    
    // reset autoScrollHeight
    if ([eid isEqualToString:@"pp"])
      result = [self increaseAutoScrollHeight:_node inContext:_ctx];
    else if ([eid isEqualToString:@"mm"])
      result = [self decreaseAutoScrollHeight:_node inContext:_ctx];
    else {
      ctxSet(_ctx, ODRTableView_FooterMode, @"YES");
      result = [self invokeActionForChildNodes:children
                     fromRequest:_request inContext:_ctx];
      ctxDel(_ctx, ODRTableView_FooterMode);
    }
    
    [_ctx deleteLastElementIDComponent];
  }
  else
    result = [self invokeActionForChildNodes:[_node childNodes]
                   fromRequest:_request inContext:_ctx];
  
  return result;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  BEGIN_PROFILE;
  
  [self updateStateOfNode:_node inContext:_ctx];
  [self updateScriptIdInContext:_ctx];
  [self updateConfig:_node      inContext:_ctx];
  
  /* open tableView */
  [_response appendContentString:
          @"<table border='0' width='100%' cellpadding='0' cellspacing='0'>"];

  /* append tableTitle + navigation */
  [self _appendTitle:_node toResponse:_response inContext:_ctx];

  [_response appendContentString:@"<tr><td></td></tr>\n"];
  
  if (self->use.scriptScrolling) {
    [self _appendTableContentAsScript:_node
          toResponse:_response
          inContext:_ctx]; //close tables
  }
  else {
    /* open header + data area */
    [_response appendContentString:@"\n<tr><td>\n"];
    
    if (self->use.overflow) {
      [_response appendContentString:
                 @"<p style=\"width:100%; height: "];
      [_response appendContentString:
                   [self stringFor:@"overflowscroll" node:_node ctx:_ctx]];
      [_response appendContentString:@"; overflow-y: auto\">"];
    }
    
    [_response appendContentString:
                 @"<table border='0' width='100%' "
                 @"cellpadding='1' cellspacing='0'>"];

    self->use.batchResizeButtons =
      ([self boolFor:@"showbatchresizebuttons" node:_node ctx:_ctx] &&
       (self->state.currentBatch < self->state.batchCount) &&
       !self->use.overflow);
    
    [self _appendHeader:_node toResponse:_response inContext:_ctx];
    [self _appendData:_node   toResponse:_response inContext:_ctx];
  
    [_response appendContentString:@"</table>\n"];
    if (self->use.overflow)
      [_response appendContentString:@"</p>"];
    
    /* close header + data area */
    [_response appendContentString:@"</td></tr>\n"];
    
    [_response appendContentString:@"</table>\n"];                  // </TABLE>

    /* append footer */
    [self _appendFooter:_node toResponse:_response inContext:_ctx];
  }
  
  // close tableView
  
  if (self->use.scriptScrolling)
    [self appendJavaScript:_response inContext:_ctx];
  
  [self removeConfigInContext:_ctx];

  END_PROFILE;
}

@end /* ODR_bind_tableview */

@implementation ODR_bind_ttitle : ODNodeRenderer

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if ([[_ctx objectForKey:ODRTableView_TitleMode] boolValue])
    [super takeValuesForNode:_node fromRequest:_request inContext:_ctx];
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  return ([[_ctx objectForKey:ODRTableView_TitleMode] boolValue])
    ? [super invokeActionForNode:_node fromRequest:_request inContext:_ctx]
    : nil;
}

- (void)appendNode:(id)_node
        toResponse:(WOResponse *)_response
         inContext:(WOContext *)_ctx
{
  if ([[_ctx objectForKey:ODRTableView_TitleMode] boolValue])
    [super appendNode:_node toResponse:_response inContext:_ctx];
}

@end

@implementation ODR_bind_tbutton : ODNodeRenderer

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if ([[_ctx objectForKey:ODRTableView_ButtonMode] boolValue])
    [super takeValuesForNode:_node fromRequest:_request inContext:_ctx];
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  return ([[_ctx objectForKey:ODRTableView_ButtonMode] boolValue])
    ? [super invokeActionForNode:_node fromRequest:_request inContext:_ctx]
    : nil;
}

- (void)appendNode:(id)_node
        toResponse:(WOResponse *)_response
         inContext:(WOContext *)_ctx
{
  if ([[_ctx objectForKey:ODRTableView_ButtonMode] boolValue])
    [super appendNode:_node toResponse:_response inContext:_ctx];
}
@end

@implementation ODR_bind_tfooter : ODNodeRenderer

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if ([[_ctx objectForKey:ODRTableView_FooterMode] boolValue])
    [super takeValuesForNode:_node fromRequest:_request inContext:_ctx];
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  return ([[_ctx objectForKey:ODRTableView_FooterMode] boolValue])
    ? [super invokeActionForNode:_node fromRequest:_request inContext:_ctx]
    : nil;
}

- (void)appendNode:(id)_node
        toResponse:(WOResponse *)_response
         inContext:(WOContext *)_ctx
{
  if ([[_ctx objectForKey:ODRTableView_FooterMode] boolValue])
    [super appendNode:_node toResponse:_response inContext:_ctx];
}
@end

@implementation ODR_bind_tgroup : ODNodeRenderer

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if ([[_ctx objectForKey:ODRTableView_GroupMode] boolValue])
    [super takeValuesForNode:_node fromRequest:_request inContext:_ctx];
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  //  NSLog(@"tgroup ... invokeActionForNode ");
  return nil;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if (![[_ctx objectForKey:ODRTableView_GroupMode] boolValue])
    return;
  
  if ([self isSettable:@"items" node:_node ctx:_ctx])
    [self setValue:[_ctx objectForKey:ODRTableView_GroupItems]
          for:@"items"
          node:_node
          ctx:_ctx];

  if ([self isSettable:@"groupname" node:_node ctx:_ctx])
    [self setString:[_ctx objectForKey:ODRTableView_GroupName]
          for:@"groupname"
          node:_node
          ctx:_ctx];

  [self appendChildNodes:[_node childNodes]
        toResponse:_response
        inContext:_ctx];
}
@end

@implementation ODRTableViewInfo
@end


#define ProfileComponents NO

@implementation NSDictionary(ODR_bind_tableview)

- (NSArray *)flattenedArrayWithHint:(unsigned int)_hint
                     andOrderedKeys:(NSArray *)_keys
{
  NSMutableArray *result  = nil;
  unsigned int   i, cnt;
  NSTimeInterval st     = 0.0;
  
  if (ProfileComponents)
    st = [[NSDate date] timeIntervalSince1970];


  result = [[NSMutableArray allocWithZone:[self zone]]
                            initWithCapacity:_hint]; // should be improved

  for (i = 0, cnt = [_keys count]; i < cnt; i++) {
    NSString *key;
    NSArray  *tmp;

    key = [_keys objectAtIndex:i];
    tmp = [self objectForKey:key];
    [result addObjectsFromArray:tmp];
  }

  if (ProfileComponents) {
    NSTimeInterval diff;
    diff = [[NSDate date] timeIntervalSince1970] - st;
    
    printf("NSDictionary.flattenedArray: %0.4fs\n", diff);
  }
  
  return result;
}

- (NSArray *)attributesWithHint:(unsigned int)_hint
                        andOrderedKeys:(NSArray *)_keys
{
  NSMutableArray *result  = nil;
  unsigned int   i, cnt;
  NSTimeInterval st     = 0.0;
  
  if (ProfileComponents)
    st = [[NSDate date] timeIntervalSince1970];

  result = [[NSMutableArray allocWithZone:[self zone]]
                            initWithCapacity:_hint+1];

  for (i = 0, cnt = [_keys count]; i < cnt; i++) {
    unsigned j, cnt2;
    NSString *key;

    key  = [_keys objectAtIndex:i];

    cnt2 = [[self objectForKey:key] count];
    for (j = 0; j < cnt2; j++)
      /* ??? [result addObject:key]; */
      [result addObject:[NSArray arrayWithObject:key]];
  }

  if (ProfileComponents) {
    NSTimeInterval diff;
    diff = [[NSDate date] timeIntervalSince1970] - st;
    
    printf("NSDictionary.attributes: %0.4fs\n", diff);
  }
  
  return result;
}

- (NGBitSet *)bitSetWithHint:(unsigned int)_hint {
  NGBitSet     *bitSet  = nil;
  NSEnumerator *keyEnum = [self keyEnumerator];
  NSString     *key     = nil;
  unsigned int firstPos = 0;
  NSTimeInterval st     = 0.0;
  
  if (ProfileComponents)
    st = [[NSDate date] timeIntervalSince1970];
 
  bitSet = [NGBitSet bitSetWithCapacity:_hint];
  
  while ((key = [keyEnum nextObject])) {
    [bitSet addMember:firstPos];
    firstPos += [[self objectForKey:key] count];
  }

  if (ProfileComponents) {
    NSTimeInterval diff;
    diff = [[NSDate date] timeIntervalSince1970] - st;
    
    printf("NSDictionary.bitSet: %0.4fs\n", diff);
  }
  
  return bitSet;
}

@end /* NSDictionary(ODR_bind_tableview) */
