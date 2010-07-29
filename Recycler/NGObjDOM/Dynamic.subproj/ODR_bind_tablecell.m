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
#include "ODR_bind_tableview.h"

#include <DOM/EDOM.h>
#include "common.h"

@implementation ODR_bind_tablecell

static NSNumber *YesNumber = nil;
static NSNumber *NoNumber  = nil;

+ (void)initialize {
  if (YesNumber == nil) YesNumber = [[NSNumber numberWithBool:YES] retain];
  if (NoNumber  == nil) NoNumber  = [[NSNumber numberWithBool:NO]  retain];
}

- (void)appendSortIcon:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString    *icon = nil;
  NSString    *nav  = nil;
  BOOL        doForm = [_ctx isInForm];
  NSString    *sortedKey;
  NSString    *label;
  NSString    *sk;
  int         sortDir;

  sortedKey = [_ctx objectForKey:ODRTableView_SORTEDKEY];
  sk        = [self stringFor:@"sortkey" node:_node ctx:_ctx];
  
  label     = [self stringFor:@"sortlabel" node:_node ctx:_ctx];
  label     = (label) ? label : ODRTableLabelForKey(@"sort", _ctx);

  if (sk == nil)
    return;

  if (![sk isEqualToString:sortedKey])
    sortDir = 0;
  else if ( [_ctx objectForKey:ODRTableView_ISDESCENDING] == nil ||
           [[_ctx objectForKey:ODRTableView_ISDESCENDING] boolValue])
    sortDir = -1;
  else
    sortDir = 1;
  
  switch (sortDir) {
    case  1: nav = @"down"; break;
    case  0: nav = @"non";  break;
    case -1: nav = @"up";   break;
  }
  switch (sortDir) {
    case  1:
      icon = [self stringFor:@"downwardsorticon" node:_node ctx:_ctx];
      if ([icon length] == 0)
        icon = [_ctx objectForKey:ODRTableView_downwardIcon];
      break;
    case  0:
      icon = [self stringFor:@"nonsorticon"      node:_node ctx:_ctx];
      if ([icon length] == 0)
        icon = [_ctx objectForKey:ODRTableView_nonSortIcon];
      break;
    case -1:
      icon = [self stringFor:@"upwardsorticon"   node:_node ctx:_ctx];
      if ([icon length] == 0)
        icon = [_ctx objectForKey:ODRTableView_upwardIcon];
      break;
  }

#if DEBUG && 0
  if (icon == nil) {
    NSLog(@"%s: DID NOT FIND SORTICON (%i), ctx is %@\n  vars: %@",
          __PRETTY_FUNCTION__,
          sortDir, _ctx, [_ctx variableDictionary]);
  }
#endif

#if 0
  if (!ODRUriOfResource(icon,_ctx)) {
    switch (sortDir) {
      case  1: icon = [_ctx objectForKey:ODRTableView_downwardIcon]; break;
      case  0: icon = [_ctx objectForKey:ODRTableView_nonSortIcon];  break;
      case -1: icon = [_ctx objectForKey:ODRTableView_upwardIcon];   break;
    }
  }
#endif
  
  icon   = ODRUriOfResource(icon, _ctx);
  doForm = doForm && (icon != nil);

  // append something like that: sort.name.down
  [_ctx appendElementIDComponent:@"sort"];
  [_ctx appendElementIDComponent:sk];     // remember sortKey
  [_ctx appendElementIDComponent:nav];    // remember sortDirection

  // append as submit button
  if (doForm)
    ODRAppendButton(_response, [_ctx elementID], icon, label);

  /* append as hyperlink */
  else {
    [_response appendContentString:@"<a href=\""];
    [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentString:@"\">"];
    
    if (icon) {
      ODRAppendImage(_response, nil, icon, label);
    }
    else {
      switch (sortDir) {
        case  1: [_response appendContentString:@"&uarr;"]; break;
        case  0: [_response appendContentString:@"-"]; break;
        case -1: [_response appendContentString:@"&darr;"]; break;
      }
    }
    [_response appendContentString:@"</a>"];
  }
  [_ctx deleteLastElementIDComponent]; // delete sortDirection
  [_ctx deleteLastElementIDComponent]; // delete sortKey
  [_ctx deleteLastElementIDComponent]; // delete @"sort"

  return;
}

- (void)appendTitle:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *title;
  NSString *tC, *tF, *tS; // text font attrtibutes
  BOOL     hasFont;

  tC  = [_ctx objectForKey:ODRTableView_fontColor];
  tF  = [_ctx objectForKey:ODRTableView_fontFace];
  tS  = [_ctx objectForKey:ODRTableView_fontSize];

  hasFont = (tC || tF || tS) ? YES : NO;
  
  title   = [self stringFor:@"title" node:_node ctx:_ctx];

  if (title) {
    if (hasFont)
      ODRAppendFont(_response, tC, tF, tS);                      //   <FONT...>
   
    [_response appendContentString:@" <b>"];
    [_response appendContentString:title];
    [_response appendContentString:@"</b>"];

    if (hasFont)
      [_response appendContentString:@"</font>"];               //   </FONT>
  }
}

/* --- responder --- */

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  NSString *k;
  
  k = [self stringFor:@"sortkey" node:_node ctx:_ctx];

  if (k && [[_ctx objectForKey:ODRTableView_HeaderMode] boolValue]) {
    NSString *tmp;
    tmp = [[_ctx elementID] stringByAppendingFormat:@".sort.%@.", k];

    if ([_req formValueForKey:[tmp stringByAppendingString:@"down.x"]]) {
      [_ctx addActiveFormElement:self];
      [_ctx setRequestSenderID:[tmp stringByAppendingString:@"down"]];
    }
    else if ([_req formValueForKey:[tmp stringByAppendingString:@"up.x"]]) {
      [_ctx addActiveFormElement:self];
      [_ctx setRequestSenderID:[tmp stringByAppendingString:@"up"]];
    }
    else if ([_req formValueForKey:[tmp stringByAppendingString:@"non.x"]]) {
      [_ctx addActiveFormElement:self];
      [_ctx setRequestSenderID:[tmp stringByAppendingString:@"non"]];
    }
    else
      [super takeValuesForNode:_node  fromRequest:_req inContext:_ctx];
  }
  else
    [super takeValuesForNode:_node  fromRequest:_req inContext:_ctx];
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  id          result = nil;
  NSString    *k;

#if DEBUG && 0
  NSLog(@"%s:    invoke on tablecell %@ (eid=%@, sid=%@)", __PRETTY_FUNCTION__,
        _node, [_ctx elementID], [_ctx senderID]);
#endif

  k   = [self stringFor:@"sortkey" node:_node ctx:_ctx];
  if ([[_ctx currentElementID] isEqual:@"sort"] && k != nil) {
    NSString *tmp;
    
    [_ctx consumeElementID];                 // consume "sort"
    [_ctx appendElementIDComponent:@"sort"]; // append  "sort"
    
    tmp = [_ctx currentElementID];
    if (tmp != nil && [tmp isEqualToString:k]) {
      BOOL doNegate = [self boolFor:@"negatesort" node:_node ctx:_ctx];

      [_ctx consumeElementID];               // consume sortKey
      [_ctx appendElementIDComponent:k];     // append  sortKey
      [_ctx setObject:k forKey:ODRTableView_SORTEDKEY];

      tmp = [_ctx currentElementID];
      
      if ([tmp isEqualToString:@"down"])
        [_ctx setObject:YesNumber forKey:ODRTableView_ISDESCENDING];
      else if ([tmp isEqualToString:@"up"])
        [_ctx setObject:NoNumber forKey:ODRTableView_ISDESCENDING];
      else if ([tmp isEqualToString:@"non"])
        [_ctx setObject:[NSNumber numberWithBool:doNegate]
                 forKey:ODRTableView_ISDESCENDING];
      else {
        [_ctx removeObjectForKey:ODRTableView_ISDESCENDING];
        [_ctx removeObjectForKey:ODRTableView_SORTEDKEY];
      }
      [_ctx deleteLastElementIDComponent];
    }
    [_ctx deleteLastElementIDComponent];
  }
  else
    result = [self invokeActionForChildNodes:[_node childNodes]
                   fromRequest:_req
                   inContext:_ctx];
  
  return result;
}

@end /* ODR_bind_tablecell */


