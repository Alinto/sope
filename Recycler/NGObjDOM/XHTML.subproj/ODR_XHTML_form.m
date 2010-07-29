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

    <form [enctype="multipart/form-data"]>
      ...
    </form>

  HTML 4:
*/

@interface ODR_XHTML_form : ODRDynamicXHTMLTag
@end

#include "common.h"

@implementation ODR_XHTML_form

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return NO;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_request
                inContext:(WOContext *)_ctx {
  if ([_node hasChildNodes]) {
    [_ctx setInForm:YES];
    
    [self takeValuesForChildNodes:[_node childNodes]
          fromRequest:_request
          inContext:_ctx];
    
    [_ctx setInForm:NO];
  }

}

- (id)invokeActionForNode:(id)_node
  fromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  id result = nil;
  
  if ([_node hasChildNodes]) {
    [_ctx setInForm:YES];
    
    result = [self invokeActionForChildNodes:[_node childNodes]
                   fromRequest:_request
                   inContext:_ctx];
    
    [_ctx setInForm:NO];
  }
  
  return result;
}


- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *enctype = nil;

  enctype = [self stringFor:@"enctype" node:_node ctx:_ctx];
  
  if ([_node hasChildNodes]) {
    [_ctx setInForm:YES];
    [_response appendContentString:@"<form method=\"post\" action=\""];
    [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentCharacter:'"'];
    if (enctype != nil) {
      [_response appendContentString:@" enctype=\""];
      [_response appendContentString:enctype];
      [_response appendContentCharacter:'"'];
    }
    [_response appendContentCharacter:'>'];
    [super appendChildNodes:[_node childNodes]
           toResponse:_response
           inContext:_ctx];
    [_ctx setInForm:NO];
    [_response appendContentString:@"</form>"];
  }
}

@end /* ODR_XHTML_form */
