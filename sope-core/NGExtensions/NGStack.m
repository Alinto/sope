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

#include "common.h"
#include "NGStack.h"
#include "NGMemoryAllocation.h"

@interface _NGConcreteStackEnumerator : NSEnumerator
{
  NGStack  *stack; // for retain
  id       *trace;
  unsigned toGo;
  BOOL     downWard; // top=>down
}

- (id)initWithStack:(NGStack *)_stack trace:(id *)_ptr count:(int)_size
  topDown:(BOOL)_downWard;

- (id)nextObject;

@end

@implementation NGStack

+ (id)stackWithCapacity:(NSUInteger)_capacity {
  return [[[self alloc] initWithCapacity:_capacity] autorelease];
}
+ (id)stack {
  return [[[self alloc] init] autorelease];
}
+ (id)stackWithArray:(NSArray *)_array {
  return [[[self alloc] initWithArray:_array] autorelease];
}

- (id)init {
  return [self initWithCapacity:256];
}
- (id)initWithCapacity:(NSUInteger)_capacity {
  if ((self = [super init])) {
    stackPointer = 0;
    capacity     = (_capacity > 0) ? _capacity : 16;

    stack = NGMalloc(sizeof(id) * capacity);
  }
  return self;
}
- (id)initWithArray:(NSArray *)_array {
  register unsigned int count = [_array count];

  if ((self = [self initWithCapacity:(count + 1)])) {
    unsigned cnt;

    for (cnt = 0; cnt < count; cnt++)
      [self push:[_array objectAtIndex:cnt]];
  }
  return self;
}

- (void)dealloc {
  if (self->stack) {
    [self clear];
    NGFree(self->stack);
  }
  [super dealloc];
}

/* sizing */

- (void)_increaseStack {
  if (capacity > 256) capacity += 256;
  else capacity *= 2;

  stack = NGRealloc(stack, sizeof(id) * capacity);
}

/* state */

- (NSUInteger)capacity {
  return capacity;
}
- (NSUInteger)stackPointer {
  return stackPointer;
}
- (NSUInteger)count {
  return stackPointer;
}
- (BOOL)isEmpty {
  return (stackPointer == 0);
}

/* operations */

- (void)push:(id)_obj {
  stackPointer++;
  if (stackPointer >= capacity) [self _increaseStack];
  stack[stackPointer] = [_obj retain];
}

- (id)pop {
  id obj = stack[stackPointer];
  if (stackPointer <= 0) {
    [[[NGStackException alloc] initWithName:@"StackException"
      reason:@"tried to pop an object from an empty stack !"
      userInfo:nil] raise];
  }
  stack[stackPointer] = nil;
  stackPointer--;
  return [obj autorelease];
}

- (void)clear {
  unsigned cnt;
  for (cnt = 1; cnt <= stackPointer; cnt++) {
#if !LIB_FOUNDATION_BOEHM_GC
    [stack[cnt] release];
#endif
    stack[cnt] = nil;
  }
  stackPointer = 0;
}

/* elements */

- (id)elementAtTop {
  return (stackPointer == 0) ? nil : stack[stackPointer];
}
- (id)elementAtBottom {
  return (stackPointer == 0) ? nil : stack[1];
}

- (NSEnumerator *)topDownEnumerator {
  if (stackPointer == 0)
    return nil;

  return [[[_NGConcreteStackEnumerator alloc]
                        initWithStack:self trace:&(stack[stackPointer])
                        count:stackPointer topDown:YES] autorelease];
}
- (NSEnumerator *)bottomUpEnumerator {
  if (stackPointer == 0)
    return nil;

  return [[[_NGConcreteStackEnumerator alloc]
                        initWithStack:self trace:&(stack[1])
                        count:stackPointer topDown:NO] autorelease];
}

/* NSCoding */

- (Class)classForCoder {
  return [NGStack class];
}

- (void)encodeWithCoder:(NSCoder *)_encoder {
  unsigned cnt;
  
  [_encoder encodeValueOfObjCType:@encode(NSUInteger) at:&capacity];
  [_encoder encodeValueOfObjCType:@encode(NSUInteger) at:&stackPointer];

  for (cnt = 1; cnt <= stackPointer; cnt++) {
    id obj = stack[cnt];
    [_encoder encodeObject:obj];
  }
}

- (id)initWithCoder:(NSCoder *)_decoder {
  int tmpCapacity;
  int tmpStackPointer;

  [_decoder decodeValueOfObjCType:@encode(NSUInteger) at:&tmpCapacity];
  [_decoder decodeValueOfObjCType:@encode(NSUInteger) at:&tmpStackPointer];

  self = [self initWithCapacity:tmpCapacity];
  {
    register int cnt;

    for (cnt = 1; cnt <= tmpStackPointer; cnt++) {
      id obj = [_decoder decodeObject];
      stack[cnt] = [obj retain];
    }
    stackPointer = tmpStackPointer;
  }
  return self;
}

/* copying */

- (id)copyWithZone:(NSZone *)_zone {
  register NGStack *newStack = nil;
  register unsigned cnt;

  newStack = [[NGStack allocWithZone:(_zone ? _zone : NSDefaultMallocZone())]
                       initWithCapacity:[self stackPointer]];

  for (cnt = 1; cnt <= stackPointer; cnt++)
    [newStack push:stack[cnt]];

  return newStack;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p] capacity=%u SP=%u count=%u content=%s>",
                     NSStringFromClass([self class]), self,
                     [self capacity], [self stackPointer], [self count],
                     [[[self toArray] description] cString]];
}

- (NSArray *)toArray {
  register NSMutableArray *array = nil;
  register unsigned cnt;

  array = [[NSMutableArray alloc] initWithCapacity:stackPointer];

  for (cnt = 1; cnt <= stackPointer; cnt++)
    [array addObject:stack[cnt]];

  return [array autorelease];
}

@end /* NGStack */

@implementation _NGConcreteStackEnumerator

- (id)initWithStack:(NGStack *)_stack trace:(id *)_ptr count:(int)_size
  topDown:(BOOL)_downWard {

  stack    = [_stack retain];
  trace    = _ptr;
  toGo     = _size;
  downWard = _downWard;

  return self;
}

- (void)dealloc {
  [self->stack release];
  trace = NULL;
  [super dealloc];
}

- (id)nextObject {
  id result = nil;
  
  if (toGo == 0)
    return nil;

  toGo--;

  result = *trace;
  
  if (downWard) trace--; // top=>bottom (downward)
  else          trace++; // bottom=>top (upward)

  return result;
}

@end /* NGStack */

@implementation NGStackException
@end /* NGStackException */

@implementation NSMutableArray(StackImp)

/* state */

- (NSUInteger)stackPointer {
  return ([self count] - 1);
}

- (BOOL)isEmpty {
  return ([self count] == 0) ? YES : NO;
}

/* operations */

- (void)push:(id)_obj {
  [self addObject:_obj];
}
- (id)pop {
  unsigned lastIdx = ([self count] - 1);

  if (lastIdx >= 0) {
    id element = [self objectAtIndex:lastIdx];
    [self removeObjectAtIndex:lastIdx];
    return element;
  }
  else {
    [[[NGStackException alloc] initWithName:@"StackException"
        reason:@"tried to pop an object from an empty stack !"
        userInfo:nil] raise];
    return nil;
  }
}

- (void)clear {
  [self removeAllObjects];
}

/* elements */

- (id)elementAtTop {
  return [self lastObject];
}

- (NSEnumerator *)topDownEnumerator {
  return [self reverseObjectEnumerator];
}
- (NSEnumerator *)bottomUpEnumerator {
  return [self objectEnumerator];
}

@end /* NSMutableArray(NGStack) */

void __link_NGExtensions_NGStack() {
  __link_NGExtensions_NGStack();
}
