/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <DOM/DOMDocument.h>
#include <DOM/DOMProcessingInstruction.h>
#include <DOM/DOMElement.h>
#include <DOM/DOMAttribute.h>
#include <DOM/DOMEntityReference.h>
#include <DOM/DOMImplementation.h>
#include "common.h"

#include <DOM/DOMTreeWalker.h>

@implementation NGDOMDocument(DocumentTraversal)

- (Class)domTreeWalkerClass {
  return NSClassFromString(@"DOMTreeWalker");
}

- (id)createNodeIterator:(id)_node
  whatToShow:(unsigned long)_whatToShow
  filter:(id)_filter
{
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (id)createTreeWalker:(id)_rootNode
  whatToShow:(unsigned long)_whatToShow
  filter:(id)_filter
  expandEntityReferences:(BOOL)_expandEntityReferences
{
  id walker;

  // should throw DOMException with NOT_SUPPORTED_ERR
  NSAssert(_rootNode, @"invalid root node !");

  walker = [[[self domTreeWalkerClass] alloc]
                   initWithRootNode:_rootNode
                   whatToShow:_whatToShow
                   filter:_filter
                   expandEntityReferences:_expandEntityReferences];
  return [walker autorelease];
}

@end /* NGDOMDocument(DocumentTraversal) */
