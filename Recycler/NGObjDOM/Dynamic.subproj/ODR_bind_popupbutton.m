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
  
    list
    item
    selection
    string
    noselectionstring
    name

  example:
    <script>
      var list = [ "1", "2", "3", "4" ];
    </script>
  
    <wo:popupbutton list="list" item="item" selection="selection"/>
>
*/

@interface ODR_bind_popupbutton : ODNodeRenderer
@end

#include <DOM/DOM.h>
#include "common.h"

@implementation ODR_bind_popupbutton

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return YES;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  NSString *formValue;
  NSString *name;

  name = [self stringFor:@"name" node:_node ctx:_ctx];
  name = (name) ? name : [_ctx elementID];
  
  formValue = [_req formValueForKey:name];
    
  if ([self isSettable:@"value" node:_node ctx:_ctx])
    [self setValue:formValue for:@"value" node:_node ctx:_ctx];
    
  if (formValue) {
    NSArray *objects;
    id      object;
      
    objects = [self valueFor:@"list" node:_node ctx:_ctx];
      
    object = nil;
    if ([self hasAttribute:@"value" node:_node ctx:_ctx]) {
      /* has a value binding, walk list to find object */
      unsigned i, toGo;

      for (i = 0, toGo = [objects count]; i < toGo; i++) {
        NSString *cv;
          
        object = [objects objectAtIndex:i];
          
        if ([self isSettable:@"item" node:_node ctx:_ctx])
          [self setValue:object for:@"item" node:_node ctx:_ctx];

        cv = [self stringFor:@"value" node:_node ctx:_ctx];
          
        if ([cv isEqualToString:formValue])
          break;
      }
    }
    else if (![formValue isEqualToString:@"$"]) {
      /* an index binding */
      int idx;
        
      idx = [formValue intValue];
      if (idx >= (int)[objects count]) {
        [[_ctx page] logWithFormat:@"popup-index %i out of range 0-%i",
                     idx, [objects count] - 1];
        object = nil;
      }
      else 
        object = [objects objectAtIndex:idx];
    }
      
    if ([self isSettable:@"selection" node:_node ctx:_ctx]) {
      if ([self isSettable:@"item" node:_node ctx:_ctx])
        [self setValue:object for:@"item" node:_node ctx:_ctx];

      if ([self isSettable:@"selection" node:_node ctx:_ctx])
        [self setValue:object for:@"selection" node:_node ctx:_ctx];
    }
  }
  else {
    // nothing selected
    if ([self isSettable:@"item" node:_node ctx:_ctx])
      [self setValue:nil for:@"item" node:_node ctx:_ctx];
    if ([self isSettable:@"selection" node:_node ctx:_ctx])
      [self setValue:nil for:@"selection" node:_node ctx:_ctx];
  }
}

- (void)appendOptions:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *nilStr   = nil;
  NSArray  *array    = nil;
  id       selection = nil;
  int      i, cnt;
  
  nilStr    = [self stringFor:@"noselectionstring" node:_node ctx:_ctx];
  if (nilStr == nil)
    nilStr = [self stringFor:@"noSelectionString" node:_node ctx:_ctx];
  array     = [self  valueFor:@"list"              node:_node ctx:_ctx];
  selection = [self  valueFor:@"selection"         node:_node ctx:_ctx];
  cnt       = [array count];
  
  if (nilStr) {
    [_response appendContentString:@"  <option value=\"$\">"];
    [_response appendContentHTMLString:nilStr];
    [_response appendContentString:@"\n"];
  }
    
  for (i = 0; i < cnt; i++) {
    NSString *v         = nil;
    NSString *displayV  = nil;
    id       object     = [array objectAtIndex:i];
    BOOL     isSelected;

    if ([self isSettable:@"item" node:_node ctx:_ctx])
      [self setValue:object for:@"item" node:_node ctx:_ctx];

    isSelected = (selection) ? [selection isEqual:object] : NO;

    v = ([self hasAttribute:@"value" node:_node ctx:_ctx])
      ? [self stringFor:@"value" node:_node ctx:_ctx]
      : [NSString stringWithFormat:@"%i", i];

    displayV = ([self hasAttribute:@"string" node:_node ctx:_ctx])
      ? [self stringFor:@"string" node:_node ctx:_ctx]
      : [object stringValue];

    if (displayV == nil) displayV = @"<nil>";

    [_response appendContentString:@"  <option value=\""];
    [_response appendContentString:v];
    [_response appendContentString:(isSelected) ? @"\" selected>" : @"\">"];
    [_response appendContentHTMLString:displayV];
    [_response appendContentString:@"\n"];
  }
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *name;

  name = [self stringFor:@"name" node:_node ctx:_ctx];
  name = (name) ? name : [_ctx elementID];

  [_response appendContentString:@"<select name=\""];
  [_response appendContentHTMLAttributeValue:name];
  [_response appendContentString:@"\">\n"];

  [self appendOptions:_node toResponse:_response inContext:_ctx];

  [_response appendContentString:@"</select>"];
}

@end /* ODR_bind_popupbutton */


@interface ODR_bind_popup : ODR_bind_popupbutton
@end

@implementation ODR_bind_popup
@end
