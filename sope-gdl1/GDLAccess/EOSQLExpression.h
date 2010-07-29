/* 
   EOSQLExpression.h

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: September 1996

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

#ifndef __EOSQLExpression_h__
#define __EOSQLExpression_h__

#import <Foundation/NSDictionary.h>
#import <Foundation/NSArray.h>

#include <GDLAccess/EOExpressionArray.h>
#include <GDLAccess/EOJoinTypes.h>

/*
  EOSQLExpression

  TODO: document
  
  Apparently the only object which implements EOExpressionContext?
*/

@class EOAdaptor, EOAdaptorChannel, EOEntity, EOSQLQualifier;

extern NSString *EOBindVariableNameKey;
extern NSString *EOBindVariablePlaceHolderKey;
extern NSString *EOBindVariableAttributeKey;
extern NSString *EOBindVariableValueKey;

@interface EOSQLExpression : NSObject <EOExpressionContext>
{
    EOEntity            *entity;
    EOAdaptor           *adaptor;
    NSMutableDictionary *entitiesAndPropertiesAliases;
    NSMutableArray      *fromListEntities;
    NSMutableString     *content;

    /* new in EOF2 */
    NSString            *whereClauseString;
    NSMutableString     *listString;
    NSMutableArray      *bindings;
}

/* Building SQL expressions */

+ (id)deleteExpressionWithQualifier:(EOSQLQualifier *)qualifier
  channel:(EOAdaptorChannel *)channel;
+ (id)insertExpressionForRow:(NSDictionary *)row
  entity:(EOEntity *)entity
  channel:(EOAdaptorChannel *)channel;
+ (id)selectExpressionForAttributes:(NSArray *)attributes
  lock:(BOOL)flag
  qualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder
  channel:(EOAdaptorChannel *)channel;
+ (id)updateExpressionForRow:(NSDictionary *)row
  qualifier:(EOSQLQualifier *)qualifier
  channel:(EOAdaptorChannel *)channel;

- (id)deleteExpressionWithQualifier:(EOSQLQualifier *)qualifier
  channel:(EOAdaptorChannel *)channel;
- (id)insertExpressionForRow:(NSDictionary *)row
  entity:(EOEntity *)entity
  channel:(EOAdaptorChannel *)channel;
- (id)selectExpressionForAttributes:(NSArray *)attributes
  lock:(BOOL)flag
  qualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder
  channel:(EOAdaptorChannel *)channel;
- (id)updateExpressionForRow:(NSDictionary *)row
  qualifier:(EOSQLQualifier *)qualifier
  channel:(EOAdaptorChannel *)channel;

/* factory classes */

+ (Class)selectExpressionClass;
+ (Class)insertExpressionClass;
+ (Class)deleteExpressionClass;
+ (Class)updateExpressionClass;

/* Getting the adaptor */
- (EOAdaptor *)adaptor;

// Private methods.

/* Creating components for the SELECT operation */
- (NSString *)selectListWithAttributes:(NSArray *)attributes
  qualifier:(EOSQLQualifier *)qualifier;
- (NSString *)fromClause;
- (NSString *)whereClauseForQualifier:(EOSQLQualifier *)qualifier;
- (NSString *)joinExpressionForRelationshipPaths:(NSArray *)relationshipPaths;
- (NSString *)lockClause;
- (NSString *)orderByClauseForFetchOrder:(NSArray *)fetchOrder;

/* Creating components for the UPDATE operation */
- (id)updateListForRow:(NSDictionary *)row;

/* Creating components for the INSERT operation */
- (id)columnListForRow:(NSDictionary *)row;
- (id)valueListForRow:(NSDictionary *)row;

/* Final initialization */
- (id)finishBuildingExpression;

/* Caching aliases */
- (NSArray *)relationshipPathsForAttributes:(NSArray *)attributes
  qualifier:(EOSQLQualifier *)qualifier
  fetchOrder:(NSArray *)fetchOrder;

/* Getting the entity */
- (EOEntity *)entity;

/* Getting the expression value of an attribute in a given context. This
   method is used by the expressionValueForAttribute: method. */
- (NSString *)expressionValueForAttribute:(EOAttribute *)attribute
  context:context;

@end

@class NSArray;
@class EOFetchSpecification, EOKeyComparisonQualifier, EOKeyValueQualifier;
@class EOQualifier;

@interface EOSQLExpression(NewInEOF2)

+ (EOSQLExpression *)selectStatementForAttributes:(NSArray *)_attributes
  lock:(BOOL)_flag
  fetchSpecification:(EOFetchSpecification *)_fspec
  entity:(EOEntity *)_entity;
+ (EOSQLExpression *)expressionForString:(NSString *)_sql;

/* accessors */

- (void)setStatement:(NSString *)_stmt;
- (NSString *)statement;
- (NSString *)whereClauseString;

/* tables */

- (NSString *)tableListWithRootEntity:(EOEntity *)_entity;

/* assembly */

- (NSString *)assembleDeleteStatementWithQualifier:(EOQualifier *)_qualifier
  tableList:(NSString *)_tableList
  whereClause:(NSString *)_whereClause;

- (NSString *)assembleInsertStatementWithRow:(NSDictionary *)_row
  tableList:(NSString *)_tables
  columnList:(NSString *)_columns
  valueList:(NSString *)_values;

- (NSString *)assembleSelectStatementWithAttributes:(NSArray *)_attributes
  lock:(BOOL)_lock
  qualifier:(EOQualifier *)_qualifier
  fetchOrder:(NSArray *)_fetchOrder
  selectString:(NSString *)_selectString
  columnList:(NSString *)_columns
  tableList:(NSString *)_tables
  whereClause:(NSString *)_whereClause
  joinClause:(NSString *)_joinClause
  orderByClause:(NSString *)_orderByClause
  lockClause:(NSString *)_lockClause;

- (NSString *)assembleUpdateStatementWithRow:(NSDictionary *)_row
  qualifier:(EOQualifier *)_qualifier
  tableList:(NSString *)_tables
  updateList:(NSString *)_updates
  whereClause:(NSString *)_whereClause;

- (NSString *)assembleJoinClauseWithLeftName:(NSString *)_leftName
  rightName:(NSString *)_rightName
  joinSemantic:(EOJoinSemantic)_semantic;

/* bind variables */

- (BOOL)mustUseBindVariableForAttribute:(EOAttribute *)_attr;
- (BOOL)shouldUseBindVariableForAttribute:(EOAttribute *)_attr;
+ (BOOL)useBindVariables;
- (NSMutableDictionary *)bindVariableDictionaryForAttribute:(EOAttribute *)_attr
  value:(id)_value;
- (void)addBindVariableDictionary:(NSMutableDictionary *)_dictionary;
- (NSArray *)bindVariableDictionaries;

/* values */

+ (NSString *)formatValue:(id)_value forAttribute:(EOAttribute *)_attribute;
- (NSString *)sqlStringForValue:(id)_value attributeNamed:(NSString *)_attrName;
+ (NSString *)sqlPatternFromShellPattern:(NSString *)_pattern;

/* attributes */

- (NSString *)sqlStringForAttribute:(EOAttribute *)_attribute;
- (NSString *)sqlStringForAttributePath:(NSString *)_attrPath;
- (NSString *)sqlStringForAttributeNamed:(NSString *)_attrName;

/* SQL formats */

+ (NSString *)formatSQLString:(NSString *)_sqlString format:(NSString *)_fmt;

/* qualifier operators */

- (NSString *)sqlStringForSelector:(SEL)_selector value:(id)_value;

/* qualifiers */

- (NSString *)sqlStringForKeyComparisonQualifier:(EOKeyComparisonQualifier *)_q;
- (NSString *)sqlStringForKeyValueQualifier:(EOKeyValueQualifier *)_q;
- (NSString *)sqlStringForNegatedQualifier:(EOQualifier *)_q;
- (NSString *)sqlStringForConjoinedQualifiers:(NSArray *)_qs;
- (NSString *)sqlStringForDisjoinedQualifiers:(NSArray *)_qs;

/* list strings */

- (NSMutableString *)listString;
- (void)appendItem:(NSString *)_itemString toListString:(NSMutableString *)_lstr;

/* deletes */

- (void)prepareDeleteExpressionForQualifier:(EOQualifier *)_qualifier;

/* updates */

- (void)addUpdateListAttribute:(EOAttribute *)_attr value:(NSString *)_value;

- (void)prepareUpdateExpressionWithRow:(NSDictionary *)_row
  qualifier:(EOQualifier *)_qualifier;

@end

/* Private subclasses used by EOSQLExpression. */

@interface EOSelectSQLExpression : EOSQLExpression
@end

@interface EOUpdateSQLExpression : EOSQLExpression
@end

@interface EOInsertSQLExpression : EOSQLExpression
@end

@interface EODeleteSQLExpression : EOSQLExpression
@end

#endif /* __EOSQLExpression_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
