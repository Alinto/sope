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

#include <NGObjDOM/ODRGenericTag.h>
#include "common.h"

@implementation ODRGenericTag

- (void)_appendAttributesOfNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  id attrs;
  id<DOMAttr> attr;
  NSString *nsuri, *prefix;
  
  prefix = [_domNode prefix];
  nsuri  = [_domNode namespaceURI];

  if ([nsuri length] > 0) {
    id parentNode;
    BOOL doNS;

    doNS = YES;
    
    if ((parentNode = [_domNode parentNode])) {
      if ([parentNode nodeType] == DOM_ELEMENT_NODE) {
        if ([[parentNode namespaceURI] isEqualToString:nsuri]) {
          NSString *pp;
          
          pp = [parentNode prefix];
          
          if ((pp == nil) && (prefix == nil))
            doNS = NO;
          else if ([pp isEqualToString:prefix])
            doNS = NO;
        }
      }
    }

    if (doNS) {
      [_response appendContentString:@" xmlns"];
      if ([prefix length] > 0) {
        [_response appendContentString:@":"];
        [_response appendContentString:prefix];
      }
      [_response appendContentString:@"='"];
      [_response appendContentString:nsuri];
      [_response appendContentString:@"'"];
    }
  }
  
  if ((attrs = [(id)[_domNode attributes] objectEnumerator]) == nil)
    return;
  
  while ((attr = [attrs nextObject])) {
    NSString *attrURI  = nil;
    NSString *attrName = nil;
    
    attrURI = [attr namespaceURI];
    if ([attrURI length] > 0) {
      if ([attrURI isEqualToString:nsuri]) {
        if ([prefix length] > 0)
          attrName = [NSString stringWithFormat:@"%@:%@", prefix, [attr name]];
        else
          attrName = [attr name];
      }
      else {
        /* different namespace */
        NSLog(@"WARNING(%s): tag '%@'(ns=%@) different namespace %@ ..",
              __PRETTY_FUNCTION__,
              [_domNode tagName], [_domNode namespaceURI], attrURI);
      }
    }
    else
      attrName = [attr name];
    
    [_response appendContentString:@" "];
    [_response appendContentString:attrName];
    [_response appendContentString:@"='"];
    [_response appendContentHTMLAttributeValue:[attr value]];
    [_response appendContentString:@"'"];
  }
}

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  if ([_domNode nodeType] != DOM_ELEMENT_NODE) {
    [super appendNode:_domNode toResponse:_response inContext:_context];
    return;
  }
  
  [_response appendContentString:@"<"];
  if ([[_domNode prefix] length] > 0) {
    [_response appendContentString:[_domNode prefix]];
    [_response appendContentString:@":"];
  }
  [_response appendContentString:[_domNode tagName]];
    
  [self _appendAttributesOfNode:_domNode
        toResponse:_response
        inContext:_context];
    
  if (![_domNode hasChildNodes]) {
    [_response appendContentString:@" />"];
  }
  else {
    [_response appendContentString:@">"];

    /* children */
    [self appendChildNodes:[_domNode childNodes]
          toResponse:_response
          inContext:_context];
    
    [_response appendContentString:@"</"];
    if ([[_domNode prefix] length] > 0) {
      [_response appendContentString:[_domNode prefix]];
      [_response appendContentString:@":"];
    }
    [_response appendContentString:[_domNode tagName]];
    [_response appendContentString:@">"];
  }
}

@end /* ODRGenericTag */
