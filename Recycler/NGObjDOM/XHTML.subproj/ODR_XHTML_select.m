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

    <select var:value="blah">
      <option .../>
    </select>

  HTML 4:

   <!ELEMENT SELECT - - (OPTGROUP|OPTION)+ -- option selector -->
   <!ATTLIST SELECT
    %attrs;                              -- %coreattrs, %i18n, %events --
    name        CDATA          #IMPLIED  -- field name --
    size        NUMBER         #IMPLIED  -- rows visible --
    multiple    (multiple)     #IMPLIED  -- default is single selection --
    disabled    (disabled)     #IMPLIED  -- unavailable in this context --
    tabindex    NUMBER         #IMPLIED  -- position in tabbing order --
    onfocus     %Script;       #IMPLIED  -- the element got the focus --
    onblur      %Script;       #IMPLIED  -- the element lost the focus --
    onchange    %Script;       #IMPLIED  -- the element value was changed --
    >
*/

@interface ODR_XHTML_select : ODRDynamicXHTMLTag
@end

#include "common.h"

@implementation ODR_XHTML_select

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return YES;
}

- (BOOL)includeChildNode:(id)_childNode
  ofNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  /* leave out text nodes */
  
  if ([_childNode nodeType] == DOM_TEXT_NODE)
    return NO;
  if ([_childNode nodeType] == DOM_CDATA_SECTION_NODE)
    return NO;

  return [super includeChildNode:_childNode ofNode:_domNode inContext:_ctx];
}

- (void)takeValuesForNode:(id)_node
  fromRequest:(WORequest *)_req
  inContext:(WOContext *)_ctx
{
  NSString *ename;
  id       formValue;
  
  ename     = [self _selectNameOfNode:_node inContext:_ctx];
  formValue = [_req formValueForKey:ename];
  
  if ([self isSettable:@"value" node:_node ctx:_ctx])
    [self setString:formValue for:@"value" node:_node ctx:_ctx];
  
  /* take values on child elements */
  
  if ([_node hasChildNodes]) {
    [self takeValuesForChildNodes:[_node childNodes]
          fromRequest:_req
          inContext:_ctx];
  }
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *ename;
  NSString *tmp;
  
  ename = [self _selectNameOfNode:_node inContext:_ctx];
  
  [_response appendContentString:@"<select name=\""];
  [_response appendContentHTMLAttributeValue:ename];
  [_response appendContentCharacter:'"'];
  
  if ((tmp = [self stringFor:@"value" node:_node ctx:_ctx])) {
    [_response appendContentString:@" value=\""];
    [_response appendContentHTMLAttributeValue:tmp];
    [_response appendContentString:@"\""];
  }
  if ((tmp = [self stringFor:@"size" node:_node ctx:_ctx])) {
    [_response appendContentString:@" size=\""];
    [_response appendContentHTMLAttributeValue:tmp];
    [_response appendContentString:@"\""];
  }
  if ([self boolFor:@"multiple" node:_node ctx:_ctx]) {
    /* XHTML!!! */
    [_response appendContentString:@" multiple"];
  }
  
  [_response appendContentString:@">\n"];
  
  /* append child elements */
  
  if ([_node hasChildNodes]) {
    [self appendChildNodes:[_node childNodes]
          toResponse:_response
          inContext:_ctx];
  }

  /* close select */
  
  [_response appendContentString:@"</select>"];
}

@end /* ODR_XHTML_select */
