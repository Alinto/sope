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

#include "NSPredicate+EO.h"
#include "EOQualifier+CoreData.h"
#include "common.h"

@implementation NSPredicate(EOCoreData)

- (NSPredicate *)asPredicate {
  return self;
}
- (NSExpression *)asExpression {
  return nil;
}

@end /* NSPredicate(EOCoreData) */


@implementation NSCompoundPredicate(EOCoreData)

- (EOQualifier *)asQualifier {
  /* 
     Compound predicates join other predicates, they do not deal with
     expressions.
  */
  NSMutableArray *sq;
  NSArray     *sp;
  unsigned    i, count;
  Class       clazz;
  BOOL        isNot = NO;
  EOQualifier *q;
  
  sp    = [self subpredicates];
  count = [sp count];
  
  switch ([self compoundPredicateType]) {
  case NSNotPredicateType:
    isNot = YES;
    clazz = [EONotQualifier class];
    break;
  case NSAndPredicateType:
    clazz = [EOAndQualifier class];
    break;
  case NSOrPredicateType:
    clazz = [EOOrQualifier class];
    break;
  default:
    NSLog(@"ERROR(%s): unknown compound predicate type: %@",
	  __PRETTY_FUNCTION__, self);
    return nil;
  }
  
  if (count == 0)
    return [[[clazz alloc] init] autorelease];
  
  if (count == 1) {
    q = [sp objectAtIndex:0];
    return (isNot)
      ? [[[EONotQualifier alloc] initWithQualifier:q] autorelease]
      : q;
  }
  
  sq = [[NSMutableArray alloc] initWithCapacity:count];
  
  for (i = 0; i < count; i++) {
    q = [EOQualifier qualifierForPredicate:[sp objectAtIndex:i]];
    if (q == nil) {
      q = [sp objectAtIndex:i];
      NSLog(@"ERROR(%s): could not convert predicate to qualifier: %@",
	    __PRETTY_FUNCTION__, q);
    }

    if (isNot)
      q = [[EONotQualifier alloc] initWithQualifier:q];
    
    [sq addObject:q];
    if (isNot) [q release];

    q = nil;
  }
  
  q = [[(isNot ? [EOAndQualifier class] : clazz) alloc] initWithQualifier:q];
  [sq release];
  return [q autorelease];
}

@end /* NSCompoundPredicate(EOCoreData) */


@implementation NSComparisonPredicate(EOCoreData)

- (EOQualifier *)asQualifier {
  NSExpression *lhs, *rhs;
  
  lhs = [self leftExpression];
  rhs = [self rightExpression];
  
  // TODO: need to check predicate modifiers
  // TODO: add support for variables

  if ([rhs expressionType] == NSKeyPathExpressionType) {
    if ([lhs expressionType] == NSConstantValueExpressionType)
      return [EOKeyValueQualifier qualifierForComparisonPredicate:self];
    
    if ([lhs expressionType] == NSKeyPathExpressionType)
      return [EOKeyComparisonQualifier qualifierForComparisonPredicate:self];
  }
  
  NSLog(@"ERROR(%s): cannot map NSComparisonPredicate to EOQualifier: %@",
	__PRETTY_FUNCTION__, self);
  return (id)self;
}

/* key/value archiving */

- (id)initWithKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  int                           opt;
  NSPredicateOperatorType       ptype;
  NSComparisonPredicateModifier mod;
  NSExpression *left, *right;
  NSString     *selName, *s;
  
  /* left / right - TODO: need to check 'official' keys fo rthat */
  
  left = [_unarchiver decodeObjectForKey:@"left"];
  if (left != nil && ![left isKindOfClass:[NSExpression class]])
    left = [NSExpression expressionForConstantValue:left];
  
  right = [_unarchiver decodeObjectForKey:@"right"];
  if (right != nil && ![right isKindOfClass:[NSExpression class]])
    right = [NSExpression expressionForConstantValue:right];

  /* custom selector */
  
  if ((selName = [_unarchiver decodeObjectForKey:@"selectorName"]) != nil) {
    if (![selName hasSuffix:@":"]) 
      selName = [selName stringByAppendingString:@":"];
  }
  else
    selName = [_unarchiver decodeObjectForKey:@"selector"];
  if ([selName length] > 0) {
    return [self initWithLeftExpression:left rightExpression:right
		 customSelector:selName ? NSSelectorFromString(selName):NULL];
  }
  
  /* modifier */
  
  if ((s = [_unarchiver decodeObjectForKey:@"modifier"]) != nil) {
    if ([s isEqualToString:@"direct"])   mod = NSDirectPredicateModifier;
    else if ([s isEqualToString:@"all"]) mod = NSAllPredicateModifier;
    else if ([s isEqualToString:@"any"]) mod = NSAnyPredicateModifier;
    else {
      NSLog(@"WARNING(%s): could not decode modifier (trying int): %@!",
	    __PRETTY_FUNCTION__, s);
      mod = [s intValue];
    }
  }
  else
    mod = NSDirectPredicateModifier;
  
  /* type */

  if ((s = [_unarchiver decodeObjectForKey:@"type"]) != nil) {
    if ([s isEqualToString:@"<"]) 
      ptype = NSLessThanPredicateOperatorType;
    else if ([s isEqualToString:@"=<"]) 
      ptype = NSLessThanOrEqualToPredicateOperatorType;
    else if ([s isEqualToString:@">"]) 
      ptype = NSGreaterThanPredicateOperatorType;
    else if ([s isEqualToString:@">="]) 
      ptype = NSGreaterThanOrEqualToPredicateOperatorType;
    else if ([s isEqualToString:@"=="]) 
      ptype = NSEqualToPredicateOperatorType;
    else if ([s isEqualToString:@"!="]) 
      ptype = NSNotEqualToPredicateOperatorType;
    else if ([s isEqualToString:@"like"]) 
      ptype = NSLikePredicateOperatorType;
    else if ([s isEqualToString:@"contains"]) 
      ptype = NSInPredicateOperatorType;
    else if ([s isEqualToString:@"beginswith"]) 
      ptype = NSBeginsWithPredicateOperatorType;
    else if ([s isEqualToString:@"endswith"]) 
      ptype = NSEndsWithPredicateOperatorType;
    else if ([s isEqualToString:@"matches"]) 
      ptype = NSMatchesPredicateOperatorType;
    else {
      NSLog(@"WARNING(%s): could not decode type (trying int): %@!",
	    __PRETTY_FUNCTION__, s);
      ptype = [s intValue];
    }
  }
  else
    ptype = NSEqualToPredicateOperatorType;
  
  /* options */
  
  // TODO: use bit-compare and a set?
  if ((s = [_unarchiver decodeObjectForKey:@"options"]) != nil) {
    if ([s isEqualToString:@"caseInsensitive"]) 
      opt = NSCaseInsensitivePredicateOption;
    else if ([s isEqualToString:@"diacritic"]) 
      opt = NSDiacriticInsensitivePredicateOption;
    else {
      NSLog(@"WARNING(%s): could not decode options (trying int): %@!",
	    __PRETTY_FUNCTION__, s);
      opt = [s intValue];
    }
  }
  else
    opt = 0;

  /* create and return */
  
  return [self initWithLeftExpression:left rightExpression:right
	       modifier:mod type:ptype options:opt];
}

- (void)encodeWithKeyValueArchiver:(EOKeyValueArchiver *)_archiver {
  NSString *s;
  
  [_archiver encodeObject:[self leftExpression]  forKey:@"left"];
  [_archiver encodeObject:[self rightExpression] forKey:@"right"];

  /* type */

  switch ([self predicateOperatorType]) {
  case NSCustomSelectorPredicateOperatorType:
    [_archiver encodeObject:NSStringFromSelector([self customSelector])
	       forKey:@"selector"];
    return; /* no more info */

  case NSLessThanPredicateOperatorType:             s = @"<";        break;
  case NSLessThanOrEqualToPredicateOperatorType:    s = @"=<";       break;
  case NSGreaterThanPredicateOperatorType:          s = @">";        break;
  case NSGreaterThanOrEqualToPredicateOperatorType: s = @">=";       break;
  case NSEqualToPredicateOperatorType:              s = @"==";       break;
  case NSNotEqualToPredicateOperatorType:           s = @"!=";       break;
  case NSLikePredicateOperatorType:                 s = @"like";     break;
  case NSInPredicateOperatorType:                   s = @"contains"; break;
  case NSBeginsWithPredicateOperatorType:           s = @"beginswith"; break;
  case NSEndsWithPredicateOperatorType:             s = @"endswith"; break;
  case NSMatchesPredicateOperatorType:              s = @"matches";  break;
    
  default:
    s = [NSString stringWithFormat:@"%i", [self predicateOperatorType]]; 
    break;
  }
  if (s != nil) [_archiver encodeObject:s forKey:@"type"];
  
  /* modifier */
  
  switch ([self comparisonPredicateModifier]) {
  case NSDirectPredicateModifier: s = nil;    break;
  case NSAllPredicateModifier:    s = @"all"; break;
  case NSAnyPredicateModifier:    s = @"any"; break;
  default:
    s = [NSString stringWithFormat:@"%i", 
		  [self comparisonPredicateModifier]]; 
    break;
  }
  if (s != nil) [_archiver encodeObject:s forKey:@"modifier"];
  
  /* options */
  
  // TODO: use bit-compare and a set?
  
  if ([self options] == NSCaseInsensitivePredicateOption)
    [_archiver encodeObject:@"caseInsensitive" forKey:@"options"];
  else if ([self options] == NSDiacriticInsensitivePredicateOption)
    [_archiver encodeObject:@"diacritic" forKey:@"options"];
}

@end /* NSComparisonPredicate(EOCoreData) */
