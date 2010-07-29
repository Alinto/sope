/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "WETableCell.h"
#include "WETableView.h"
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

@implementation WETableCell

static NSNumber *YesNumber = nil;
static NSNumber *NoNumber  = nil;

+ (void)initialize {
  if (YesNumber == nil) YesNumber = [[NSNumber numberWithBool:YES] retain];
  if (NoNumber  == nil) NoNumber  = [[NSNumber numberWithBool:NO]  retain];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->sortKey          = WOExtGetProperty(_config, @"sortKey");
    self->negateSortDir    = WOExtGetProperty(_config, @"negateSortDir");
    
    self->bgColor          = WOExtGetProperty(_config, @"bgColor");
    self->upwardSortIcon   = WOExtGetProperty(_config, @"upwardSortIcon");
    self->downwardSortIcon = WOExtGetProperty(_config, @"downwardSortIcon");
    self->nonSortIcon      = WOExtGetProperty(_config, @"nonSortIcon");
    self->sortLabel        = WOExtGetProperty(_config, @"sortLabel");
    
    self->template = [_c retain];
  }
  return self;
}

- (void)dealloc {
  [self->sortKey          release];
  [self->negateSortDir    release];
  [self->bgColor          release];
  [self->upwardSortIcon   release];
  [self->downwardSortIcon release];
  [self->nonSortIcon      release];
  [self->sortLabel        release];
  [self->template         release];
  [super dealloc];
}

/* generating response */

- (void)appendSortIcon:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *cmp;
  NSString    *icon = nil;
  NSString    *nav  = nil;
  BOOL        doForm;
  NSString    *sortedKey;
  NSString    *label;
  NSString    *sk;
  int         sortDir;
  
  doForm    = [_ctx isInForm];
  cmp       = [_ctx component];
  sortedKey = [_ctx objectForKey:WETableView_SORTEDKEY];
  sk        = [self->sortKey stringValueInComponent:cmp];
  
  label     = [self->sortLabel stringValueInComponent:cmp];
  label     = (label) ? label : WETableLabelForKey(@"sort", _ctx);

  if (sk == nil)
    return;
  
  if ([sk rangeOfString:@"."].length > 0)
    sk = [sk stringByReplacingString:@"." withString:@"_"];
  
  if (![sk isEqualToString:sortedKey])
    sortDir = 0;
  else if ( [_ctx objectForKey:WETableView_ISDESCENDING] == nil ||
           [[_ctx objectForKey:WETableView_ISDESCENDING] boolValue])
    sortDir = -1;
  else
    sortDir = 1;
  
  switch (sortDir) {
    case  1: nav = @"down"; break;
    case  0: nav = @"non";  break;
    case -1: nav = @"up";   break;
  }
  switch (sortDir) {
    case  1: icon = [self->downwardSortIcon stringValueInComponent:cmp]; break;
    case  0: icon = [self->nonSortIcon      stringValueInComponent:cmp]; break;
    case -1: icon = [self->upwardSortIcon   stringValueInComponent:cmp]; break;
  }
  if (!WEUriOfResource(icon,_ctx)) {
    switch (sortDir) {
      case  1: icon = [_ctx objectForKey:WETableView_downwardIcon]; break;
      case  0: icon = [_ctx objectForKey:WETableView_nonSortIcon];  break;
      case -1: icon = [_ctx objectForKey:WETableView_upwardIcon];   break;
    }
  }

  icon   = WEUriOfResource(icon, _ctx);
  doForm = doForm && (icon);

#if 0
  if (icon == nil)
    return;
#endif
  
  // append something like that: sort.name.down
  [_ctx appendElementIDComponent:@"sort"];
  [_ctx appendElementIDComponent:sk];     // remember sortKey
  [_ctx appendElementIDComponent:nav];    // remember sortDirection

  // append as submit button
  if (doForm) {
    [_response appendContentString:@"<input type=\"image\" border=\"0\""];
    [_response appendContentString:@" align=\"top\" name=\""];
    [_response appendContentString:[_ctx elementID]];
    [_response appendContentString:@"\" src=\""];
    [_response appendContentString:icon];
    [_response appendContentString:@"\" alt=\""];
    [_response appendContentString:label];
    [_response appendContentString:@"\" title=\""];
    [_response appendContentString:label];
    [_response appendContentString:@"\" />"];
  }
  /* append as hyperlink */
  else {
    [_response appendContentString:@"<a href=\""];
    [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentString:@"\">"];

    if (icon) {
      [_response appendContentString:@"<img border=\"0\" src=\""];
      [_response appendContentString:icon];
      [_response appendContentString:@"\" alt=\""];
      [_response appendContentString:label];
      [_response appendContentString:@"\" title=\""];
      [_response appendContentString:label];
      [_response appendContentString:@"\" align=\"top\" />"];
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
  [_ctx deleteLastElementIDComponent];
  [_ctx deleteLastElementIDComponent];
  [_ctx deleteLastElementIDComponent];

  return;
}

/* processing request */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSString *k;

  k = [self->sortKey stringValueInComponent:[_ctx component]];

  if (k && [[_ctx objectForKey:WETableView_HeaderMode] boolValue]) {
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
      [self ->template takeValuesFromRequest:_req inContext:_ctx];
  }
  else if (![[_ctx objectForKey:WETableView_HeaderMode] boolValue])
    [self->template takeValuesFromRequest:_req inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent *cmp   = nil;
  NSString    *k, *tmp;
  BOOL        doNegate;
  
  cmp = [_ctx component];
  k   = [self->sortKey stringValueInComponent:cmp];
  if (!([[_ctx currentElementID] isEqual:@"sort"] && k != nil))
    return [self->template invokeActionForRequest:_rq inContext:_ctx];
  
  [_ctx consumeElementID];                 // consume "sort"
  [_ctx appendElementIDComponent:@"sort"]; // append  "sort"
  
  if ([k rangeOfString:@"."].length > 0)
    k = [k stringByReplacingString:@"." withString:@"_"];
  
  tmp = [_ctx currentElementID];

  if (!(tmp != nil && [tmp isEqualToString:k])) {
    [_ctx deleteLastElementIDComponent]; // 'sort'
    return nil;
  }
  
  doNegate = [[self->negateSortDir valueInComponent:cmp] boolValue];

  [_ctx consumeElementID];               // consume sortKey
  [_ctx appendElementIDComponent:k];     // append  sortKey
  [_ctx setObject:k forKey:WETableView_SORTEDKEY];

  tmp = [_ctx currentElementID];

  if ([tmp isEqualToString:@"down"])
    [_ctx setObject:YesNumber forKey:WETableView_ISDESCENDING];
  else if ([tmp isEqualToString:@"up"])
    [_ctx setObject:NoNumber forKey:WETableView_ISDESCENDING];
  else if ([tmp isEqualToString:@"non"])
    [_ctx setObject:[NSNumber numberWithBool:doNegate]
             forKey:WETableView_ISDESCENDING];
  else {
    [_ctx removeObjectForKey:WETableView_ISDESCENDING];
    [_ctx removeObjectForKey:WETableView_SORTEDKEY];
  }
  [_ctx deleteLastElementIDComponent]; // sortKey
  [_ctx deleteLastElementIDComponent]; // 'sort'
  
  return nil;
}

@end /* WETableCell */
