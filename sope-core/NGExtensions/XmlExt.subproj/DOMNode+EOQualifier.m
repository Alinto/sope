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

#include "DOMNode+EOQualifier.h"
#import <EOControl/EOQualifier.h>
#include "common.h"

@interface NSObject(DOMNodeEOQualifier)
- (NSArray *)_domChildrenMatchingQualifier:(EOQualifier *)_qualifier;
- (NSArray *)_domDescendantsMatchingQualifier:(EOQualifier *)_qualifier
  includeSelf:(BOOL)_includeSelf;
@end

@implementation NSObject(DOMNodeEOQualifier)
/* this category is used to support DOM ops on any object */

static NSArray *emptyArray = nil;

- (NSArray *)_domChildrenMatchingQualifier:(EOQualifier *)_qualifier {
  id       children;
  unsigned count;
  
  if (![(id<DOMNode>)self hasChildNodes])
    return nil;

  if ((children = [(id<DOMNode>)self childNodes]) == nil)
    return nil;

  if ((count = [children count]) == 0) {
    if (emptyArray == nil) emptyArray = [[NSArray alloc] init];
    return emptyArray;
  }
  else {
    NSMutableArray *marray;
    unsigned i;
    
    marray = [NSMutableArray arrayWithCapacity:(count + 1)];
    
    for (i = 0; i < count; i++) {
      id childNode;
      
      if ((childNode = [children objectAtIndex:i])) {
        if ((_qualifier == nil) ||
            [(id<EOQualifierEvaluation>)_qualifier evaluateWithObject:childNode])
          [marray addObject:childNode];
      }
    }
    
    return [[marray copy] autorelease];
  }
}

- (void)_addDOMDescendantsMatchingQualifier:(EOQualifier *)_qualifier
  toMutableArray:(NSMutableArray *)_array
  includeSelf:(BOOL)_includeSelf
{
  id       children;
  unsigned i, count;

  if (_includeSelf) {
    if ([(id<EOQualifierEvaluation>)_qualifier evaluateWithObject:self])
      [_array addObject:self];
  }
  
  if (![(id<DOMNode>)self hasChildNodes])
    return;

  children = [(id<DOMNode>)self childNodes];
  for (i = 0, count = [children count]; i < count; i++) {
    [[children objectAtIndex:i]
               _addDOMDescendantsMatchingQualifier:_qualifier
               toMutableArray:_array
               includeSelf:YES];
  }
}
- (NSArray *)_domDescendantsMatchingQualifier:(EOQualifier *)_qualifier
  includeSelf:(BOOL)_includeSelf
{
  NSMutableArray *marray;
  
  marray = [NSMutableArray arrayWithCapacity:16];
  
  [self _addDOMDescendantsMatchingQualifier:_qualifier
        toMutableArray:marray
        includeSelf:_includeSelf];
  
  return [[marray copy] autorelease];
}

@end /* NSObject(DOMNodeEOQualifier) */

@implementation NGDOMNode(EOQualifier)

- (NSArray *)childrenMatchingQualifier:(EOQualifier *)_qualifier {
  return [self _domChildrenMatchingQualifier:_qualifier];
}

- (NSArray *)descendantsMatchingQualifier:(EOQualifier *)_qualifier {
  return [self _domDescendantsMatchingQualifier:_qualifier
               includeSelf:NO];
}

@end /* NGDOMNode(EOQualifier) */
