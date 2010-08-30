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

#import "common.h"
#import "NGMemoryAllocation.h"
#import "NGBitSet.h"

#define NGStorageSize   sizeof(NGBitSetStorage)
#define NGBitsPerEntry  (NGStorageSize * 8)
#define NGByteSize      (universe / 8)

#define NGTestBit(_x)   (((storage[ _x / NGBitsPerEntry ] & \
                         (1 << (_x % NGBitsPerEntry))) == 0) ? NO : YES)

@interface NGConcreteBitSetEnumerator : NSEnumerator
{
@public
  unsigned int    universe;
  unsigned int    count;
  NGBitSetStorage *storage;

  unsigned int position;
  unsigned int found;
}

- (id)nextObject;

@end

@implementation NGBitSet

+ (id)bitSet {
  return [[[self alloc] init] autorelease];
}
+ (id)bitSetWithCapacity:(NSUInteger)_capacity {
  return [[[self alloc] initWithCapacity:_capacity] autorelease];
}
+ (id)bitSetWithBitSet:(NGBitSet *)_set {
  return [[[self alloc] initWithBitSet:_set] autorelease];
}

- (id)initWithCapacity:(NSUInteger)_capacity {
  if ((self = [super init])) {
    self->universe = (_capacity / NGBitsPerEntry + 1) * NGBitsPerEntry;
    storage  = NGMallocAtomic(NGByteSize);
    memset(storage, 0, NGByteSize);
    count = 0;
  }
  return self;
}

- (id)initWithBitSet:(NGBitSet *)_set {
  if ((self = [self initWithCapacity:NGBitsPerEntry])) {
    NSEnumerator *enumerator = [_set objectEnumerator];
    id obj = nil;

    while ((obj = [enumerator nextObject]))
      [self addMember:[obj unsignedIntValue]];

    enumerator = nil;
  }
  return self;
}
- (id)init {
  return [self initWithCapacity:NGBitsPerEntry];
}
- (id)initWithNullTerminatedArray:(unsigned int *)_array {
  if ((self = [self initWithCapacity:NGBitsPerEntry])) {
    while (*_array) {
      [self addMember:*_array];
      _array++;
    }
  }
  return self;
}

- (void)dealloc {
  if (self->storage) {
    NGFree(self->storage);
    self->storage = NULL;
  }
  [super dealloc];
}

/* storage */

- (void)_expandToInclude:(NSUInteger)_element {
  unsigned int nu = (_element / NGBitsPerEntry + 1) * NGBitsPerEntry;
  if (nu > self->universe) {
    void *old = storage;
    storage = (NGBitSetStorage *)NGMallocAtomic(nu / 8);
    memset(storage, 0, nu / 8);
    if (old) {
      memcpy(storage, old, NGByteSize);
      NGFree(old);
      old = NULL;
    }
    self->universe = nu;
  }
}

/* accessors */

- (NSUInteger)capacity {
  return self->universe;
}
- (NSUInteger)count {
  return count;
}

/* membership */

- (BOOL)isMember:(NSUInteger)_element {
  return (_element >= self->universe) ? NO : NGTestBit(_element);
}

- (void)addMember:(NSUInteger)_element {
  register unsigned int subIdxPattern = 1 << (_element % NGBitsPerEntry);

  if (_element >= self->universe)
    [self _expandToInclude:_element];

  if ((storage[ _element / NGBitsPerEntry ] & subIdxPattern) == 0) {
    storage[ _element / NGBitsPerEntry ] |= subIdxPattern;
    count++;
  }
}
- (void)addMembersInRange:(NSRange)_range {
  register unsigned int from = _range.location;
  register unsigned int to   = from + _range.length - 1;

  if (to >= self->universe)
    [self _expandToInclude:to];

  for (; from <= to; from++) {
    register unsigned int subIdxPattern = 1 << (from % NGBitsPerEntry);

    if ((storage[ from / NGBitsPerEntry ] & subIdxPattern) == 0) {
      storage[ from / NGBitsPerEntry ] |= subIdxPattern;
      count++;
    }
  }
}

- (void)addMembersFromBitSet:(NGBitSet *)_set {
  unsigned i;

  if ([_set capacity] > self->universe)
    [self _expandToInclude:[_set capacity]];

  for (i = 0; i < [_set capacity]; i++) {
    if ([_set isMember:i]) {
      register unsigned int subIdxPattern = 1 << (i % NGBitsPerEntry);
      
      if ((storage[ i / NGBitsPerEntry ] & subIdxPattern) == 0) {
        storage[ i / NGBitsPerEntry ] |= subIdxPattern;
        count++;
      }
    }
  }
}

- (void)removeMember:(NSUInteger)_element {
  register unsigned int subIdxPattern = 1 << (_element % NGBitsPerEntry);

  if (_element >= self->universe)
    return;

  if ((storage[ _element / NGBitsPerEntry ] & subIdxPattern) != 0) {
    storage[ _element / NGBitsPerEntry ] -= subIdxPattern;
    count--;
  }
}
- (void)removeMembersInRange:(NSRange)_range {
  register unsigned int from = _range.location;
  register unsigned int to   = from + _range.length - 1;

  if (from >= self->universe)
    return;
  if (to >= self->universe) to = self->universe - 1;
  
  for (; from <= to; from++) {
    register unsigned int subIdxPattern = 1 << (from % NGBitsPerEntry);

    if ((storage[ from / NGBitsPerEntry ] & subIdxPattern) != 0) {
      storage[ from / NGBitsPerEntry ] -= subIdxPattern;
      count--;
    }
  }
}
- (void)removeAllMembers {
  memset(storage, 0, NGByteSize);
  count = 0;
}

- (NSUInteger)firstMember {
  register unsigned int element;

  for (element = 0; element < self->universe; element++) {
    if (NGTestBit(element))
      return element;
  }
  return NSNotFound;
}

- (NSUInteger)lastMember {
  register unsigned int element;

  for (element = (self->universe - 1); element >= 0; element--) {
    if (NGTestBit(element))
      return element;
  }
  return NSNotFound;
}

/* equality */

- (BOOL)isEqual:(id)_object {
  if (self == _object) return YES;
  if ([self class] != [_object class]) return NO;
  return [self isEqualToSet:_object];
}
- (BOOL)isEqualToSet:(NGBitSet *)_set {
  if (self == _set) return YES;
  if (count != [_set count]) return NO;

  {
    register unsigned int element;

    for (element = 0; element < self->universe; element++) {
      if (NGTestBit(element)) {
        if (![_set isMember:element])
          return NO;
      }
    }
    return YES;
  }
}

/* enumerator */

- (NSEnumerator *)objectEnumerator {
  if (self->count == 0) 
    return nil;
  else {
    NGConcreteBitSetEnumerator *en = [[NGConcreteBitSetEnumerator alloc] init];
    en->universe = self->universe;
    en->count    = self->count;
    en->storage  = self->storage;
    return [en autorelease];
  }
}

/* NSCopying */

- (id)copy {
  return [self copyWithZone:[self zone]];
}
- (id)copyWithZone:(NSZone *)_zone {
  return [[NGBitSet alloc] initWithBitSet:self];
}


/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  unsigned int element;
  register unsigned int found;

  [_coder encodeValueOfObjCType:@encode(NSUInteger) at:&count];

  for (element = 0, found = 0; (element < self->universe) && (found < count); element++) {
    if (NGTestBit(element)) {
      [_coder encodeValueOfObjCType:@encode(NSUInteger) at:&element];
      found++;
    }
  }
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super init])) {
    unsigned int nc;
    register unsigned int cnt;

    self->universe = NGBitsPerEntry;
    storage  = NGMallocAtomic(NGByteSize);
    memset(storage, 0, NGByteSize);

    [_coder decodeValueOfObjCType:@encode(NSUInteger) at:&nc];

    for (cnt = 0; cnt < nc; cnt++) {
      unsigned int member;
      [_coder decodeValueOfObjCType:@encode(NSUInteger) at:&member];
      [self addMember:member];
    }
  }
  return self;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<NGBitSet[0x%p]: capacity=%u count=%u content=%@>",
                     self, self->universe, self->count,
                     [[self toArray] description]];
}

- (NSArray *)toArray {
  NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:count + 1];
  register unsigned int element, found;

  for (element = 0, found = 0;
       (element < self->universe) && (found < self->count); element++) {
    
    if (NGTestBit(element)) {
      [result addObject:[NSNumber numberWithUnsignedInt:element]];
      found++;
    }
  }
  return [[[result autorelease] copy] autorelease];
}

@end /* NGBitSet */

@implementation NGConcreteBitSetEnumerator

- (id)nextObject {
  if (self->found == self->count)
    return nil;
  if (self->position >= self->universe)
    return nil;

  while (!NGTestBit(self->position))
    self->position++;

  self->found++;
  self->position++;

  return [NSNumber numberWithUnsignedInt:(self->position - 1)];
}

@end /* NGConcreteBitSetEnumerator */

NSString *stringValueForBitset(unsigned int _set, char _setC, char _unsetC,
                               short _wide) {
  char           buf[_wide + 1];
  register short pos;

  for (pos = 0; pos < _wide; pos++) {
    register unsigned int v = (1 << pos);
    buf[(int)pos] = ((v & _set) == v) ? _setC : _unsetC;
  }
  
  buf[_wide] = '\0';
  return [NSString stringWithCString:buf];
}

void __link_NGExtensions_NGBitSet() {
  __link_NGExtensions_NGBitSet();
}
