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

#include "NGMerging.h"
#include "common.h"
#import <Foundation/Foundation.h>
#import <Foundation/NSObject.h>

static NSString *NGCannotMergeWithObjectException =
  @"NGCannotMergeWithObjectException";

@implementation NSObject(NGMerging)

- (BOOL)canMergeWithObject:(id)_object {
  return ((_object == nil) || (_object == self)) ? YES : NO;
}

- (id)_makeMergeCopyWithZone:(NSZone *)_zone {
  return [(id<NSCopying>)self copyWithZone:_zone];
}

- (id)mergeWithObject:(id)_object zone:(NSZone *)_zone {
  if ((_object == nil) || (_object == self))
    return [self _makeMergeCopyWithZone:_zone];
  
  [NSException raise:NGCannotMergeWithObjectException
               format:@"cannot merge objects of class %@ and %@",
                 NSStringFromClass([self class]),
                 NSStringFromClass([_object class])];
  return nil;
}

- (id)mergeWithObject:(id)_object {
  return [self mergeWithObject:_object zone:NULL];
}

@end

@implementation NSDictionary(NGMerging)

- (BOOL)canMergeWithObject:(id)_object {
  if ((self == _object) || (_object == nil))
    return YES;

  if ([_object isKindOfClass:[NSDictionary class]])
    return YES;

  return NO;
}

- (id)_makeMergeCopyWithZone:(NSZone *)_zone {
  return [self retain];
}

- (id)mergeWithDictionary:(NSDictionary *)_object zone:(NSZone *)_zone {
  NSMutableDictionary *result;
  NSArray *aKeys, *bKeys;
  int i, count;
  
  if ((self == _object) || (_object == nil))
    return [self _makeMergeCopyWithZone:_zone];

  aKeys = [self allKeys];
  bKeys = [_object allKeys];
  result = [NSMutableDictionary dictionary];

  /* merge all keys of a */
  for (i = 0, count = [aKeys count]; i < count; i++) {
    id key;
    id av, bv;

    key = [aKeys objectAtIndex:i];
    av = [self    objectForKey:key];
    bv = [_object objectForKey:key];

    if (bv == nil) {
      /* key is only in a */
      [result setObject:av forKey:key];
    }
    else {
      /* key is in both - need to merge */
      if ([av canMergeWithObject:bv]) {
        av = [av mergeWithObject:bv zone:_zone];
        [result setObject:av forKey:key];
      }
      else
        // if objects cannot be merged, av wins
        [result setObject:av forKey:key];
    }
  }

  /* add remaining keys in b */
  for (i = 0, count = [bKeys count]; i < count; i++) {
    id key;

    key = [bKeys objectAtIndex:i];
    if ([result objectForKey:key])
      // already merged key ..
      continue;

    [result setObject:[_object objectForKey:key] forKey:key];
  }

  return result;
}

- (id)mergeWithObject:(id)_object zone:(NSZone *)_zone {
  if ((self == _object) || (_object == nil))
    return [self _makeMergeCopyWithZone:_zone];
  
  if ([_object isKindOfClass:[NSDictionary class]])
    return [self mergeWithDictionary:_object zone:_zone];

  [NSException raise:NGCannotMergeWithObjectException
               format:@"cannot merge %@ with %@",
                 NSStringFromClass([self class]),
                 NSStringFromClass([_object class])];
  return nil;
}

@end

@implementation NSMutableDictionary(NGMerging)

- (id)_makeMergeCopyWithZone:(NSZone *)_zone {
  return [self copyWithZone:_zone];
}

@end

@implementation NSArray(NGMerging)

- (BOOL)canMergeWithObject:(id)_object {
  if ((self == _object) || (_object == nil))
    return YES;

  if ([_object respondsToSelector:@selector(objectEnumerator)])
    return YES;
  
  return NO;
}

- (id)_makeMergeCopyWithZone:(NSZone *)_zone {
  return [self retain];
}

- (id)mergeWithEnumeration:(NSEnumerator *)_object zone:(NSZone *)_zone {
  NSMutableArray *result;
  id value;

  if (_object == nil)
    return [self _makeMergeCopyWithZone:_zone];

  /* make copy of self */
  result = [[self mutableCopyWithZone:_zone] autorelease];

  /* add other elements */
  while ((value = [_object nextObject]))
    [result addObject:value];

  return result;
}

- (id)mergeWithArray:(NSArray *)_object zone:(NSZone *)_zone {
  if (_object == nil)
    return [self _makeMergeCopyWithZone:_zone];
  
  return [self arrayByAddingObjectsFromArray:_object];
}

- (id)mergeWithObject:(id)_object zone:(NSZone *)_zone {
  if (_object == nil)
    return [self _makeMergeCopyWithZone:_zone];
  
  if ([_object respondsToSelector:@selector(objectEnumerator)])
    return [self mergeWithEnumeration:[_object objectEnumerator] zone:_zone];

  [NSException raise:NGCannotMergeWithObjectException
               format:@"cannot merge %@ with %@",
                 NSStringFromClass([self class]),
                 NSStringFromClass([_object class])];
  return nil;
}

@end

@implementation NSMutableArray(NGMerging)

- (id)_makeMergeCopyWithZone:(NSZone *)_zone {
  return [self copyWithZone:_zone];
}

@end

// for static linking

void __link_NGExtensions_NGMerging(void) {
  __link_NGExtensions_NGMerging();
}
