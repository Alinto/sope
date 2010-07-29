/*
  Copyright (C) 2004 eXtrapola Srl

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

#import "StructuredStack.h"
#include "common.h"

@implementation StructuredStack

- (void)dealloc {
  [self->_stack release];
  [super dealloc];
}

/* accessors */

- (NSMutableArray *)stack {
  if (self->_stack == nil)
    // TODO: find a proper capacity
    self->_stack = [[NSMutableArray alloc] initWithCapacity:16];

  return _stack;
}

/* operations */

- (void)removeAllObjects {
  [[self stack] removeAllObjects];
  [self first];
}

- (void)push:(id)anObject {
  NSMutableArray *stack;
  
  if (anObject == nil)
    return;
  
  stack = [self stack];
  [stack addObject:anObject];
  
  if (![self cursorFollowsFIFO])
    return;

  self->start = NO;
  self->pos   = ([stack count] - 1);
}

- (id)pop {
  NSMutableArray *stack;
  int count;
  id object;

  object = nil;

  stack = [self stack];
  count = [stack count];
  
  if (count > 0) {
    object = [stack objectAtIndex:--count];

    [stack removeLastObject];
  }

  if ([self cursorFollowsFIFO]) {
    start = NO;
    pos = count - 1;
  }

  return object;
}

- (void)first {
  pos = 0;
  start = YES;
}
- (void)last {
  pos = [[self stack] count];
  start = NO;
}

/* enumerator */

- (id)nextObject {
  NSMutableArray *stack;
  int count;

  stack = [self stack];
  count = [stack count];

  if (count == 0 || pos >= count) {
    return nil;
  }

  if (self->start) {
    self->start = NO;
  } 
  else {
    pos++;

    if (pos >= count)
      return nil;
  }

  return [stack objectAtIndex:pos];
}

- (id)currentObject {
  NSMutableArray *stack;
  int count;

  stack = [self stack];
  count = [stack count];

  if (count == 0 || pos >= count)
    return nil;
  
  self->start = NO;

  return [[self stack] objectAtIndex:pos];
}

- (id)prevObject {
  NSMutableArray *stack;
  id result;

  stack = [self stack];
  
  result = ((start || pos == 0) && [stack count])
    ? nil
    : [stack objectAtIndex:--pos];
  return result;
}

- (void)setCursorFollowsFIFO:(BOOL)aValue {
  self->cursorFIFO = aValue;
}
- (BOOL)cursorFollowsFIFO {
  return self->cursorFIFO;
}

- (id)objectRelativeToCursorAtIndex:(int)anIndex {
  NSMutableArray *stack;
  int i, count;

  stack = [self stack];
  count = [stack count];

  i = pos + anIndex;

  if (count == 0 || i < 0 || i >= count)
    return nil;
  
  return [[self stack] objectAtIndex:i];
}

@end /* StructuredStack */
