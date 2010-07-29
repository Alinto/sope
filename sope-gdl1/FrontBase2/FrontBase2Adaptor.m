/* 
   FBAdaptor.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge.hess@mdlink.de)

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
// $Id: FrontBase2Adaptor.m 1 2004-08-20 10:38:46Z znek $

#import "common.h"

NSString *FBNotificationName = @"FBNotification";

@interface FrontBase2Adaptor(FetchUserTypes)
- (void)_fetchUserTypes;
@end

@implementation FrontBase2Adaptor

+ (void)initialize {
  static BOOL isInitialized = NO;

  if (!isInitialized) {
    void __init_FBValues(void);
    isInitialized = YES;
    __init_FBValues();
  }
}

- (id)initWithName:(NSString *)_name {
  if ((self = [super initWithName:_name])) {
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  if (self->typeNameToCode) {
    NSFreeMapTable(self->typeNameToCode);
    self->typeCodeToName = NULL;
  }
  if (self->typeCodeToName) {
    NSFreeMapTable(self->typeCodeToName);
    self->typeCodeToName = NULL;
  }
  [super dealloc];
}
#endif

/* NSCopying methods */

- (id)copyWithZone:(NSZone *)_zone {
  // copy is needed during creation of NSNotification object
  return RETAIN(self); 
}

/* connections */

- (NSString *)serverName {
  NSString *serverName;

  serverName = [[self connectionDictionary] objectForKey:@"hostName"];

  return AUTORELEASE([serverName copy]);
}
- (NSString *)loginName {
  return AUTORELEASE([[[self connectionDictionary]
                             objectForKey:@"userName"] copy]);
}
- (NSString *)loginPassword {
  return AUTORELEASE([[[self connectionDictionary]
                             objectForKey:@"password"] copy]);
}
- (NSString *)databaseName {
  return AUTORELEASE([[[self connectionDictionary]
                             objectForKey:@"databaseName"] copy]);
}
- (NSString *)databasePassword {
  return AUTORELEASE([[[self connectionDictionary]
                             objectForKey:@"databasePassword"] copy]);
}

- (NSString *)transactionIsolationLevel {
  return AUTORELEASE([[[self connectionDictionary]
                             objectForKey:@"transactionIsolationLevel"] copy]);
}
- (NSString *)lockingDiscipline {
  return AUTORELEASE([[[self connectionDictionary]
                             objectForKey:@"lockingDiscipline"] copy]);
}

/* key generation */

- (NSString *)newKeyExpression {
  return AUTORELEASE([[[self pkeyGeneratorDictionary]
                             objectForKey:@"newKeyExpression"]
                             copy]);
}

/* formatting values */

- (NSString *)formatAttribute:(EOAttribute *)_attribute {
  return [NSString stringWithFormat:@"\"%s\"",
                     [[_attribute columnName] cString]];
}

- (NSString *)lowerExpressionForTextAttributeNamed:(NSString *)_attrName {
  return  [NSString stringWithFormat:@"LOWER(%@)", _attrName];
}

- (NSString *)expressionForTextValue:(id)_value {
  return [_value lowercaseString];
}

- (NSString *)charConvertExpressionForAttributeNamed:(NSString *)_attrName {
  return [NSString stringWithFormat:@"CAST(%@ AS VARCHAR(255))", _attrName];
}

- (id)formatValue:(id)value forAttribute:(EOAttribute *)attribute {
  int      fbType;
  NSString *result;

  fbType = [self typeCodeForExternalName:[attribute externalType]];
  result = [value stringValueForFrontBaseType:fbType
                  attribute:attribute];

#if 0
  NSLog(@"formatting value %@ result %@", value, result);
  NSLog(@"  value class %@ attr %@ attr type %@",
               [value class], attribute, [attribute externalType]);
#endif
  return result;
}

/* adaptor info */

- (Class)adaptorContextClass {
  return [FrontBaseContext class];
}
- (Class)adaptorChannelClass {
  return [FrontBaseChannel class];
}

- (Class)expressionClass {
  return [FBSQLExpression class];
}

@end /* FrontBase2Adaptor */
