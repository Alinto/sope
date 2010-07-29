/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

#include "ODR_XUL_box.h"
#include "common.h"
#include <DOM/DOMNode+QueryPath.h>

@interface ODR_XUL_tabbox : ODR_XUL_box
@end

@implementation ODR_XUL_tabbox

- (NSString *)borderWidthForNode:(id)_node inContext:(WOContext *)_context {
  return @"1";
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *align;
  BOOL     selection;

  if (![_node hasChildNodes])
    return;
  
  align     = [self stringFor:@"align"     node:_node ctx:_ctx];
  selection = [self   boolFor:@"selection" node:_node ctx:_ctx];
  
  if ([align isEqualToString:@"vertical"]) {
    [self verticalAppendChildList:[_node childNodes] ofNode:_node
          toResponse:_response
          inContext:_ctx];
  }
  else {
    [self horizontalAppendChildList:[_node childNodes] ofNode:_node
          toResponse:_response
          inContext:_ctx];
  }
}

@end

@interface ODR_XUL_tabpanel : ODR_XUL_box
@end

@implementation ODR_XUL_tabpanel
- (NSString *)borderWidthForNode:(id)_node inContext:(WOContext *)_ctx {
  return @"1";
}

- (BOOL)addChildNode:(id)_node inContext:(WOContext *)_ctx {
  return YES;
}

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  NSArray *childs;

  childs = (NSArray *)[_domNode childNodes];

  if ([childs count] == 0) return;
}

@end /* ODR_XUL_tabpanel */

@interface ODR_XUL_tab : ODRDynamicXULTag
@end

@implementation ODR_XUL_tab

- (BOOL)addChildNode:(id)_node inContext:(WOContext *)_ctx {
  return NO;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *value;
  BOOL     isSelected = YES;;

  value = [self stringFor:@"value" node:_node ctx:_ctx];
  NSLog(@"__tab value is %@", value);
  value = (value) ? value : @"tab";

  NSLog(@"_________ stringValue is %@",
        [self stringFor:@"selected" node:_node ctx:_ctx]);
  
  if (isSelected) [_response appendContentString:@"<B>"];
  
  [_response appendContentString:value];
  
  if (isSelected) [_response appendContentString:@"</B>"];
}

@end /* ODR_XUL_tab */


@interface ODR_XUL_tabcontrol : ODR_XUL_box
@end

@implementation ODR_XUL_tabcontrol

- (NSString *)borderWidthForNode:(id)_node inContext:(WOContext *)_ctx {
  return @"1";
}

- (BOOL)addChildNode:(id)_node inContext:(WOContext *)_ctx {
  return ([[_node nodeName] isEqualToString:@"tabbox"] ||
          [[_node nodeName] isEqualToString:@"tabpanel"]);
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *align;

  if (![_node hasChildNodes])
    return;

  align = [self stringFor:@"align" node:_node ctx:_ctx];
  
  if ([align isEqualToString:@"vertical"]) {
    [self verticalAppendChildList:[_node childNodes] ofNode:_node
          toResponse:_response
          inContext:_ctx];
  }
  else {
    [self horizontalAppendChildList:[_node childNodes] ofNode:_node
          toResponse:_response
          inContext:_ctx];
  }
}

@end /* ODR_XUL_tabcontrol */
