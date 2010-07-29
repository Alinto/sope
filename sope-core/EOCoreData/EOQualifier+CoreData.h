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

#ifndef __EOQualifier_CoreData_H__
#define __EOQualifier_CoreData_H__

#import <Foundation/NSPredicate.h>
#import <Foundation/NSComparisonPredicate.h>
#include <EOControl/EOQualifier.h>

/*
  EOQualifier(CoreData)
  
  Convert an libEOControl EOQualifier to a CoreData compliant NSPredicate
  object.
*/

@class NSArray;
@class NSPredicate, NSExpression, NSComparisonPredicate, NSCompoundPredicate;

@interface EOQualifier(CoreData)

+ (EOQualifier *)qualifierForPredicate:(NSPredicate *)_predicate;
- (NSPredicate *)asPredicate;
- (NSExpression *)asExpression;

/* support methods */

+ (SEL)eoSelectorForForComparisonPredicate:(NSComparisonPredicate *)_p;
+ (NSPredicateOperatorType)predicateOperatorTypeForEOSelector:(SEL)_sel;

- (NSPredicate *)predicateWithLeftExpression:(NSExpression *)_lhs
  rightExpression:(NSExpression *)_rhs
  eoSelector:(SEL)_selector;

/* CoreData compatibility */

+ (NSPredicate *)andPredicateWithSubpredicates:(NSArray *)_sub;
+ (NSPredicate *)orPredicateWithSubpredicates:(NSArray *)_sub;
+ (NSPredicate *)notPredicateWithSubpredicate:(id)_predicate;

@end

#import <Foundation/Foundation.h>


/* compound qualifiers */

@interface EOAndQualifier(CoreData)
- (NSCompoundPredicateType)compoundPredicateType;
@end

@interface EOOrQualifier(CoreData)
- (NSCompoundPredicateType)compoundPredicateType;
@end

@interface EONotQualifier(CoreData)
- (NSCompoundPredicateType)compoundPredicateType;
@end


/* comparison qualifiers */

@interface EOKeyValueQualifier(CoreData)
+ (EOQualifier *)qualifierForComparisonPredicate:(NSComparisonPredicate *)_p;
- (NSComparisonPredicateModifier)comparisonPredicateModifier;
- (NSPredicateOperatorType)predicateOperatorType;
- (SEL)customSelector;
- (unsigned)options;
@end

@interface EOKeyComparisonQualifier(CoreData)
+ (EOQualifier *)qualifierForComparisonPredicate:(NSComparisonPredicate *)_p;
- (NSComparisonPredicateModifier)comparisonPredicateModifier;
- (NSPredicateOperatorType)predicateOperatorType;
- (SEL)customSelector;
- (unsigned)options;
@end

#endif /* __EOQualifier_CoreData_H__ */
