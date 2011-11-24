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

#include "EOSortOrdering.h"
#include "EOKeyValueCoding.h"
#include <EOControl/EONull.h>
#include "common.h"

#if GNU_RUNTIME
#  include <objc/objc.h>
#endif

#ifndef SEL_EQ
#  if GNU_RUNTIME
#    define SEL_EQ(sel1,sel2) sel_isEqual(sel1,sel2)
#  else
#    define SEL_EQ(sel1,sel2) (sel1 == sel2)
#  endif
#endif

@implementation EOSortOrdering
/*"
  This class specifies a sort-ordering as used with
  EOFetchSpecification. It takes a key and a sort
  selector which is used for comparision.
"*/

/*" Create a sort-ordering object with the specified key and sort selector "*/
+ (EOSortOrdering *)sortOrderingWithKey:(NSString *)_key selector:(SEL)_sel {
  return [[[self alloc] initWithKey:_key selector:_sel] autorelease];
}

/*" 
  Initialize a sort-ordering object with the specified key and sort selector
"*/
- (id)initWithKey:(NSString *)_key selector:(SEL)_selector {
  if ((self = [super init])) {
    self->key      = [_key copyWithZone:[self zone]];
    self->selector = _selector;
  }
  return self;
}

- (void)dealloc {
  [self->key release];
  [super dealloc];
}

/* accessors */

/*"
  Returns the key the ordering sorts with.
"*/
- (NSString *)key {
  return self->key;
}

/*"
  Returns the selector the ordering sorts with.
"*/
- (SEL)selector {
  return self->selector;
}

/* equality */

- (BOOL)isEqualToSortOrdering:(EOSortOrdering *)_sortOrdering {
  if (!SEL_EQ([_sortOrdering selector], [self selector]))
    return NO;
  if (![[_sortOrdering key] isEqualToString:[self key]])
    return NO;
  return YES;
}
- (BOOL)isEqual:(id)_other {
  if ([_other isKindOfClass:[EOSortOrdering class]])
    return [self isEqualToSortOrdering:_other];

  return NO;
}

/* remapping keys */

- (EOSortOrdering *)sortOrderingByApplyingKeyMap:(NSDictionary *)_map {
  NSString *k;
  
  k = [_map objectForKey:self->key];
  return [EOSortOrdering sortOrderingWithKey:(k ? k : self->key)
			 selector:self->selector];
}

/* key/value archiving */

- (id)initWithKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  if ((self = [super init]) != nil) {
    NSString *s;
    
    self->key = [[_unarchiver decodeObjectForKey:@"key"] copy];
    
    if ((s = [_unarchiver decodeObjectForKey:@"selector"]) != nil)
      self->selector = NSSelectorFromString(s);
    else if ((s = [_unarchiver decodeObjectForKey:@"selectorName"]) != nil) {
      if (![s hasSuffix:@":"]) s = [s stringByAppendingString:@":"];
      self->selector = NSSelectorFromString(s);
    }
  }
  return self;
}
- (void)encodeWithKeyValueArchiver:(EOKeyValueArchiver *)_archiver {
  [_archiver encodeObject:[self key] forKey:@"key"];
  [_archiver encodeObject:NSStringFromSelector([self selector])
             forKey:@"selectorName"];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<0x%p[%@]: key=%@ selector=%@>",
                     self, NSStringFromClass([self class]),
                     [self key], NSStringFromSelector([self selector])];
}

@end /* EOSortOrdering */

@implementation NSArray(EOSortOrdering)

/*" 
  Sort the array using the sort-orderings contained in the argument. If no
  orderings are given, a copy of self is returned.
"*/
- (NSArray *)sortedArrayUsingKeyOrderArray:(NSArray *)_orderings {
  NSMutableArray *m      = nil;
  NSArray        *result = nil;
  
  if ([_orderings count] == 0)
    return [[self copy] autorelease];
  
  m = [self mutableCopy];
  [m sortUsingKeyOrderArray:_orderings];
  result = [m copy];
  [m release]; m = nil;
  return [result autorelease];
}

@end /* NSArray(EOSortOrdering) */

@implementation NSMutableArray(EOSortOrdering)

typedef struct {
  EOSortOrdering *orderings[10]; /* max depth 10 */
  short          count;
} EOSortOrderingContext;

static EONull *null = nil;

static int keyOrderComparator(id o1, id o2, EOSortOrderingContext *context) {
  short i;

  for (i = 0; i < context->count; i++) {
    NSString *key;
    SEL      sel;
    id       v1, v2;
    int      (*ccmp)(id, SEL, id);
    int      result;

    key = [context->orderings[i] key];
    sel = [context->orderings[i] selector];
    
    v1 = [o1 valueForKeyPath:key];
    v2 = [o2 valueForKeyPath:key];

    if (v1 == v2)
      result = NSOrderedSame;
    else if ((v1 == nil) || (v1 == null))
      result = (sel == EOCompareAscending)
        ? NSOrderedAscending : NSOrderedDescending;
    else if ((v2 == nil) || (v2 == null))
      result = (sel == EOCompareAscending)
        ? NSOrderedDescending : NSOrderedAscending;
    else if ((ccmp = (void *)[v1 methodForSelector:sel]))
      result = ccmp(v1, sel, v2);
    else
      result = (unsigned long)[v1 performSelector:sel withObject:v2];

    if (result != NSOrderedSame)
      return result;
  }
  return NSOrderedSame;
}

/*" 
  Sort the array using the sort-orderings contained in the argument.
"*/
- (void)sortUsingKeyOrderArray:(NSArray *)_orderings {
  NSEnumerator          *e        = nil;
  EOSortOrdering        *ordering = nil;
  EOSortOrderingContext ctx;
  int                   i;
  
  NSAssert([_orderings count] < 10, @"max sort descriptor count is 10!");
  
  e = [_orderings objectEnumerator];
  for (i = 0; (ordering = [e nextObject]) && (i < 10); i++)
    ctx.orderings[i] = ordering;

  ctx.count = i;

  if (null == nil) null = [EONull null];
  [self sortUsingFunction:(void *)keyOrderComparator context:&ctx];
}

@end /* NSMutableArray(EOSortOrdering) */

@implementation EONull(EOSortOrdering)

/*" 
  Compares the null object, "nil" and "self" are considered of the same order,
  otherwise null is considered of lower order.
"*/
- (int)compareAscending:(id)_object {
  if (_object == self) return NSOrderedSame;
  if (_object == nil)  return NSOrderedSame;
  return NSOrderedDescending;
}

/*" 
  Compares the null object, "nil" and "self" are considered of the same order,
  otherwise null is considered of higher order.
"*/
- (int)compareDescending:(id)_object {
  if (_object == self) return NSOrderedSame;
  if (_object == nil)  return NSOrderedSame;
  return NSOrderedAscending;
}

@end /* EONull(EOSortOrdering) */

@implementation NSNumber(EOSortOrdering)

static Class NumClass = Nil;

- (int)compareAscending:(id)_object {
  if (_object == self) return NSOrderedSame;
  if (NumClass == Nil) NumClass = [NSNumber class];
  
  if ([_object isKindOfClass:NumClass])
    return [self compare:_object];
  else
    return [_object compareDescending:self];
}

- (int)compareDescending:(id)_object {
  int result;
  
  result = [self compareAscending:_object];
  
  if (result == NSOrderedAscending)
    return NSOrderedDescending;
  else if (result == NSOrderedDescending)
    return NSOrderedAscending;
  else
    return NSOrderedSame;
}

@end /* NSNumber(EOSortOrdering) */

@implementation NSString(EOSortOrdering)

- (int)compareAscending:(id)_object {
  if (_object == self) return NSOrderedSame;
  return [self compare:[_object stringValue]];
}
- (int)compareCaseInsensitiveAscending:(id)_object {
  if (_object == self) return NSOrderedSame;
  return [self caseInsensitiveCompare:[_object stringValue]];
}

- (int)compareDescending:(id)_object {
  int result;
  
  if (_object == self) return NSOrderedSame;
  
  result = [self compareAscending:_object];
  
  if (result == NSOrderedAscending)
    return NSOrderedDescending;
  else if (result == NSOrderedDescending)
    return NSOrderedAscending;
  else
    return NSOrderedSame;
}

- (int)compareCaseInsensitiveDescending:(id)_object {
  int result;
  
  if (_object == self) return NSOrderedSame;
  result = [self compareCaseInsensitiveAscending:_object];
  
  if (result == NSOrderedAscending)
    return NSOrderedDescending;
  else if (result == NSOrderedDescending)
    return NSOrderedAscending;
  else
    return NSOrderedSame;
}

@end /* NSString(EOSortOrdering) */

@implementation NSDate(EOSortOrdering)

static Class DateClass = Nil;

- (int)compareAscending:(id)_object {
  if (_object == self) return NSOrderedSame;
  if (DateClass == Nil) DateClass = [NSDate class];
  if (![_object isKindOfClass:DateClass]) return NSOrderedAscending;
  return [self compare:_object];
}
- (int)compareDescending:(id)_object {
  int result;

  if (_object == self) return NSOrderedSame;

  if (DateClass == Nil) DateClass = [NSDate class];
  if (![_object isKindOfClass:DateClass]) return NSOrderedDescending;
  
  result = [self compare:_object];
  
  if (result == NSOrderedAscending)
    return NSOrderedDescending;
  else if (result == NSOrderedDescending)
    return NSOrderedAscending;
  else
    return NSOrderedSame;
}

@end /* NSDate(EOSortOrdering) */
