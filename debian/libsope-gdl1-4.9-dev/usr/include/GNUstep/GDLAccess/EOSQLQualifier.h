/* 
   EOSQLQualifier.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
           Helge Hess <helge.hess@mdlink.de>
   Date:   September 1996
           November 1999

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#ifndef __EOSQLQualifier_h__
#define __EOSQLQualifier_h__

#import <EOControl/EOQualifier.h>

#import <GDLAccess/EOExpressionArray.h>

/*
  EOSQLQualifier
  
  TODO: document

  Note: the expression context is the EOSQLExpression.
*/

@class NSDictionary, NSString, NSMutableSet;
@class EOEntity, EORelationship, EOExpressionArray, EOSQLQualifier;
@class EOSQLExpression;

@protocol EOQualifierSQLGeneration

- (NSString *)sqlStringForSQLExpression:(EOSQLExpression *)_sqlExpr;
- (EOQualifier *)schemaBasedQualifierWithRootEntity:(EOEntity *)_entity;

@end

@interface EOSQLQualifier : EOQualifier < NSCopying >
{
    /* TODO: these should be GCMutableSet */
    NSMutableSet *relationshipPaths;
    NSMutableSet *additionalEntities;

    /* Garbage collectable objects */
    EOEntity          *entity;
    EOExpressionArray *content;
    BOOL usesDistinct;
}

/* Combining qualifiers */
- (void)negate;
- (void)conjoinWithQualifier:(EOSQLQualifier*)qualifier;
- (void)disjoinWithQualifier:(EOSQLQualifier*)qualifier;

/* Getting the entity */
- (EOEntity *)entity;

/* Checking the definition */
- (BOOL)isEmpty;

/* Accessing the distinct selection */
- (void)setUsesDistinct:(BOOL)flag;
- (BOOL)usesDistinct;

/* Accessing the relationships referred within qualifier */
- (NSMutableSet*)relationshipPaths;
- (NSMutableSet*)additionalEntities;

/* Getting the expression value */
- (NSString*)expressionValueForContext:(id<EOExpressionContext>)ctx;

/* Private methods */
- (void)_computeRelationshipPaths:(NSArray *)_relationshipPaths;
- (void)_computeRelationshipPaths;

- (EOSQLQualifier *)sqlQualifierForEntity:(EOEntity *)_entity;

@end

@interface EOSQLQualifier(QualifierCreation)

- (id)initWithEntity:(EOEntity *)_entity 
  qualifierFormat:(NSString *)_qualifierFormat, ...;

- (id)initWithEntity:(EOEntity *)_entity 
  qualifierFormat:(NSString *)_qualifierFormat
  argumentsArray:(NSArray *)_args;

/* Creating instances */

+ (EOSQLQualifier *)qualifierForRow:(NSDictionary *)row
  entity:(EOEntity *)entity;

+ (EOSQLQualifier *)qualifierForPrimaryKey:(NSDictionary *)key
  entity:(EOEntity *)entity;

+ (EOSQLQualifier *)qualifierForRow:(NSDictionary *)row 
  relationship:(EORelationship *)relationship;

+ (EOSQLQualifier *)qualifierForObject:(id)sourceObject 
  relationship:(EORelationship *)relationship;

@end

@interface EOQualifier(SQLQualifier)
- (EOSQLQualifier *)sqlQualifierForEntity:(EOEntity *)_entity;
@end

@interface EOAndQualifier(SQLGeneration) < EOQualifierSQLGeneration >
@end

@interface EOOrQualifier(SQLGeneration) < EOQualifierSQLGeneration >
@end

@interface EONotQualifier(SQLGeneration) < EOQualifierSQLGeneration >
@end

@interface EOKeyValueQualifier(SQLGeneration) < EOQualifierSQLGeneration >
@end

@interface EOKeyComparisonQualifier(SQLGeneration) < EOQualifierSQLGeneration >
@end

#endif /* __EOSQLQualifier_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
