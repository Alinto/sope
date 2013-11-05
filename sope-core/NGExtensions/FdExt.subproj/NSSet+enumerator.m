/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "NSSet+enumerator.h"
#include "common.h"

@implementation NSSet(enumerator)

- (id)initWithObjectsFromEnumerator:(NSEnumerator *)_enumerator {
  NSMutableSet *set = nil;

  set = [[NSMutableSet alloc] initWithObjectsFromEnumerator:_enumerator];
  self = [self initWithSet:set];
  [set release]; set = nil;
  return self;
}

/* mapping */

- (NSArray *)mappedArrayUsingSelector:(SEL)_selector {
  NSArray *array;
  NSSet   *set;

  if ((set = [self mappedSetUsingSelector:_selector]) == nil)
    return nil;
  
  array = [[NSArray alloc]
	            initWithObjectsFromEnumerator:[set objectEnumerator]];
  return [array autorelease];
}
- (NSArray *)mappedArrayUsingSelector:(SEL)_selector withObject:(id)_object {
  NSArray *array;
  NSSet   *set;

  if ((set = [self mappedSetUsingSelector:_selector withObject:_object])== nil)
    return nil;
  
  array = [[NSArray allocWithZone:[self zone]]
                    initWithObjectsFromEnumerator:[set objectEnumerator]];
  return [array autorelease];
}

- (NSSet *)mappedSetUsingSelector:(SEL)_selector {
  NSMutableSet *set;
  NSEnumerator *e;
  id           object;

  set = [NSMutableSet setWithCapacity:[self count]];
  e   = [self objectEnumerator];
  while ((object = [e nextObject]) != nil) {
    object = [object performSelector:_selector];
    
    [set addObject:(object != nil ? object : (id)[NSNull null])];
  }
  return set;
}
- (NSSet *)mappedSetUsingSelector:(SEL)_selector withObject:(id)_object {
  NSMutableSet *set;
  NSEnumerator *e;
  id           object;
  
  set = [NSMutableSet setWithCapacity:[self count]];
  e   = [self objectEnumerator];
  while ((object = [e nextObject]) != nil) {
    object = [object performSelector:_selector withObject:_object];

    [set addObject:(object != nil ? object : (id)[NSNull null])];
  }
  return set;
}

@end /* NSSet(enumerator) */


@implementation NSMutableSet(enumerator) 

- (id)initWithObjectsFromEnumerator:(NSEnumerator *)_enumerator {
  if ((self = [self init]) != nil) {
    id obj;
     
    while ((obj = [_enumerator nextObject]) != nil)
      [self addObject:obj];
  }
  return self;
}

@end /* NSMutableSet(enumerator)  */

void __link_NGExtensions_NSSetEnumerator() {
  __link_NGExtensions_NSSetEnumerator();
}
