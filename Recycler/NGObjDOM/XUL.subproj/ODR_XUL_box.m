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

@interface ODR_XUL_hbox : ODR_XUL_box
@end

@interface ODR_XUL_vbox : ODR_XUL_box
@end

#include "common.h"

@implementation ODR_XUL_box

- (NSString *)borderWidthForNode:(id)_node inContext:(WOContext *)_ctx {
  return @"0";
}

- (void)appendAfterTableOfNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
}

- (void)_openTheBox:(id)_node
           response:(WOResponse *)_response
                ctx:(WOContext *)_ctx
{
  NSString *tmp;

  [_response appendContentString:@"<table"];
  
  tmp = [self borderWidthForNode:_node inContext:_ctx];
  if (tmp) {
    [_response appendContentString:@" border=\""];
    [_response appendContentString:tmp];
    [_response appendContentString:@"\""];
  }
  
  tmp = [self stringFor:@"width" node:_node ctx:_ctx];
  tmp = (tmp) ? tmp : @"100%";
  if (tmp) {
    [_response appendContentString:@" width=\""];
    [_response appendContentString:tmp];
    [_response appendContentString:@"\""];
  }

  tmp = [self stringFor:@"height" node:_node ctx:_ctx];
  if (tmp) {
    [_response appendContentString:@" height=\""];
    [_response appendContentString:tmp];
    [_response appendContentString:@"\""];
  }
  [_response appendContentCharacter:'>'];
}

- (void)_openTheCell:(id)_node
            response:(WOResponse *)_response
                 ctx:(WOContext *)_ctx
{
  NSString *tmp;

  [_response appendContentString:@"<td"];
  
  tmp = [self stringFor:@"align" node:_node ctx:_ctx];
  tmp = (tmp) ? tmp : @"center";
  if (tmp) {
    [_response appendContentString:@" align=\""];
    [_response appendContentString:tmp];
    [_response appendContentString:@"\""];
  }
  tmp = [self stringFor:@"valign" node:_node ctx:_ctx];
  if (tmp) {
    [_response appendContentString:@" valign=\""];
    [_response appendContentString:tmp];
    [_response appendContentString:@"\""];
  }
  [_response appendContentCharacter:'>'];
}

- (void)verticalAppendChildList:(id)_nodeList ofNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  id children;
  id child;
  
  if ([_nodeList count] == 0)
    return;
  
  // append <table ....>
  [self _openTheBox:_node response:_response ctx:_ctx];

  [self appendAfterTableOfNode:_node
        toResponse:_response
        inContext:_ctx];
  
  [_ctx appendZeroElementIDComponent];
  
  children = [_nodeList objectEnumerator];
  while ((child = [children nextObject])) {
    ODNodeRenderer *renderer;

    if ([self addChildNode:child inContext:_ctx]) {
      renderer = [self rendererForNode:child inContext:_ctx];
      if (renderer) {
        [_response appendContentString:@"<tr>"];
        // append <td ... >
        [self _openTheCell:_node response:_response ctx:_ctx];
      
        [renderer appendNode:child
                  toResponse:_response
                  inContext:_ctx];
        
        [_response appendContentString:@"</td></tr>"];
      }
    }
    
    [_ctx incrementLastElementIDComponent];
  }
  
  [_ctx deleteLastElementIDComponent];
  
  [_response appendContentString:@"</table>"];
}

- (void)horizontalAppendChildList:(id)_nodeList ofNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  id children;
  id child;
  
  if ([_nodeList count] == 0)
    return;

  // append <table ...>
  [self _openTheBox:_node response:_response ctx:_ctx];
    
  [self appendAfterTableOfNode:_node
        toResponse:_response
        inContext:_ctx];
  
  [_response appendContentString:@"<tr>"];
  
  [_ctx appendZeroElementIDComponent];
  
  children = [_nodeList objectEnumerator];
  while ((child = [children nextObject])) {
    ODNodeRenderer *renderer;
    
    if ([self addChildNode:child inContext:_ctx]) {
      renderer = [self rendererForNode:child inContext:_ctx];
      if (renderer) {
        // append <td ... >
        [self _openTheCell:_node response:_response ctx:_ctx];
      
        [renderer appendNode:child
                  toResponse:_response
                  inContext:_ctx];
        
        [_response appendContentString:@"</td>"];
      }
    }
    
    [_ctx incrementLastElementIDComponent];
  }
  
  [_ctx deleteLastElementIDComponent];
  
  [_response appendContentString:@"</tr></table>"];
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *orient;

  if (![_node hasChildNodes])
    return;
  
  orient = [self stringFor:@"orient" node:_node ctx:_ctx];
  
  if ([orient isEqualToString:@"vertical"]) {
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

@end /* ODR_XUL_box */

@implementation ODR_XUL_hbox

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  if (![_domNode hasChildNodes])
    return;
  
  [self horizontalAppendChildList:[_domNode childNodes] ofNode:_domNode
        toResponse:_response
        inContext:_context];
}

@end /* ODR_XUL_hbox */

@implementation ODR_XUL_vbox

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  if (![_domNode hasChildNodes])
    return;
  
  [self verticalAppendChildList:[_domNode childNodes] ofNode:_domNode
        toResponse:_response
        inContext:_context];
}

@end /* ODR_XUL_vbox */
