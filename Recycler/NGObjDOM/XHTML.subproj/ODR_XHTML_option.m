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

    <option>Text</option>

  HTML 4:
   <!ELEMENT OPTION - O (#PCDATA)         -- selectable choice -->
   <!ATTLIST OPTION
     %attrs;                              -- %coreattrs, %i18n, %events --
     selected    (selected)     #IMPLIED
     disabled    (disabled)     #IMPLIED  -- unavailable in this context --
     label       %Text;         #IMPLIED  -- for use in hierarchical menus --
     value       CDATA          #IMPLIED  -- defaults to element content --
     >
*/

@interface ODR_XHTML_option : ODRDynamicXHTMLTag
@end

#include "common.h"

@implementation ODR_XHTML_option

- (BOOL)requiresFormForNode:(id)_domNode inContext:(WOContext *)_ctx {
  return YES;
}

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *tmp;
  NSString *value;
  BOOL isSelected;

  isSelected = NO;
  
  if ((value = [self stringFor:@"value" node:_node ctx:_ctx]) == nil)
    value = [_ctx elementID];
  
  [_response appendContentString:@"<option"];
  
  if (value) {
    [_response appendContentString:@" value=\""];
    [_response appendContentHTMLAttributeValue:value];
    [_response appendContentString:@"\""];
  }
  if ((tmp = [self stringFor:@"label" node:_node ctx:_ctx])) {
    [_response appendContentString:@" label=\""];
    [_response appendContentHTMLAttributeValue:tmp];
    [_response appendContentString:@"\""];
  }
  
  /* find out selected state */
  {
    id pnode;
    
    for (pnode = [_node parentNode];
         (pnode != nil) && ([pnode nodeType] == DOM_ELEMENT_NODE);
         pnode = [pnode parentNode]) {
      
      if ([[pnode tagName] isEqualToString:@"select"]) {
        NSString *selectValue;
        
        selectValue = [self stringFor:@"value" node:pnode ctx:_ctx];
        if ([selectValue isEqualToString:value])
          isSelected = YES;
        
        break;
      }
    }
  }
  
  if (isSelected) {
    /* XHMTL !! */
    [_response appendContentString:@" selected"];
  }
  
  [_response appendContentCharacter:'>'];

  /* append child elements */
  
  if ([_node hasChildNodes]) {
    [super appendChildNodes:[_node childNodes]
           toResponse:_response
           inContext:_ctx];
  }
  
  /* XHTML CloseTag !!! */
}

@end /* ODR_XHTML_option */
