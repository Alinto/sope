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

@implementation EOAndQualifier(CoreData)

- (NSCompoundPredicateType)compoundPredicateType {
  return NSAndPredicateType;
}

- (NSPredicate *)asPredicate {
  NSArray *tmp;
  
  tmp = [self subqualifiers];
  tmp = [tmp valueForKey:@"asPredicate"];
  return [NSCompoundPredicate andPredicateWithSubpredicates:tmp];
}

@end /* EOAndQualifier(CoreData) */


@implementation EOOrQualifier(CoreData)

- (NSCompoundPredicateType)compoundPredicateType {
  return NSOrPredicateType;
}

- (NSPredicate *)asPredicate {
  NSArray *tmp;
  
  tmp = [self subqualifiers];
  tmp = [tmp valueForKey:@"asPredicate"];
  return [NSCompoundPredicate orPredicateWithSubpredicates:tmp];
}

@end /* EOOrQualifier(CoreData) */


@implementation EONotQualifier(CoreData)

- (NSCompoundPredicateType)compoundPredicateType {
  return NSNotPredicateType;
}

- (NSPredicate *)asPredicate {
  return [NSCompoundPredicate notPredicateWithSubpredicate:
				[[self qualifier] asPredicate]];
}

@end /* EONotQualifier(CoreData) */
