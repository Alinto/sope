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

#include "EOQualifier+CtxEval.h"
#import <EOControl/EOKeyValueCoding.h>
#import <EOControl/EONull.h>
#include "common.h"

#if LIB_FOUNDATION_LIBRARY
#  import <objc/objc-api.h>
#  import <objc/objc.h>
#  import <extensions/objc-runtime.h>
#elif GNUSTEP_BASE_LIBRARY
#if __GNU_LIBOBJC__ == 20100911
#  define sel_get_name sel_getName
#  import <objc/runtime.h>
#else
#  import <objc/objc-api.h>
#endif
#else
#  import <objc/objc.h>
#  define sel_get_name sel_getName
#endif

static inline int countSelArgs(SEL _sel) {
  register const char *selName;

  if ((selName = sel_get_name(_sel))) {
    register int count;
    
    for (count = 0; *selName; selName++) {
      if (*selName == ':')
        count++;
    }
    return count + 2;
  }
  else
    return -1;
}

@implementation EOQualifier(ContextEvaluation)

- (BOOL)evaluateWithObject:(id)_object context:(id)_context {
  [self doesNotRecognizeSelector:_cmd]; /* subclass */
  return NO;
}

@end /* EOQualifier(ContextEvaluation) */

@implementation NSArray(ContextEvaluation)

- (NSArray *)filteredArrayUsingQualifier:(EOQualifier *)_qualifier
  context:(id)_context
{
  NSMutableArray *a = nil;
  unsigned i, count;

  for (i = 0, count = [self count]; i < count; i++) {
    id o;

    o = [self objectAtIndex:i];
    
    if ([_qualifier evaluateWithObject:o context:_context]) {
      if (a == nil) a = [NSMutableArray arrayWithCapacity:count];
      [a addObject:o];
    }
  }
  return a ? [[a copy] autorelease] : [NSArray array];
}

@end /* NSArray(ContextEvaluation) */

@implementation EOAndQualifier(ContextEvaluation)

- (BOOL)evaluateWithObject:(id)_object context:(id)_context {
  unsigned i;
  IMP objAtIdx;
  NSArray *qs;

  qs       = [self qualifiers];
  objAtIdx = [qs methodForSelector:@selector(objectAtIndex:)];
  
  for (i = 0; i < [qs count]; i++) {
    EOQualifier *q;

    q = objAtIdx(qs, @selector(objectAtIndex:), i);

    if (![q evaluateWithObject:_object context:_context])
      return NO;
  }
  return YES;
}

@end /* EOAndQualifier(ContextEvaluation) */

@implementation EOOrQualifier(ContextEvaluation)

- (BOOL)evaluateWithObject:(id)_object context:(id)_context {
  unsigned i;
  IMP objAtIdx;
  NSArray *qs;

  qs       = [self qualifiers];
  objAtIdx = [qs methodForSelector:@selector(objectAtIndex:)];
  
  for (i = 0; i < [qs count]; i++) {
    EOQualifier *q;
    
    q = objAtIdx(qs, @selector(objectAtIndex:), i);
    
    if ([q evaluateWithObject:_object context:_context])
      return YES;
  }
  return NO;
}

@end /* EOOrQualifier(ContextEvaluation) */

@implementation EONotQualifier(ContextEvaluation)

- (BOOL)evaluateWithObject:(id)_object context:(id)_context {
  return
    [[self qualifier] evaluateWithObject:_object context:_context]
    ? NO : YES;
}

@end /* EONotQualifier(ContextEvaluation) */

@implementation EOKeyValueQualifier(ContextEvaluation)

- (BOOL)evaluateWithObject:(id)_object context:(id)_context {
  static EONull *null = nil;
  id lv, rv;
  union {
    IMP  m;
    BOOL (*unary)(id, SEL);
    BOOL (*binary)(id, SEL, id);
    BOOL (*ctx)(id, SEL, id, id);
  } m;
  SEL op;
  
  op = [self selector];
  lv = [_object valueForKeyPath:[self key]];
  rv = [self value];

  if (null == nil) null = [EONull null];
  if (lv == nil) lv = null;
  if (rv == nil) rv = null;
  
  if ((m.m = [lv methodForSelector:op]) == NULL) {
    /* no such operator method ! */
    [lv doesNotRecognizeSelector:op];
    return NO;
  }
  switch (countSelArgs(op)) {
    case 0:
    case 1:
      NSLog(@"%s: called with invalid selector %@", __PRETTY_FUNCTION__,
            NSStringFromSelector(op));
      return NO;
      
    case 2:
      return m.unary(lv, op);
    case 3:
      return m.binary(lv, op, rv);
    default:
      return m.ctx(lv, op, rv, _context);
  }
}

@end /* EOKeyValueQualifier(ContextEvaluation) */

@implementation EOKeyComparisonQualifier(ContextEvaluation)

- (BOOL)evaluateWithObject:(id)_object context:(id)_context {
  static EONull *null = nil;
  id lv, rv;
  union {
    IMP  m;
    BOOL (*unary)(id, SEL);
    BOOL (*binary)(id, SEL, id);
    BOOL (*ctx)(id, SEL, id, id);
  } m;
  SEL op;
  
  lv = [_object valueForKeyPath:[self leftKey]];
  rv = [_object valueForKeyPath:[self rightKey]];
  if (null == nil) null = [EONull null];
  if (lv == nil) lv = null;
  if (rv == nil) rv = null;

  op = [self selector];
  
  if ((m.m = (void *)[lv methodForSelector:op]) == NULL) {
    /* no such operator method ! */
    [lv doesNotRecognizeSelector:op];
    return NO;
  }
  switch (countSelArgs(op)) {
    case 0:
    case 1:
      NSLog(@"%s: called with invalid selector %@", __PRETTY_FUNCTION__,
            NSStringFromSelector(op));
      return NO;
      
    case 2:
      return m.unary(lv, op);
    case 3:
      return m.binary(lv, op, rv);
    default:
      return m.ctx(lv, op, rv, _context);
  }
}

@end /* EOKeyComparisonQualifier(ContextEvaluation) */

@implementation NSObject(ImplementedQualifierComparisons2)

- (BOOL)isEqualTo:(id)_object inContext:(id)_context {
  return [self isEqualTo:_object];
}
- (BOOL)isNotEqualTo:(id)_object inContext:(id)_context {
  return [self isNotEqualTo:_object];
}

- (BOOL)isLessThan:(id)_object inContext:(id)_context {
  return [self isLessThan:_object];
}
- (BOOL)isGreaterThan:(id)_object inContext:(id)_context {
  return [self isGreaterThan:_object];
}
- (BOOL)isLessThanOrEqualTo:(id)_object inContext:(id)_context {
  return [self isLessThanOrEqualTo:_object];
}
- (BOOL)isGreaterThanOrEqualTo:(id)_object inContext:(id)_context {
  return [self isGreaterThanOrEqualTo:_object];
}

- (BOOL)doesContain:(id)_object inContext:(id)_context {
  return [self doesContain:_object];
}

- (BOOL)isLike:(NSString *)_object inContext:(id)_context {
  return [self isLike:_object];
}
- (BOOL)isCaseInsensitiveLike:(NSString *)_object inContext:(id)_context {
  return [self isCaseInsensitiveLike:_object];
}

@end
