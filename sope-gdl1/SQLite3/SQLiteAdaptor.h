/* 
   SQLiteAdaptor.h

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

#ifndef ___SQLite_Adaptor_H___
#define ___SQLite_Adaptor_H___

/*
  The SQLite adaptor.

  The connection dictionary of this adaptor understands these keys:
    databaseName
  
  The adaptor is based on libsqlite.
*/

#import <Foundation/NSMapTable.h>
#import <GDLAccess/EOAdaptor.h>
#import <GDLAccess/EOAttribute.h>

@class NSString, NSMutableDictionary;

@interface SQLiteAdaptor : EOAdaptor
{
}

- (id)initWithName:(NSString *)_name;

// connection management

- (NSString *)databaseName;
- (NSString *)newKeyExpression;

// sequence for primary key generation

- (NSString *)primaryKeySequenceName;

// value formatting

- (id)formatValue:(id)value forAttribute:(EOAttribute *)attribute;

// attribute typing

- (BOOL)attributeAllowedInDistinctSelects:(EOAttribute *)_attr;

// classes used

- (Class)adaptorContextClass; // SQLiteContext
- (Class)adaptorChannelClass; // SQLiteChannel
- (Class)expressionClass;     // SQLiteExpression

@end

#endif
