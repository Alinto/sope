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

#include <NGObjDOM/ODNodeRendererFactory.h>
#include <NGObjDOM/ODRNodeText.h>
#include <NGObjDOM/ODRGenericTag.h>
#include "common.h"

@implementation ODNodeRendererFactory

+ (int)version {
  return 1;
}

- (ODNodeRenderer *)rendererForTextNode:(id)_domNode 
  inContext:(WOContext *)_ctx
{
  static id r = nil;
  if (r == nil) r = [[ODRNodeText alloc] init];
  return r;
}

- (ODNodeRenderer *)rendererForElementNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  static id r = nil;
  if (r == nil) r = [[ODRGenericTag alloc] init];
  return r;
}

- (ODNodeRenderer *)rendererForDocumentNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  static id r = nil;
  if (r == nil) r = [[ODNodeRenderer alloc] init];
  return r;
}
- (ODNodeRenderer *)rendererForDocumentFragmentNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  static id r = nil;
  if (r == nil) r = [[ODNodeRenderer alloc] init];
  return r;
}

- (ODNodeRenderer *)rendererForNode:(id)_domNode
  inContext:(WOContext *)_ctx
{
  ODNodeRenderer *renderer;
  
  switch ([_domNode nodeType]) {
    case DOM_TEXT_NODE:
    case DOM_CDATA_SECTION_NODE:
      renderer = [self rendererForTextNode:_domNode inContext:_ctx];
      break;
      
    case DOM_ELEMENT_NODE:
      renderer = [self rendererForElementNode:_domNode inContext:_ctx];
      break;

    case DOM_DOCUMENT_NODE:
      renderer = [self rendererForDocumentNode:_domNode inContext:_ctx];
      break;
      
    case DOM_DOCUMENT_FRAGMENT_NODE:
      renderer =
        [self rendererForDocumentFragmentNode:_domNode inContext:_ctx];
      break;
      
    default:
      renderer = nil;
      break;
  }
  return renderer;
}

@end /* ODNodeRendererFactory */
