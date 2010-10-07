/* 
   MySQL4Values.h

   Copyright (C) 1999-2005 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

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

#ifndef ___MySQL4_Values_H___
#define ___MySQL4_Values_H___

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <GDLAccess/EONull.h>
#import "MySQL4Exception.h"

#include <mysql/mysql.h>

@class EOAttribute;
@class MySQL4Channel;

@interface MySQL4DataTypeMappingException : MySQL4Exception

- (id)initWithObject:(id)_obj
  forAttribute:(EOAttribute *)_attr
  andMySQL4Type:(NSString *)_dt
  inChannel:(MySQL4Channel *)_channel;

@end

@protocol MySQL4Values

- (NSString *)stringValueForMySQL4Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute;

@end

@interface NSObject(MySQL4Values)

- (id)initWithMySQL4Field:(MYSQL_FIELD *)_field value:(const void *)_v length:(int)_len;

@end

@interface NSString(MySQL4Values) < MySQL4Values >
@end

@interface NSNumber(MySQL4Values) < MySQL4Values >
@end

@interface NSData(MySQL4Values) < MySQL4Values >
@end

@interface NSCalendarDate(MySQL4Values) < MySQL4Values >
@end

@interface EONull(MySQL4Values)

- (NSString *)stringValueForMySQL4Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute;

@end

#endif /* ___MySQL4_Values_H___ */
