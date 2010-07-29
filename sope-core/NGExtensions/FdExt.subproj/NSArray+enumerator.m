/*
  Copyright (C) 2000-2008 SKYRIX Software AG
  Copyright (C) 2008      Helge Hess

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

#include "NSArray+enumerator.h"
#include "common.h"

@implementation NSArray(enumerator)

- (id)initWithObjectsFromEnumerator:(NSEnumerator *)_enumerator {
  NSMutableArray *array = nil;
  
  array = [[NSMutableArray alloc]
                           initWithObjectsFromEnumerator:_enumerator];
  self = [self initWithArray:array];
  [array release]; array = nil;
  return self;
}

/* mapping */

- (NSArray *)mappedArrayUsingSelector:(SEL)_selector {
  int i, count = [self count];
  id  objects[count];
  IMP objAtIndex;
  
  if (_selector == NULL) return self;

  objAtIndex = [self methodForSelector:@selector(objectAtIndex:)];

  for (i = 0; i < count; i++) {
    objects[i] = objAtIndex(self, @selector(objectAtIndex:), i);
    objects[i] = [objects[i] performSelector:_selector];
    if (objects[i] == nil)
      objects[i] = [NSNull null];
  }

  return [NSArray arrayWithObjects:objects count:count];
}
- (NSArray *)mappedArrayUsingSelector:(SEL)_selector withObject:(id)_object {
  int i, count = [self count];
  id  objects[count];
  IMP objAtIndex;
  
  if (_selector == NULL) return self;

  objAtIndex = [self methodForSelector:@selector(objectAtIndex:)];

  for (i = 0; i < count; i++) {
    objects[i] = [objAtIndex(self, @selector(objectAtIndex:), i)
                            performSelector:_selector withObject:_object];

    if (objects[i] == nil)
      objects[i] = [NSNull null];
  }

  return [NSArray arrayWithObjects:objects count:count];
}

- (NSSet *)mappedSetUsingSelector:(SEL)_selector {
  return [NSSet setWithArray:[self mappedArrayUsingSelector:_selector]];
}
- (NSSet *)mappedSetUsingSelector:(SEL)_selector withObject:(id)_object {
  return [NSSet setWithArray:[self mappedArrayUsingSelector:_selector
                                   withObject:_object]];
}

#if !LIB_FOUNDATION_LIBRARY

- (NSArray *)map:(SEL)_sel {
  unsigned int index, count;
  id array;
  
  count = [self count];
  array = [NSMutableArray arrayWithCapacity:count];
  for (index = 0; index < count; index++) {
    [array insertObject:[[self objectAtIndex:index] performSelector:_sel]
	   atIndex:index];
  }
  return array;
}

- (NSArray *)map:(SEL)_sel with:(id)_arg {
  unsigned int index, count;
  id array;
  
  count = [self count];
  array = [NSMutableArray arrayWithCapacity:count];
  for (index = 0; index < count; index++) {
    [array insertObject:[[self objectAtIndex:index]
			       performSelector:_sel withObject:_arg]
	   atIndex:index];
  }
  return array;
}

#endif

@end /* NSArray(enumerator) */

@implementation NSMutableArray(enumerator) 

- (id)initWithObjectsFromEnumerator:(NSEnumerator *)_enumerator {
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
  NSMutableArray *ma = [[NSMutableArray alloc] initWithCapacity:64];
  id obj;

  while ((obj = [_enumerator nextObject]))
    [ma addObject:obj];

  self = [self initWithArray:ma];
  [ma release]; ma = nil;
  return self;
#else
  if ((self = [self init]) != nil) {
    id obj = nil;
     
    // Does not work on Cocoa because we only have NSCFArray over there ...
    while ((obj = [_enumerator nextObject]))
      [self addObject:obj];
  }
  return self;
#endif
}

@end /* NSMutableArray(enumerator)  */

void __link_NGExtensions_NSArrayEnumerator() {
  __link_NGExtensions_NSArrayEnumerator();
}
