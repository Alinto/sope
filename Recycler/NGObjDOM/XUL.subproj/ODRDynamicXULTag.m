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

#include "ODRDynamicXULTag.h"
#include <NGObjDOM/ODNamespaces.h>
#include <NGScripting/NSObject+Scripting.h>
#include "common.h"

@implementation ODRDynamicXULTag

- (BOOL)addChildNode:(id)_node inContext:(WOContext *)_ctx {
  return [_node nodeType] == DOM_ELEMENT_NODE ? YES : NO;
}

- (id)invokeValueForAttributeNode:(id<DOMAttr>)_attrNode inContext:(id)_ctx {
  id scriptResult;
  
  if (![[_attrNode namespaceURI] isEqualToString:XMLNS_XUL])
    return [super invokeValueForAttributeNode:_attrNode inContext:_ctx];

  if (![(NSString *)[(id<DOMAttr>)_attrNode name] hasPrefix:@"on"]) 
    return [super invokeValueForAttributeNode:_attrNode inContext:_ctx];
  
  /* a JS action, eg onclick */
  
  scriptResult =
    [[_ctx component] evaluateScript:[_attrNode value] language:nil];
  
  return nil;
}

- (void)takeValuesForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  if ([_domNode hasChildNodes]) {
    [self takeValuesForChildNodes:[_domNode childNodes]
          fromRequest:_request
          inContext:_context];
  }
}

- (id)invokeActionForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  if (![_domNode hasChildNodes])
    return nil;
  
  return [self invokeActionForChildNodes:[_domNode childNodes]
               fromRequest:_request
               inContext:_context];
}

- (void)willAppendChildNode:(id)_child
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
}
- (void)didAppendChildNode:(id)_child
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
}

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  id children;
  id child;
  
  if (![_domNode hasChildNodes])
    return;
  
  [_ctx appendZeroElementIDComponent];
  
  children = [(id)[_domNode childNodes] objectEnumerator];
  while ((child = [children nextObject])) {
    ODNodeRenderer *renderer;
    
    if ([self includeChildNode:child ofNode:_domNode inContext:_ctx]) {
      if ((renderer = [self rendererForNode:child inContext:_ctx])) {
        [self willAppendChildNode:child
              toResponse:_response
              inContext:_ctx];
        
        [renderer appendNode:child
                  toResponse:_response
                  inContext:_ctx];
        
        [self didAppendChildNode:child
              toResponse:_response
              inContext:_ctx];
      }
    }
    [_ctx incrementLastElementIDComponent];
  }
  [_ctx deleteLastElementIDComponent];
}

@end /* ODRDynamicXULTag */
