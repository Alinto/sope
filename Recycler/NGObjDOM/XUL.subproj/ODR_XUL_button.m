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

/*
  http://www.xulplanet.com/tutorials/xultu/elemref/ref_button.html
*/

@interface ODR_XUL_button : ODRDynamicXULTag
@end

#include <DOM/DOM.h>
#include "common.h"
#include "ODNamespaces.h"

@interface WOContext(Privates)
- (void)addActiveFormElement:(id)_element;
@end

@implementation ODR_XUL_button

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return YES;
}

- (void)takeValuesForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  if ([_context isInForm]) {
    NSString *formId;
    id formValue;
    
    formId = [_context elementID];
    
    if ((formValue = [_request formValueForKey:formId])) {
      /* yep, we are the active element (submit-button) */
      [_context addActiveFormElement:_domNode];
    }
    else {
      /* check for image button coordinates */
      NSString *xId;
      
      xId = [formId stringByAppendingString:@".x"];
      if ((formValue = [_request formValueForKey:xId]))
        /* yep, we are the active element (image-button) */
        [_context addActiveFormElement:_domNode];
    }
  }
  
  [super takeValuesForNode:_domNode
         fromRequest:_request
         inContext:_context];
}

- (id)invokeActionForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  if ([[_context elementID] isEqualToString:[_context senderID]]) {
    /* active element .. */
    id onClickNode;
    id<DOMNamedNodeMap> attrs;
    
    if ((attrs = [_domNode attributes]) == nil)
      return nil;
    
    if ((onClickNode = [_domNode attributeNode:@"onclick" namespaceURI:@"*"])) {
      return [self invokeValueForAttributeNode:onClickNode inContext:_context];
    }
    else {
      NSLog(@"%s: did not find 'onclick' attribute in xul:button !",
            __PRETTY_FUNCTION__);
      return nil;
    }
  }
  else {
    return [super invokeActionForNode:_domNode
                  fromRequest:_request
                  inContext:_context];
  }
}


- (void)appendAsFormButton:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *value, *ttip, *src, *onClick;

  value   = [self stringFor:@"value"       node:_node ctx:_ctx];
  ttip    = [self stringFor:@"tooltiptext" node:_node ctx:_ctx];
  src     = [self stringFor:@"src"         node:_node ctx:_ctx];
  onClick = [self stringFor:@"onclick"     node:_node ctx:_ctx];

  if ([src length] == 0) {
    [_response appendContentString:@"<input type=\"submit\" name=\""];
    [_response appendContentString:[_ctx elementID]];
    [_response appendContentString:@"\" value=\""];
    [_response appendContentHTMLAttributeValue:value];
    [_response appendContentString:@"\" />"];
  }
  else {
    NSString *alt;
      
    [_response appendContentString:@"<input type=\"image\" name=\""];
    [_response appendContentString:[_ctx elementID]];
    [_response appendContentString:@"\" src=\""];
    [_response appendContentString:src];
    [_response appendContentCharacter:'"'];
        
    if ([ttip length] > 0)
      alt = ttip;
    else if ([value length] > 0)
      alt = value;
    else
      alt = nil;
    
    if ([alt length] > 0) {
      [_response appendContentString:@" alt=\""];
      [_response appendContentHTMLAttributeValue:alt];
      [_response appendContentString:@"\" title=\""];
      [_response appendContentHTMLAttributeValue:alt];
      [_response appendContentCharacter:'"'];
    }
    
    [_response appendContentString:@" />"];
  }
  
  [super appendNode:_node
         toResponse:_response
         inContext:_ctx];
}

- (void)appendAsHyperlink:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *value, *ttip, *src, *onClick;

  value   = [self stringFor:@"value"       node:_node ctx:_ctx];
  ttip    = [self stringFor:@"tooltiptext" node:_node ctx:_ctx];
  src     = [self stringFor:@"src"         node:_node ctx:_ctx];
  onClick = [self stringFor:@"onclick"     node:_node ctx:_ctx];
  
  if ([onClick length] > 0) {
    [_response appendContentString:@"<a href=\""];
    [_response appendContentString:onClick];
    [_response appendContentString:@"\""];
    
    if ([ttip length] > 0) {
      [_response appendContentString:@" title=\""];
      [_response appendContentHTMLAttributeValue:ttip];
      [_response appendContentString:@"\""];
    }
    
    [_response appendContentString:@">"];
  }
  
  if ([src length] > 0) {
    NSString *alt;
    
    [_response appendContentString:@"<img border='0' src=\""];
    [_response appendContentHTMLAttributeValue:src];
    [_response appendContentString:@"\""];
    
    if ([ttip length] > 0)
      alt = ttip;
    else if ([value length] > 0)
      alt = value;
    else
      alt = nil;
    
    if ([alt length] > 0) {
      [_response appendContentString:@" alt=\""];
      [_response appendContentHTMLAttributeValue:alt];
      [_response appendContentString:@"\""];
    }
    
    [_response appendContentString:@" />"];
  }
  else if ([value length] > 0)
    [_response appendContentHTMLString:value];
  
  [super appendNode:_node
         toResponse:_response
         inContext:_ctx];
  
  if (onClick != nil)
    [_response appendContentString:@"</a>"];
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if ([_ctx isInForm])
    [self appendAsFormButton:_node toResponse:_response inContext:_ctx];
  else
    [self appendAsHyperlink:_node toResponse:_response inContext:_ctx];
}


@end /* ODR_XUL_button */
