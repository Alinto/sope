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

#include <NGObjDOM/ODR_bind_collapsible.h>
#include "common.h"

@implementation ODR_bind_collapsible

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *eid;

  eid = [_ctx elementID];

  if ([self boolFor:@"visible" node:_node ctx:_ctx]) {
    [_ctx appendZeroElementIDComponent];
    [self takeValuesForChildNodes:[_node childNodes]
          fromRequest:_request
          inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  
  if ([_request formValueForKey:[eid stringByAppendingString:@".c"]] ||
      [_request formValueForKey:[eid stringByAppendingString:@".c.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:[[_ctx senderID] stringByAppendingString:@".c"]];
  }
  else if ([_request formValueForKey:[eid stringByAppendingString:@".e"]] ||
           [_request formValueForKey:[eid stringByAppendingString:@".e.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:[[_ctx senderID] stringByAppendingString:@".e"]];
  }
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *state;
  NSString *eid;

  state = [[_ctx currentElementID] stringValue];

  eid = [_ctx elementID];

  if (state) {
    [_ctx consumeElementID]; // consume state-id (on or off)
    
    if ([state isEqualToString:@"e"]) {
      [self forceSetBool:NO for:@"visible" node:_node ctx:_ctx];
      if (NO)
        ; //[self->submitActionName valueInComponent:[_ctx component]];
    }
    else if ([state isEqualToString:@"c"]) {
      [self forceSetBool:YES for:@"visible" node:_node ctx:_ctx];
      if (NO)
        ; // [self->submitActionName valueInComponent:[_ctx component]];
    }
    else {
      id result;
      
      [_ctx appendElementIDComponent:state];
      result = [self invokeActionForChildNodes:[_node childNodes]
                     fromRequest:_request
                     inContext:_ctx];
      
      [_ctx deleteLastElementIDComponent];

      return result;
    }
  }
  return nil;
}

- (void)appendNode:(id)_node
        toResponse:(WOResponse *)_response
         inContext:(WOContext *)_ctx
{
  NSString *img;
  NSString *label;
  BOOL     isCollapsed;
  BOOL     doForm;

  if (![self hasAttribute:@"visible" node:_node ctx:_ctx])
    [self forceSetBool:YES for:@"visible" node:_node ctx:_ctx];

  doForm      = [_ctx isInForm];
  isCollapsed = ![self boolFor:@"visible" node:_node ctx:_ctx];

  img = (isCollapsed)
    ? [self stringFor:@"closedicon" node:_node ctx:_ctx]
    : [self stringFor:@"openedicon" node:_node ctx:_ctx];

  label = (isCollapsed)
    ? [self stringFor:@"closedlabel" node:_node ctx:_ctx]
    : [self stringFor:@"openedlabel" node:_node ctx:_ctx];

  if (label == nil)
    label = [self stringFor:@"label" node:_node ctx:_ctx];

  img = ODRUriOfResource(img, _ctx);

  [_ctx appendElementIDComponent:(isCollapsed) ? @"c" : @"e"];

  if (doForm) {
    NSString *value;

    value = (img == nil || label == nil)
      ? (isCollapsed) ? @"+" : @"-"
      : (id)label;
    
    ODRAppendButton(_response, [_ctx elementID], img, value);
  }
  else {
    NSString *value;
    
    value = (img == nil || label == nil)
      ? (isCollapsed) ? @"[+]" : @"[-]"
      : (id)label;
    
    [_response appendContentString:@"<A HREF=\""];
    [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentString:@"\">"];

    ODRAppendImage(_response, nil, img, value);

    [_response appendContentString:@"</A>"];
  }

  [_ctx deleteLastElementIDComponent];

  if (label) {
    [_response appendContentString:@"&nbsp;"];
    [_response appendContentString:label];
  }

  if (!isCollapsed) {
    [_response appendContentString:@"<br>"];
    [_ctx appendZeroElementIDComponent];
    [self appendChildNodes:[_node childNodes]
          toResponse:_response
          inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  [_response appendContentString:@"<br>"];
}

@end /* ODR_bind_collapsible */
