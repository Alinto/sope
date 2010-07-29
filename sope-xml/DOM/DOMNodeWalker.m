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

#include "DOMNodeWalker.h"
#include "DOMNode.h"
#include "common.h"

@interface NGDOMNodeWalker(Privates)
- (void)_processCurrentNode;
@end

@implementation NGDOMNodeWalker

- (id)initWithTarget:(id)_target selector:(SEL)_selector context:(id)_ctx {
  self->target   = [_target retain];
  self->selector = _selector;
  self->ctx      = [_ctx retain];

  if (self->target == nil) {
    [self release];
    return nil;
  }
  if (self->selector == NULL) {
    [self release];
    return nil;
  }
  
  return self;
}
- (void)dealloc {
  [self->ctx      release];
  [self->rootNode release];
  [self->target   release];
  [super dealloc];
}

/* accessors */

- (id)context {
  return self->ctx;
}

- (id)rootNode {
  return self->rootNode;
}
- (id)currentParentNode {
  return self->currentParentNode;
}
- (id)currentNode {
  return self->currentNode;
}

/* private */

- (void)_processCurrentNode {
  [self->target performSelector:self->selector withObject:self];
}

- (void)_beforeChildren {
}
- (void)_afterChildren {
}

- (void)_walkNodeUsingChildNodes:(id)_node {
  if (self->isStopped) return;
  
  self->currentNode = _node;
  
  [self _beforeChildren];
  if (self->isStopped) return;

  if ([_node hasChildNodes]) {
    id       children;
    unsigned i, count;
    id oldParent;

    oldParent = self->currentParentNode;
    self->currentParentNode = self->currentNode;
    
    children = [_node childNodes];
    
    for (i = 0, count = [children count]; i < count; i++) {
      [self _walkNodeUsingChildNodes:[children objectAtIndex:i]];
      if (self->isStopped) return;
    }
    
    self->currentParentNode = oldParent;
  }

  [self _afterChildren];
  if (self->isStopped) return;
}

/* public */

- (void)walkNode:(id)_node {
  self->rootNode  = [_node retain];
  self->isStopped = NO;
  self->currentParentNode = nil;
  
  [self _walkNodeUsingChildNodes:_node];

  [self->rootNode release]; self->rootNode = nil;
}

- (void)stopWalking {
  self->isStopped = YES;
}

@end /* NGDOMNodeWalker */

@implementation NGDOMNodePreorderWalker

- (void)_beforeChildren {
  [self _processCurrentNode];
}
- (void)_afterChildren {
}

@end /* NGDOMNodePreorderWalker */

@implementation NGDOMNodePostorderWalker

- (void)_beforeChildren {
}
- (void)_afterChildren {
  [self _processCurrentNode];
}

@end /* NGDOMNodePreorderWalker */
