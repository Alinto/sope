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

#include <DOM/DOMTreeWalker.h>
#include <DOM/DOMNodeFilter.h>
#include <DOM/DOMNode.h>
#include "common.h"

@implementation NGDOMTreeWalker

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
    
    [self setCurrentNode:_rootNode];
  }
  return self;
}

- (void)dealloc {
  [self->visibleChildren release];
  [self->currentNode release];
  [self->root        release];
  [self->filter      release];
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

- (void)setCurrentNode:(id)_node {
  if (_node == self->currentNode)
    /* same node */
    return;
  
  ASSIGN(self->currentNode, _node);

  /* clear state caches */
  [self->visibleChildren release]; self->visibleChildren = nil;
}
- (id)currentNode {
  return self->currentNode;
}

/* internals */

- (BOOL)_shouldShowNode:(id)_node {
  if (self->whatToShow == DOM_SHOW_ALL)
    return YES;
  
  switch([_node nodeType]) {
    case DOM_ATTRIBUTE_NODE:
      return (self->whatToShow & DOM_SHOW_ATTRIBUTE) != 0 ? YES : NO;
    case DOM_CDATA_SECTION_NODE:
      return (self->whatToShow & DOM_SHOW_CDATA_SECTION) != 0 ? YES : NO;
    case DOM_COMMENT_NODE:
      return (self->whatToShow & DOM_SHOW_COMMENT) != 0 ? YES : NO;
    case DOM_DOCUMENT_NODE:
      return (self->whatToShow & DOM_SHOW_DOCUMENT) != 0 ? YES : NO;
    case DOM_DOCUMENT_FRAGMENT_NODE:
      return (self->whatToShow & DOM_SHOW_DOCUMENT_FRAGMENT) != 0 ? YES : NO;
    case DOM_ELEMENT_NODE:
      return (self->whatToShow & DOM_SHOW_ELEMENT) != 0 ? YES : NO;
    case DOM_PROCESSING_INSTRUCTION_NODE:
      return (self->whatToShow & DOM_SHOW_PROCESSING_INSTRUCTION) != 0 ? YES:NO;
    case DOM_TEXT_NODE:
      return (self->whatToShow & DOM_SHOW_TEXT) != 0 ? YES : NO;
    case DOM_DOCUMENT_TYPE_NODE:
      return (self->whatToShow & DOM_SHOW_DOCUMENT_TYPE) != 0 ? YES : NO;
    case DOM_ENTITY_NODE:
      return (self->whatToShow & DOM_SHOW_ENTITY) != 0 ? YES : NO;
    case DOM_ENTITY_REFERENCE_NODE:
      return (self->whatToShow & DOM_SHOW_ENTITY_REFERENCE) != 0 ? YES : NO;
    case DOM_NOTATION_NODE:
      return (self->whatToShow & DOM_SHOW_NOTATION) != 0 ? YES : NO;
    default:
      return YES;
  }
}

- (BOOL)_isVisibleNode:(id)_node {
  if (![self _shouldShowNode:_node])
    return NO;
  if (self->filter)
    return [self->filter acceptNode:_node] == DOM_FILTER_ACCEPT ? YES : NO;
  return YES;
}
- (unsigned short)_navTypeOfNode:(id)_node {
  if (![self _shouldShowNode:_node])
    return DOM_FILTER_SKIP;
  if (self->filter)
    return [self->filter acceptNode:_node] == DOM_FILTER_ACCEPT ? YES : NO;
  return DOM_FILTER_ACCEPT;
}

- (NSArray *)_ensureVisibleChildren {
  static NSArray *emptyArray = nil;
  id children;
  unsigned count;

  if (self->visibleChildren)
    return self->visibleChildren;
  
  children = [[self currentNode] childNodes];

  if ((count = [children count]) > 0) {
    unsigned i;
    NSMutableArray *ma;
    
    ma = [[NSMutableArray alloc] initWithCapacity:(count + 1)];
    
    for (i = 0; i < count; i++) {
      id childNode;
      
      childNode = [children objectAtIndex:i];
      
      if ([self _isVisibleNode:childNode])
        [ma addObject:childNode];
    }
    
    self->visibleChildren = [ma copy];
    [ma release]; ma = nil;
  }
  else {
    if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
    self->visibleChildren = [emptyArray retain];
  }
  return self->visibleChildren;
}

- (BOOL)_hasVisibleChildren {
  return [[self _ensureVisibleChildren] count] > 0 ? YES : NO;
}
- (id)_visibleChildren {
  return [self _ensureVisibleChildren];
}
- (id)_firstVisibleChild {
  NSArray *a = [self _ensureVisibleChildren];
  if ([a count] == 0)
    return nil;
  return [a objectAtIndex:0];
}
- (id)_lastVisibleChild {
  NSArray *a = [self _ensureVisibleChildren];
  unsigned count;
  
  if ((count = [a count]) == 0)
    return nil;
  return [a objectAtIndex:(count - 1)];
}

- (id<NSObject,DOMNode>)_visibleParentNode {
  id<NSObject,DOMNode> node;

  for (node = [[self currentNode] parentNode]; node; node =[node parentNode]) {
    if ([self _isVisibleNode:node])
      return node;
    
    if (node == [self root])
      /* do not step above root */
      break;
  }
  return nil;
}

- (id<NSObject,DOMNode>)_nextVisibleSibling {
  id<NSObject,DOMNode> node;

  for (node = [(id<NSObject,DOMNode>)[self currentNode] nextSibling];
       node != nil;
       node = [node nextSibling]) {
    if ([self _isVisibleNode:node])
      return node;
  }
  return nil;
}
- (id<NSObject,DOMNode>)_previousVisibleSibling {
  id<NSObject,DOMNode> node;

  for (node = [(id<NSObject,DOMNode>)[self currentNode] previousSibling];
       node != nil;
       node = [node previousSibling]) {
    if ([self _isVisibleNode:node])
      return node;
  }
  return nil;
}

/* operations */

- (id<NSObject,DOMNode>)parentNode {
  id parent;

  if ((parent = [self _visibleParentNode])) {
    [self setCurrentNode:parent];
    return parent;
  }
  else
    return nil;
}

- (id<NSObject,DOMNode>)firstChild {
  if ([self _hasVisibleChildren]) {
    id child;

    child = [self _firstVisibleChild];
    [self setCurrentNode:child];
    return child;
  }
  else
    return nil;
}

- (id<NSObject,DOMNode>)lastChild {
  if ([self _hasVisibleChildren]) {
    id child;

    child = [self _lastVisibleChild];
    [self setCurrentNode:child];
    return child;
  }
  else
    return nil;
}

- (id<NSObject,DOMNode>)previousSibling {
  id node;

  if ((node = [self _previousVisibleSibling])) {
    [self setCurrentNode:node];
    return node;
  }
  else
    return nil;
}

- (id<NSObject,DOMNode>)nextSibling {
  id node;

  if ((node = [self _nextVisibleSibling])) {
    [self setCurrentNode:node];
    return node;
  }
  else
    return nil;
}

- (id<NSObject,DOMNode>)previousNode {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}
- (id<NSObject,DOMNode>)nextNode {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

@end /* NGDOMTreeWalker */
