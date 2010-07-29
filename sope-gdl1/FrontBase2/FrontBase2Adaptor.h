/* 
   FBAdaptor.h

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
// $Id: FrontBase2Adaptor.h 1 2004-08-20 10:38:46Z znek $

#ifndef ___FB_Adaptor_H___
#define ___FB_Adaptor_H___

/*
  The FB adaptor.

  The connection dictionary of this adaptor understands these keys:
    hostName
    userName
    password
    databaseName
    databasePassword
    transactionIsolationLevel
    lockingDiscipline
*/

#import <Foundation/NSMapTable.h>
#import <GDLAccess/EOAdaptor.h>
#import <GDLAccess/EOAttribute.h>
#import "FBHeaders.h"

@class NSString, NSMutableDictionary;
@class FrontBaseChannel;

extern NSString *FBNotificationName;

@interface FrontBase2Adaptor : EOAdaptor
{
@private
  NSMapTable *typeNameToCode;
  NSMapTable *typeCodeToName;
}

- (id)initWithName:(NSString *)_name;

/* connection management */

- (NSString *)serverName;
- (NSString *)loginName;
- (NSString *)loginPassword;
- (NSString *)databaseName;
- (NSString *)databasePassword;
- (NSString *)transactionIsolationLevel;
- (NSString *)lockingDiscipline;

/* key generation */

- (NSString *)newKeyExpression;

/* value formatting */

- (id)formatValue:(id)value forAttribute:(EOAttribute *)attribute;

/* classes used */

- (Class)adaptorContextClass; // FrontBaseContext
- (Class)adaptorChannelClass; // FrontBaseChannel
- (Class)expressionClass;     // FBSQLExpression

@end

@interface FrontBase2Adaptor(ExternalTyping)

- (int)typeCodeForExternalName:(NSString *)_typeName;
- (NSString *)externalNameForTypeCode:(int)_typeCode;

- (BOOL)isInternalBlobType:(int)_type;
- (BOOL)isBlobAttribute:(EOAttribute *)_attr;
- (BOOL)isValidQualifierType:(NSString *)_typeName;
- (BOOL)attributeAllowedInDistinctSelects:(EOAttribute *)_attr;

@end

#endif
