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

#ifndef __NGExtensions_NGBitSet_H__
#define __NGExtensions_NGBitSet_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSRange.h>

@class NSArray, NSEnumerator;

typedef unsigned int NGBitSetStorage;

@protocol NGBitSet < NSObject >

// state

- (unsigned int)count;

// membership

- (BOOL)isMember:(unsigned int)_element;
- (void)addMember:(unsigned int)_element;
- (void)addMembersInRange:(NSRange)_range;
- (void)removeMember:(unsigned int)_element;
- (void)removeMembersInRange:(NSRange)_range;
- (void)removeAllMembers;

@end

@interface NGBitSet : NSObject < NGBitSet, NSCopying, NSCoding >
{
@protected
  unsigned int    universe;
  unsigned int    count;
  NGBitSetStorage *storage;
}

+ (id)bitSet;
+ (id)bitSetWithCapacity:(unsigned)_capacity;
+ (id)bitSetWithBitSet:(NGBitSet *)_set;
- (id)init;
- (id)initWithCapacity:(unsigned)_capacity; // designated initializer
- (id)initWithBitSet:(NGBitSet *)_set;
- (id)initWithNullTerminatedArray:(unsigned int *)_array;

// state

- (unsigned int)capacity;

// membership

- (unsigned int)firstMember;
- (unsigned int)lastMember;
- (void)addMembersFromBitSet:(NGBitSet *)_set;

// equality

- (BOOL)isEqual:(id)_object;
- (BOOL)isEqualToSet:(NGBitSet *)_set;

// enumerator

- (NSEnumerator *)objectEnumerator;

// NSCopying

- (id)copy;
- (id)copyWithZone:(NSZone *)_zone;

// NSCoding

- (void)encodeWithCoder:(NSCoder *)_coder;
- (id)initWithCoder:(NSCoder *)_coder;

// description

- (NSString *)description;
- (NSArray *)toArray;

@end

NSString *stringValueForBitset(unsigned int _set, char _setC, char _unsetC,
                               short _wide);

#endif /* __NGExtensions_NGBitSet_H__ */
