/*
  Copyright (C) 2005 SKYRIX Software AG
  
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

#include "NSAttributeDescription+EO.h"
#import <Foundation/NSComparisonPredicate.h>
#include "common.h"

@implementation NSAttributeDescription(EO)

- (unsigned)width {
  /* 
     This scans for a validation predicate checking for the maximum length. The
     code looks for:
     - an NSComparisonPredicate
     - which has the operator <=
     - and a keypath LHS with the keypath 'length'
     
     Note: only scans one level, does not walk NSCompoundPredicates
  */
  NSArray  *preds;
  unsigned i, count;
  
  if ((preds = [self validationPredicates]) == nil)
    return 0;
  
  if ((count = [preds count]) == 0)
    return 0;

  for (i = 0; i < count; i++) {
    NSComparisonPredicate *p;
    
    p = [preds objectAtIndex:i];
    if (![p isKindOfClass:[NSComparisonPredicate class]])
      continue;
    
    if ([p predicateOperatorType] != NSLessThanOrEqualToPredicateOperatorType)
      continue;
    
    if (![[[p leftExpression] keyPath] isEqualToString:@"length"])
      continue;
    
    /* found it! */
    return [[[p rightExpression] constantValue] unsignedIntValue];
  }
  return 0;
}

- (BOOL)allowsNull {
  return [self isOptional];
}

@end /* NSAttributeDescription(EO) */
