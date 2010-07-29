/* 
   EOAttribute+SQLite.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

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

#include "common.h"
#import "EOAttribute+SQLite.h"

static NSString *SQLITE3_DATETIME_FORMAT  = @"%b %d %Y %I:%M:%S:000%p";
static NSString *SQLITE3_TIMESTAMP_FORMAT = @"%Y-%m-%d %H:%M:%S%z";

@implementation EOAttribute(SQLiteAttributeAdditions)

- (void)loadValueClassAndTypeUsingSQLiteType:(int)_type
  size:(int)_size
  modification:(int)_modification
  binary:(BOOL)_isBinary
{
  /* This method makes no sense with SQLite? */
  
  if (_isBinary)
    [self setValueClassName:@"NSData"];

#if 0
  switch (_type) {
  case BOOLOID:
      [self setExternalType:@"bool"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"i"];
      return;
  case NAMEOID:
      [self setExternalType:@"name"];
      [self setValueClassName:@"NSString"];
      return;
  case TEXTOID:
      [self setExternalType:@"textoid"];
      [self setValueClassName:@"NSString"];
      return;
  case INT2OID:
      [self setExternalType:@"int2"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"d"];
      return;
  case INT4OID:
      [self setExternalType:@"int4"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"d"];
      return;
  case INT8OID:
      [self setExternalType:@"int8"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"d"];
      return;
      
    case CHAROID:
      [self setExternalType:@"char"];
      [self setValueClassName:@"NSString"];
      break;
    case VARCHAROID:
      [self setExternalType:@"varchar"];
      [self setValueClassName:@"NSString"];
      break;
    case NUMERICOID:
      [self setExternalType:@"numeric"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"d"];
      break;
    case FLOAT4OID:
      [self setExternalType:@"float4"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"f"];
      break;
    case FLOAT8OID:
      [self setExternalType:@"float8"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"f"];
      break;

    case DATEOID:
      [self setExternalType:@"datetime"];
      [self setValueClassName:@"NSCalendarDate"];
      [self setCalendarFormat:SQLITE3_DATETIME_FORMAT];
      break;
    case TIMEOID:
      [self setExternalType:@"time"];
      [self setValueClassName:@"NSCalendarDate"];
      [self setCalendarFormat:SQLITE3_DATETIME_FORMAT];
      break;
    case TIMESTAMPOID:
      [self setExternalType:@"timestamp"];
      [self setValueClassName:@"NSCalendarDate"];
      [self setCalendarFormat:SQLITE3_DATETIME_FORMAT];
      break;
    case TIMESTAMPTZOID:
      [self setExternalType:@"timestamptz"];
      [self setValueClassName:@"NSCalendarDate"];
      [self setCalendarFormat:SQLITE3_DATETIME_FORMAT];
      break;
    case BITOID:
      [self setExternalType:@"bit"];
      break;
    default:
    NSLog(@"What is SQLITE3 Oid %i ???", _type);
    break;
  }
#endif
}

- (void)loadValueClassForExternalSQLiteType:(NSString *)_type {
  if ([_type isEqualToString:@"bool"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"i"];
  }
  else if ([_type isEqualToString:@"int2"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"i"];
  }
  else if ([_type isEqualToString:@"int4"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"i"];
  }
  else if ([_type isEqualToString:@"float4"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"f"];
  }
  else if ([_type isEqualToString:@"float8"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"d"];
  }
  else if ([_type isEqualToString:@"decimal"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"d"];
  }
  else if ([_type isEqualToString:@"numeric"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"d"];
  }
  else if ([_type isEqualToString:@"name"]) {
    [self setExternalType:@"name"];
    [self setValueClassName:@"NSString"];
  }
  else if ([_type isEqualToString:@"varchar"]) {
    [self setExternalType:@"varchar"];
    [self setValueClassName:@"NSString"];
  }
  else if ([_type isEqualToString:@"char"]) {
    [self setExternalType:@"char"];
    [self setValueClassName:@"NSString"];
  }
  else if ([_type isEqualToString:@"timestamp"]) {
    [self setValueClassName:@"NSCalendarDate"];
    [self setCalendarFormat:SQLITE3_TIMESTAMP_FORMAT];
  }
  else if ([_type isEqualToString:@"timestamptz"]) {
    [self setValueClassName:@"NSCalendarDate"];
    [self setCalendarFormat:SQLITE3_TIMESTAMP_FORMAT];
  }
  else if ([_type isEqualToString:@"datetime"]) {
    [self setValueClassName:@"NSCalendarDate"];
    [self setCalendarFormat:SQLITE3_DATETIME_FORMAT];
  }
  else if ([_type isEqualToString:@"date"]) {
    [self setValueClassName:@"NSString"];
  }
  else if ([_type isEqualToString:@"time"]) {
    [self setValueClassName:@"NSString"];
  }
  else if ([_type isEqualToString:@"text"]) {
    [self setValueClassName:@"NSString"];
  }
  else {
    NSLog(@"invalid argument %@", _type);
    
    [NSException raise:@"InvalidArgumentException"
		 format:@"invalid SQLite type %@ passed to %s",
		   _type, __PRETTY_FUNCTION__];
  }
}

@end /* EOAttribute(SQLite) */

void __link_EOAttributeSQLite() {
  // used to force linking of object file
  __link_EOAttributeSQLite();
}
