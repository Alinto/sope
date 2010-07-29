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
  
    checked || value selection
    name
    
  example:

    <script>
      var selection="2";
    </script>
    
    <wo:radiobutton const:name="radio" const:value="1" selection="selection"/>
    <wo:radiobutton const:name="radio" const:value="2" selection="selection"/>
    <wo:radiobutton const:name="radio" const:value="3" selection="selection"/>
    
    or:
    
    <script>
       var radio1Checked=false;
       var radio2Checked=true;
       var radio3Checked=false;
    </script>
    
    <wo:radiobutton const:name="radio" checked="radio1Checked">
    <wo:radiobutton const:name="radio" checked="radio2Checked">
    <wo:radiobutton const:name="radio" checked="radio3Checked">
*/

@interface ODR_bind_radiobutton : ODNodeRenderer
@end

#include <DOM/DOM.h>
#include "common.h"

@implementation ODR_bind_radiobutton

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return YES;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  id       formValue;
  NSString *name;

  name = [self stringFor:@"name" node:_node ctx:_ctx];
  name = (name) ? name : [_ctx elementID];
  
  formValue = [_req formValueForKey:name];

  if ([self hasAttribute:@"checked" node:_node ctx:_ctx]) {
    if ([self isSettable:@"checked" node:_node ctx:_ctx]) {
      [self setBool:[formValue isEqual:[_ctx elementID]]
            for:@"checked"
            node:_node
            ctx:_ctx];
    }
  }
  if ([self isSettable:@"selection" node:_node ctx:_ctx])
    [self setValue:formValue for:@"selection" node:_node ctx:_ctx];
}

- (void)appendNode:(id)_node
        toResponse:(WOResponse *)_response
         inContext:(WOContext *)_ctx
{
  NSString *name;

  name = [self stringFor:@"name" node:_node ctx:_ctx];

  if (name == nil) {
    NSLog(@"var:radiobutton no name is specified!");
    name = [_ctx elementID];
  }

  [_response appendContentString: @"<input type=\"radio\" name=\""];
  [_response appendContentHTMLAttributeValue:name];
  [_response appendContentString:@"\" value=\""];
  [_response appendContentHTMLAttributeValue:
             ([self hasAttribute:@"checked" node:_node ctx:_ctx])
             ? [_ctx elementID]
             : [self stringFor:@"value" node:_node ctx:_ctx]];
  [_response appendContentString:@"\""];

  if ([self hasAttribute:@"checked" node:_node ctx:_ctx]) {
    if ([self boolFor:@"checked" node:_node ctx:_ctx])
      [_response appendContentString:@" checked"];
  }
  else {
    id v   = [self valueFor:@"value" node:_node ctx:_ctx];
    id sel = [self valueFor:@"selection" node:_node ctx:_ctx];

    if ([v isEqual:sel])
      [_response appendContentString:@" checked"];
  }
  [_response appendContentString:@">\n"];
}

@end /* ODR_bind_radiobutton */
