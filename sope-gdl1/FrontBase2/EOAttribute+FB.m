/* 
   EOAttribute+FB.m

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
// $Id: EOAttribute+FB.m 1 2004-08-20 10:38:46Z znek $

#import "common.h"
#import "EOAttribute+FB.h"
#import <FBCAccess/FBCAccess.h>

// Frontbase Date: Oct 21 1997  21:52:26+08:00
static NSString *FRONTBASE_DATE_FORMAT = @"%Y-%m-%d %H:%M:%S";

@implementation EOAttribute(FBAttributeAdditions)

- (void)loadValueClassForExternalFrontBaseType:(NSString *)_type {
  _type = [_type lowercaseString];
  
  if ([_type isEqualToString:@"tinyint"] ||
      [_type isEqualToString:@"bit"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"i"];
  }
  else if ([_type isEqualToString:@"smallint"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"i"];
  }
  else if ([_type isEqualToString:@"int"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"i"];
  }
  else if ([_type isEqualToString:@"char"] ||
           [_type isEqualToString:@"varchar"]) {
    [self setValueClassName:@"NSString"];
  }
  else if ([_type isEqualToString:@"date"] ||
           [_type isEqualToString:@"timestamp"] ||
           [_type isEqualToString:@"timestamp with time zone"]) {
    [self setValueClassName:@"NSCalendarDate"];
    [self setCalendarFormat:FRONTBASE_DATE_FORMAT];
  }
  else if ([_type isEqualToString:@"float"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"f"];
  }
  else if ([_type isEqualToString:@"time"] ||
           [_type isEqualToString:@"time with time zone"]) {
    [self setValueClassName:@"NSString"];
  }
  else if ([_type isEqualToString:@"real"]    ||
           [_type isEqualToString:@"money"]   ||
           [_type isEqualToString:@"money4"]  ||
           [_type isEqualToString:@"decimal"] ||
           [_type isEqualToString:@"numeric"]) {
    [self setValueClassName:@"NSNumber"];
    [self setValueType:@"d"];
  }
  else if ([_type isEqualToString:@"BLOB"]) {
    [self setValueClassName:@"NSData"];
  }
  else if ([_type isEqualToString:@"CLOB"]) {
    [self setValueClassName:@"NSString"];
  }
  else {
    NSLog(@"invalid argument %@", _type);
    
    [InvalidArgumentException raise:@"InvalidArgumentException"
                              format:
                                @"invalid FrontBase type %@ passed to -%@",
                                _type, NSStringFromSelector(_cmd)];
  }
}

- (void)loadValueClassAndTypeFromFrontBaseType:(int)_type {
  switch (_type) {
    case FB_Boolean:
      [self setExternalType:@"BOOLEAN"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"i"];
      break;

    case FB_Integer:
      [self setExternalType:@"INTEGER"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"i"];
      break;
    case FB_SmallInteger:
      [self setExternalType:@"SMALLINT"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"i"];
      break;
      
    case FB_Float:
      [self setExternalType:@"FLOAT"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"d"];
      break;
    case FB_Real:
      [self setExternalType:@"REAL"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"d"];
      break;
    case FB_Double:
      [self setExternalType:@"DOUBLE"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"d"];
      break;
    case FB_Numeric:
      [self setExternalType:@"NUMERIC"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"d"];
      break;
    case FB_Decimal:
      [self setExternalType:@"DECIMAL"];
      [self setValueClassName:@"NSNumber"];
      [self setValueType:@"d"];
      break;
      
    case FB_Character:
      [self setExternalType:@"CHAR"];
      [self setValueClassName:@"NSString"];
      break;
    case FB_VCharacter:
      [self setExternalType:@"VARCHAR"];
      [self setValueClassName:@"NSString"];
      break;
      
    case FB_Bit:
      [self setExternalType:@"BIT"];
      [self setValueClassName:@"NSData"];
      break;
    case FB_VBit:
      [self setExternalType:@"VARBIT"];
      [self setValueClassName:@"NSData"];
      break;
      
    case FB_Date:
      [self setExternalType:@"DATE"];
      [self setValueClassName:@"NSCalendarDate"];
      break;
      
    case FB_Time:
      [self setExternalType:@"TIME"];
      [self setValueClassName:@"NSString"];
      break;
    case FB_TimeTZ:
      [self setExternalType:@"TIME WITH TIME ZONE"];
      [self setValueClassName:@"NSString"];
      break;
      
    case FB_Timestamp:
      [self setExternalType:@"TIMESTAMP"];
      [self setValueClassName:@"NSCalendarDate"];
      break;
    case FB_TimestampTZ:
      [self setExternalType:@"TIMESTAMP WITH TIME ZONE"];
      [self setValueClassName:@"NSCalendarDate"];
      break;
      
    case FB_YearMonth:
      [self setExternalType:@"INTERVAL YEAR TO MONTH"];
      [self setValueClassName:@"NSNumber"];
      break;
    case FB_DayTime: /* NSDecimalNumber */
      [self setExternalType:@"INTERVAL DAY TO SECOND"];
      [self setValueClassName:@"NSNumber"];
      break;
      
    case FB_CLOB:
      [self setExternalType:@"CLOB"];
      [self setValueClassName:@"NSString"];
      break;
    case FB_BLOB:
      [self setExternalType:@"BLOB"];
      [self setValueClassName:@"NSData"];
      break;

    default:
      [InvalidArgumentException raise:@"InvalidArgumentException"
                                format:
                                  @"invalid frontbase type %d passed to -%s",
                                  _type, NSStringFromSelector(_cmd)];
      break;
  }
}

@end

void __link_EOAttributeFB() {
  // used to force linking of object file
  __link_EOAttributeFB();
}
