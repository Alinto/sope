/* 
   PostgreSQL72Adaptor.h

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

#ifndef ___PostgreSQL72_Adaptor_H___
#define ___PostgreSQL72_Adaptor_H___

/*
  The PostgreSQL72 adaptor.

  The connection dictionary of this adaptor understands these keys:
    hostName
    port
    options
    tty
    userName
    password
    databaseName

  The adaptor is based on libpq.
*/

#import <Foundation/NSMapTable.h>
#import <GDLAccess/EOAdaptor.h>
#import <GDLAccess/EOAttribute.h>

@class NSString, NSMutableDictionary, NSArray;

@interface PostgreSQL72Adaptor : EOAdaptor
{
}

- (id)initWithName:(NSString *)_name;

/* connection management */

- (NSString *)serverName;
- (NSString *)loginName;
- (NSString *)loginPassword;
- (NSString *)databaseName;
- (NSString *)port;
- (NSString *)options;
- (NSString *)tty;
- (NSString *)newKeyExpression;

/* sequence for primary key generation */

- (NSString *)primaryKeySequenceName;

/* value formatting */

- (id)formatValue:(id)value forAttribute:(EOAttribute *)attribute;

/* attribute typing */

- (BOOL)attributeAllowedInDistinctSelects:(EOAttribute *)_attr;

/* classes used */

- (Class)adaptorContextClass; // PostgreSQL72Context
- (Class)adaptorChannelClass; // PostgreSQL72Channel
- (Class)expressionClass;     // PostgreSQL72Expression

@end

#endif
