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

#include "DOMDocumentType.h"
#include "common.h"

@implementation NGDOMDocumentType

- (id)initWithName:(NSString *)_name
  publicId:(NSString *)_pubId
  systemId:(NSString *)_sysId
  dom:(id)_dom
{
  [self release];
  return nil;
}

/* attributes */

- (NSString *)name {
  return nil;
}
- (id)entities {
  return nil;
}
- (id)notations {
  return nil;
}
- (NSString *)publicId {
  return nil;
}
- (NSString *)systemId {
  return nil;
}
- (NSString *)internalSubset {
  return nil;
}

/* node */

- (DOMNodeType)nodeType {
  return DOM_DOCUMENT_TYPE_NODE;
}

- (BOOL)_isValidChildNode:(id)_node {
  return NO;
}
- (BOOL)hasChildNodes {
  return NO;
}
- (id<NSObject,DOMNodeList>)childNodes {
  return nil;
}

- (id<NSObject,DOMNamedNodeMap>)attributes {
  return nil;
}

/* parent node */

- (void)_domNodeRegisterParentNode:(id)_parent {
  self->parent = _parent;
}
- (void)_domNodeForgetParentNode:(id)_parent {
  if (_parent == self->parent)
    /* the node's parent was deallocated */
    self->parent = nil;
}
- (id<NSObject,DOMNode>)parentNode {
  return self->parent;
}

@end /* NGDOMDocumentType */
