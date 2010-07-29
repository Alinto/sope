/* 
   PostgreSQL72Adaptor.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess
   Copyright (C) 2000-2004 SKYRIX Software AG and Helge Hess

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

#include "common.h"
#include "PostgreSQL72Adaptor.h"
#include "PostgreSQL72Context.h"
#include "PostgreSQL72Channel.h"
#include "PostgreSQL72Expression.h"
#include "PostgreSQL72Values.h"
#include "PGConnection.h"

@implementation PostgreSQL72Adaptor

static BOOL debugOn = NO;

- (id)initWithName:(NSString *)_name {
  if ((self = [super initWithName:_name])) {
  }
  return self;
}

- (void)gcFinalize {
}

- (void)dealloc {
  //  NSLog(@"%s", __PRETTY_FUNCTION__);
  [self gcFinalize];
  [super dealloc];
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

  if (serverName == nil) { // lookup env-variable
    serverName = 
      [[[NSProcessInfo processInfo] environment] objectForKey:@"PGHOST"];
  }
  
  return [[serverName copy] autorelease];
}
- (NSString *)loginName {
  return [self _copyOfConDictString:@"userName"];
}
- (NSString *)loginPassword {
  return [self _copyOfConDictString:@"password"];
}
- (NSString *)databaseName {
  return [self _copyOfConDictString:@"databaseName"];
}

- (NSString *)port {
  return [self _copyOfConDictString:@"port"];
}
- (NSString *)options {
  return [self _copyOfConDictString:@"options"];
}
- (NSString *)tty {
  return [self _copyOfConDictString:@"tty"];
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
  /*
    This formats values into SQL constants, eg:
      @"blah" will be converted to 'blah'
  */
  NSString *result;
  
  result = [value stringValueForPostgreSQLType:[attribute externalType]
                  attribute:attribute];
  if (debugOn) {
    NSLog(@"formatting value '%@'(%@) result '%@'", 
	  value, NSStringFromClass([value class]), result);
    NSLog(@"  value class %@ attr %@ attr type %@",
	  [value class], attribute, [attribute externalType]);
  }
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
  return [PostgreSQL72Context class];
}
- (Class)adaptorChannelClass {
  return [PostgreSQL72Channel class];
}

- (Class)expressionClass {
  return [PostgreSQL72Expression class];
}

@end /* PostgreSQL72Adaptor */

void __linkPostgreSQL72Adaptor(void) {
  extern void __link_EOAttributePostgreSQL72();
  extern void __link_NSStringPostgreSQL72();
  extern void __link_PostgreSQL72ChannelModel();
  extern void __link_PostgreSQL72Values();
  ;
  [PostgreSQL72Channel    class];
  [PostgreSQL72Context    class];
  [PostgreSQL72Exception  class];
  [PostgreSQL72Expression class];
  __link_EOAttributePostgreSQL72();
  __link_NSStringPostgreSQL72();
  //__link_PostgreSQL72ChannelModel();
  __link_PostgreSQL72Values();
  __linkPostgreSQL72Adaptor();
}
