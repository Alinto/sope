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

#ifndef __WEExtensions_WETreeMatrixElement_H__
#define __WEExtensions_WETreeMatrixElement_H__

#import <Foundation/NSString.h>

/*
  _WETreeMatrixElement
  
  This object represents a row in the table generated for the tree view. Prior
  rendering the tree view iterates over the active list of nodes and collects
  them as matrix-elements. The view needs to do this to calculate proper
  colspans and lines.
  
  The 'elements' array contains the columns of the table, this includes markers
  for the tree parts being rendered (lines, +/- etc).

  For rendering WETreeData retrieves the 'active' tree element from the context
  using the 'WETreeView_TreeElement' key.
*/

#define MAX_TREE_DEPTH 21  /* max recursion depth is 20 */

@interface _WETreeMatrixElement : NSObject
{
@protected
  int      depth;
  NSString *leaf;
  NSString *elements[MAX_TREE_DEPTH];
  id       itemPath[MAX_TREE_DEPTH];      // --> currentPath
  int      indexPath[MAX_TREE_DEPTH];
  int      colspan;
}

- (id)initWithElement:(_WETreeMatrixElement *)_element;
- (void)setLeaf:(NSString *)_leaf;
- (void)setElement:(NSString *)_element;
- (void)setItem:(id)_item;
- (void)setIndex:(int)_index;

- (NSString *)leaf;
- (int)index;
- (id)item;
- (NSArray *)currentPath;

- (NSString *)elementAtIndex:(int)_index;
- (int)depth;
- (void)setColspan:(int)_colspan;
- (NSString *)colspanAsString;
- (NSString *)elementID;

@end

#endif /* __WEExtensions_WETreeMatrixElement_H__ */
