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

#include "EOQualifier+CoreData.h"
#include "NSPredicate+EO.h"
#include "NSExpression+EO.h"
#include "common.h"

@implementation EOKeyValueQualifier(CoreData)

+ (EOQualifier *)qualifierForComparisonPredicate:(NSComparisonPredicate *)_p {
  SEL sel;

  if ((sel = [self eoSelectorForForComparisonPredicate:_p]) == nil)
    return (EOQualifier *)_p;
  
  return [[[self alloc] initWithKey:[[_p leftExpression] keyPath]
			operatorSelector:sel
			value:[[_p rightExpression] constantValue]] 
	                autorelease];
}

- (NSPredicate *)asPredicate {
  /*
    EOKeyValueQualifier has a key/value path expression on the left side
    and a constant value expression on the right side.
  */
  NSExpression *lhs, *rhs;
  id tmp;
  
  tmp = [self key];
  lhs = [tmp isKindOfClass:[EOQualifierVariable class]]
    ? [NSExpression expressionForVariable:[(EOQualifierVariable *)tmp key]]
    : [NSExpression expressionForKeyPath:tmp];
  
  tmp = [self value];
  rhs = [tmp isKindOfClass:[EOQualifierVariable class]]
    ? [NSExpression expressionForVariable:[(EOQualifierVariable *)tmp key]]
    : [NSExpression expressionForConstantValue:tmp];
  
  return [self predicateWithLeftExpression:lhs rightExpression:rhs
	       eoSelector:[self selector]];
}

/* CoreData compatibility */

- (NSComparisonPredicateModifier)comparisonPredicateModifier {
  return NSDirectPredicateModifier;
}

- (NSPredicateOperatorType)predicateOperatorType {
  return [[self class] predicateOperatorTypeForEOSelector:[self selector]];
}

- (unsigned)options {
  return (SEL_EQ([self selector], EOQualifierOperatorCaseInsensitiveLike))
    ? NSCaseInsensitivePredicateOption : 0;
}

- (SEL)customSelector {
  return [self predicateOperatorType] == NSCustomSelectorPredicateOperatorType
    ? [self selector] : nil;
}

@end /* EOKeyValueQualifier(CoreData) */
