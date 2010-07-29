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

#include <DOM/DOMNodeIterator.h>
#include <DOM/DOMNodeFilter.h>
#include <DOM/DOMNode.h>
#include "common.h"

@implementation NGDOMNodeIterator

- (id)initWithRootNode:(id)_rootNode
  whatToShow:(unsigned long)_whatToShow
  filter:(id)_filter
  expandEntityReferences:(BOOL)_flag
{
  NSAssert(_rootNode, @"missing root-node !");

  if ((self = [super init])) {
    self->root       = [_rootNode retain];
    self->whatToShow = _whatToShow;
    self->filter     = [_filter retain];
    self->expandEntityReferences = _flag;

    self->lastNode    = nil;
    self->beforeFirst = YES;
    self->afterLast   = NO;
  }
  return self;
}

- (void)dealloc {
  [self->lastNode release];
  [self->root     release];
  [self->filter   release];
  [super dealloc];
}
                 
/* attributes */

- (id)root {
  return self->root;
}
- (unsigned long)whatToShow {
  return self->whatToShow;
}
- (id)filter {
  return self->filter;
}
- (BOOL)expandEntityReferences {
  return self->expandEntityReferences;
}

/* operations */

- (id)nextNode {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}
- (id)previousNode {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)detach {
}

@end /* NGDOMNodeIterator */
