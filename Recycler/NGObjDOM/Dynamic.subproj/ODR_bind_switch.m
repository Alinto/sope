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
*/

@interface ODR_bind_switch : ODNodeRenderer
@end

#include <DOM/EDOM.h>
#include "common.h"

@implementation ODR_bind_switch

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
    [super takeValuesForNode:_node
           fromRequest:_req
           inContext:_ctx];
}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  NSString *key;
  id       node   = nil;
  id       result = nil;

  key = [[_ctx currentElementID] stringValue];

  if (key) {
    [_ctx consumeElementID]; // consume case-key
    
    if ([key isEqualToString:@"_default"]) {

      node = [_node lookupQueryPath:@"-default"];
      if ([node isKindOfClass:[NSArray class]])
        node = [node lastObject];
    }
    else {
      NSArray *children;
      int     i, cnt;

      children = (NSArray *)[_node childNodes];
      cnt = [children count];
      
      for (i = 0; i < cnt; i++) {
        NSString *childKey;
        id       child;

        child    = [children objectAtIndex:i];
        childKey = [self stringFor:@"key" node:child ctx:_ctx];
        if ([key isEqualToString:childKey]) {
          node = child;
          break;
        }
      }
    }

    if (node) {
      result = [super invokeActionForNode:node
                      fromRequest:_req
                      inContext:_ctx];
    }
    else
      NSLog(@"Warning! switch: couldn't find case element '%@'", key);

    [_ctx deleteLastElementIDComponent]; // delete case-key

  }
  return nil;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSArray        *selections = nil;
  NSString       *selection  = nil;
  NSArray        *cases      = nil;
  NSMutableArray *children   = nil;
  unsigned       i, cnt, j, cnt2;

  if (![_node hasChildNodes])
    return;

  selections = [self  valueFor:@"selections" node:_node ctx:_ctx];
  selection  = [self stringFor:@"selection"  node:_node ctx:_ctx];
  cases      = [_node lookupQueryPath:@"-case"]; // case nodes
  
  if ((selection!=nil) && (selections == nil))
    selections = [NSArray arrayWithObject:selection];

  cnt  = [selections count]; // number of selections
  cnt2 = [cases count];      // number of cases

  children = [NSMutableArray arrayWithCapacity:cnt];
  
  for (i=0; i<cnt; i++) { // for all selections
    NSString *key;

    key = [selections objectAtIndex:i];
    
    for (j=0; j<cnt2; j++) { // and all cases
      NSString *caseKey;
      id       caseChild;

      caseChild = [cases objectAtIndex:j];
      caseKey   = [self stringFor:@"key" node:caseChild ctx:_ctx];
      if ([caseKey isEqualToString:key]) {
        [children addObject:caseChild];
        break;
      }
    }
  }

  if ([children count] == 0) {
    id tmp;

    tmp = [_node lookupQueryPath:@"-default"];
    if ([tmp isKindOfClass:[NSArray class]]) {
      NSLog(@"Warning! switch: more than one 'default' section!");
      tmp = [tmp lastObject];
    }
    [children addObject:tmp];
  }
  
  for (i=0, cnt = [children count]; i<cnt; i++) {
    NSString *key;
    id       node;

    node = [children objectAtIndex:i];
    key = [self stringFor:@"key" node:node ctx:_ctx];
    key = (key) ? key : @"_default";
    
    [_ctx appendElementIDComponent:key];
    [super appendNode:node
           toResponse:_response
           inContext:_ctx];
    
    [_ctx deleteLastElementIDComponent]; // delete key
  }
}

@end /* ODR_bind_switch */
