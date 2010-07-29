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
  http://www.xulplanet.com/tutorials/xultu/elemref/ref_image.html
*/

@interface ODR_XUL_image : ODRDynamicXULTag
@end

#include <DOM/DOM.h>
#include "common.h"
#include "ODNamespaces.h"

@interface WOContext(Privates)
- (void)addActiveFormElement:(id)_element;
@end

@implementation ODR_XUL_image

- (void)takeValuesForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  if ([_context isInForm]) {
    NSString *formId;
    id formValue;
    
    formId = [_context elementID];
    
    if ((formValue = [_request formValueForKey:formId])) {
      /* yep, we are the active element (submit-image) */
      [_context addActiveFormElement:_domNode];
    }
    else {
      /* check for image image coordinates */
      NSString *xId;
      
      xId = [formId stringByAppendingString:@".x"];
      if ((formValue = [_request formValueForKey:xId]))
        /* yep, we are the active element (image-image) */
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
      NSLog(@"%s: did not find 'onclick' attribute in xul:image !",
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


- (void)appendAsFormImage:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *ttip, *src, *onclick;

  ttip    = [self stringFor:@"tooltiptext" node:_node ctx:_ctx];
  src     = [self stringFor:@"src"         node:_node ctx:_ctx];
  onclick = [self stringFor:@"onclick"     node:_node ctx:_ctx];
  
  if ([src length] == 0) {
    [_response appendContentString:@"|missing 'src' attribute in xul:image|"];
  }
  else if ([onclick length] == 0) {
    [_response appendContentString:@"<img src=\""];
    [_response appendContentString:src];
    [_response appendContentCharacter:'"'];
    
    if ([ttip length] > 0) {
      [_response appendContentString:@" alt=\""];
      [_response appendContentHTMLAttributeValue:ttip];
      [_response appendContentString:@"\" title=\""];
      [_response appendContentHTMLAttributeValue:ttip];
      [_response appendContentCharacter:'"'];
    }
    
    [_response appendContentString:@" />"];
  }
  else {
    [_response appendContentString:@"<input type=\"image\" name=\""];
    [_response appendContentString:[_ctx elementID]];
    [_response appendContentString:@"\" src=\""];
    [_response appendContentString:src];
    [_response appendContentCharacter:'"'];
    
    if ([ttip length] > 0) {
      [_response appendContentString:@" alt=\""];
      [_response appendContentHTMLAttributeValue:ttip];
      [_response appendContentString:@"\" title=\""];
      [_response appendContentHTMLAttributeValue:ttip];
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
  NSString *ttip, *src, *onClick;
  
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
    [_response appendContentString:@"<img border='0' src=\""];
    [_response appendContentHTMLAttributeValue:src];
    [_response appendContentString:@"\""];
    
    if ([ttip length] > 0) {
      [_response appendContentString:@" alt=\""];
      [_response appendContentHTMLAttributeValue:ttip];
      [_response appendContentString:@"\""];
    }
    
    [_response appendContentString:@" />"];
  }
  else {
    [_response appendContentString:@"|missing 'src' attribute in xul:image|"];
  }
  
  [super appendNode:_node
         toResponse:_response
         inContext:_ctx];
  
  if ([onClick length] > 0)
    [_response appendContentString:@"</a>"];
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if ([_ctx isInForm])
    [self appendAsFormImage:_node toResponse:_response inContext:_ctx];
  else
    [self appendAsHyperlink:_node toResponse:_response inContext:_ctx];
}


@end /* ODR_XUL_image */
