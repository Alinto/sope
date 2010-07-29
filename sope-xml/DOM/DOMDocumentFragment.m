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

#include "DOMDocumentFragment.h"
#include "common.h"

@implementation NGDOMDocumentFragment

/* node */

- (BOOL)_isValidChildNode:(id)_node {
  switch ([_node nodeType]) {
    case DOM_ELEMENT_NODE:
    case DOM_PROCESSING_INSTRUCTION_NODE:
    case DOM_COMMENT_NODE:
    case DOM_TEXT_NODE:
    case DOM_CDATA_SECTION_NODE:
    case DOM_ENTITY_REFERENCE_NODE:
      return YES;
      
    default:
      return NO;
  }
}

- (DOMNodeType)nodeType {
  return DOM_DOCUMENT_FRAGMENT_NODE;
}

- (id<NSObject,DOMNamedNodeMap>)attributes {
  return nil;
}

/* parent node */

- (id<NSObject,DOMNode>)parentNode {
  return nil;
}
- (id<NSObject,DOMNode>)nextSibling {
  return nil;
}
- (id<NSObject,DOMNode>)previousSibling {
  return nil;
}

@end /* NGDOMDocumentFragment */
