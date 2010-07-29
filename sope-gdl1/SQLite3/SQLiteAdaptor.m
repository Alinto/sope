/* 
   SQLiteAdaptor.m

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

#include "SQLiteAdaptor.h"
#include "SQLiteContext.h"
#include "SQLiteChannel.h"
#include "SQLiteExpression.h"
#include "SQLiteValues.h"
#include "common.h"

@implementation SQLiteAdaptor

- (NSDictionary *)connectionDictionaryForNSURL:(NSURL *)_url {
  /*
    "Database URLs"
    
    We use the schema:
      SQLite3://localhost/dbpath/foldername
  */
  NSMutableDictionary *md;
  NSString *p;
  
  if ((p = [_url path]) == nil)
    return nil;
  
  p = [p stringByDeletingLastPathComponent];
  if ([p length] == 0) p = [_url path];
  
  md = [NSMutableDictionary dictionaryWithCapacity:8];
  [md setObject:p forKey:@"databaseName"];
  return md;
}

- (id)initWithName:(NSString *)_name {
  if ((self = [super initWithName:_name])) {
  }
  return self;
}

/* NSCopying methods */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

// connections

- (NSString *)serverName {
  return @"localhost";
}
- (NSString *)loginName {
  return @"no-login-required";
}
- (NSString *)loginPassword {
  return @"no-pwd-required";
}
- (NSString *)databaseName {
  return [[[[self connectionDictionary]
                  objectForKey:@"databaseName"] copy] autorelease];
}

- (NSString *)port {
  return @"no-port-required";
}
- (NSString *)options {
  return [[[[self connectionDictionary]
                  objectForKey:@"options"] copy] autorelease];
}

/* sequence for primary key generation */

- (NSString *)primaryKeySequenceName {
  NSString *seqName;

  seqName =
    [[self pkeyGeneratorDictionary] objectForKey:@"primaryKeySequenceName"];
  return [[seqName copy] autorelease];
}

- (NSString *)newKeyExpression {
  NSString *newKeyExpr;
  
  newKeyExpr =
    [[self pkeyGeneratorDictionary] objectForKey:@"newKeyExpression"];
  return [[newKeyExpr copy] autorelease];
}

// formatting

- (NSString *)charConvertExpressionForAttributeNamed:(NSString *)_attrName {
  return _attrName;
}

- (id)formatValue:(id)value forAttribute:(EOAttribute *)attribute {
  NSString *result;
  
  result = [value stringValueForSQLite3Type:[attribute externalType]
                  attribute:attribute];

  //NSLog(@"formatting value %@ result %@", value, result);
  //NSLog(@"  value class %@ attr %@ attr type %@",
  //             [value class], attribute, [attribute externalType]);

  return result;
}

- (BOOL)attributeAllowedInDistinctSelects:(EOAttribute *)_attr {
  return YES;
}

/* types */

- (BOOL)isValidQualifierType:(NSString *)_typeName {
  return YES;
}

/* adaptor info */

- (Class)adaptorContextClass {
  return [SQLiteContext class];
}
- (Class)adaptorChannelClass {
  return [SQLiteChannel class];
}

- (Class)expressionClass {
  return [SQLiteExpression class];
}

@end /* SQLiteAdaptor */

void __linkSQLiteAdaptor(void) {
  extern void __link_EOAttributeSQLite();
  extern void __link_NSStringSQLite();
  extern void __link_SQLiteChannelModel();
  extern void __link_SQLiteValues();
  ;
  [SQLiteChannel    class];
  [SQLiteContext    class];
  [SQLiteException  class];
  [SQLiteExpression class];
  __link_EOAttributeSQLite();
  __link_NSStringSQLite();
  //__link_SQLiteChannelModel();
  __link_SQLiteValues();
  __linkSQLiteAdaptor();
}
