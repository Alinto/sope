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

#ifndef __DOMTreeWalker_H__
#define __DOMTreeWalker_H__

#import <Foundation/NSObject.h>
#include <DOM/DOMProtocols.h>

@class NSArray;

@interface NGDOMTreeWalker : NSObject
{
  id            root;
  unsigned long whatToShow;
  id            filter;
  BOOL          expandEntityReferences;
  id            currentNode;

  /* cache state */
  NSArray       *visibleChildren;
}

/* attributes */

- (id)root;
- (unsigned long)whatToShow;
- (id)filter;
- (BOOL)expandEntityReferences;

- (void)setCurrentNode:(id)_node;
- (id)currentNode;

/* operations */

- (id<NSObject,DOMNode>)parentNode;
- (id<NSObject,DOMNode>)firstChild;
- (id<NSObject,DOMNode>)lastChild;
- (id<NSObject,DOMNode>)previousSibling;
- (id<NSObject,DOMNode>)nextSibling;

- (id<NSObject,DOMNode>)previousNode;
- (id<NSObject,DOMNode>)nextNode;

@end

@interface NGDOMTreeWalker(PrivateCtors)
/* use DOMDocument(DocumentTraversal) for constructing DOMTreeWalker's ! */

- (id)initWithRootNode:(id)_rootNode
  whatToShow:(unsigned long)_whatToShow
  filter:(id)_filter
  expandEntityReferences:(BOOL)_flag;

@end

#endif /* __DOMTreeWalker_H__ */
