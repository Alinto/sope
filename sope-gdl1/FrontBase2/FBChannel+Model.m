/* 
   FBChannel+Model.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

   This file is part of the FB Adaptor Library

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
// $Id: FBChannel+Model.m 1 2004-08-20 10:38:46Z znek $

#import "common.h"
#import <GDLAccess/EOAccess.h>

@interface EORelationship(Private)
- (void)addJoin:(EOJoin *)_join;
@end

@implementation FrontBaseChannel(ModelFetching)

- (NSArray *)_attributesForTableName:(NSString *)_tableName {
  NSArray *attrForTableName = nil;
  
  if ((attrForTableName =
       [self->_attributesForTableName objectForKey:_tableName]) == nil) {
    NSMutableArray      *attributes        = nil;
    NSArray             *resultDescription = nil;
    NSString            *selectExpression  = nil;
    NSString            *columnNameKey     = nil;
    NSString            *externalTypeKey   = nil;
    NSDictionary        *row               = nil;
    unsigned            cnt                = 0;

    selectExpression = [NSString stringWithFormat:
      @"SELECT C1.\"COLUMN_NAME\", DTD1.\"DATA_TYPE\" FROM INFORMATION_SCHEMA."
      @"COLUMNS C1, INFORMATION_SCHEMA.TABLES T1, INFORMATION_SCHEMA.DATA_"
      @"TYPE_DESCRIPTOR DTD1 WHERE T1.\"TABLE_NAME\" = '%s' AND T1.\""
      @"TABLE_PK\" = DTD1.\"TABLE_OR_DOMAIN_PK\" AND C1.\"TABLE_PK\" = T1."
      @"\"TABLE_PK\" AND C1.\"COLUMN_PK\" = DTD1.\"COLUMN_NAME_PK\"",
                                 [[_tableName uppercaseString] cString]];
    
    if (![self evaluateExpression:selectExpression]) {
      fprintf(stderr, "Couldn`t evaluate expression %s\n",
              [selectExpression cString]);
      return nil;
    }
    resultDescription = [self describeResults];
    columnNameKey     = [(EOAttribute *)[resultDescription objectAtIndex:0] name];
    externalTypeKey   = [(EOAttribute *)[resultDescription objectAtIndex:1] name];
    attributes        = [NSMutableArray arrayWithCapacity:16];

    while ((row = [self fetchAttributes:resultDescription withZone:NULL])) {
      EOAttribute *attribute    = nil;
      NSString    *columnName   = nil;
      NSString    *externalType = nil;
      NSString    *attrName     = nil;
      int         fbType        = 0;

      attribute    = [[EOAttribute alloc] init];
      columnName   = [row objectForKey:columnNameKey];
      externalType = [row objectForKey:externalTypeKey];
      attrName     = [columnName _sybModelMakeInstanceVarName];
      fbType       = [(id)[adaptorContext adaptor]
                          typeCodeForExternalName:externalType];

      [attribute setName:attrName];
      [attribute setColumnName:columnName];
      [attribute loadValueClassAndTypeFromFrontBaseType:fbType];
      [attribute setExternalType:externalType];
    
      [attributes addObject:attribute];
      RELEASE(attribute); attribute = nil;
    }

    // fetch external types

    for (cnt = 0; cnt < [attributes count]; cnt++) {
      EOAttribute *attribute    = nil;
      NSString    *externalType = nil;
      int         fbType        = 0;

      attribute    = [attributes objectAtIndex:cnt];
      externalType = [attribute externalType];
      fbType       = [(id)[adaptorContext adaptor]
                          typeCodeForExternalName:externalType];
      [attribute loadValueClassAndTypeFromFrontBaseType:fbType];
      [attribute setExternalType:externalType];
    }
    attrForTableName = attributes;
    [self->_attributesForTableName setObject:attrForTableName forKey:_tableName];
  }
  return attrForTableName;
}

- (NSArray *)_primaryKeysNamesForTableName:(NSString *)_tableName {
  NSArray *pkNameForTable = nil;

  if (_tableName == nil)
    return nil;
  
  if ((pkNameForTable =
       [self->_primaryKeysNamesForTableName objectForKey:_tableName]) == nil) {
    NSMutableArray *primaryKeys       = nil;
    NSString       *selectExpression  = nil;
    NSArray        *resultDescription = nil;
    NSString       *columnNameKey     = nil;
    NSDictionary   *row               = nil;

    selectExpression = [NSString stringWithFormat:
      @"SELECT C1.\"COLUMN_NAME\" FROM INFORMATION_SCHEMA.COLUMNS C1, "
      @"INFORMATION_SCHEMA.TABLES T1, INFORMATION_SCHEMA.TABLE_CONSTRAINTS TC1, "
      @"INFORMATION_SCHEMA.KEY_COLUMN_USAGE KCU1 WHERE T1.\"TABLE_NAME\" = "
      @"'%s' AND TC1.\"TABLE_PK\" = T1.\"TABLE_PK\" AND TC1.\"CONSTRAINT"
      @"_TYPE\" = 'PRIMARY KEY' AND KCU1.\"TABLE_PK\" = T1.\"TABLE_PK\" AND "
      @"KCU1.\"CONSTRAINT_NAME_PK\" = TC1.\"CONSTRAINT_NAME_PK\" AND C1.\""
      @"COLUMN_PK\" = KCU1.\"COLUMN_PK\"",
                                 [[_tableName uppercaseString] cString]];
  
    if (![self evaluateExpression:selectExpression]) {
      fprintf(stderr, "Couldn`t evaluate expression %s\n",
              [selectExpression cString]);
      return nil;
    }
    resultDescription  = [self describeResults];
    columnNameKey      = [(EOAttribute *)[resultDescription objectAtIndex:0]
                                         name];
    primaryKeys        = [NSMutableArray arrayWithCapacity:4];
  
    while ((row = [self fetchAttributes:resultDescription withZone:NULL]))
      [primaryKeys addObject:[row objectForKey:columnNameKey]];

    pkNameForTable = primaryKeys;
    [self->_primaryKeysNamesForTableName setObject:pkNameForTable
                                         forKey:_tableName];
  }
  return pkNameForTable;
}

- (NSArray *)_foreignKeysForTableName:(NSString *)_tableName {
  return [NSArray array];
}

- (EOModel *)describeModelWithTableNames:(NSArray *)_tableNames {
  NSMutableArray *buildRelShips = nil;
  EOModel        *model         = nil;
  int            cnt            = 0;
  int            tc             = 0;

  buildRelShips = [NSMutableArray arrayWithCapacity:64];
  model         = [[EOModel alloc] init];
  tc            = [_tableNames count];
  AUTORELEASE(model);
  
  for (cnt = 0; cnt < tc; cnt++) {
    NSMutableDictionary *relNamesUsed         = nil;
    NSMutableArray      *classProperties      = nil;
    NSMutableArray      *primaryKeyAttributes = nil;
    NSString            *tableName            = nil;
    NSArray             *attributes           = nil;
    NSArray             *pkeys                = nil;
    NSArray             *fkeys                = nil;
    EOEntity            *entity               = nil;
    int                 cnt2                  = 0;
    int                 ac                    = 0;
    int                 fkc                   = 0;

    relNamesUsed         = [NSMutableDictionary dictionary];
    classProperties      = [NSMutableArray array];
    primaryKeyAttributes = [NSMutableArray array];
    tableName            = [_tableNames objectAtIndex:cnt];
    attributes           = [self _attributesForTableName:tableName];
    pkeys                = [self _primaryKeysNamesForTableName:tableName];
    fkeys                = [self _foreignKeysForTableName:tableName];
    entity               = [[EOEntity alloc] init];
    ac                   = [attributes count];
    fkc                  = [fkeys count];
    AUTORELEASE(entity);
    
    [entity setName:[tableName _sybModelMakeClassName]];
    [entity setClassName:
              [@"EO" stringByAppendingString:[tableName _sybModelMakeClassName]]];
    [entity setExternalName:tableName];
    [classProperties addObjectsFromArray:[entity classProperties]];
    [primaryKeyAttributes addObjectsFromArray:[entity primaryKeyAttributes]];
    [model addEntity:entity];
    
    for (cnt2 = 0; cnt2 < ac; cnt2++) {
      EOAttribute *attribute  = [attributes objectAtIndex:cnt2];
      NSString    *columnName = [attribute columnName];

      [entity addAttribute:attribute];
      [classProperties addObject:attribute];

      if ([pkeys containsObject:columnName])
        [primaryKeyAttributes addObject:attribute];
    }
    [entity setClassProperties:classProperties];
    [entity setPrimaryKeyAttributes:primaryKeyAttributes];
    
    for (cnt2 = 0; cnt2 < fkc; cnt2++) {
      NSDictionary   *fkey             = nil;
      NSMutableArray *classProperties  = nil;
      NSString       *sa               = nil;
      NSString       *da               = nil;
      NSString       *dt               = nil;
      EORelationship *rel              = nil;
      EOJoin         *join             = nil;
      NSString       *relName          = nil;

      fkey             = [fkeys objectAtIndex:cnt2];
      classProperties  = [NSMutableArray array];
      sa               = [fkey objectForKey:@"sourceAttr"];
      da               = [fkey objectForKey:@"targetAttr"];
      dt               = [fkey objectForKey:@"targetTable"];
      rel              = [[EORelationship alloc] init];
      join             = [[EOJoin alloc] init];
      AUTORELEASE(rel);
      AUTORELEASE((id)join);
      
      if ([pkeys containsObject:sa])
        relName = [@"to" stringByAppendingString:[dt _sybModelMakeClassName]];
      else {
        relName = [@"to" stringByAppendingString:
                    [[sa _sybModelMakeInstanceVarName]
                         _sybStringWithCapitalizedFirstChar]];
        if ([relName hasSuffix:@"Id"]) {
          int cLength = [relName cStringLength];

          relName = [relName substringToIndex:cLength - 2];
        }
      }
      if ([relNamesUsed objectForKey:relName]) {
        int useCount = [[relNamesUsed objectForKey:relName] intValue];
        
        [relNamesUsed setObject:[NSNumber numberWithInt:(useCount++)]
                      forKey:relName];
        relName = [NSString stringWithFormat:@"%s%d",
                              [relName cString], useCount];
      }
      else
        [relNamesUsed setObject:[NSNumber numberWithInt:0] forKey:relName];

      [rel setName:relName];
      //[rel setDestinationEntity:(EOEntity *)[dt _sybModelMakeClassName]];
      [rel setToMany:NO];

      [(id)join setSourceAttribute:
           (EOAttribute *)[sa _sybModelMakeInstanceVarName]];
      [(id)join setDestinationAttribute:
           (EOAttribute *)[da _sybModelMakeInstanceVarName]];
      [rel  addJoin:join];
      
      [entity addRelationship:rel];
      [classProperties addObjectsFromArray:[entity classProperties]];
      [classProperties addObject:rel];
      [entity setClassProperties:classProperties];
      [buildRelShips addObject:rel];
    }

    [entity setAttributesUsedForLocking:[[entity attributes] copy]];
  }

  [buildRelShips makeObjectsPerformSelector:@selector(replaceStringsWithObjects)];

  [model setAdaptorName:@"FrontBase2"];
  [model setAdaptorClassName:@"FrontBase2Adaptor"];
  [model setConnectionDictionary:[[adaptorContext adaptor] connectionDictionary]];
  return model;
}

- (NSArray *)describeTableNames {
  NSMutableArray *tableNames        = nil;
  NSArray        *resultDescription = nil;
  NSString       *attributeName     = nil;
  NSDictionary   *row               = nil;
  NSString       *selectExpression  = nil;

  selectExpression = @"SELECT T1.\"TABLE_NAME\" FROM "
                     @"INFORMATION_SCHEMA.TABLES T1";

  if (![self evaluateExpression:selectExpression]) {
    fprintf(stderr, "Couldn`t evaluate expression %s\n",
            [selectExpression cString]);
    return nil;
  }
  resultDescription = [self describeResults];
  attributeName     = [(EOAttribute *)[resultDescription objectAtIndex:0] name];
  tableNames        = [NSMutableArray arrayWithCapacity:16];

  while ((row = [self fetchAttributes:resultDescription withZone:NULL]))
    [tableNames addObject:[row objectForKey:attributeName]];
  
  return tableNames;
}

@end

void __link_FBChannelModel() {
  // used to force linking of object file
  __link_FBChannelModel();
}
