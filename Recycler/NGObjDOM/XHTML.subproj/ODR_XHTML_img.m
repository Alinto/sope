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

  HTML 4:
   <!ELEMENT IMG - O EMPTY                -- Embedded image -->
   <!ATTLIST IMG
     %attrs;                              -- %coreattrs, %i18n, %events --
     src         %URI;          #REQUIRED -- URI of image to embed --
     alt         %Text;         #REQUIRED -- short description --
     longdesc    %URI;          #IMPLIED  -- link to long description
                                             (complements alt) --
     name        CDATA          #IMPLIED  -- name of image for scripting --
     height      %Length;       #IMPLIED  -- override height --
     width       %Length;       #IMPLIED  -- override width --
     usemap      %URI;          #IMPLIED  -- use client-side image map --
     ismap       (ismap)        #IMPLIED  -- use server-side image map --
     >
*/

@interface ODR_XHTML_img : ODRDynamicXHTMLTag
@end

#include "common.h"

@implementation ODR_XHTML_img

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
  NSString *src, *href;
  NSString *tmp;
  id srcNode;
  
  if ([_node attributeNode:@"onclick" namespaceURI:@"*"])
    href = [_ctx componentActionURL];
  else
    href = nil;
  
  if ((srcNode = [_node attributeNode:@"src" namespaceURI:@"*"]))
    src = [[self valueForAttributeNode:srcNode inContext:_ctx] stringValue];
  else
    src = nil;
  
  /* open link tag */
  if ([href length] > 0) {
    [_response appendContentString:@"<a href=\""];
    [_response appendContentHTMLAttributeValue:href];
    [_response appendContentString:@"\">"];
  }
  
  if ([src length] > 0) {
    [_response appendContentString:@"<img src=\""];
    [_response appendContentString:src];
    [_response appendContentCharacter:'"'];
  
    if ((tmp = [self stringFor:@"alt" node:_node ctx:_ctx])) {
      [_response appendContentString:@" alt=\""];
      [_response appendContentHTMLAttributeValue:tmp];
      [_response appendContentCharacter:'"'];
    }
    if ((tmp = [self stringFor:@"border" node:_node ctx:_ctx])) {
      [_response appendContentString:@" border=\""];
      [_response appendContentHTMLAttributeValue:tmp];
      [_response appendContentCharacter:'"'];
    }
    if ((tmp = [self stringFor:@"height" node:_node ctx:_ctx])) {
      [_response appendContentString:@" height=\""];
      [_response appendContentHTMLAttributeValue:tmp];
      [_response appendContentCharacter:'"'];
    }
    if ((tmp = [self stringFor:@"width" node:_node ctx:_ctx])) {
      [_response appendContentString:@" width=\""];
      [_response appendContentHTMLAttributeValue:tmp];
      [_response appendContentCharacter:'"'];
    }
    
    [_response appendContentString:@" />"];
  }
  else {
    [_response appendContentString:@"[img: "];
    
    if ((tmp = [self stringFor:@"alt" node:_node ctx:_ctx]))
      [_response appendContentHTMLString:tmp];
    
    [_response appendContentString:@"]"];
  }
  
  /* close link tag */
  if ([href length] > 0)
    [_response appendContentString:@"</a>"];
}

@end /* ODR_XHTML_img */
