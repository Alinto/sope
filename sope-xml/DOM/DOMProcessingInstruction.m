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

#include "DOMProcessingInstruction.h"
#include "common.h"

@implementation NGDOMProcessingInstruction

- (id)initWithTarget:(NSString *)_target data:(NSString *)_data {
  if ((self = [super init])) {
    self->target = [_target copy];
    self->data   = [_data   copy];
  }
  return self;
}

- (void)dealloc {
  [self->target release];
  [self->data   release];
  [super dealloc];
}

/* attributes */

- (NSString *)target {
  return self->target;
}

- (void)setData:(NSString *)_data {
  id old = self->data;
  self->data = [_data copy];
  [old release];
}
- (NSString *)data {
  return self->data;
}

/* node */

- (DOMNodeType)nodeType {
  return DOM_PROCESSING_INSTRUCTION_NODE;
}

- (id<NSObject,DOMNamedNodeMap>)attributes {
  return nil;
}

- (BOOL)_isValidChildNode:(id)_node {
  return NO;
}
- (BOOL)hasChildNodes {
  /* PI's have no children ! */
  return NO;
}
- (id<NSObject,DOMNodeList>)childNodes {
  /* PI's have no children ! */
  return nil;
}
- (id<NSObject,DOMNode>)appendChild:(id<NSObject,DOMNode>)_node {
  /* PI's have no children ! */
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

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]: target=%@ data='%@'>",
                     self, NSStringFromClass([self class]),
                     [self target], [self data]];
}

@end /* NGDOMProcessingInstruction */
