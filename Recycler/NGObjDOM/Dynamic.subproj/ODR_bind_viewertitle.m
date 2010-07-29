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

/*

  <var:viewertitle title="t" textcolor="tc" textfont="tf" textsize="ts">
    <var:vtitle>  title  content </var:vtitle>
    <var:vbutton> button content </var:vbutton>
  </var:viewertitle>

*/

#include <NGObjDOM/ODR_bind_viewertitle.h>
#include "common.h"

@implementation ODR_bind_viewertitle

- (void)takeValuesFromNode:(id)_node
             fromRequest:(WORequest *)_request
               inContext:(WOContext *)_ctx
{

  [_ctx appendElementIDComponent:@"t"];
  
  [self takeValuesForChildNodes:ODRLookupQueryPath(_node, @"-vtitle")
        fromRequest:_request
        inContext:_ctx];

  [_ctx deleteLastElementIDComponent];

  [_ctx appendElementIDComponent:@"b"];
  
  [self takeValuesForChildNodes:ODRLookupQueryPath(_node, @"-vbutton")
        fromRequest:_request
        inContext:_ctx];

  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForNode:(id)_node
              fromRequest:(WORequest *)_request
                inContext:(WOContext *)_ctx
{
  NSString *section;
  id       result = nil;

  section = [_ctx currentElementID];
  
  if ([section isEqualToString:@"t"]) {
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:@"t"];
    
    result = [self invokeActionForNode:ODRLookupQueryPath(_node, @"-vtitle")
               fromRequest:_request
               inContext:_ctx];

    [_ctx deleteLastElementIDComponent];
  }
  else if ([section isEqualToString:@"b"]) {
    [_ctx consumeElementID];
    [_ctx appendElementIDComponent:@"b"];
    
    result = [self invokeActionForNode:ODRLookupQueryPath(_node, @"-vbutton")
               fromRequest:_request
               inContext:_ctx];

    [_ctx deleteLastElementIDComponent];
  }

  return result;
}

- (void)appendNode:(id)_node
        toResponse:(WOResponse *)_response
         inContext:(WOContext *)_ctx
{
  NSString *sC, *sF, *sS;
  NSString *bgcolor;
  NSString *title;
  BOOL     hasFont;

  sC = [self stringFor:@"textcolor" node:_node ctx:_ctx];
  sF = [self stringFor:@"textface"  node:_node ctx:_ctx];
  sS = [self stringFor:@"textsize"  node:_node ctx:_ctx];
  
  hasFont = (sC || sF || sS) ? YES : NO;
  bgcolor = [self stringFor:@"bgcolor" node:_node ctx:_ctx];
  title   = [self stringFor:@"title"   node:_node ctx:_ctx];

  [_response appendContentString:
             @"<table cellpadding=\"5\" cellspacing=\"0\" "
             @"width=\"100%\" border=\"0\""];
  
  if (bgcolor) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentHTMLAttributeValue:bgcolor];
    [_response appendContentCharacter:'"'];
  }
  
  [_response appendContentString:@"><tr><td>"];
  ODRAppendFont(_response, sC,sF, sS);
  
  if (title != nil) {
    [_response appendContentString:@"<b>"];
    [_response appendContentString:title];
    [_response appendContentString:@"</b>"];
  }
  
  [_ctx appendElementIDComponent:@"t"];

  [self appendChildNodes:ODRLookupQueryPath(_node, @"-vtitle")
        toResponse:_response
        inContext:_ctx];

  [_ctx deleteLastElementIDComponent]; // delete "t" 

  [_response appendContentString:@"&nbsp;</font></td><td>"];
  ODRAppendFont(_response, sC,sF, sS);

  [_ctx appendElementIDComponent:@"b"];
  
  [self appendChildNodes:ODRLookupQueryPath(_node, @"-vbutton")
        toResponse:_response
        inContext:_ctx];

  [_ctx deleteLastElementIDComponent]; // delete "b"
  
  [_response appendContentString:@"&nbsp;</font></td></tr></table>"];
}

@end /* ODR_bind_viewertitle */


@implementation ODR_bind_vtitle
@end /* ODR_bind_vtitle */

@implementation ODR_bind_vbutton
@end /* ODR_bind_vbutton */
