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

#include <NGObjDOM/ODNodeRenderer.h>

/*
   attributes:
     condition
     value1
     value2
     
   usage:
     <script>
       var condition=true;
     </script>
     
     <var:if condition="condition1">
       content of if
       <var:elseif condition="condition2"/>content of elseif</elseif>
       <var:else>content of else</var:else>
     </var:if>
     
     <var:ifnot condition="condition">
       <content />
     </var:ifnot>

     <var:if const:value1="10" const:value2="20">
       ..
     </var:if>
*/

@interface ODR_bind_if : ODNodeRenderer
@end

@interface ODR_bind_ifnot : ODR_bind_if
@end

#include <DOM/DOM.h>
#include "common.h"

@implementation ODR_bind_if

- (BOOL)doShow:(id)_node ctx:(WOContext *)_ctx {
  BOOL doShow;

  doShow = YES;
  
  if ([self hasAttribute:@"condition" node:_node ctx:_ctx]) {
    BOOL flag;
    flag = [self boolFor:@"condition" node:_node ctx:_ctx];
    if (!flag) doShow = NO;
  }
  
  if ([self hasAttribute:@"value1" node:_node ctx:_ctx]) {
    if ([self hasAttribute:@"value2" node:_node ctx:_ctx]) {
      id value1, value2;
      BOOL flag;
      
      value1 = [self valueFor:@"value1" node:_node ctx:_ctx];
      value2 = [self valueFor:@"value2" node:_node ctx:_ctx];
      
      if (value1 == nil && value2 == nil)
        flag = YES;
      else
        flag = [value1 isEqual:value2];
      
      if (!flag) doShow = NO;
    }
  }
  
  return doShow;
}

- (NSArray *)_contentOfIfNode:(id)_node {
  NSArray        *children;
  NSMutableArray *result;
  int            i, cnt;

  children = (NSArray *)[_node childNodes];
  //children = ODRLookupQueryPath(_node, @"-*");
  cnt      = [children count];
  result   = [NSMutableArray arrayWithCapacity:cnt];
  
  for (i=0; i<cnt; i++) {
    NSString *tagName;
    id       child;

    child = [children objectAtIndex:i];
    tagName = [child nodeName];
    
    if (![tagName isEqualToString:@"else"] &&
        ![tagName isEqualToString:@"elseif"])
      [result addObject:child];
  }
  return result;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if ([self doShow:_node ctx:_ctx]) {
    [_ctx appendElementIDComponent:@"if"];
    
    [self takeValuesForChildNodes:[self _contentOfIfNode:_node]
           fromRequest:_request
           inContext:_ctx];
    
    [_ctx deleteLastElementIDComponent]; // delete "if"
  }
  else {
    BOOL    didMatch = NO;
    NSArray *children;
    int     i, cnt;

    children = ODRLookupQueryPath(_node, @"-elseif");
    cnt      = [children count];
    
    for (i = 0; i < cnt; i++) {
      id child;

      child = [children objectAtIndex:i];
      
      if ([self doShow:child ctx:_ctx]) {
        [_ctx appendElementIDComponent:@"elseif"];
        [_ctx appendElementIDComponent:[NSString stringWithFormat:@"%d", i]];
        [super takeValuesForNode:child fromRequest:_request inContext:_ctx];
        [_ctx deleteLastElementIDComponent]; // i
        [_ctx deleteLastElementIDComponent]; // "elseif"
        didMatch = YES;
        break;
      }
    }
    if (!didMatch) {
      [_ctx appendElementIDComponent:@"else"];
      [self takeValuesForChildNodes:ODRLookupQueryPath(_node, @"-else")
            fromRequest:_request
            inContext:_ctx];
      [_ctx deleteLastElementIDComponent]; // "else"
    }
  }
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *state;
  id       result = nil;

  state = [[_ctx currentElementID] stringValue];
  
  if (state) {
    [_ctx consumeElementID]; // consume ("if" | "elseif" | "else")

    if ([state isEqualToString:@"if"]) {
      
      [_ctx appendElementIDComponent:@"if"];
      result = [self invokeActionForChildNodes:[self _contentOfIfNode:_node]
                     fromRequest:_request
                     inContext:_ctx];
      [_ctx deleteLastElementIDComponent]; // if
    }
    else if ([state isEqualToString:@"elseif"]) {
      NSArray  *children;
      NSString *idx;
      int      i;

      children = ODRLookupQueryPath(_node, @"-elseif");
      idx      = [[_ctx currentElementID] stringValue];
      i        = [idx intValue];

      if (i < (int)[children count]) {
        [_ctx appendElementIDComponent:@"elseif"];
        [_ctx appendElementIDComponent:idx];
        result = [super invokeActionForNode:[children objectAtIndex:i]
                        fromRequest:_request
                        inContext:_ctx];
        [_ctx deleteLastElementIDComponent]; // idx
        [_ctx deleteLastElementIDComponent]; // "elseif"        
      }
      else
        [[_ctx component] logWithFormat:@"index out of range"];
    }
    else if ([state isEqualToString:@"else"]) {
      [_ctx appendElementIDComponent:@"else"];
      result = 
        [self invokeActionForChildNodes:ODRLookupQueryPath(_node, @"-else")
              fromRequest:_request
              inContext:_ctx];
      [_ctx deleteLastElementIDComponent]; // "else"
    }
    else
      [[_ctx component] logWithFormat:@"wrong section"]; 
  }
  return result;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{ 
  if ([self doShow:_node ctx:_ctx]) {
    [_ctx appendElementIDComponent:@"if"];
    
    [self appendChildNodes:[self _contentOfIfNode:_node]
           toResponse:_response
           inContext:_ctx];
    
    [_ctx deleteLastElementIDComponent]; // delete "if"
  }
  else {
    BOOL    didMatch = NO;
    NSArray *children;
    int     i, cnt;

    children = ODRLookupQueryPath(_node, @"-elseif");
    cnt      = [children count];
    
    for (i = 0; i < cnt; i++) {
      id child;

      child = [children objectAtIndex:i];
      
      if ([self doShow:child ctx:_ctx]) {
        [_ctx appendElementIDComponent:@"elseif"];
        [_ctx appendElementIDComponent:[NSString stringWithFormat:@"%d", i]];
        [super appendNode:child toResponse:_response inContext:_ctx];
        [_ctx deleteLastElementIDComponent]; // i
        [_ctx deleteLastElementIDComponent]; // "elseif"
        didMatch = YES;
        break;
      }
    }

    if (!didMatch) {
      [_ctx appendElementIDComponent:@"else"];
      [self appendChildNodes:ODRLookupQueryPath(_node, @"-else")
            toResponse:_response
            inContext:_ctx];
      [_ctx deleteLastElementIDComponent]; // "else"
    }
  }
}

@end /* ODR_bind_if */

@implementation ODR_bind_ifnot

- (BOOL)doShow:(id)_node ctx:(WOContext *)_ctx {
  return [self boolFor:@"condition" node:_node ctx:_ctx] ? NO : YES;
}

@end /* ODR_bind_ifnot */
