/* 
   MySQL4Adaptor.m

   Copyright (C) 2003-2005 SKYRIX Software AG

   Author: Helge Hess (helge.hess@skyrix.com)

   This file is part of the MySQL4 Adaptor Library

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

#include "MySQL4Adaptor.h"
#include "MySQL4Context.h"
#include "MySQL4Channel.h"
#include "MySQL4Expression.h"
#include "MySQL4Values.h"
#include "common.h"

@implementation MySQL4Adaptor

- (id)initWithName:(NSString *)_name {
  if ((self = [super initWithName:_name])) {
  }
  return self;
}

/* NSCopying methods */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* connections */

- (NSString *)_copyOfConDictString:(NSString *)_key {
  return [[[[self connectionDictionary] objectForKey:_key] copy] autorelease];
}

- (NSString *)serverName {
  NSString *serverName;

  serverName = [[self connectionDictionary] objectForKey:@"hostName"];

#if 0 // do not default to something, to allow for sockets?
  if (serverName == nil)
    serverName = @"127.0.0.1";
#endif
  
  return [[serverName copy] autorelease];
}
- (NSString *)loginName {
  return [self _copyOfConDictString:@"userName"];
}
- (NSString *)loginPassword {
  return [self _copyOfConDictString:@"password"];
}
- (NSString *)databaseName {
  return [[[[self connectionDictionary]
                  objectForKey:@"databaseName"] copy] autorelease];
}

- (NSString *)port {
  return [self _copyOfConDictString:@"port"];
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

/* formatting */

- (NSString *)charConvertExpressionForAttributeNamed:(NSString *)_attrName {
  return _attrName;
}

- (id)formatValue:(id)value forAttribute:(EOAttribute *)attribute {
  NSString *result;
  
  result = [value stringValueForMySQL4Type:[attribute externalType]
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
  return [MySQL4Context class];
}
- (Class)adaptorChannelClass {
  return [MySQL4Channel class];
}

- (Class)expressionClass {
  return [MySQL4Expression class];
}

@end /* MySQL4Adaptor */

void __linkMySQL4Adaptor(void) {
  extern void __link_EOAttributeMySQL4();
  extern void __link_NSStringMySQL4();
  extern void __link_MySQL4ChannelModel();
  extern void __link_MySQL4Values();
  ;
  [MySQL4Channel    class];
  [MySQL4Context    class];
  [MySQL4Exception  class];
  [MySQL4Expression class];
  __link_EOAttributeMySQL4();
  __link_NSStringMySQL4();
  //__link_MySQL4ChannelModel();
  __link_MySQL4Values();
  __linkMySQL4Adaptor();
}
