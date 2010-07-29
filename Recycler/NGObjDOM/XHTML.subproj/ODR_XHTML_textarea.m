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

    <textarea var:value="blah/>

  Additions:

    value - stores value of textarea
  
  HTML 4:
   <!ELEMENT TEXTAREA - - (#PCDATA)       -- multi-line text field -->
   <!ATTLIST TEXTAREA
     %attrs;                              -- %coreattrs, %i18n, %events --
     name        CDATA          #IMPLIED
     rows        NUMBER         #REQUIRED
     cols        NUMBER         #REQUIRED
     disabled    (disabled)     #IMPLIED  -- unavailable in this context --
     readonly    (readonly)     #IMPLIED
     tabindex    NUMBER         #IMPLIED  -- position in tabbing order --
     accesskey   %Character;    #IMPLIED  -- accessibility key character --
     onfocus     %Script;       #IMPLIED  -- the element got the focus --
     onblur      %Script;       #IMPLIED  -- the element lost the focus --
     onselect    %Script;       #IMPLIED  -- some text was selected --
     onchange    %Script;       #IMPLIED  -- the element value was changed --
     >
*/

@interface ODR_XHTML_textarea : ODRDynamicXHTMLTag
@end

#include "common.h"

@implementation ODR_XHTML_textarea

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return YES;
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  NSString *ename;
  id formValue;
  
  ename     = [self _selectNameOfNode:_node inContext:_ctx];
  formValue = [_req formValueForKey:ename];
  
  if ([self isSettable:@"value" node:_node ctx:_ctx])
    [self setString:formValue for:@"value" node:_node ctx:_ctx];
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *ename;
  int rows, cols;
  id  value;
  
  ename = [self _selectNameOfNode:_node inContext:_ctx];
  rows  = [self intFor:@"rows"    node:_node ctx:_ctx];
  cols  = [self intFor:@"cols"    node:_node ctx:_ctx];
  value = [self valueFor:@"value" node:_node ctx:_ctx];
  
  if ([_ctx isInForm]) {
    [_response appendContentString:@"<textarea name=\""];
    [_response appendContentHTMLAttributeValue:ename];
    [_response appendContentCharacter:'"'];
    
    if (rows > 0) {
      [_response appendContentString:@" rows=\""];
      [_response appendContentString:[NSString stringWithFormat:@"%d", rows]];
      [_response appendContentCharacter:'"'];
    }
    if (cols > 0) {
      [_response appendContentString:@" cols=\""];
      [_response appendContentString:[NSString stringWithFormat:@"%d", cols]];
      [_response appendContentCharacter:'"'];
    }
    
    [_response appendContentString:@">"];
    
    /* append content (value + element content) */
    
    if (value) {
      [_response appendContentHTMLString:value];
    }
    else {
      /* 'default' value */
      [self appendChildNodes:[_node childNodes]
            toResponse:_response
            inContext:_ctx];
    }
    
    /* close tag */
    [_response appendContentString:@"</textarea>"];
  }
  else {
    [[_ctx component]
           logWithFormat:@"WARNING: textarea is not in a form !"];
    [_response appendContentHTMLString:[value stringValue]];
  }
}

@end /* ODR_XHTML_textarea */
