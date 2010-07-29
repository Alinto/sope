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

#include "ODRDynamicXHTMLTag.h"

/*
  Usage:

  Additions:

  HTML 4.01:
    <!ELEMENT BUTTON - -
         (%flow;)* -(A|%formctrl;|FORM|FIELDSET)
         -- push button -->
    <!ATTLIST BUTTON
      %attrs;                              -- %coreattrs, %i18n, %events --
      name        CDATA          #IMPLIED
      value       CDATA          #IMPLIED  -- sent to server when submitted --
      type        (button|submit|reset) submit -- for use as form button --
      disabled    (disabled)     #IMPLIED  -- unavailable in this context --
      tabindex    NUMBER         #IMPLIED  -- position in tabbing order --
      accesskey   %Character;    #IMPLIED  -- accessibility key character --
      onfocus     %Script;       #IMPLIED  -- the element got the focus --
      onblur      %Script;       #IMPLIED  -- the element lost the focus --
      >
*/

@interface ODR_XHTML_button : ODRDynamicXHTMLTag
@end

#include "common.h"

@implementation ODR_XHTML_button

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  NSString *atype;
  
  if ((atype = [self stringFor:@"type" node:_domNode ctx:_ctx]) == nil) {
    if ([_ctx isInForm])
      atype = @"submit";
    else {
      if ([_domNode attributeNode:@"onclick" namespaceURI:@"*"])
        atype = @"button";
      else
        atype = @"submit";
    }
  }
  
  if ([atype isEqualToString:@"submit"])
    return YES;
  if ([atype isEqualToString:@"reset"])
    return YES;
  
  return NO;
}

- (id)invokeActionForNode:(id)_domNode
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  if ([[_context elementID] isEqualToString:[_context senderID]]) {
    id onClickNode;
    id<DOMNamedNodeMap> attrs;
    
    if ((attrs = [_domNode attributes]) == nil)
      return nil;
    
    if ((onClickNode = [_domNode attributeNode:@"onclick" namespaceURI:@"*"])) {
      return [self invokeValueForAttributeNode:onClickNode inContext:_context];
    }
    else {
      NSLog(@"%s: did not find 'onclick' attribute in a:href !",
            __PRETTY_FUNCTION__);
      return nil;
    }
  }
  
  return [super invokeActionForNode:_domNode
                fromRequest:_request
                inContext:_context];
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *value;
    
  value = [self stringFor:@"value" node:_node ctx:_ctx];
  
  if ([_ctx isInForm]) {
    NSString *atype;
    NSString *value = nil;
    
    atype = [self stringFor:@"type" node:_node ctx:_ctx];
    if (atype == nil) atype = @"submit";

    if ([atype isEqualToString:@"reset"]) {
      [_response appendContentString:@"<input type=\"reset\""];
    }
    else {
      [_response appendContentString:@"<input type=\"submit\""];
    }
    
    if (value) {
      [_response appendContentString:@" value=\""];
      [_response appendContentHTMLAttributeValue:value];
      [_response appendContentString:@"\""];
    }
    
    [_response appendContentString:@" />"];
  }
  else {
    if ([_node attributeNode:@"onclick" namespaceURI:@"*"]) {
      [_response appendContentString:@"<a href=\""];
      [_response appendContentHTMLAttributeValue:[_ctx componentActionURL]];
      [_response appendContentString:@"\">"];
      [_response appendContentHTMLString:value];
      [_response appendContentString:@"</a>"];
    }
    else {
      [_response appendContentString:(value ? value : @"[button]")];
    }
  }
}

@end /* ODR_XHTML_button */
