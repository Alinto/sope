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

#include "ODR_XUL_box.h"
#include "common.h"
#include <DOM/DOMNode+QueryPath.h>

@interface ODR_XUL_titledbox : ODR_XUL_box
@end

@implementation ODR_XUL_titledbox

- (BOOL)addChildNode:(id)_node inContext:(WOContext *)_ctx {
  if ([_node nodeType] != DOM_ELEMENT_NODE)
    return NO;
  
  if ([[_node tagName] isEqualToString:@"title"])
    return NO;
  
  return YES;
}

- (void)appendNode:(id)_domNode
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_context
{
  id titleNode;
  
  if (![_domNode hasChildNodes])
    return;
  
  [_response appendContentString:@"<fieldset>"];
  
  if ((titleNode = [_domNode lookupQueryPath:@"-title"])) {
    ODNodeRenderer *renderer;

    if ((renderer = [self rendererForNode:titleNode inContext:_context])){
      [renderer appendNode:titleNode
                toResponse:_response
                inContext:_context];
    }
  }
  
  [super appendNode:_domNode
         toResponse:_response
         inContext:_context];
  
  [_response appendContentString:@"</fieldset>"];
}

@end /* ODR_XUL_titledbox */
