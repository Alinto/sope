/* 
   SQLiteChannel+Model.m

   Copyright (C) 2003-2005 SKYRIX Software AG

   Author: Helge Hess (helge.hess@skyrix.com)

   This file is part of the SQLite Adaptor Library

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

#include "SQLiteChannel.h"
#include "NSString+SQLite.h"
#include "EOAttribute+SQLite.h"
#include "common.h"

@interface EORelationship(FixMe)
- (void)addJoin:(id)_join;
@end

@implementation SQLiteChannel(ModelFetching)

- (NSArray *)_attributesForTableName:(NSString *)_tableName {
  NSMutableArray *attributes;
  NSString       *sqlExpr;
  NSArray        *resultDescription;
  NSDictionary   *row;
  
  if ([_tableName length] == 0)
    return nil;
  
  attributes = [self->_attributesForTableName objectForKey:_tableName];
  if (attributes == nil) {
#if 1
    // TODO: we would need to parse the SQL field of 'sqlite_master'?
    NSLog(@"ERROR(%s): operation not supported on SQLite!",
	  __PRETTY_FUNCTION__);
    return nil;
#else
    sqlExpr = [NSString stringWithFormat:sqlExpr, _tableName];
#endif
  
    if (![self evaluateExpression:sqlExpr]) {
      fprintf(stderr,
              "Couldn`t evaluate column-describe '%s' on table '%s'\n",
              [sqlExpr cString], [_tableName cString]);
      return nil;
    }
  
    resultDescription = [self describeResults];
    attributes = [NSMutableArray arrayWithCapacity:16];
  
    while ((row = [self fetchAttributes:resultDescription withZone:NULL])) {
      EOAttribute *attribute;
      NSString    *columnName   = nil;
      NSString    *externalType = nil;
      NSString    *attrName     = nil;

      columnName   = [[row objectForKey:@"attname"] stringValue];
      attrName     = [columnName _sqlite3ModelMakeInstanceVarName];
      externalType = [[row objectForKey:@"typname"] stringValue];
    
      attribute = [[EOAttribute alloc] init];
      [attribute setColumnName:columnName];
      [attribute setName:attrName];
      [attribute setExternalType:externalType];
      [attribute loadValueClassForExternalSQLiteType:externalType];
      [attributes addObject:attribute];
      [attribute release];
    }
    [self->_attributesForTableName setObject:attributes forKey:_tableName];
    //NSLog(@"got attrs: %@", attributes);
  }
  return attributes;
}

- (NSArray *)_primaryKeysNamesForTableName:(NSString *)_tableName {
  //NSArray *pkNameForTableName = nil;

  if ([_tableName length] == 0)
    return nil;
  
  NSLog(@"ERROR(%s): operation not supported on SQLite!", __PRETTY_FUNCTION__);
  return nil;
}

- (NSArray *)_foreignKeysForTableName:(NSString *)_tableName {
  return nil;
}

- (EOModel *)describeModelWithTableNames:(NSArray *)_tableNames {
  // TODO: is this correct for SQLite?!
  NSMutableArray *buildRelShips;
  EOModel *model;
  int cnt, tc;

  buildRelShips = [NSMutableArray arrayWithCapacity:64];
  model = [[[EOModel alloc] init] autorelease];
  
  for (cnt = 0, tc = [_tableNames count]; cnt < tc; cnt++) {
    NSMutableDictionary *relNamesUsed;
    NSMutableArray      *classProperties, *primaryKeyAttributes;
    NSString *tableName;
    NSArray  *attributes, *pkeys, *fkeys;
    EOEntity *entity;
    int      cnt2, ac, fkc;
    
    relNamesUsed         = [NSMutableDictionary dictionaryWithCapacity:16];
    classProperties      = [NSMutableArray arrayWithCapacity:16];
    primaryKeyAttributes = [NSMutableArray arrayWithCapacity:2];
    tableName            = [_tableNames objectAtIndex:cnt];
    attributes           = [self _attributesForTableName:tableName];
    pkeys                = [self _primaryKeysNamesForTableName:tableName];
    fkeys                = [self _foreignKeysForTableName:tableName];
    entity               = [[[EOEntity alloc] init] autorelease];
    ac                   = [attributes count];
    fkc                  = [fkeys      count];

    [entity setName:[tableName _sqlite3ModelMakeClassName]];
    [entity setClassName:
              [@"EO" stringByAppendingString:
                  [tableName _sqlite3ModelMakeClassName]]];
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
      NSDictionary   *fkey;
      NSMutableArray *classProperties;
      NSString       *sa, *da, *dt;
      EORelationship *rel;
      EOJoin         *join; // TODO: fix me, EOJoin is deprecated
      NSString       *relName;
      
      fkey             = [fkeys objectAtIndex:cnt2];
      classProperties  = [NSMutableArray arrayWithCapacity:8];
      sa               = [fkey objectForKey:@"sourceAttr"];
      da               = [fkey objectForKey:@"targetAttr"];
      dt               = [fkey objectForKey:@"targetTable"];
      rel              = [[[EORelationship alloc] init] autorelease];

      // TODO: fix me
      join = [[[NSClassFromString(@"EOJoin") alloc] init] autorelease];

      if ([pkeys containsObject:sa]) {
        relName = [@"to" stringByAppendingString:
		      [dt _sqlite3ModelMakeClassName]];
      }
      else {
        relName = [@"to" stringByAppendingString:
                    [[sa _sqlite3ModelMakeInstanceVarName]
                         _sqlite3StringWithCapitalizedFirstChar]];
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
      //[rel setDestinationEntity:(EOEntity *)[dt _sqlite3ModelMakeClassName]];
      [rel setToMany:NO];

      // TODO: EOJoin is removed, fix this ...
      [(id)join setSourceAttribute:
	     (EOAttribute *)[sa _sqlite3ModelMakeInstanceVarName]];
      [(id)join setDestinationAttribute:
	     (EOAttribute *)[da _sqlite3ModelMakeInstanceVarName]];
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
                    [[[sa name] _sqlite3ModelMakeInstanceVarName]
                          _sqlite3StringWithCapitalizedFirstChar]];
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
  [model setAdaptorName:@"SQLite"];
  [model setAdaptorClassName:@"SQLiteAdaptor"];
  [model setConnectionDictionary:
           [[adaptorContext adaptor] connectionDictionary]];
  
  return model;
}

- (NSArray *)describeTableNames {
  NSMutableArray *tableNames        = nil;
  NSArray        *resultDescription = nil;
  NSString       *attributeName     = nil;
  NSDictionary   *row               = nil;
  NSString       *selectExpression  = nil;
  
  selectExpression = @"SELECT name FROM sqlite_master WHERE type='table'";
  if (![self evaluateExpression:selectExpression]) {
    fprintf(stderr, "Could not evaluate table-describe expression '%s'\n",
            [selectExpression cString]);
    return nil;
  }
  
  resultDescription = [self describeResults];
  attributeName = [(EOAttribute *)[resultDescription objectAtIndex:0] name];
  tableNames    = [NSMutableArray arrayWithCapacity:16];
  
  while ((row = [self fetchAttributes:resultDescription withZone:NULL])!=nil)
    [tableNames addObject:[row objectForKey:attributeName]];
  
  return tableNames;
}

@end /* SQLiteChannel(ModelFetching) */

void __link_SQLiteChannelModel() {
  // used to force linking of object file
  __link_SQLiteChannelModel();
}
