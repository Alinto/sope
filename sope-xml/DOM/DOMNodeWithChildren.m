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

#include <DOM/DOMNode.h>
#include "common.h"

@implementation NGDOMNodeWithChildren

- (void)dealloc {
  [self->childNodes makeObjectsPerformSelector:
	              @selector(_domNodeForgetParentNode:)
                    withObject:nil];
  
  [self->childNodes release];
  [super dealloc];
}

- (void)_ensureChildNodes {
  if (self->childNodes == nil)
    self->childNodes = [[NSMutableArray alloc] init];
}

- (BOOL)_isValidChildNode:(id)_node {
  return YES;
}

/* navigation */

- (id<NSObject,DOMNodeList>)childNodes {
  [self _ensureChildNodes];

  /* casting NSMutableArray to DOMNodeList */
  return (id<NSObject,DOMNodeList>)self->childNodes;
}
- (BOOL)hasChildNodes {
  return [self->childNodes count] > 0 ? YES : NO;
}
- (id<NSObject,DOMNode>)firstChild {
  return [self->childNodes count] > 0 
    ? [self->childNodes objectAtIndex:0]
    : nil;
}
- (id<NSObject,DOMNode>)lastChild {
  unsigned count;

  return (count = [self->childNodes count]) > 0 
    ? [self->childNodes objectAtIndex:(count - 1)]
    : nil;
}

/* modification */

- (id<NSObject,DOMNode>)removeChild:(id<NSObject,DOMNode>)_node {
  unsigned idx;

  if (self->childNodes == nil)
    /* this node has no childnodes ! */
    return nil;
  
  if ((idx = [self->childNodes indexOfObject:_node]) == NSNotFound)
    /* given node is not a child of this node ! */
    return nil;
  
  [[_node retain] autorelease];
  [self->childNodes removeObjectAtIndex:idx];
  [(id)_node _domNodeForgetParentNode:self];
  
  return _node;
}

- (id<NSObject,DOMNode>)appendChild:(id<NSObject,DOMNode>)_node {
  if (_node == nil)
    /* adding a 'nil' node ?? */
    return nil;
  
  if ([_node nodeType] == DOM_DOCUMENT_FRAGMENT_NODE) {
    id             fragNodes;
    unsigned       i, count;
    NSMutableArray *cache;
    
    fragNodes = [_node childNodes];
    
    if ((count = [fragNodes count]) == 0)
      /* no nodes to add */
      return nil;

    /* 
       copy to cache, since 'childNodes' result is 'live' and 
       appendChild modifies the tree 
    */
    cache = [NSMutableArray arrayWithCapacity:count];
    for (i = 0; i < count; i++)
      [cache addObject:[fragNodes objectAtIndex:i]];
    
    /* append nodes (in reverse order [array implemention is assumed]) .. */
    for (i = count = [cache count]; i > 0; i--)
      [self appendChild:[cache objectAtIndex:(i - 1)]];
  }
  else {
    id oldParent;
    
    if ((oldParent = [_node parentNode]))
      [oldParent removeChild:_node];
    
    [self _ensureChildNodes];
    
    [self->childNodes addObject:_node];
    [(id)_node _domNodeRegisterParentNode:self];
  }
  
  /* return the node 'added' */
  return _node;
}

/* sibling navigation */

- (id)_domNodeBeforeNode:(id)_node {
  unsigned idx;
  
  if ((idx = [self->childNodes indexOfObject:_node]) == NSNotFound)
    /* given node isn't a child of this node */
    return nil;
  if (idx == 0)
    /* given node is the first child */
    return nil;
  
  return [self->childNodes objectAtIndex:(idx - 1)];
}
- (id)_domNodeAfterNode:(id)_node {
  unsigned idx, count;

  if ((count = [self->childNodes count]) == 0)
    /* this node has no children at all .. */
    return nil;
  
  if ((idx = [self->childNodes indexOfObject:_node]) == NSNotFound)
    /* given node isn't a child of this node */
    return nil;
  if (idx == (count - 1))
    /* given node is the last child */
    return nil;
  
  return [self->childNodes objectAtIndex:(idx + 1)];
}

@end /* NGDOMNodeWithChildren */
