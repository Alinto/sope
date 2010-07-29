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

  Dynamic Serverside Attributes
    action
    page

  HTML 4:
    <!ELEMENT A - - (%inline;)* -(A)       -- anchor -->
    <!ATTLIST A
      %attrs;                              -- %coreattrs, %i18n, %events --
      charset     %Charset;      #IMPLIED  -- char encoding of linked resource --
      type        %ContentType;  #IMPLIED  -- advisory content type --
      name        CDATA          #IMPLIED  -- named link end --
      href        %URI;          #IMPLIED  -- URI for linked resource --
      hreflang    %LanguageCode; #IMPLIED  -- language code --
      rel         %LinkTypes;    #IMPLIED  -- forward link types --
      rev         %LinkTypes;    #IMPLIED  -- reverse link types --
      accesskey   %Character;    #IMPLIED  -- accessibility key character --
      shape       %Shape;        rect      -- for use with client-side image maps
      coords      %Coords;       #IMPLIED  -- for use with client-side image maps
      tabindex    NUMBER         #IMPLIED  -- position in tabbing order --
      onfocus     %Script;       #IMPLIED  -- the element got the focus --
      onblur      %Script;       #IMPLIED  -- the element lost the focus --
      >
*/

@interface ODR_XHTML_a : ODRDynamicXHTMLTag
@end

#include "common.h"
#include <NGScripting/NSObject+Scripting.h>
#include <NGObjDOM/ODNamespaces.h>

@interface WOComponent(ProcessHrefPageAction)

- (id)gotoAnkerURL:(NSString *)_url;

@end

@implementation ODR_XHTML_a

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_context
{
  id result = nil;
  
  if ([[_context elementID] isEqualToString:[_context senderID]]) {
    id onClickNode;
    id<DOMNamedNodeMap> attrs;

    if ([_node hasAttribute:@"page"]) {
      NSString *pageName;
      
      pageName = [self stringFor:@"page" node:_node ctx:_context];
      
      return [[_context component] pageWithName:pageName];
    }
    else if ([_node hasAttribute:@"action" namespaceURI:@"*"]) {
      return [self valueFor:@"action" node:_node ctx:_context];
    }
    
    if ((attrs = [_node attributes]) == nil) {
#if DEBUG
      NSLog(@"%s: 'a' node %@ has no attributes ..",
            __PRETTY_FUNCTION__, _node);
#endif
      return nil;
    }

    if ((onClickNode = [_node attributeNode:@"onclick" namespaceURI:@"*"])) {
#if 0 && DEBUG
      NSLog(@"%s: invoke onclick node %@", __PRETTY_FUNCTION__, onClickNode);
#endif
      id o;
      
      o = [self invokeValueForAttributeNode:onClickNode inContext:_context];
      
      if (![o conformsToProtocol:@protocol(WOActionResults)])
        o = nil;
      
      return o;
    }
    
    if ([[_context component] respondsToSelector:@selector(gotoAnkerURL:)]) {
      id<DOMAttr> hrefNode;
      NSString    *href;
      
      if ((hrefNode = [_node attributeNode:@"href" namespaceURI:XMLNS_XHTML]))
        href = [hrefNode value];
      else if ((hrefNode = [_node attributeNode:@"href" 
                                  namespaceURI:XMLNS_HTML40]))
        href = [hrefNode value];
      else if ((hrefNode = [_node attributeNode:@"href"
                                     namespaceURI:XMLNS_OD_BIND]))
        href = [[_context component] valueForKeyPath:[hrefNode value]];
      else if ((hrefNode = [_node attributeNode:@"href"
                                  namespaceURI:XMLNS_OD_EVALJS])) {
        href = [[_context component]
                          evaluateScript:[hrefNode value] language:nil];
      }
      else
        href = nil;
      
      if (href)
        return [[_context component] gotoAnkerURL:href];
    }

    NSLog(@"%s: did not active attribute in <a> node %@ !",
          __PRETTY_FUNCTION__, _node);
    return nil;
  }
#if DEBUG
  else {
    NSLog(@"%s: senderID and elementID differ:\nsid=%@\neid=%@",
          __PRETTY_FUNCTION__, [_context senderID], [_context elementID]);
  }
#endif
  
  result = [super invokeActionForNode:_node
                  fromRequest:_request
                  inContext:_context];
  
  return result;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *src;
  NSString *tmp;
  id hrefNode;
  
  if ([_node hasAttribute:@"page" namespaceURI:@"*"]) {
    /* page action */
    src = [_ctx componentActionURL];
  }
  else if ([_node hasAttribute:@"action" namespaceURI:@"*"]) {
    /* component action */
    src = [_ctx componentActionURL];
  }
  else if ([_node attributeNode:@"onclick" namespaceURI:@"*"] != nil) {
    src = [_ctx componentActionURL];
  }
  else if ((hrefNode = [_node attributeNode:@"href" namespaceURI:@"*"])) {
    if ([[_ctx component] respondsToSelector:@selector(gotoAnkerURL:)])
      src = [_ctx componentActionURL];
    else
      src = [self valueForAttributeNode:hrefNode inContext:_ctx];
  }
  else
    src = nil;
  
  [_response appendContentString:@"<a "];
  
  if ([src length] > 0) {
    [_response appendContentString:@" href=\""];
    [_response appendContentHTMLAttributeValue:src];
    [_response appendContentCharacter:'"'];
  }
  
  if ((tmp = [self stringFor:@"target" node:_node ctx:_ctx])) {
    [_response appendContentString:@" target=\""];
    [_response appendContentHTMLAttributeValue:tmp];
    [_response appendContentCharacter:'"'];
  }
  if ((tmp = [self stringFor:@"name" node:_node ctx:_ctx])) {
    [_response appendContentString:@" name=\""];
    [_response appendContentHTMLAttributeValue:tmp];
    [_response appendContentCharacter:'"'];
  }
  
  [_response appendContentCharacter:'>'];
  
  /* add subelements */
  [self appendChildNodes:[_node childNodes]
        toResponse:_response
        inContext:_ctx];
  
  /* close tag */
  [_response appendContentString:@"</a>"];
}

@end /* ODR_XHTML_a */
