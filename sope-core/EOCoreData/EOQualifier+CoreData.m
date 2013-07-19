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

/*
  CoreData / Foundation       EOF
    Predicates:
      NSComparisonPredicate   EOKeyValueQualifier / EOKeyComparisonQualifier
      NSCompoundPredicate     EOAndQualifier / EOOrQualifier / EONotQualifier

    NSExpressions:
      - constant
      - evaluatedObject
      - variable              EOQualifierVariable
      - keypath
      - function

  EOF operators:
    EOQualifierOperatorEqual;
    EOQualifierOperatorNotEqual;
    EOQualifierOperatorLessThan;
    EOQualifierOperatorGreaterThan;
    EOQualifierOperatorLessThanOrEqualTo;
    EOQualifierOperatorGreaterThanOrEqualTo;
    EOQualifierOperatorContains;
    EOQualifierOperatorLike;
    EOQualifierOperatorCaseInsensitiveLike;
*/

@implementation EOQualifier(CoreData)

+ (NSPredicateOperatorType)predicateOperatorTypeForEOSelector:(SEL)_sel {
  if (SEL_EQ(_sel, EOQualifierOperatorEqual))
    return NSEqualToPredicateOperatorType;
  if (SEL_EQ(_sel, EOQualifierOperatorNotEqual))
    return NSNotEqualToPredicateOperatorType;
  
  if (SEL_EQ(_sel, EOQualifierOperatorLessThan))
    return NSLessThanPredicateOperatorType;
  if (SEL_EQ(_sel, EOQualifierOperatorGreaterThan))
    return NSGreaterThanPredicateOperatorType;
  
  if (SEL_EQ(_sel, EOQualifierOperatorLessThanOrEqualTo))
    return NSLessThanOrEqualToPredicateOperatorType;
  if (SEL_EQ(_sel, EOQualifierOperatorGreaterThanOrEqualTo))
    return NSGreaterThanOrEqualToPredicateOperatorType;
  
  if (SEL_EQ(_sel, EOQualifierOperatorContains))
    return NSInPredicateOperatorType;
  
  if (SEL_EQ(_sel, EOQualifierOperatorLike) ||
      SEL_EQ(_sel, EOQualifierOperatorCaseInsensitiveLike))
    return NSLikePredicateOperatorType;
  
  return NSCustomSelectorPredicateOperatorType;
}

+ (SEL)eoSelectorForForComparisonPredicate:(NSComparisonPredicate *)_p {
  BOOL hasOpt;
  SEL  sel = NULL;
  
  if (_p == nil)
    return NULL;
  
  hasOpt = [_p options] != 0 ? YES : NO;
  
  // TODO: need to check options
  
  switch ([_p predicateOperatorType]) {
  case NSCustomSelectorPredicateOperatorType:
    sel = hasOpt ? NULL : [_p customSelector];
    break;
    
  case NSLessThanPredicateOperatorType:
    sel = hasOpt ? NULL : EOQualifierOperatorLessThan; break;
  case NSLessThanOrEqualToPredicateOperatorType:
    sel = hasOpt ? NULL : EOQualifierOperatorLessThanOrEqualTo; break;
  case NSGreaterThanPredicateOperatorType:
    sel = hasOpt ? NULL : EOQualifierOperatorGreaterThan; break;
  case NSGreaterThanOrEqualToPredicateOperatorType:
    sel = hasOpt ? NULL : EOQualifierOperatorGreaterThanOrEqualTo; break;
    
  case NSEqualToPredicateOperatorType:
    sel = hasOpt ? NULL : EOQualifierOperatorEqual; break;
  case NSNotEqualToPredicateOperatorType:
    sel = hasOpt ? NULL : EOQualifierOperatorNotEqual; break;
    
  case NSLikePredicateOperatorType:
    sel = ([_p options] == NSCaseInsensitivePredicateOption)
      ? EOQualifierOperatorCaseInsensitiveLike 
      : (hasOpt ? NULL : EOQualifierOperatorLike);
    break;
    
  case NSInPredicateOperatorType:
    // TODO: for arrays: containsObject:, for strings: containsString:
    sel = hasOpt ? NULL : EOQualifierOperatorContains; break;
    
  case NSBeginsWithPredicateOperatorType:
    sel = hasOpt ? NULL : @selector(hasPrefix:); break;
  case NSEndsWithPredicateOperatorType:
    sel = hasOpt ? NULL : @selector(hasSuffix:); break;
    
    /* unsupported predicates */
  case NSMatchesPredicateOperatorType:
    // TODO
  default:
    sel = NULL;
    break;
  }
  
  if (sel == NULL) {
    NSLog(@"ERROR(%s): cannot map NSComparisonPredicate to "
	  @"EOQualifier selector: %@",
	  __PRETTY_FUNCTION__, _p);
  }
  return sel;
}

- (NSPredicate *)predicateWithLeftExpression:(NSExpression *)_lhs
  rightExpression:(NSExpression *)_rhs
  eoSelector:(SEL)_selector
{
  // TODO: create non-custom predicate if possible
  NSComparisonPredicateModifier pmod;
  NSPredicateOperatorType       ptype;
  unsigned popts;

  if (_selector == NULL) {
    NSLog(@"ERROR(0x%p/%@): missing selector for predicate construction: %@",
	  self, NSStringFromClass([self class]), self);
    return nil;
  }
  
  ptype = [EOQualifier predicateOperatorTypeForEOSelector:_selector];
  
  if (ptype == NSCustomSelectorPredicateOperatorType) {
    return [NSComparisonPredicate predicateWithLeftExpression:_lhs
				  rightExpression:_rhs
				  customSelector:_selector];
  }
  
  pmod  = NSDirectPredicateModifier;
  popts = 0;
  
  if (SEL_EQ(_selector, EOQualifierOperatorCaseInsensitiveLike))
    popts = NSCaseInsensitivePredicateOption;
  
  return [NSComparisonPredicate predicateWithLeftExpression:_lhs
				rightExpression:_rhs
				modifier:pmod type:ptype options:popts];
}

+ (EOQualifier *)qualifierForPredicate:(NSPredicate *)_predicate {
  if (_predicate == nil)
    return nil;
  
  if ([_predicate respondsToSelector:@selector(asQualifier)])
    return [_predicate asQualifier];
  
  NSLog(@"ERROR(%s): cannot convert NSPredicate class %@!", 
	__PRETTY_FUNCTION__,
	NSStringFromClass([self class]));
  return nil;
}

- (EOQualifier *)asQualifier {
  return self;
}

- (NSPredicate *)asPredicate {
  NSLog(@"TODO(%s): implement me for class %@!", __PRETTY_FUNCTION__,
	NSStringFromClass([self class]));
  return nil;
}

- (NSExpression *)asExpression {
  return nil;
}


/* CoreData compatibility */

+ (NSPredicate *)andPredicateWithSubpredicates:(NSArray *)_sub {
  return [NSCompoundPredicate andPredicateWithSubpredicates:
				[_sub valueForKey:@"asPredicate"]];
}

+ (NSPredicate *)orPredicateWithSubpredicates:(NSArray *)_sub {
  return [NSCompoundPredicate orPredicateWithSubpredicates:
				[_sub valueForKey:@"asPredicate"]];
}

+ (NSPredicate *)notPredicateWithSubpredicate:(id)_predicate {
  return [NSCompoundPredicate notPredicateWithSubpredicate:
				[_predicate asPredicate]];
}

- (NSPredicate *)predicateWithSubstitutionVariables:(NSDictionary *)_vars {
  return [[self asPredicate] predicateWithSubstitutionVariables:_vars];
}

- (NSString *)predicateFormat {
  return [[self asPredicate] predicateFormat];
}

@end /* EOQualifier(CoreData) */
