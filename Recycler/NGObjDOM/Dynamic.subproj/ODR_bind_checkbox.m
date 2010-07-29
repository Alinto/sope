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

     name
     checked
     value

   example:
     <script>
       var checked=true;
     </script>
     
     <var:checkbox checked="checked"/>
*/

@interface ODR_bind_checkbox : ODNodeRenderer
@end

#include <DOM/DOM.h>
#include "common.h"

@implementation ODR_bind_checkbox

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

  if ([self isSettable:@"checked" node:_node ctx:_ctx])
    [self setBool:(formValue) ? YES : NO for:@"checked" node:_node ctx:_ctx];

  if ([self isSettable:@"value" node:_node ctx:_ctx] && (formValue != nil))
    [self setString:formValue for:@"value" node:_node ctx:_ctx];
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *name;

  name = [self stringFor:@"name" node:_node ctx:_ctx];
  name = (name) ? name : [_ctx elementID];

  if (![[_ctx request] isFromClientComponent]) {
    NSString *v;
    BOOL     isChecked;

    v         = [self stringFor:@"value" node:_node ctx:_ctx];
    isChecked = [self boolFor:@"checked" node:_node ctx:_ctx];
    
    [_response appendContentString:@"<input type=\"checkbox\" name=\""];
    [_response appendContentHTMLAttributeValue:name];
    [_response appendContentString:@"\" value=\""];
    [_response appendContentHTMLAttributeValue:([v length] > 0) ? v : @"1"];
    [_response appendContentString:@"\""];
  
    if (isChecked)
      [_response appendContentString:@" checked"];

    [_response appendContentString:@">\n"];
  }
}

@end /* ODR_bind_checkbox */
