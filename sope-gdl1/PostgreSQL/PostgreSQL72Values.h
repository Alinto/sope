/* 
   PostgreSQL72Values.h

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

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

#ifndef ___PostgreSQL72_Values_H___
#define ___PostgreSQL72_Values_H___

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <GDLAccess/EONull.h>
#import "PostgreSQL72Exception.h"

@class EOAttribute;
@class PostgreSQL72Channel;

@interface PostgreSQL72DataTypeMappingException : PostgreSQL72Exception

- (id)initWithObject:(id)_obj
  forAttribute:(EOAttribute *)_attr
  andPostgreSQLType:(NSString *)_dt
  inChannel:(PostgreSQL72Channel *)_channel;

@end

@protocol PostgreSQL72Values

+ (id)valueFromCString:(const char *)_cstr length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel;

+ (id)valueFromBytes:(const void *)_bytes length:(int)_length
  postgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(PostgreSQL72Channel *)_channel;

- (NSString *)stringValueForPostgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute;

@end

@interface NSString(PostgreSQL72Values) < PostgreSQL72Values >
@end

@interface NSNumber(PostgreSQL72Values) < PostgreSQL72Values >
@end

@interface NSData(PostgreSQL72Values) < PostgreSQL72Values >
@end

@interface NSCalendarDate(PostgreSQL72Values) < PostgreSQL72Values >
@end

@interface EONull(PostgreSQL72Values)

- (NSString *)stringValueForPostgreSQLType:(NSString *)_type
  attribute:(EOAttribute *)_attribute;

@end

#endif
