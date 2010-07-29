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

#include "ODR_bind_tablecell.h"

@interface ODR_bind_td : ODR_bind_tablecell
{
}
@end /* ODR_bind_td */

#include "ODR_bind_tableview.h"
#include "common.h"

@implementation ODR_bind_td

- (void)_collectData:(id)_node inContext:(WOContext *)_ctx {
  NSMutableArray   *infos;
  ODRTableViewInfo *info;
  NSString         *key;
  NSString         *sortedKey;

  infos     = [_ctx objectForKey:ODRTableView_INFOS];
  key       = [self stringFor:@"sortkey" node:_node ctx:_ctx];
  sortedKey = [_ctx objectForKey:ODRTableView_SORTEDKEY];

  if (infos == nil) {
    infos = [NSMutableArray array];
    [_ctx setObject:infos forKey:ODRTableView_INFOS];
  }
  info = [[ODRTableViewInfo allocWithZone:[self zone]] init];
  info->rowSpan  = 1;
  info->isGroup  = [self boolFor:@"isgroup" node:_node ctx:_ctx];
  info->isSorted = (key != nil && sortedKey != nil && [key isEqual:sortedKey]);

  [infos addObject:info];
  AUTORELEASE(info);
}

- (void)_appendHeader:(id)_node
        toResponse:(WOResponse *)_response
        inContext:(WOContext *)_ctx
{
  NSString    *bg; // bgcolor

  bg = [_ctx objectForKey:ODRTableView_headerColor];

  ODRAppendTD(_response, @"left", nil, bg, nil);                 // <TD...>
  [_response appendContentString:@"<nobr>"];
  
  [self appendSortIcon:_node toResponse:_response inContext:_ctx];
  
  [self appendTitle:_node   toResponse:_response inContext:_ctx];

  [_response appendContentString:@"</nobr>"];
  [_response appendContentString:@"</td>\n"];                   // </TD>
}

- (void)_appendStringContent:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *s;
  
  /* add value */
  
  if ([self hasAttribute:@"value" node:_node ctx:_ctx]) {
    NSFormatter *fmt;
    id          obj;
    
    obj = [self valueFor:@"value" node:_node ctx:_ctx];

    if ([self hasAttribute:@"numberformat" node:_node ctx:_ctx]) {
      fmt = AUTORELEASE([[NSNumberFormatter alloc] init]);
      [(NSNumberFormatter *)fmt setFormat:
                    [self valueFor:@"numberformat" node:_node ctx:_ctx]];
    }
    else if ([self hasAttribute:@"dateformat" node:_node ctx:_ctx]) {
      fmt = [[NSDateFormatter alloc]
                          initWithDateFormat:
                          [self valueFor:@"dateformat" node:_node ctx:_ctx]
                          allowNaturalLanguage:NO];
      fmt = AUTORELEASE(fmt);
    }
    else if ([self hasAttribute:@"formatter" node:_node ctx:_ctx]) {
      fmt = [self valueFor:@"formatter" node:_node ctx:_ctx];
#if DEBUG
      if (fmt && ![fmt respondsToSelector:@selector(stringForObjectValue:)]) {
        [[_ctx component] logWithFormat:
                          @"invalid formatter determined by %@", fmt];
      }
#endif
    }
    else
      fmt = nil;
    
    if (fmt)
      obj = [fmt stringForObjectValue:obj];
    
    s = [obj stringValue];
    
    if (s) [_response appendContentHTMLString:s];
  }
  
  /* add string */
  
  if ([self hasAttribute:@"string" node:_node ctx:_ctx]) {
    s = [self stringFor:@"string" node:_node ctx:_ctx];
    [_response appendContentHTMLString:s];
  }
}

- (void)_appendData:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  info:(ODRTableViewInfo *)_info
{
  if (!_info->isGroup) {
    NSString    *bg  = [self stringFor:@"bgcolor" node:_node ctx:_ctx];
  
    if (bg == nil) {
      bg = (_info->isEven)
        ? [_ctx objectForKey:ODRTableView_evenColor]
        : [_ctx objectForKey:ODRTableView_oddColor];
    }
    [_response appendContentString:@"<td bgcolor=\""];          // <TD...>
    [_response appendContentString:bg];
    if (_info->rowSpan > 1) {
      [_response appendContentString:@"\" rowspan=\""];
      [_response appendContentString:
                 [NSString stringWithFormat:@"%i", _info->rowSpan]];
    }
    [_response appendContentCharacter:'"'];
    [_response appendContentCharacter:'>'];
    
    [super appendChildNodes:[_node childNodes]
           toResponse:_response
           inContext:_ctx];

    [self _appendStringContent:_node toResponse:_response inContext:_ctx];

    [_response appendContentString:@"</td>\n"];                  // </TD>
  }
}

/* responder */

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if ([_ctx objectForKey:ODRTableView_CollectMode]) {
    [self _collectData:_node inContext:_ctx];
    return;
  }
  
  if ([_ctx objectForKey:ODRTableView_HeaderMode] &&
      [self hasAttribute:@"title" node:_node ctx:_ctx]) {
    [self _appendHeader:_node toResponse:_response inContext:_ctx];
  }
  else if ([[_ctx objectForKey:ODRTableView_DataMode] boolValue]) {
    NSMutableArray *infos = nil;

    infos  = [_ctx objectForKey:ODRTableView_INFOS];

    if (infos != nil && [infos count] > 0) {
      [self _appendData:_node
            toResponse:_response
            inContext:_ctx
            info:[infos objectAtIndex:0]];
      [infos removeObjectAtIndex:0];
    }
  }
}

@end /* ODR_bind_td */


