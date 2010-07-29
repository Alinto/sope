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

#include <NGObjDOM/ODREmbedComponent.h>
#include <NGObjDOM/ODNamespaces.h>
#include "common.h"

@interface WOComponent(PrivateMethods)
- (WOComponent *)childComponentWithName:(NSString *)_cname;
@end

@interface NSObject(DOMPrivates)
- (id)attributeNode:(NSString *)_key namespaceURI:(NSString *)_ns;
@end

extern void WOContext_enterComponent
(WOContext *_ctx, WOComponent *_component, WOElement *element);
extern void WOContext_leaveComponent(WOContext *_ctx, WOComponent *_component);

@implementation ODREmbedComponent

- (NSString *)_keyForNode:(id)_domNode inContext:(WOContext *)_ctx {
  NSString *key;
  id attrNode;
  
  attrNode = [_domNode attributeNode:@"id" namespaceURI:XMLNS_OD_BIND];
  key      = [attrNode textValue];
  
  if ([key length] == 0) {
    attrNode = [_domNode attributeNode:@"name" namespaceURI:XMLNS_OD_BIND];
    key      = [attrNode textValue];
  }
  
  if ([key length] == 0)
    key = [NSString stringWithFormat:@"key0%08X", _domNode];
  
  return key;
}

- (void)takeValuesForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *parent, *child;
  NSString    *key;
  
  key = [self _keyForNode:_domNode inContext:_ctx];
  
  if ((parent = [_ctx component]) == nil) {
    [[_ctx session]
           logWithFormat:@"WARNING: did not find parent component of child %@",
             key];
    return;
  }
  if ((child = [parent childComponentWithName:key]) == nil) {
    [[_ctx session]
           logWithFormat:
             @"WARNING: did not find child component %@ of parent %@",
             key, [parent name]];
    return;
  }
  
  WOContext_enterComponent(_ctx, child, nil /*self->template*/);
  [child takeValuesFromRequest:_request inContext:_ctx];
  WOContext_leaveComponent(_ctx, child);
}

- (id)invokeActionForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  id          result = nil;
  WOComponent *parent, *child;
  NSString    *key;
  
  key = [self _keyForNode:_domNode inContext:_ctx];
  
  if ((parent = [_ctx component]) == nil) {
    [[_ctx session]
           logWithFormat:@"WARNING: did not find parent component of child %@",
             key];
    return nil;
  }
  if ((child = [parent childComponentWithName:key]) == nil) {
    [[_ctx session]
           logWithFormat:
             @"WARNING: did not find child component %@ of parent %@",
             key, [parent name]];
    return nil;
  }
  
  WOContext_enterComponent(_ctx, child, nil /*self->template*/);
  result = [child invokeActionForRequest:_request inContext:_ctx];
  WOContext_leaveComponent(_ctx, child);
  
  return result;
}

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *parent, *child;
  NSString    *key;
  
  if ([_domNode nodeType] != DOM_ELEMENT_NODE) {
    [super appendNode:_domNode toResponse:_response inContext:_ctx];
    return;
  }
  
  key = [self _keyForNode:_domNode inContext:_ctx];
  
  if ((parent = [_ctx component]) == nil) {
    [[_ctx session]
           logWithFormat:@"WARNING: did not find parent component of child %@",
             key];
    return;
  }
  
  if ((child = [parent childComponentWithName:key]) == nil) {
    [[_ctx session]
           logWithFormat:
             @"WARNING: did not find child component %@ of parent %@",
             key, [parent name]];
    [_response appendContentString:@"<pre>[missing component: "];
    [_response appendContentHTMLString:key];
    [_response appendContentString:@"]</pre>"];
    return;
  }
  
  WOContext_enterComponent(_ctx, child, nil /*self->template*/);
  [child appendToResponse:_response inContext:_ctx];
  WOContext_leaveComponent(_ctx, child);
}

@end /* ODREmbedComponent */
