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

#include <NGObjDOM/ODRWebObject.h>
#include <NGObjDOM/ODNamespaces.h>
#include <NGObjWeb/WODynamicElement.h>
#include "common.h"

@interface NSObject(WOPrivates)
+ (BOOL)isDynamicElement;
- (BOOL)isDynamicElement;
@end

@interface _WODRTemplateElement : WODynamicElement
{
@public
  /* both non-retained */
  ODNodeRenderer *renderer;
  id domNode;
}
@end

@implementation ODRWebObject

- (NSMutableDictionary *)associationsForNodeAttributes:(id)_domNode {
  NSMutableDictionary *md;
  NSEnumerator *attrs;
  id attrNode;
  
  md = [NSMutableDictionary dictionaryWithCapacity:16];
  
  attrs = [(id)[_domNode attributes] objectEnumerator];
  while ((attrNode = [attrs nextObject])) {
    NSString *nsuri;
    
    nsuri = [attrNode namespaceURI];
    
    if ([nsuri isEqualToString:XMLNS_OD_BIND]) {
      [md setObject:[WOAssociation associationWithKeyPath:[attrNode textValue]]
          forKey:[(id<DOMAttr>)attrNode name]];
    }
    else {
      [md setObject:[WOAssociation associationWithValue:[attrNode textValue]]
          forKey:[(id<DOMAttr>)attrNode name]];
    }
  }
  
  return md;
}

- (WOElement *)constructElementForElementNode:(id)_domNode {
  Class clazz;
  
  clazz = NSClassFromString([_domNode tagName]);

  if (clazz == Nil) {
    NSLog(@"%s: Can't find class for node %@",
          __PRETTY_FUNCTION__, _domNode);
    return nil;
  }
  else if ([clazz isDynamicElement]) {
    WODynamicElement     *elem;
    NSString             *elemName;
    NSMutableDictionary  *assocs;
    _WODRTemplateElement *template;

    elemName = [[[_domNode attributes] namedItem:@"id"] textValue];
    assocs   = [self associationsForNodeAttributes:_domNode];
    template = nil;

    if ([_domNode hasChildNodes]) {
      template = [[_WODRTemplateElement alloc] init];
      template->renderer = self;
      template->domNode  = _domNode;
      AUTORELEASE(template);
    }
    
    elem  = [clazz alloc];
    elem  = [elem initWithName:elemName
                  associations:assocs
                  template:template];
    
    if ([assocs count] > 0)
      [elem setExtraAttributes:assocs];
    
    [assocs removeAllObjects];
    
    return AUTORELEASE(elem);
  }
  else {
    NSLog(@"%s: Can't handle element class %@ for node %@",
          __PRETTY_FUNCTION__,
          clazz, _domNode);
    return nil;
  }
}

- (void)takeValuesForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  WOElement *e;
  
  e = [self constructElementForElementNode:_domNode];
  [e takeValuesFromRequest:_request inContext:_context];
}

- (id)invokeActionForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  WOElement *e;
  id result;
  
  e = [self constructElementForElementNode:_domNode];
  result = [e invokeActionForRequest:_request inContext:_context];
  
  return result;
}

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  WOElement *e;
  
  if ([_domNode nodeType] != DOM_ELEMENT_NODE) {
    [super appendNode:_domNode toResponse:_response inContext:_context];
    return;
  }
  
  e = [self constructElementForElementNode:_domNode];
  [e appendToResponse:_response inContext:_context];
}

@end /* ODRWebObject */

@implementation _WODRTemplateElement

- (id)_childRendererForNode:(id)_node {
  static id childRenderer = nil;
  if (childRenderer == nil)
    childRenderer = [[NSClassFromString(@"WODRChildNodes") alloc] init];
  return childRenderer;
}

- (void)takeValuesFromRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  if (![self->domNode hasChildNodes])
    return;
  
  [self->renderer takeValuesForChildNodes:[self->domNode childNodes]
       fromRequest:_request
       inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  if (![self->domNode hasChildNodes])
    return nil;
  
  return [self->renderer invokeActionForChildNodes:[self->domNode childNodes]
              fromRequest:_request
              inContext:_ctx];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([self->domNode hasChildNodes]) {
    //NSLog(@"%s: %@ ..", __PRETTY_FUNCTION__, self->domNode);
  
    [self->renderer appendChildNodes:[self->domNode childNodes]
         toResponse:_response
         inContext:_ctx];
  }
}

@end /* _WODRTemplateElement */

