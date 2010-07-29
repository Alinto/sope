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

#include "WETreeMatrixElement.h"
#include "common.h"

@implementation _WETreeMatrixElement

static Class StrClass = Nil;

+ (void)initialize {
  StrClass = [NSString class];
}

- (id)initWithElement:(_WETreeMatrixElement *)_element {
  if ((self = [super init])) {
    int j;
    
    for (j = 0; j < MAX_TREE_DEPTH; j++)
      self->elements[j] = 0;
    
    if (_element) {
      int i;
      
      self->depth = _element->depth + 1;
      for (i = 0; i < self->depth; i++) {
        self->leaf         = _element->leaf;
        self->elements[i]  = [_element->elements[i] retain];
        self->indexPath[i] = _element->indexPath[i];
        self->itemPath[i]  = [_element->itemPath[i] retain];
      }
    }
    else
      self->depth = 0;
  }
  return self;  
}

- (id)init {
  return [self initWithElement:nil];
}

- (void)dealloc {
  int i;

  for (i = 0; i < self->depth; i++) {
    [self->itemPath[i] release];
    [self->elements[i] release];
  }
  [super dealloc];
}

/* accessors */
  
- (void)setElement:(NSString *)_element {
  ASSIGN(self->elements[self->depth], _element);
}
- (NSString *)elementAtIndex:(int)_index {
  return self->elements[_index];
}

- (void)setItem:(id)_item {
  ASSIGN(self->itemPath[self->depth], _item);
}
- (id)item {
  return self->itemPath[self->depth-1];
}

- (void)setIndex:(int)_index {
  self->indexPath[self->depth] = _index;
}
- (int)index {
  return self->indexPath[self->depth-1];
}

- (void)setLeaf:(NSString *)_leaf {
  ASSIGN(self->leaf, _leaf);
}
- (NSString *)leaf {
  return self->leaf;
}

- (void)setColspan:(int)_colspan {
  self->colspan = _colspan;
}

- (NSString *)colspanAsString {
  switch (self->colspan) {
  case 0: return @"0";
  case 1: return @"1";
  case 2: return @"2";
  case 3: return @"3";
  default: {
    char buf[8];
    sprintf(buf, "%d", self->colspan);
    return [StrClass stringWithCString:buf];
  }
  }
}

- (int)depth {
  return self->depth;
}

- (NSArray *)currentPath {
  NSMutableArray *result;
  int            i;

  result = [NSMutableArray arrayWithCapacity:self->depth];
  for (i = 0; i < self->depth+1; i++) {
    if (self->itemPath[i] == nil)
      break;
    [result addObject:self->itemPath[i]];
  }
  return (NSArray *)result;
}

- (NSString *)elementID {
  // TODO: improve performance
  NSMutableArray *tmp;
  NSString     *s;
  unsigned int i;
  
  tmp = [[NSMutableArray alloc] initWithCapacity:self->depth];
  
  for (i = 0; i < self->depth; i++) {
    char buf[8];
    
    sprintf(buf, "%d", self->indexPath[i]);
    s = [[StrClass alloc] initWithCString:buf];
    [tmp addObject:s];
    [s release];
  }
  s = [tmp componentsJoinedByString:@"."];
  [tmp release];
  return s;
}

@end /* _WETreeMatrixElement */
