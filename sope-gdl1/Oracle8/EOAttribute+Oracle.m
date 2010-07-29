/*
**  OracleEOAttribute.m
**
**  Copyright (c) 2007  Inverse groupe conseil inc. and Ludovic Marcotte
**
**  Author: Ludovic Marcotte <ludovic@inverse.ca>
**
**  This library is free software; you can redistribute it and/or
**  modify it under the terms of the GNU Lesser General Public
**  License as published by the Free Software Foundation; either
**  version 2.1 of the License, or (at your option) any later version.
**
**  This library is distributed in the hope that it will be useful,
**  but WITHOUT ANY WARRANTY; without even the implied warranty of
**  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
**  Lesser General Public License for more details.
**
**  You should have received a copy of the GNU Lesser General Public
**  License along with this library; if not, write to the Free Software
**  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
*/

#import "EOAttribute+Oracle.h"

@implementation EOAttribute (OracleExtensions)

+ (id) attributeWithOracleType: (ub2) theType
                          name: (text *) theName
                        length: (ub4) theLength
			 width: (ub4) theWidth
{
  EOAttribute *attr;
  NSString *s;

  attr = [[EOAttribute alloc] init];
  s = AUTORELEASE([[NSString alloc] initWithBytes: theName  length: theLength  encoding: NSASCIIStringEncoding]);

  // Oracle returns us the column names using uppercase strings.
  // We change that to avoid lameness in other parts of GDL.
  s = [s lowercaseString];

  [attr setName: s];
  [attr setColumnName: s];
  [attr setWidth: (unsigned)theWidth];

  switch (theType)
    {
    case SQLT_CHR:
      [attr setExternalType: @"VARCHAR2"];
      [attr setValueClassName: @"NSString"];
      break;
    case SQLT_CLOB:
      [attr setExternalType: @"CLOB"];
      [attr setValueClassName: @"NSString"];
      break;
    case SQLT_DAT:
      // char[7] that contains the date and time but no time zone information.
      [attr setExternalType: @"DATE"];
      [attr setValueClassName: @"NSDate"];
      break;
    case SQLT_INT:
      [attr setExternalType: @"INTEGER"];
      [attr setValueClassName: @"NSNumber"];
      [attr setValueType: @"d"];
      break;
    case SQLT_NUM:
      // char[22]
      [attr setExternalType: @"NUMBER"];
      [attr setValueClassName: @"NSNumber"];
      [attr setValueType: @"d"];
      break;
    case SQLT_STR:
      [attr setExternalType: @"STRING"];
      [attr setValueClassName: @"NSString"];
      break;
    case SQLT_TIMESTAMP:
      [attr setExternalType: @"TIMESTAMP"];
      [attr setValueClassName: @"NSCalendarDate"];
      break;
    case SQLT_TIMESTAMP_TZ:
      [attr setExternalType: @"TIMESTAMP WITH TIME ZONE"];
      [attr setValueClassName: @"NSCalendarDate"];
      break;
    case SQLT_TIMESTAMP_LTZ:
      [attr setExternalType: @"TIMESTAMP WITH LOCAL TIME ZONE"];
      [attr setValueClassName: @"NSCalendarDate"];
      break;
    default:
      NSLog(@"Unsupported type! %d\n", theType);
    }

  return AUTORELEASE(attr);
}

@end
