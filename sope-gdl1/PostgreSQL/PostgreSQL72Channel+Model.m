/* 
   PostgreSQL72Channel+Model.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2008 SKYRIX Software AG and Helge Hess

   Author: Helge Hess (helge.hess@opengroupware.org)
   
   This file is part of the PostgreSQL72 Adaptor Library

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

#include "PostgreSQL72Channel.h"
#include "NSString+PostgreSQL72.h"
#include "EOAttribute+PostgreSQL72.h"
#import "common.h"

@interface EORelationship(FixMe)
- (void)addJoin:(id)_join;
@end

@implementation PostgreSQL72Channel(ModelFetching)

static BOOL debugOn = NO;

- (NSArray *)_attributesForTableName:(NSString *)_tableName {
  NSMutableArray *attributes;
  NSString       *sqlExpr;
  NSArray        *resultDescription;
  NSDictionary   *row;
  
  if (![_tableName length])
    return nil;
  
  attributes = [self->_attributesForTableName objectForKey:_tableName];
  if (attributes != nil)
    return attributes;

  sqlExpr = 
    @"SELECT a.attnum, a.attname, t.typname, a.attlen, a.attnotnull "
    @"FROM pg_class c, pg_attribute a, pg_type t "
    @"WHERE c.relname='%@' AND a.attnum>0 AND a.attrelid=c.oid AND "
    @"a.atttypid=t.oid "
    @"ORDER BY attnum;";
  sqlExpr = [NSString stringWithFormat:sqlExpr, _tableName];
  
  if (![self evaluateExpression:sqlExpr]) {
    fprintf(stderr,
	    "Could not evaluate column-describe '%s' on table '%s'\n",
	    [sqlExpr UTF8String], [_tableName UTF8String]);
    return nil;
  }
  
  resultDescription = [self describeResults];
  attributes = [NSMutableArray arrayWithCapacity:16];
  
  while ((row = [self fetchAttributes:resultDescription withZone:NULL])) {
      EOAttribute *attribute;
      NSString    *columnName, *externalType, *attrName;
      
      columnName   = [[row objectForKey:@"attname"] stringValue];
      attrName     = [columnName _pgModelMakeInstanceVarName];
      externalType = [[row objectForKey:@"typname"] stringValue];
    
      attribute = [[EOAttribute alloc] init];
      [attribute setColumnName:columnName];
      [attribute setName:attrName];
      [attribute setExternalType:externalType];
      [attribute loadValueClassForExternalPostgreSQLType:externalType];
      [attributes addObject:attribute];
      [attribute release]; attribute = nil;
  }
  [self->_attributesForTableName setObject:attributes forKey:_tableName];
  if (debugOn) NSLog(@"%s: got attrs: %@", __PRETTY_FUNCTION__, attributes);
  return attributes;
}

- (NSArray *)_primaryKeysNamesForTableName:(NSString *)_tableName {
  NSArray *pkNameForTableName = nil;
  NSMutableArray *primaryKeys       = nil;
  NSString       *selectExpression;
  NSArray        *resultDescription = nil;
  NSString       *columnNameKey     = nil;
  NSDictionary   *row               = nil;
  
  if ([_tableName length] == 0)
    return nil;

  pkNameForTableName =
    [self->_primaryKeysNamesForTableName objectForKey:_tableName];
  
  if (pkNameForTableName != nil)
    return pkNameForTableName;
  
  selectExpression = [NSString stringWithFormat:
                                 @"SELECT attname FROM pg_attribute WHERE "
                                 @"attrelid IN (SELECT a.indexrelid FROM "
                                 @"pg_index a, pg_class b WHERE "
                                 @"a.indexrelid = b.oid AND "
                                 @"b.relname in (SELECT indexname FROM "
                                 @"pg_indexes WHERE "
                                 @"tablename = '%@') "
                                 @"AND a.indisprimary)", _tableName];

  if (![self evaluateExpression:selectExpression])
    return nil;
    
  resultDescription = [self describeResults];
  columnNameKey = [(EOAttribute *)[resultDescription objectAtIndex:0] name];
  primaryKeys   = [NSMutableArray arrayWithCapacity:4];
    
  while ((row = [self fetchAttributes:resultDescription withZone:NULL]))
    [primaryKeys addObject:[row objectForKey:columnNameKey]];

  pkNameForTableName = primaryKeys;
  [self->_primaryKeysNamesForTableName setObject:pkNameForTableName
                                       forKey:_tableName];
  return pkNameForTableName;
}

- (NSArray *)_foreignKeysForTableName:(NSString *)_tableName {
  return nil;
}

- (EOModel *)describeModelWithTableNames:(NSArray *)_tableNames {
  NSMutableArray *buildRelShips = [NSMutableArray arrayWithCapacity:64];
  EOModel *model = AUTORELEASE([EOModel new]);
  int cnt, tc = [_tableNames count];

  for (cnt = 0; cnt < tc; cnt++) {
    NSMutableDictionary *relNamesUsed;
    NSMutableArray      *classProperties;
    NSMutableArray      *primaryKeyAttributes;
    NSString *tableName;
    NSArray  *attributes;
    NSArray  *pkeys;
    NSArray  *fkeys;
    EOEntity *entity;
    int      cnt2, ac, fkc;
    
    relNamesUsed         = [NSMutableDictionary dictionaryWithCapacity:4];
    classProperties      = [NSMutableArray arrayWithCapacity:16];
    primaryKeyAttributes = [NSMutableArray arrayWithCapacity:2];
    
    tableName  = [_tableNames objectAtIndex:cnt];
    attributes = [self _attributesForTableName:tableName];
    pkeys      = [self _primaryKeysNamesForTableName:tableName];
    fkeys      = [self _foreignKeysForTableName:tableName];
    entity     = [[EOEntity new] autorelease];
    ac         = [attributes count];
    fkc        = [fkeys      count];
    
    [entity setName:[tableName _pgModelMakeClassName]];
    [entity setClassName:
              [@"EO" stringByAppendingString:
		  [tableName _pgModelMakeClassName]]];
    [entity setExternalName:tableName];
    [classProperties addObjectsFromArray:[entity classProperties]];
    [primaryKeyAttributes addObjectsFromArray:[entity primaryKeyAttributes]];
    [model addEntity:entity];

    for (cnt2 = 0; cnt2 < ac; cnt2++) {
      EOAttribute *attribute  = [attributes objectAtIndex:cnt2];
      NSString    *columnName = [attribute columnName];

      attribute  = [attributes objectAtIndex:cnt2];
      columnName = [attribute columnName];
      
      [entity addAttribute:attribute];
      [classProperties addObject:attribute];

      if ([pkeys containsObject:columnName])
        [primaryKeyAttributes addObject:attribute];
    }
    [entity setClassProperties:classProperties];
    [entity setPrimaryKeyAttributes:primaryKeyAttributes];
    
    for (cnt2 = 0; cnt2 < fkc; cnt2++) {
      NSDictionary   *fkey;
      NSMutableArray *classProperties;
      NSString       *sa, *da, *dt;
      EORelationship *rel;
      EOJoin         *join;
      NSString       *relName = nil;
      
      fkey             = [fkeys objectAtIndex:cnt2];
      classProperties  = [NSMutableArray arrayWithCapacity:16];
      sa               = [fkey objectForKey:@"sourceAttr"];
      da               = [fkey objectForKey:@"targetAttr"];
      dt               = [fkey objectForKey:@"targetTable"];
      rel              = [[[EORelationship alloc] init] autorelease];

      // TODO: do something about the join (just use rel?)
      join = [[[NSClassFromString(@"EOJoin") alloc] init] autorelease];
      
      if ([pkeys containsObject:sa])
        relName = [@"to" stringByAppendingString:[dt _pgModelMakeClassName]];
      else {
        relName = [@"to" stringByAppendingString:
                    [[sa _pgModelMakeInstanceVarName]
                         _pgStringWithCapitalizedFirstChar]];
        if ([relName hasSuffix:@"Id"])
          relName = [relName substringToIndex:([relName length] - 2)];
      }
      if ([relNamesUsed objectForKey:relName] != nil) {
        int useCount = [[relNamesUsed objectForKey:relName] intValue];
        
        [relNamesUsed setObject:[NSNumber numberWithInt:(useCount++)] 
		      forKey:relName];
        relName = [NSString stringWithFormat:@"%@%d", relName, useCount];
      }
      else
        [relNamesUsed setObject:[NSNumber numberWithInt:0] forKey:relName];
      
      [rel setName:relName];
      //[rel setDestinationEntity:(EOEntity *)[dt _pgModelMakeClassName]];
      [rel setToMany:NO];

      // TODO: EOJoin is removed, fix this ...
      [(id)join setSourceAttribute:
	     (EOAttribute *)[sa _pgModelMakeInstanceVarName]];
      [(id)join setDestinationAttribute:
	     (EOAttribute *)[da _pgModelMakeInstanceVarName]];
      [rel addJoin:join];
      
      [entity addRelationship:rel];
      [classProperties addObjectsFromArray:[entity classProperties]];
      [classProperties addObject:rel];
      [entity setClassProperties:classProperties];
      [buildRelShips addObject:rel];
    }

    [entity setAttributesUsedForLocking:[entity attributes]];
  }

  [buildRelShips makeObjectsPerformSelector:
                   @selector(replaceStringsWithObjects)];
  /*
  // make reverse relations
  {
    int cnt, rc = [buildRelShips count];

    for (cnt = 0; cnt < rc; cnt++) {
      EORelationship *rel     = [buildRelShips objectAtIndex:cnt];
      NSMutableArray *classProperties  = [NSMutableArray new];   
      EORelationship *reverse = [rel reversedRelationShip];
      EOEntity       *entity  = [rel destinationEntity];
      NSArray        *pkeys   = [entity primaryKeyAttributes];
      BOOL           isToMany = [reverse isToMany];
      EOAttribute    *sa      = [[[reverse joins] lastObject] sourceAttribute];
      NSString       *relName = nil;

      if ([pkeys containsObject:sa]
          || isToMany)
        relName = [@"to" stringByAppendingString:
                    [(EOEntity *)[reverse destinationEntity] name]];
      else {
        relName = [@"to" stringByAppendingString:
                    [[[sa name] _pgModelMakeInstanceVarName]
                          _pgStringWithCapitalizedFirstChar]];
        if ([relName hasSuffix:@"Id"]) {
          int cLength = [relName cStringLength];

          relName = [relName substringToIndex:cLength - 2];
        }
      }

      if ([entity relationshipNamed:relName]) {
        int cnt = 1;
        NSString *numName;

        numName = [NSString stringWithFormat:@"%s%d", [relName cString], cnt];
        while ([entity relationshipNamed:numName]) {
          cnt++;
          numName = [NSString stringWithFormat:@"%s%d", [relName cString], cnt];
        }

        relName = numName;
      }

      [reverse setName:relName];

      [entity addRelationship:reverse];
      
      [classProperties addObjectsFromArray:[entity classProperties]];
      [classProperties addObject:reverse];
      [entity setClassProperties:classProperties];
    }
  }
  */
  [model setAdaptorName:@"PostgreSQL72"];
  [model setAdaptorClassName:@"PostgreSQL72Adaptor"];
  [model setConnectionDictionary:
           [[adaptorContext adaptor] connectionDictionary]];
  
  return model;
}

- (NSArray *)_runSingleColumnQuery:(NSString *)_query {
  NSMutableArray *names;
  NSArray        *resultDescription;
  NSString       *attributeName;
  NSDictionary   *row;
  
  if (![self evaluateExpression:_query]) {
    fprintf(stderr, "Could not evaluate expression: '%s'\n",
#if LIB_FOUNDATION_LIBRARY
	    [_query cString]
#else
	    [_query UTF8String]
#endif
	    );
    return nil;
  }
  
  resultDescription = [self describeResults];
  attributeName    = [(EOAttribute *)[resultDescription objectAtIndex:0] name];
  names            = [NSMutableArray arrayWithCapacity:16];
  
  while ((row = [self fetchAttributes:resultDescription withZone:NULL]))
    [names addObject:[row objectForKey:attributeName]];
  
  return names;
}

- (NSArray *)describeTableNames {
  NSString *sql;
  
  sql = 
    @"SELECT relname "
    @"FROM pg_class "
    @"WHERE (relkind='r') AND (relname !~ '^pg_') AND "
    @"(relname !~ '^xinv[0-9]+') "
    @"ORDER BY relname";
  return [self _runSingleColumnQuery:sql];
}

- (NSArray *)describeDatabaseNames {
  return [self _runSingleColumnQuery:
		 @"SELECT datname FROM pg_database ORDER BY datname"];
}

- (NSArray *)describeUserNames {
  return [self _runSingleColumnQuery:@"SELECT usename FROM pg_user"];
}

@end /* PostgreSQL72Channel(ModelFetching) */

void __link_PostgreSQL72ChannelModel() {
  // used to force linking of object file
  __link_PostgreSQL72ChannelModel();
}
