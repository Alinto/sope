/* 
   SQLiteValues.h

   Copyright (C) 1999-2005 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

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

#ifndef ___SQLite_Values_H___
#define ___SQLite_Values_H___

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <GDLAccess/EONull.h>
#import "SQLiteException.h"

@class EOAttribute;
@class SQLiteChannel;

@interface SQLiteDataTypeMappingException : SQLiteException

- (id)initWithObject:(id)_obj
  forAttribute:(EOAttribute *)_attr
  andSQLite3Type:(NSString *)_dt
  inChannel:(SQLiteChannel *)_channel;

@end

@protocol SQLiteValues

- (NSString *)stringValueForSQLite3Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute;

@end

@interface NSObject(SQLiteValues)

- (id)initWithSQLiteInt:(int)_value;
- (id)initWithSQLiteText:(const unsigned char *)_value;
- (id)initWithSQLiteDouble:(double)_value;
- (id)initWithSQLiteData:(const void *)_data length:(int)_length;

@end

@interface NSString(SQLiteValues) < SQLiteValues >
@end

@interface NSNumber(SQLiteValues) < SQLiteValues >
@end

@interface NSData(SQLiteValues) < SQLiteValues >
@end

@interface NSCalendarDate(SQLiteValues) < SQLiteValues >
@end

@interface EONull(SQLiteValues)

- (NSString *)stringValueForSQLite3Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute;

@end

#endif /* ___SQLite_Values_H___ */
