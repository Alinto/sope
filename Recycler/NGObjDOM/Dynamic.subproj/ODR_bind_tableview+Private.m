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

/*

  elementID structure:

  dataSection:

    ["data"].[batchSize].[identifier|index]

*/

#include "ODR_bind_tableview+Private.h"

//#define PROFILE 1

#import <EOControl/EOControl.h>
#include <NGObjDOM/ODNamespaces.h>
#include <DOM/EDOM.h>
#include "common.h"
#include "ODR_bind_sortorderings.h"

@implementation ODR_bind_tableview(Private_Rendering)

static inline void _rawAdd(WOResponse *response, NSString *s) {
  /* appendContentString: with selector caching */
#define sel @selector(appendContentString:)
  static IMP   add       = NULL;
  static Class lastClass = Nil;
  
  if ((response == nil) || (s == nil)) return;
  
  if ((*(Class *)response) == lastClass) {
    if (add)
      add(response, sel, s);
    else
      [response appendContentString:s];
  }
  else {
    lastClass = (*(Class *)response);
    if ((add = [response methodForSelector:sel]))
      add(response, sel, s);
    else
      [response appendContentString:s];
  }
#undef sel
}

- (void)_applyIdentifier:(NSString *)_id node:(id)_node ctx:(WOContext *)_ctx {
  unsigned count;
  BEGIN_PROFILE;
  
  count = [self->list count];

  if (count > 0) {
    unsigned i;

    /* find subelement for unique id */
    
    for (i = 0; i < count; i++) {
      NSString *ident;
      
      if ([self isSettable:@"index" node:_node ctx:_ctx])
        [self setInt:i for:@"index" node:_node ctx:_ctx];

      if ([self isSettable:@"item" node:_node ctx:_ctx]) {
        [self setValue:[self->list objectAtIndex:i] for:@"item"
                  node:_node                        ctx:_ctx];

      }
      if ([self isSettable:@"previousitem" node:_node ctx:_ctx]) {
        [self setValue:(i > self->state.firstIndex)
              ? [self->list objectAtIndex:i-1] : nil
              for:@"previousitem" node:_node ctx:_ctx];
      }
      if ([self isSettable:@"previousindex" node:_node ctx:_ctx])
        [self setInt:(i-1) for:@"previousindex" node:_node ctx:_ctx];

      ident = [self stringFor:@"identifier" node:_node ctx:_ctx];

      if ([ident isEqualToString:_id]) {
        /* found subelement with unique id */
        return;
      }
    }
    
    [[_ctx component] logWithFormat:
          @"tableview: array did change, "
          @"unique-id isn't contained."];
    if ([self isSettable:@"item" node:_node ctx:_ctx])
      [self setValue:nil for:@"item"  node:_node ctx:_ctx];
    if ([self isSettable:@"index" node:_node ctx:_ctx])
      [self setValue:0   for:@"index" node:_node ctx:_ctx];
  }
  
  END_PROFILE;
}

- (void)_applyItemForIndex:(int)_i node:(id)_node ctx:(WOContext *)_ctx {
  unsigned count;
  BEGIN_PROFILE;
  
  count = [self->list count];
  
  if ([self isSettable:@"index" node:_node ctx:_ctx])
    [self setInt:_i for:@"index" node:_node ctx:_ctx];
  
  if ([self isSettable:@"item" node:_node ctx:_ctx]) {
    id obj;

    obj = ((count > 0) && ((int)count > _i))
      ? [self->list objectAtIndex:_i]
      : nil;
    
    [self setValue:obj for:@"item" node:_node ctx:_ctx];
  }
  
  if ([self isSettable:@"previousitem" node:_node ctx:_ctx]) {
    id obj;
    
    if (_i > (int)self->state.firstIndex) {
      obj = ((count > 0) && ((int)count > (_i - 1)))
        ? [self->list objectAtIndex:(_i - 1)]
        : nil;
    }
    else
      obj = nil;
    
    [self setValue:obj for:@"previousitem" node:_node ctx:_ctx];
  }
  
  if ([self isSettable:@"previousindex" node:_node ctx:_ctx])
    [self setInt:(_i - 1) for:@"previousindex" node:_node ctx:_ctx];
  
  END_PROFILE;
}

- (NSString *)labelForKey:(NSString *)_key ctx:(WOContext *)_ctx {
  NSString *key;
  key = [NSString stringWithFormat:@"ODRTableView_%@Label", _key];
  return [_ctx objectForKey:key];
}

- (void)_appendNav:(NSString *)_nav isBlind:(BOOL)_isBlind
  toResponse:(WOResponse *)_response inContext:(WOContext *)_ctx
{
  NSString *imgUri = nil;
  NSString *label  = nil;
  BOOL     doForm;
  BEGIN_PROFILE;

  doForm  = [_ctx isInForm];
  
  imgUri = [ODRTableView_ stringByAppendingString:_nav];
  imgUri = [imgUri stringByAppendingString:(_isBlind) ? @"_blind" : @""];
  imgUri = [_ctx objectForKey:imgUri];
  imgUri = ODRUriOfResource(imgUri,_ctx);

  label  = [self labelForKey:_nav ctx:_ctx];
  
  _rawAdd(_response, @"<td valign='middle'>");
  // append as submit button
  if (doForm && !_isBlind && self->use.scriptScrolling && (imgUri != nil)) {
    [_ctx appendElementIDComponent:_nav];
    ODRAppendButton(_response, [_ctx elementID], imgUri, label);
    [_ctx deleteLastElementIDComponent];
  }
  else {
    /* open anker */
    if (!_isBlind || self->use.scriptScrolling) {
      [_ctx appendElementIDComponent:_nav];
      _rawAdd(_response, @"<a href=\"");
      if (self->use.scriptScrolling)
        [self _appendScriptLink:_response name:_nav];
      else
        _rawAdd(_response, [_ctx componentActionURL]);
      _rawAdd(_response, @"\">");
    }
    if (imgUri == nil) {
      [_response appendContentCharacter:'['];
      _rawAdd(_response, label);
      [_response appendContentCharacter:']'];
    }
    else {
      ODRAppendImage(_response,
                     [NSString stringWithFormat:@"%@PageImg%@",
                               _nav, self->scriptID], // ??? 
                     imgUri,
                     label);
    }
    /* close anker */
    if (!_isBlind || self->use.scriptScrolling) {
      _rawAdd(_response, @"</a>");
      [_ctx deleteLastElementIDComponent];
    }
    _rawAdd(_response, @"</td>");
  }
  END_PROFILE;
}

- (void)_appendNavigation:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSArray *buttons;
  int     batch, batchCount;
  BOOL    isFirstBlind, isPreviousBlind, isNextBlind, isLastBlind, didTD;
  
  batch      = self->state.currentBatch;
  batchCount = self->state.batchCount;
  didTD      = NO;

  isFirstBlind    = (batch < 2);
  isPreviousBlind = (batch < 2);
  isNextBlind     = ((batchCount-1) < batch);
  isLastBlind     = ((batchCount-1) < batch);

  _rawAdd(_response, 
          @"<table border='0' cellspacing='0' cellpadding='0'><tr>");

  if (!(isFirstBlind && isPreviousBlind && isNextBlind && isLastBlind)) {
    [self _appendNav:@"first"    isBlind:isFirstBlind
          toResponse:_response   inContext:_ctx];
    [self _appendNav:@"previous" isBlind:isPreviousBlind
          toResponse:_response   inContext:_ctx];
    didTD = YES;
  }

  /* append extra buttons */
  buttons = ODRLookupQueryPath(_node, @"-tbutton");
  if ([buttons count]) {
    _rawAdd(_response, @"<td valign='middle'>");
    [_ctx appendElementIDComponent:@"button"];
    [_ctx setObject:@"YES" forKey:ODRTableView_ButtonMode];
    [super appendChildNodes:buttons toResponse:_response inContext:_ctx];
    [_ctx removeObjectForKey:ODRTableView_ButtonMode];
    [_ctx deleteLastElementIDComponent];
    _rawAdd(_response, @"</td>");
    didTD = YES;
  }
  
  if (!(isFirstBlind && isPreviousBlind && isNextBlind && isLastBlind)) {
    [self _appendNav:@"next"     isBlind:isNextBlind
          toResponse:_response  inContext:_ctx];
    [self _appendNav:@"last"     isBlind:isLastBlind
          toResponse:_response  inContext:_ctx];
    didTD = YES;
  }

  if (!didTD)
    _rawAdd(_response, @"<td>&nbsp;</td>");
  
  _rawAdd(_response, @"</tr></table>");
}

- (void)_appendTitle:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *bg;
  NSArray  *titles;

  bg = [_ctx objectForKey:ODRTableView_titleColor];
  titles = ODRLookupQueryPath(_node, @"-ttitle");
  
  _rawAdd(_response, @"<tr><td>");

  /* open title bar*/
  _rawAdd(_response, 
             @"<table border='0' width='100%' cellpadding='0' cellspacing='0'>"
             @"<tr>");

  /* append title */
  [_ctx appendElementIDComponent:@"title"];
  [_ctx setObject:@"YES" forKey:ODRTableView_TitleMode];
  ODRAppendTD(_response, @"left", @"middle", bg, nil);               // <TD..>
  if ([titles count] > 0)
    [super appendChildNodes:titles toResponse:_response inContext:_ctx];
  else
    _rawAdd(_response, @"&nbsp;");
  
  _rawAdd(_response, @"</td>");                        // </TD>
  [_ctx deleteLastElementIDComponent]; // delete "title"
  [_ctx removeObjectForKey:ODRTableView_TitleMode];

  /* append navigation + extra buttons */
  ODRAppendTD(_response, @"right", @"middle", bg, nil);              // <TD..>
  [self _appendNavigation:_node toResponse:_response inContext:_ctx];
  _rawAdd(_response, @"</td>");                        // </TD>
  
  /* close title bar*/
  _rawAdd(_response, @"</tr></table>");
  _rawAdd(_response, @"</td></tr>");
}

- (void)_appendHeader:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  [_ctx setObject:[self stringFor:@"sortedkey" node:_node ctx:_ctx]
        forKey:ODRTableView_SORTEDKEY];
  
  [_ctx setObject:[NSNumber numberWithBool:
                            [self boolFor:@"isdescending" node:_node ctx:_ctx]]
        forKey:ODRTableView_ISDESCENDING];

  [_ctx setObject:@"YES" forKey:ODRTableView_HeaderMode];
  _rawAdd(_response, @"<tr>");

  [_ctx appendElementIDComponent:@"header"];
  // append batchNumber
  {
    NSString *bn;
    bn = [self stringForInt:self->state.currentBatch];
    //bn = [NSString stringWithFormat:@"%d", self->state.currentBatch];
    [_ctx appendElementIDComponent:bn];
  }
  
  if (self->use.checkBoxes) {
    _rawAdd(_response, 
               @"<td  width=\"1%\" align=\"center\" bgcolor=\"");
    _rawAdd(_response, 
               [_ctx objectForKey:ODRTableView_headerColor]);
    _rawAdd(_response, @"\">");

    [_ctx appendElementIDComponent:@"_sa"];
    [self _appendCheckboxToResponse:_response
          ctx:_ctx
          value:@"selectAll"
          isChecked:[self boolFor:@"selectall" node:_node ctx:_ctx]];

    [_ctx deleteLastElementIDComponent]; // delete "_sa" ==> SelectAll

    _rawAdd(_response, @"</td>");
  }

  [self appendChildNodes:[_node childNodes]
        toResponse:_response
        inContext:_ctx];
  
  [_ctx deleteLastElementIDComponent]; // delete batchNumber
  [_ctx deleteLastElementIDComponent]; // delete "header"

  if (self->use.batchResizeButtons) {
    int cnt;

    cnt = (self->state.lastIndex - self->state.firstIndex + 1);

    if (cnt == (int)self->state.batchSize && !self->use.overflow) {
      _rawAdd(_response, @"<td width='1%'");
      if ([_ctx objectForKey:ODRTableView_headerColor]) {
        _rawAdd(_response, @" bgcolor='");
        _rawAdd(_response, 
                   [_ctx objectForKey:ODRTableView_headerColor]);
        _rawAdd(_response, @"'");
      }
      _rawAdd(_response, @"></td>");
    }
  }
  
  _rawAdd(_response, @"</tr>");
  [_ctx removeObjectForKey:ODRTableView_HeaderMode];
  [_ctx removeObjectForKey:ODRTableView_SORTEDKEY];
  [_ctx removeObjectForKey:ODRTableView_ISDESCENDING];
}


- (NSArray *)_collectData:(id)_node inContext:(WOContext *)_ctx {
  NSAutoreleasePool *pool;
  NSArray           *children  = nil;
  NSMutableArray    *matrix    = nil;
  NSMutableArray    *headInfos = nil;
  NSString          *k         = nil;
  id                oldGroup   = nil;
  int               i, first, last;
  int               sortedHeadIndex = -2;
  BEGIN_PROFILE;
  
  pool   = [[NSAutoreleasePool alloc] init];
  k      = [self stringFor:@"sortedkey" node:_node ctx:_ctx];

  first  = self->state.firstIndex;
  last   = self->state.lastIndex;
  matrix = [NSMutableArray arrayWithCapacity:last-first+1];

  [_ctx setObject:k      forKey:ODRTableView_SORTEDKEY];
  [_ctx setObject:@"YES" forKey:ODRTableView_CollectMode];

  self->state.groupCount = 0;

  children = (NSArray *)[_node childNodes];
  
  i = ([children count] > 0) ? first : last+1;
  i = first;
    
  for (; i<=last; i++) {
    NSMutableArray *infos = nil;
    NSString       *tmp   = nil;

    [self _applyItemForIndex:i node:_node ctx:_ctx];
    
    [_ctx removeObjectForKey:ODRTableView_INFOS];
    [self appendChildNodes:children
          toResponse:nil
          inContext:_ctx];
    infos = [_ctx objectForKey:ODRTableView_INFOS];

    NSAssert(infos != nil, @"Infos is nil.");

    if (headInfos == nil) {
      unsigned j, cnt;
      headInfos = [[NSMutableArray alloc] initWithArray:infos];

      for (j=0, cnt=[headInfos count]; j<cnt; j++) {
        ODRTableViewInfo *headInfo = [headInfos objectAtIndex:j];
        
        headInfo->isEven = (((i-first) % 2) == 0) ? YES : NO;
      }
    }
    else {
      unsigned j, cnt;
      BOOL     isEven = NO;

      cnt = [infos count];
      
      if (sortedHeadIndex == -2) { // first time
        for (j=0; j < cnt; j++) {
          ODRTableViewInfo *info;

          info = [infos objectAtIndex:j];
          if (info->isSorted) {
            sortedHeadIndex = j;
            break;
          }
        }
        sortedHeadIndex = (sortedHeadIndex < 0) ? -1 : sortedHeadIndex;
      }

      if (cnt) {
        ODRTableViewInfo *headInfo;
        ODRTableViewInfo *info;

        if (sortedHeadIndex >= 0) {
          NSAssert(sortedHeadIndex < (int)cnt, 
                   @"SortedHeadIndex out of range!!!");
          headInfo = [headInfos objectAtIndex:sortedHeadIndex];
          info     = [infos     objectAtIndex:sortedHeadIndex];
          isEven = (!info->isGroup) ? !headInfo->isEven : headInfo->isEven;
        }
        else { // sortedHeadIndex == -1 --> no column is sorted
          headInfo = [headInfos lastObject];
          isEven = !headInfo->isEven;
        }
      }

      for (j = 0; j < cnt; j++) {
        ODRTableViewInfo *info     = [infos     objectAtIndex:j];
        ODRTableViewInfo *headInfo = [headInfos objectAtIndex:j];

        if (!info->isGroup || ((int)j != sortedHeadIndex)) {
          info->isEven  = isEven;
          info->isGroup = NO;
          [headInfos replaceObjectAtIndex:j withObject:info];
        }
        else
          headInfo->rowSpan++;
      }
    }

    // ??? tmp = [self valueFor:@"currentGroup" node:_node ctx:_ctx];
    if (self->indexToGrouppath) {
      tmp = ((int)[self->indexToGrouppath count] > i)
        ? [self->indexToGrouppath objectAtIndex:i]
        : nil;
    }
    if ((tmp != nil) && ![oldGroup isEqual:tmp]) {
      oldGroup = tmp;
      self->state.groupCount++;
      [infos addObject:tmp];
      [infos addObject:ODRTableView_GroupMode];
    }

    [matrix addObject:infos];
  }
  [_ctx removeObjectForKey:ODRTableView_INFOS];
  [_ctx removeObjectForKey:ODRTableView_SORTEDKEY];
  [_ctx removeObjectForKey:ODRTableView_CollectMode];

  RETAIN(matrix);
  RELEASE(headInfos);
  RELEASE(pool);

  END_PROFILE;
  return AUTORELEASE(matrix);
}

- (void)_appendResizeButtons:(id)_node
  toResponse:(WOResponse *)_response
  actionUrl:(NSString *)_actionUrl
  inContext:(WOContext *)_ctx
{
  NSString *img;
  NSString *uri;
  BEGIN_PROFILE;

  // append batchSize--Button  
  img = [_ctx objectForKey:ODRTableView_minusIcon];
  img = ODRUriOfResource(img, _ctx);
  uri = [_actionUrl stringByAppendingString:@".mm"];
  
  if (img && [_ctx isInForm]) {
    uri = [[uri componentsSeparatedByString:@"/"] lastObject];
    _rawAdd(_response, @"<input type=\"image\" border=\"0\"");
    _rawAdd(_response, @" name=\"");
    _rawAdd(_response, uri);
    _rawAdd(_response, @"\" src=\"");
    _rawAdd(_response, img);
    _rawAdd(_response, @"\">");
  }
  else {
    _rawAdd(_response, @"<a href=\"");
    _rawAdd(_response, uri);
    _rawAdd(_response, @"\">");
  }
  
  if (img && ![_ctx isInForm]) {
    _rawAdd(_response, @"<img border=\"0\" src=\"");
    _rawAdd(_response, img);
    _rawAdd(_response, @"\" />");
  }
  else if (!img)
    _rawAdd(_response, @"-");

  if (!(img && [_ctx isInForm]))
    _rawAdd(_response, @"</a>");

  // append batchSize--Button
  img = [_ctx objectForKey:ODRTableView_plusIcon];
  img = ODRUriOfResource(img, _ctx);
  uri = [_actionUrl stringByAppendingString:@".pp"];
  
  if (img && [_ctx isInForm]) {
    uri = [[uri componentsSeparatedByString:@"/"] lastObject];
    _rawAdd(_response, @"<input type=\"image\" border=\"0\"");
    _rawAdd(_response, @" name=\"");
    _rawAdd(_response, uri);
    _rawAdd(_response, @"\" src=\"");
    _rawAdd(_response, img);
    _rawAdd(_response, @"\" />");
  }
  else {
    _rawAdd(_response, @"<a href=\"");
    _rawAdd(_response, uri);
    _rawAdd(_response, @"\">");
  }
  
  if (img && ![_ctx isInForm]) {
    _rawAdd(_response, @"<img border=\"0\" src=\"");
    _rawAdd(_response, img);
    _rawAdd(_response, @"\" />");
  }
  else if (!img)
    _rawAdd(_response, @"+");

  if (!(img && [_ctx isInForm]))
    _rawAdd(_response, @"</a>");
  
  END_PROFILE;
}

- (void)_appendBatchResizeButtons:(id)_node
  toResponse:(WOResponse *)_response
  rowSpan:(unsigned int)_rowSpan
  actionUrl:(NSString *)_actionUrl
  inContext:(WOContext *)_ctx
{
  BEGIN_PROFILE;
  // open "td"
  _rawAdd(_response, 
              @"<td align='center' valign='bottom' width='5' rowspan='");
  _rawAdd(_response, [self stringForInt:_rowSpan]);
  [_response appendContentCharacter:'\''];
#if 0
  _rawAdd(_response, [NSString stringWithFormat:
      @"<td align='center' valign='bottom' width='5' rowspan='%d'", _rowSpan]);
#endif
  
  if ([_ctx objectForKey:ODRTableView_footerColor]) {
    _rawAdd(_response, @" bgcolor='");
    _rawAdd(_response, 
               [_ctx objectForKey:ODRTableView_footerColor]);
    [_response appendContentCharacter:'\''];
  }
  [_response appendContentCharacter:'>'];

      // apppend resize buttons
  [self _appendResizeButtons:_node
        toResponse:_response
        actionUrl:_actionUrl
        inContext:_ctx];
  // close "td"
  _rawAdd(_response, @"</td>");
  END_PROFILE;
}

- (void)_appendCheckboxToResponse:(WOResponse *)_response
  ctx:(WOContext *)_ctx
  value:(NSString *)_value
  isChecked:(BOOL)_isChecked
{
  _rawAdd(_response, @"<input type=\"checkbox\" name=\"");
  [_response appendContentHTMLAttributeValue:[_ctx elementID]];
  _rawAdd(_response, @"\" value=\"");
  _rawAdd(_response, _value);
  [_response appendContentCharacter:'"'];

  if (_isChecked)
    _rawAdd(_response, @" checked");

  _rawAdd(_response, @" />");
}

- (void)_appendData:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSArray     *matrix;
  NSString    *batchSizeUrl = nil;
  NSArray     *selArray     = nil;
  NSString    *groupId      = nil;
  BOOL        hideObject    = NO;
  unsigned    i, cnt, first;
  BEGIN_PROFILE;
  
  matrix   = [self _collectData:_node inContext:_ctx];
  first    = self->state.firstIndex;
  cnt      = [matrix count];

  if (matrix == nil || cnt == 0)
    return;

  if (self->use.checkBoxes)
    selArray = [self valueFor:@"selection" node:_node ctx:_ctx];

  if (self->use.scriptCollapsing)
    [self _appendGroupCollapseScript:_response inContext:_ctx];

  [_ctx appendElementIDComponent:@"data"];
  {
    NSString *bn;
    bn = [self stringForInt:self->state.currentBatch];
    //bn = [NSString stringWithFormat:@"%d", self->state.currentBatch];
    [_ctx appendElementIDComponent:bn]; // append batchNumber
  }
  
  batchSizeUrl = [_ctx componentActionURL];

  if (![self hasAttribute:@"identifier"node:_node ctx:_ctx])
    [_ctx appendElementIDComponent:[NSString stringWithFormat:@"%i", first]];

  [_ctx setObject:@"YES" forKey:ODRTableView_DataMode];
  
  for (i = 0; i < cnt; i++) {
    NSMutableArray *infos = nil;

    [self _applyItemForIndex:first+i node:_node ctx:_ctx];
    if ([self hasAttribute:@"identifier" node:_node ctx:_ctx]) {
      NSString *ident;

      ident = [self stringFor:@"identifier" node:_node ctx:_ctx];
      [_ctx appendElementIDComponent:ident];
    }
    
    infos = [matrix objectAtIndex:i];

    if ([[infos lastObject] isEqual:ODRTableView_GroupMode]) {
      unsigned rowSpan;

      groupId = [NSString stringWithFormat:@"group%d", i];

      rowSpan = ((i==0) && self->use.batchResizeButtons)
        ? cnt+self->state.groupCount
        : 0;
      [self _appendGroupTitle:_node
            toResponse:_response
            inContext:_ctx
            infos:infos
            actionUrl:batchSizeUrl
            rowSpan:rowSpan
            groupId:groupId
            index:i+first];
      
      if ((self->state.groupCount > 0) && !self->use.scriptCollapsing)
        hideObject = ![self _showGroupAtIndex:i+first node:_node ctx:_ctx];
      else
        hideObject = NO;
    }
        
    [_ctx setObject:infos forKey:ODRTableView_INFOS];

    if (hideObject) {
      if (![self hasAttribute:@"identifier" node:_node ctx:_ctx])
        [_ctx incrementLastElementIDComponent];
      else
        [_ctx deleteLastElementIDComponent]; // delete identifier
      continue;
    }
    
    _rawAdd(_response, @"<tr");
    if (groupId) {
      _rawAdd(_response, @" groupName=\"");
      _rawAdd(_response, groupId);
      [_response appendContentCharacter:'"'];
      if (self->use.scriptCollapsing &&
          ![self _showGroupAtIndex:i+first node:_node ctx:_ctx])
        _rawAdd(_response, @" style=\"display:none;\"");
    }
    [_response appendContentCharacter:'>'];

    if (self->use.checkBoxes) {
      ODRTableViewInfo *info = nil;
      NSString        *bg   = nil;

      info = ([infos count]) ? [infos objectAtIndex:0] : nil;

      bg = (info && info->isEven)
        ? [_ctx objectForKey:ODRTableView_evenColor]
        : [_ctx objectForKey:ODRTableView_oddColor];

      [_ctx appendElementIDComponent:@"cb"];
      _rawAdd(_response, @"<td width=\"1%\" align=\"left\"");
      _rawAdd(_response, @" bgcolor=\"");
      _rawAdd(_response, bg);
      _rawAdd(_response, @"\">");

      [self _appendCheckboxToResponse:_response
            ctx:_ctx
            value:[self stringForInt:(first + i)]
            //value:[NSString stringWithFormat:@"%d", first+i]
            isChecked:[selArray containsObject:
                                [self->list objectAtIndex:first+i]]];
      
      _rawAdd(_response, @"</td>");
      
      [_ctx deleteLastElementIDComponent]; // delete "cb"
    }

    [self appendChildNodes:[_node childNodes]
          toResponse:_response
          inContext:_ctx];

    if (!i && self->use.batchResizeButtons &&!self->state.groupCount) {
      [self _appendBatchResizeButtons:_node
            toResponse:_response
            rowSpan:cnt+self->state.groupCount
            actionUrl:batchSizeUrl
            inContext:_ctx];
    }
    
    _rawAdd(_response, @"</tr>");

    if (![self hasAttribute:@"identifier" node:_node ctx:_ctx])
      [_ctx incrementLastElementIDComponent];
    else
      [_ctx deleteLastElementIDComponent]; // delete identifier
  }
  if (![self hasAttribute:@"identifier" node:_node ctx:_ctx])
    [_ctx deleteLastElementIDComponent]; // delete index
  [_ctx deleteLastElementIDComponent];   // delete batchNumber
  [_ctx deleteLastElementIDComponent];   // delete "data"
  [_ctx removeObjectForKey:ODRTableView_DataMode];

  END_PROFILE;
}

- (void)_appendFooter:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *bg      = nil;
  unsigned first    = self->state.firstIndex + 1;
  unsigned last     = self->state.lastIndex  + 1;
  unsigned count    = [self->list count];
  unsigned batch    = self->state.currentBatch;
  unsigned batchCnt = self->state.batchCount;
  BEGIN_PROFILE;

  first    = (count)    ? first    : 0;
  batchCnt = (batchCnt) ? batchCnt : 1;
  bg       = [_ctx objectForKey:ODRTableView_footerColor];
  
  [_ctx appendElementIDComponent:@"footer"];

  _rawAdd(_response, 
         @"<table border='0' width='100%' cellpadding='0' cellspacing='0'>");
  _rawAdd(_response, @"<tr>");                        // <TR>
  ODRAppendTD(_response, @"left", nil, bg, nil);                  //   <TD...>

  [_ctx setObject:@"YES" forKey:ODRTableView_FooterMode];
  [self appendChildNodes:ODRLookupQueryPath(_node, @"-tfooter")
        toResponse:_response
        inContext:_ctx];
  [_ctx removeObjectForKey:ODRTableView_FooterMode];
  
  _rawAdd(_response, @"<small>");
  if (!self->use.overflow) {
    _rawAdd(_response, [self stringForInt:first]);
    //_rawAdd(_response, [NSString stringWithFormat:@"%d ", first]];
    _rawAdd(_response, [self labelForKey:@"to" ctx:_ctx]);
    _rawAdd(_response, [self stringForInt:last]);
    //_rawAdd(_response, [NSString stringWithFormat:@" %d ", last]];
    _rawAdd(_response, [self labelForKey:@"of" ctx:_ctx]);
  }
  _rawAdd(_response, [self stringForInt:count]);
  //_rawAdd(_response, [NSString stringWithFormat:@" %d", count]];
  _rawAdd(_response, @"</small>");
  
  _rawAdd(_response, @"</td>");                       // </TD>
  
  ODRAppendTD(_response, @"right", nil, bg, nil);                 // <TD...>
  if (!self->use.overflow) {
    NSString *tmp;

    tmp = [self labelForKey:@"page" ctx:_ctx];
    
    _rawAdd(_response, @"<small>");
    if (tmp) {
      _rawAdd(_response, tmp);
      [_response appendContentCharacter:':'];
    }
    _rawAdd(_response, [self stringForInt:batch]);
    //               [NSString stringWithFormat:@" %d ", batch]];
    _rawAdd(_response, [self labelForKey:@"of" ctx:_ctx]);
    _rawAdd(_response, [self stringForInt:batchCnt]);
    //               [NSString stringWithFormat:@" %d", batchCnt]];
    _rawAdd(_response, @"</small>");
  }
  else {
    [self _appendResizeButtons:_node
          toResponse:_response
          actionUrl:[_ctx componentActionURL]
          inContext:_ctx];
  }


  _rawAdd(_response, @"</td></tr>");              // </TD><TR>
  _rawAdd(_response, @"</table>");                  // </TABLE>

  [_ctx deleteLastElementIDComponent];
  END_PROFILE;
}

@end /* ODR_bind_tableview(Private_Rendering) */

@implementation ODR_bind_tableview(Private_ActionHandling)


- (NSArray *)_sortedArrayOfNode:(id)_node
                      inContext:(WOContext *)_ctx
                          fetch:(BOOL)_doFetch
{
  NSArray        *array     = nil;
  EOSortOrdering *so        = nil;
  NSArray        *orderings = nil;
  NSString       *sortedKey = nil;
  BOOL           isDesc     = NO;
  SEL            sel;

  if (![self hasAttribute:@"sortaction" node:_node ctx:_ctx]) {
    isDesc    = [self boolFor:@"isdescending" node:_node ctx:_ctx];
    sortedKey = [self stringFor:@"sortedkey"  node:_node ctx:_ctx];
    
    sel = (isDesc) ? EOCompareDescending : EOCompareAscending;
    if (sortedKey)
      so  = [EOSortOrdering sortOrderingWithKey:sortedKey  selector:sel];

    // get sortOrderings
    [_ctx setObject:@"YES" forKey:ODR_SortOrderingContainerMode];
    [self appendChildNodes:ODRLookupQueryPath(_node, @"-sortorderings")
          toResponse:nil
          inContext:_ctx];
    [_ctx removeObjectForKey:ODR_SortOrderingContainerMode];

    if (so)
      orderings = [NSArray arrayWithObject:so];

    if (orderings)
      orderings = [orderings arrayByAddingObjectsFromArray:
                             [_ctx objectForKey:ODR_SortOrderingContainer]];
    else
      orderings = [_ctx objectForKey:ODR_SortOrderingContainer];

    if ([self hasAttribute:@"datasource" node:_node ctx:_ctx]) {
      EODataSource *ds = [self valueFor:@"datasource" node:_node ctx:_ctx];

      if (orderings) {
        EOFetchSpecification *fspec;
          
        fspec = [[ds fetchSpecification] copy];
        
        if (fspec == nil)
          fspec = [[EOFetchSpecification alloc] init];

        [fspec setSortOrderings:orderings];
        
        [ds setFetchSpecification:fspec];
        RELEASE(fspec);
      }
      if (_doFetch)
        array = [ds fetchObjects];
    }
    else if (_doFetch) {
      array = [self valueFor:@"list" node:_node ctx:_ctx];
      if (orderings)
        array = [array sortedArrayUsingKeyOrderArray:orderings];
    }
  }
  else {
    // [self->sortAction valueInComponent:cmp];
    if (_doFetch)
      array = [self valueFor:@"list" node:_node ctx:_ctx];
  }
  return array;
}

- (void)_handleSortAction:(id)_node inContext:(WOContext *)_ctx {
  NSString    *key;
  NSString    *oldKey;
  BOOL        isDesc;
  BOOL        oldIsDesc;
  BEGIN_PROFILE;

  if ([_ctx objectForKey:ODRTableView_SORTEDKEY] == nil ||
      [_ctx objectForKey:ODRTableView_ISDESCENDING] == nil)
    return; // nothing to do

  key    = [_ctx  objectForKey:ODRTableView_SORTEDKEY];
  isDesc = [[_ctx objectForKey:ODRTableView_ISDESCENDING] boolValue];

  oldIsDesc = [self boolFor:@"isdescending" node:_node ctx:_ctx];
  oldKey    = [self stringFor:@"sortedkey"  node:_node ctx:_ctx];

  if ([oldKey isEqual:key] && oldIsDesc == isDesc)
    return; // nothing to do

  [self forceSetBool:isDesc for:@"isdescending" node:_node ctx:_ctx];
  [self forceSetString:key  for:@"sortedkey"    node:_node ctx:_ctx];

  [self _sortedArrayOfNode:_node inContext:_ctx fetch:NO];
  
  END_PROFILE;
  return;
}

- (id)_handleFirstButton:(id)_node inContext:(WOContext *)_ctx {
  if ([self hasAttribute:@"firstaction" node:_node ctx:_ctx])
    ; // ??? [self->firstAction valueInComponent:[_ctx component]];
  else {
    self->state.currentBatch = 1; // ???
    [self forceSetInt:1 for:@"currentbatch" node:_node ctx:_ctx];
  }
  return nil;
}

- (id)_handlePreviousButton:(id)_node inContext:(WOContext *)_ctx {
  if ([self hasAttribute:@"previousaction" node:_node ctx:_ctx])
    ; // ??? [self->previousAction valueInComponent:[_ctx component]];
  else {
    unsigned batch = self->state.currentBatch;
    
    self->state.currentBatch = ((batch -1) > 0) ? batch - 1 : 1;
    [self forceSetInt:self->state.currentBatch
          for:@"currentbatch" node:_node ctx:_ctx];
  }
  return nil;
}

- (id)_handleNextButton:(id)_node inContext:(WOContext *)_ctx {
  if ([self hasAttribute:@"nextaction" node:_node ctx:_ctx])
    ; // ??? [self->nextAction valueInComponent:[_ctx component]];
  else {
    unsigned batch = self->state.currentBatch;
    unsigned cnt   = self->state.batchCount;
    
    self->state.currentBatch = ((batch +1) < cnt) ? batch + 1 : cnt;
    [self forceSetInt:self->state.currentBatch
          for:@"currentbatch" node:_node ctx:_ctx];
  }
  return nil;
}

- (id)_handleLastButton:(id)_node inContext:(WOContext *)_ctx {
  if ([self hasAttribute:@"lastaction" node:_node ctx:_ctx])
    ; // ??? [self->lastAction valueInComponent:[_ctx component]];
  else {
    self->state.currentBatch = self->state.batchCount;
    [self forceSetInt:self->state.currentBatch
          for:@"currentbatch" node:_node ctx:_ctx];
  }
  return nil;
}

- (id)increaseAutoScrollHeight:(id)_node inContext:(WOContext *)_ctx {
  if ([self isSettable:@"autoscroll" node:_node ctx:_ctx]) {
    int sh; // scrollHeight

    sh = [self intFor:@"autoscroll" node:_node ctx:_ctx] + 20;
    [self setInt:sh for:@"autoscroll" node:_node ctx:_ctx];
  }
  return nil;
}

- (id)decreaseAutoScrollHeight:(id)_node inContext:(WOContext *)_ctx {
  if ([self isSettable:@"autoscroll" node:_node ctx:_ctx]) {
    int sh; // scrollHeight

    sh = [self intFor:@"autoscroll" node:_node ctx:_ctx] - 20;
    if (sh > 50)
      [self setInt:sh for:@"autoscroll" node:_node ctx:_ctx];
  }
  return nil;
}


- (id)increaseBatchSize:(id)_node inContext:(WOContext *)_ctx {
  if ([self isSettable:@"batchsize" node:_node ctx:_ctx]) {
    int bs;

    bs = [self intFor:@"batchsize" node:_node ctx:_ctx] + 1;
    [self setInt:bs for:@"batchsize" node:_node ctx:_ctx];
  }
  return nil;
}

- (id)decreaseBatchSize:(id)_node inContext:(WOContext *)_ctx {
  if ([self isSettable:@"batchsize" node:_node ctx:_ctx]) {
    int bs;

    bs = [self intFor:@"batchsize" node:_node ctx:_ctx] - 1;
    if (bs > 1)
      [self setInt:bs for:@"batchsize" node:_node ctx:_ctx];
  }
  return nil;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  forBatch:(int)_batch
  selections:(NSMutableArray *)_selArray
  inContext:(WOContext *)_ctx
{
  NSString *eid;
  int      i, first, last;
  BEGIN_PROFILE;
  
  first = self->state.firstIndex;
  last  = self->state.lastIndex;
  
  {
    NSString *bn;
    bn = [self stringForInt:self->state.currentBatch];
    //bn = [NSString stringWithFormat:@"%d", self->state.currentBatch];
    [_ctx appendElementIDComponent:bn]; // append batchNumber
  }

  eid = [_ctx elementID];

  if ([_request formValueForKey:[eid stringByAppendingString:@".pp.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".pp"]];
  }
  else if ([_request formValueForKey:[eid stringByAppendingString:@".mm.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:
          [[_ctx senderID] stringByAppendingString:@".mm"]];
  }
  
  if (![self hasAttribute:@"identifier" node:_node ctx:_ctx]) // append index
    //[_ctx appendElementIDComponent:[NSString stringWithFormat:@"%d", first]];
    [_ctx appendElementIDComponent:[self stringForInt:first]];
  
  for (i = first; i <=last; i++) {
    [self _applyItemForIndex:i node:_node ctx:_ctx];
    if ([self hasAttribute:@"identifier" node:_node ctx:_ctx]) {
      NSString *s;
        
      s = [self stringFor:@"identifier" node:_node ctx:_ctx];
      [_ctx appendElementIDComponent:s];
    }

    if (_selArray != nil) {
      NSString *cbID; // checkBoxID
      id       formValue;
      id       obj;

      cbID = [[_ctx elementID] stringByAppendingString:@".cb"];
      obj  = [self valueFor:@"item" node:_node ctx:_ctx];

      if (obj) {
        if ((formValue = [_request formValueForKey:cbID])) {
          if (![_selArray containsObject:obj])
            [_selArray addObject:obj];
        }
        else if ([_selArray containsObject:obj])
          [_selArray removeObject:obj];
      }
    }
    [_ctx setObject:@"YES" forKey:ODRTableView_DataMode];
    [self takeValuesForChildNodes:[_node childNodes]
          fromRequest:_request
          inContext:_ctx];
    [_ctx removeObjectForKey:ODRTableView_DataMode];
    
    if (![self hasAttribute:@"identifier" node:_node ctx:_ctx])
      [_ctx incrementLastElementIDComponent];
    else
      [_ctx deleteLastElementIDComponent]; // delete identifier
  }
  if (![self hasAttribute:@"identifier" node:_node ctx:_ctx])
    [_ctx deleteLastElementIDComponent]; // delete index

  [_ctx deleteLastElementIDComponent]; // delete batchNumber
  END_PROFILE;
}

@end /* ODR_bind_tableview(Private_ActionHandling) */

@implementation ODR_bind_tableview(Private_JavaScriptAdditions)

- (void)_appendGroupCollapseScript:(WOResponse *)_resp
  inContext:(WOContext *)_ctx
{
  if (![_ctx objectForKey:ODRTableView_HasCollapseScript]) {
    [_resp appendContentString:
           @"\n<script language=\"JavaScript\">\n"
           @"<!--\n"
           @"function toggleTableGroup()\n"
           @"{\n"
           @"   img = event.srcElement;\n"
           @"   visibility = img.isGroupVisible;\n"
           @"   visibility = (visibility != \"none\") ? \"none\" : \"\";\n"
           @"   img.isGroupVisible = visibility;\n"
           @"   img.src = (visibility == \"\") ? img.openImg : img.closeImg;\n"
           @"   groupName  = img.group;\n"
           @"   table  = img.parentNode.parentNode.parentNode;\n"
           @"   trList = table.getElementsByTagName(\"TR\");\n"
           @"   cnt    = trList.length;\n"
           @"   for (i=0; i<cnt; i++) {\n"
           @"     tr = trList[i];\n"
           @"     if (tr.groupName == groupName)\n"
           @"       tr.style.display = visibility;\n"
           @"   }\n"
           @"}\n"
           @"//-->\n"
           @"</script>\n"];
    [_ctx setObject:@"YES" forKey:ODRTableView_HasCollapseScript];
  }
}

- (void)jsButton:(WOResponse *)_resp ctx:(WOContext *)_ctx
  name:(NSString *)_name button:(NSString *)_button
{
  NSString *imgUri;
  NSString *n;
  
  _button = [_button stringByAppendingString:@".gif"];
  imgUri  = ODRUriOfResource(_button, _ctx);
  n       = [_name stringByAppendingString:self->scriptID];
  
  [_resp appendContentString:[NSString stringWithFormat:
         @"var %@ = new Image(); %@.src = \"%@\";\n", n, n, imgUri]];
}
                                    
- (void)appendJavaScript:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  [_resp appendContentString:@"<SCRIPT LANGUAGE=\"JavaScript\">\n<!--\n"];
  
  [self jsButton:_resp ctx:_ctx name:@"First"     button:@"first"];
  [self jsButton:_resp ctx:_ctx name:@"First2"    button:@"first_blind"];
  [self jsButton:_resp ctx:_ctx name:@"Previous"  button:@"previous"];
  [self jsButton:_resp ctx:_ctx name:@"Previous2" button:@"previous_blind"];
  [self jsButton:_resp ctx:_ctx name:@"Next"      button:@"next"];
  [self jsButton:_resp ctx:_ctx name:@"Next2"     button:@"next_blind"];
  [self jsButton:_resp ctx:_ctx name:@"Last"      button:@"last"];
  [self jsButton:_resp ctx:_ctx name:@"Last2"     button:@"last_blind"];

  [_resp appendContentString:[NSString stringWithFormat:
    @"function showPage%@() {\n"
    @"  for (var i=1; i< page%@.length; i++) {\n"
	@"    if (i == actualPage%@) {\n"
    @"      page%@[i][\"Div\"].style.display = \"\";\n"
    @"      footer%@[i][\"Div\"].style.display = \"\";\n"
    @"    }\n"
	@"    else {\n"
    @"      page%@[i][\"Div\"].style.display = \"none\";\n"
    @"      footer%@[i][\"Div\"].style.display = \"none\";\n"
    @"    }\n"
	@"	}\n"
	@"	flushImages%@();\n"
	@"}\n",
    self->scriptID, // showPage
    self->scriptID, // page.length
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID, // footer
    self->scriptID, // page
    self->scriptID, // footer
    self->scriptID  // flushImages
  ]];
  
  [_resp appendContentString:[NSString stringWithFormat:
    @"function firstPage%@() {\n"
    @"  actualPage%@ = 1;\n"
    @"  showPage%@();\n"
    @"}\n",
    self->scriptID, // firstPage
    self->scriptID, // actualPage
    self->scriptID  // showPage
  ]];

  [_resp appendContentString:[NSString stringWithFormat:
    @"function previousPage%@() {\n"
    @"	if (actualPage%@ > 1) {\n"
    @"    actualPage%@--;\n"
    @"    showPage%@();\n"
    @"  }\n"
	@"}\n",
    self->scriptID, // previousPage
    self->scriptID, // actualPage
    self->scriptID, // actualPage
    self->scriptID  // showPage
  ]];

  [_resp appendContentString:[NSString stringWithFormat:
    @"function nextPage%@() {\n"
    @"  if (actualPage%@ < page%@.length - 1) {\n"
    @"    actualPage%@++;\n"
    @"    showPage%@();\n"
    @"	}\n"
	@"}\n",
    self->scriptID, // nextPage
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID, // actualPage
    self->scriptID  // showPage
  ]];

  [_resp appendContentString:[NSString stringWithFormat:
    @"function lastPage%@() {\n"
    @"  actualPage%@ = page%@.length - 1;\n"
    @"  showPage%@();\n"
    @"}\n",
    self->scriptID, // lastPage
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID  // showPage
  ]];

  [_resp appendContentString:[NSString stringWithFormat:
    @"function flushImages%@() {\n"
    @"  document.images[\"firstPageImg%@\"].src    = First%@.src;\n"
    @"  document.images[\"previousPageImg%@\"].src = Previous%@.src;\n"
    @"  document.images[\"nextPageImg%@\"].src     = Next%@.src;\n"
    @"  document.images[\"lastPageImg%@\"].src     = Last%@.src;\n"
    @"  if (actualPage%@ == 1) {\n"
    @"    document.images[\"firstPageImg%@\"].src    = First2%@.src;\n"
    @"    document.images[\"previousPageImg%@\"].src = Previous2%@.src;\n"
    @"  }\n"
                                       
    //    @"  if (actualPage%@ == 2) {\n"
    //    @"    document.images[\"firstPageImg%@\"].src = First2%@.src;\n"
    //    @"  }\n"
    //    @"  if (actualPage%@ == page%@.length -2) {\n"
    //    @"    document.images[\"lastPageImg%@\"].src = Last2%@.src;\n"
    //    @"  }\n"
                                       
    @"  if (actualPage%@ == page%@.length - 1) {\n"
    @"    document.images[\"nextPageImg%@\"].src = Next2%@.src;\n"
    @"    document.images[\"lastPageImg%@\"].src = Last2%@.src;\n"
    @"  }\n"
    @"}\n",
    self->scriptID, // flushImages
    self->scriptID, // firstPageImg
    self->scriptID, // First
    self->scriptID, // previousPageImg
    self->scriptID, // Previous
    self->scriptID, // nextPageImg
    self->scriptID, // Next
    self->scriptID, // lastPageImg
    self->scriptID, // Last
    self->scriptID, // actualPage
    self->scriptID, // firstPageImg
    self->scriptID, // First2
    self->scriptID, // previousPageImg
    self->scriptID, // Previous2
                                       
/*                                       
    self->scriptID, // actualPage
    self->scriptID, // firstPageImg
    self->scriptID, // First2
                                       
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID, // lastPageImg
    self->scriptID, // Last2
*/
                                       
    self->scriptID, // actualPage
    self->scriptID, // page
    self->scriptID, // nextPageImg,
    self->scriptID, // Next2
    self->scriptID, // lastPageImg
    self->scriptID  // Last2
  ]];
  
  [_resp appendContentString:[NSString stringWithFormat:
    @"var page%@   = new Array();\n"
    @"var footer%@ = new Array();\n"
    @"var actualPage%@ = %d;",
    self->scriptID, // page
    self->scriptID, // footer
    self->scriptID, //actualPage
    self->state.currentBatch
  ]];
  {
    unsigned i;

    for (i = 1; i <= self->state.batchCount; i++) {
      [_resp appendContentString:[NSString stringWithFormat:
        @"page%@[%d] = new Array();\n"
        @"page%@[%d][\"Div\"] = page%dDiv%@;\n\n"
        @"footer%@[%d] = new Array();\n"
        @"footer%@[%d][\"Div\"] = footer%dDiv%@;\n\n",
        self->scriptID, // page
        i,              // page[i]
        self->scriptID, // page
        i,              // page[i]
        i,              // pageiDiv
        self->scriptID, // pageDiv
        self->scriptID, // footer
        i,              // footer[i]
        self->scriptID, // footer
        i,              // footer[i]
        i,              // footeriDiv
        self->scriptID  // footerDiv
       ]];
    }
  }
  [_resp appendContentString:[NSString stringWithFormat:
    @"showPage%@();", self->scriptID]];

  [_resp appendContentString:@"//-->\n</SCRIPT>\n"];
}

- (void)_appendTableContentAsScript:(id)_node
  toResponse:(WOResponse *)_resp
  inContext:(WOContext *)_ctx
{
  WOComponent *cmp;
  unsigned i, savedBatchIndex;
  BEGIN_PROFILE;

  cmp = [_ctx component];
  
  savedBatchIndex = self->state.currentBatch;
  /* open header + data area */
  [_resp appendContentString:@"\n<tr><td>"];

  for (i = 1; i <= self->state.batchCount; i++) {
    self->state.currentBatch = i;
    [self forceSetInt:i for:@"currentbatch" node:_node ctx:_ctx];
    [self updateStateOfNode:_node inContext:_ctx];
    [_resp appendContentString:[NSString stringWithFormat:         // <DIV...>
      @"<div id=\"page%dDiv%@\" style=\"display: ; \">", i, self->scriptID]];

    [_resp appendContentString:
           @"<table border='0' width='100%' cellpadding='1' cellspacing='0'>"];
    
    [self _appendHeader:_node toResponse:_resp inContext:_ctx];
    [self _appendData:_node   toResponse:_resp inContext:_ctx];
    
    [_resp appendContentString:@"</table>\n"];
    [_resp appendContentString:@"</div>"];                        // </DIV>
    

    /* append footer */
    [_resp appendContentString:[NSString stringWithFormat:        // <DIV...>
      @"<div id=\"footer%dDiv%@\" style=\"display: ; \">", i, self->scriptID]];

    [self _appendFooter:_node toResponse:_resp inContext:_ctx];
    
    [_resp appendContentString:@"</div>"];                        // </DIV>
  }
  
  /* close header + data area */
  [_resp appendContentString:@"</td></tr>\n"];

  self->state.currentBatch = savedBatchIndex;
  [self forceSetInt:self->state.currentBatch
        for:@"currentbatch" node:_node ctx:_ctx];
  [self updateStateOfNode:_node inContext:_ctx];

  END_PROFILE;
}

- (void)_appendScriptLink:(WOResponse *)_response name:(NSString *)_name {
  _rawAdd(_response, @"JavaScript:");
  _rawAdd(_response, _name);
  _rawAdd(_response, [NSString stringWithFormat:
    @"Page%@();", self->scriptID]);
}

@end /* ODR_bind_tableview(Private_JavaScriptAdditions) */


@implementation ODR_bind_tableview(Private_Grouping)

/* structure of attribute "visibleGroups":

   separator of groups is "&"

   qualGroupName1.keyGroupName1&qualGroupName2.keyGroupName2&...
   |__________________________| |__________________________|
                |                             |
         path of group                  path of group
       (separator is ".")             (separator is ".")
*/

- (BOOL)_showGroupAtIndex:(int)_idx node:(id)_node ctx:(WOContext *)_ctx {
  id visibleGroups; /* Array of strings  */
  id group;         /* string */
  
  if ([self hasAttribute:@"showgroup" node:_node ctx:_ctx])
    return [self boolFor:@"showgroup" node:_node ctx:_ctx];
  
  if (self->indexToGrouppath == nil)
    return NO;
  
  NSAssert(((int)[self->indexToGrouppath count] > _idx), 
           @"index is out of range");
  
  visibleGroups = [self stringFor:@"visiblegroups" node:_node ctx:_ctx];
  visibleGroups = (NSString *)[visibleGroups componentsSeparatedByString:@"&"];

  group = [self->indexToGrouppath objectAtIndex:_idx];
  group = (NSArray *)[group componentsJoinedByString:@"."];

  return [visibleGroups containsObject:group];
}

- (void)_setShowGroup:(BOOL)_flag
  atIndex:(int)_idx
  node:(id)_node
  ctx:(WOContext *)_ctx
{
  id   visibleGroups; /* Array of strings  */
  id   group;         /* string */
  BOOL isMarked;
  BEGIN_PROFILE;

  if ([self isSettable:@"showgroup" node:_node ctx:_ctx]) {
    [self setBool:_flag for:@"showgroup" node:_node ctx:_ctx];
    return;
  }
  
  if (self->indexToGrouppath == nil) return;
  
  NSAssert(((int)[self->indexToGrouppath count] > _idx), 
           @"index is out of range");
  
  visibleGroups = [self stringFor:@"visiblegroups" node:_node ctx:_ctx];
  visibleGroups = (NSString *)[visibleGroups componentsSeparatedByString:@"&"];

  group = [self->indexToGrouppath objectAtIndex:_idx];
  group = (NSArray *)[group componentsJoinedByString:@"."];

  isMarked = [visibleGroups containsObject:group];
  
  if (_flag && !isMarked) {
    visibleGroups = (visibleGroups)
      ? [visibleGroups arrayByAddingObject:group]
      : [NSArray arrayWithObject:group];
    
    [self forceSetString:[visibleGroups componentsJoinedByString:@"&"]
          for:@"visiblegroups"
          node:_node
          ctx:_ctx];
  }
  else if (!_flag && isMarked) {
    NSMutableArray *tmp;

    tmp = [NSMutableArray arrayWithArray:visibleGroups];
    [tmp removeObject:group];
    
    [self forceSetString:[tmp componentsJoinedByString:@"&"]
          for:@"visiblegroups"
          node:_node
          ctx:_ctx];
  }
  END_PROFILE;
}

- (id)_invokeGrouping:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *stateId;

  stateId = [[_ctx currentElementID] stringValue];

  if (stateId) {
    int idx;
    id  obj;
    
    /* ??? */
    obj = [self valueFor:@"item" node:_node ctx:_ctx];
    idx = [self->list indexOfObject:obj];

#if DEBUG && 0
    NSLog(@"%s: (grouping=%@) idx is %d (eid=%@)", __PRETTY_FUNCTION__,
          _node, idx, [_ctx elementID]);
#endif
    
    if ([stateId isEqualToString:@"e"]) {
      [self _setShowGroup:NO atIndex:idx node:_node ctx:_ctx];
    }
    else if ([stateId isEqualToString:@"c"]) {
      [self _setShowGroup:YES atIndex:idx node:_node ctx:_ctx];
    }
    else {
#if DEBUG && 0
      NSLog(@"%s:   invoke on children idx is %d (eid=%@)",
            __PRETTY_FUNCTION__, idx, [_ctx elementID]);
#endif
      [_ctx setObject:@"YES" forKey:ODRTableView_DataMode];
      return [self invokeActionForChildNodes:[_node childNodes]
                   fromRequest:_request
                   inContext:_ctx];
      [_ctx removeObjectForKey:ODRTableView_DataMode];
    }
  }
  return nil;
}

- (void)_appendGroupTitle:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  infos:(NSMutableArray *)_infos
  actionUrl:(NSString *)_actionUrl
  rowSpan:(unsigned)_rowSpan
  groupId:(NSString *)_groupId
  index:(int)_idx
{
  NSString    *bgcolor;
  BOOL        isCollapsed;
  NSString    *img;
  int         colspan;
  BEGIN_PROFILE;
  
  [_ctx removeObjectForKey:ODRTableView_INFOS];
  colspan  = [_infos count] - 2;
  colspan += (self->use.checkBoxes) ? 1 : 0;

  isCollapsed = ![self _showGroupAtIndex:_idx node:_node ctx:_ctx];
  
  _rawAdd(_response, 
             [NSString stringWithFormat:@"<tr><td colspan='%d'", colspan]);
  bgcolor = [self stringFor:@"groupcolor" node:_node ctx:_ctx];
  if (!bgcolor)
    bgcolor = [_ctx objectForKey:ODRTableView_groupColor];
      
  if (bgcolor != nil) {
    _rawAdd(_response, @" bgcolor='");
    _rawAdd(_response, bgcolor);
    [_response appendContentCharacter:'\''];
  }
  _rawAdd(_response, @"width='1%'>");
      
  [_ctx setObject:@"YES" forKey:ODRTableView_GroupMode];
  
  img = (!isCollapsed)
    ? [_ctx objectForKey:ODRTableView_openedIcon]
    : [_ctx objectForKey:ODRTableView_closedIcon];
  
  img = ODRUriOfResource(img, _ctx);
  
  [_ctx appendElementIDComponent:(isCollapsed) ? @"c" : @"e"];
  
  if (!self->use.scriptCollapsing) {
    _rawAdd(_response, @"<a href=\"");
    _rawAdd(_response, [_ctx componentActionURL]);
    _rawAdd(_response, @"\">");
  }

  if (img) {
    _rawAdd(_response, @"<img border='0' src=\"");
    _rawAdd(_response, img);
    [_response appendContentCharacter:'"'];
    if (self->use.scriptCollapsing) {
      NSString *openImg;
      NSString *closeImg;

      openImg  = [_ctx objectForKey:ODRTableView_openedIcon];
      closeImg = [_ctx objectForKey:ODRTableView_closedIcon];

      openImg  = ODRUriOfResource(openImg, _ctx);
      closeImg = ODRUriOfResource(closeImg, _ctx);

      openImg  = (openImg) ? openImg : closeImg;
      closeImg = (closeImg) ? closeImg : openImg;
      
      _rawAdd(_response, @" onclick=\"toggleTableGroup();\"");
      _rawAdd(_response, @" group=\"");
      _rawAdd(_response, _groupId);
      _rawAdd(_response, @"\" openImg=\"");
      _rawAdd(_response, openImg);
      _rawAdd(_response, @"\" closeImg=\"");
      _rawAdd(_response, closeImg);
      [_response appendContentCharacter:'"'];
      if (isCollapsed)
        _rawAdd(_response, @" isGroupVisible=\"none\"");
      else
        _rawAdd(_response, @" isGroupVisible=\"\"");
    }
    _rawAdd(_response, @" />");
  }
  else
    _rawAdd(_response, (isCollapsed) ? @"[+]" : @"[-]");
  if (!self->use.scriptCollapsing)
    _rawAdd(_response, @"</a>&nbsp;");

  [_ctx deleteLastElementIDComponent];

  if ([self isSettable:@"currentgroup" node:_node ctx:_ctx]) {
    NSAssert(([_infos count] > 1), @"info count must be at least 2");

    
    
    [self setValue:[_infos objectAtIndex:[_infos count]-1]
          for:@"currentgroup"
          node:_node ctx:_ctx];
  }
  
  [_ctx setObject:@"YES" forKey:ODRTableView_GroupMode];
  {
    NSString *gName = nil;
    NSArray  *gPath = nil;
    NSString *gList = nil;
    
    gPath = [self->indexToGrouppath objectAtIndex:_idx];

    if ((gName = [gPath lastObject]))
      gList = [self->groupedList objectForKey:gName];
    
    [_ctx setObject:gName  forKey:ODRTableView_GroupName];
    [_ctx setObject:gList  forKey:ODRTableView_GroupItems];
    [_ctx setObject:@"YES" forKey:ODRTableView_GroupMode];

    [self appendChildNodes:ODRLookupQueryPath(_node, @"-tgroup")
          toResponse:_response
          inContext:_ctx];

    [_ctx removeObjectForKey:ODRTableView_GroupMode];
    [_ctx removeObjectForKey:ODRTableView_GroupName];
    [_ctx removeObjectForKey:ODRTableView_GroupItems];
  }
  [_ctx removeObjectForKey:ODRTableView_GroupMode];

  _rawAdd(_response, @"</td>");

  if (_rowSpan) {
    [self _appendBatchResizeButtons:_node
          toResponse:_response
          rowSpan:_rowSpan
          actionUrl:_actionUrl
          inContext:_ctx];
  }
  _rawAdd(_response, @"</tr>");
  [_infos removeLastObject]; // groups
  [_infos removeLastObject]; // ODRTableView_GroupMode

  END_PROFILE;
}

@end /* ODR_bind_tableview(Private_Grouping) */
