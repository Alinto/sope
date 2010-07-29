/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include "XmlRpcMethodResponse.h"
#include "NSObject+XmlRpc.h"
#include "XmlRpcCoder.h"
#include "common.h"

#if LIB_FOUNDATION_LIBRARY
#  include <Foundation/NSConcreteNumber.h>
#endif

#define BOOLEAN_TYPE 0
#define INTEGER_TYPE 1
#define DOUBLE_TYPE  2

@implementation NSNumber(XmlRpcCoding)

- (unsigned int)_xmlRpcNumberType {
  static Class BoolClass = Nil;

  if (BoolClass == Nil)
    BoolClass = NSClassFromString(@"NSBoolNumber");

  if ([self isKindOfClass:BoolClass])
    return BOOLEAN_TYPE;
  
  switch (*[self objCType]) {
    case 'i':
    case 'I':
    case 'c':
    case 'C':
    case 's':
    case 'S':
    case 'l':
    case 'L':
      return INTEGER_TYPE;
      
    case 'f':
    case 'd':
    default:
      return DOUBLE_TYPE;
  }
}

- (NSString *)xmlRpcType {
  switch ([self _xmlRpcNumberType]) {
    case BOOLEAN_TYPE:
      return @"boolean";
    case DOUBLE_TYPE:
      return @"double";
    default: /* INTEGER_TYPE */
      return @"i4";
  }
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  switch ([self _xmlRpcNumberType]) {
    case BOOLEAN_TYPE:
      [_coder encodeBoolean:[self boolValue]];
      break;
    case DOUBLE_TYPE:
      [_coder encodeDouble:[self doubleValue]];
      break;
    default: /* INTEGER_TYPE */
      [_coder encodeInt:[self intValue]];
  }
}

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [NSNumber numberWithInt:[_coder decodeInt]];
}

@end /* NSNumber(XmlRpcCoding) */

#if LIB_FOUNDATION_LIBRARY

@implementation NSBoolNumber(XmlRpcCoding)

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [[[NSNumber alloc] initWithBool:[_coder decodeBoolean]] autorelease];
}

- (NSString *)xmlRpcType {
  return @"boolean";
}

@end /* NSBoolNumber(XmlRpcCoding) */

// nicht notwendig, nur BOOL muss speziell abgefangen werden ??? :
@implementation NSFloatNumber(XmlRpcCoding)
+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [[[NSNumber alloc] initWithDouble:[_coder decodeDouble]] autorelease];
}

- (NSString *)xmlRpcType {
  return @"double";
}

@end /* NSFloatNumber(XmlRpcCoding) */

@implementation NSDoubleNumber(XmlRpcCoding)
+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [[[NSNumber alloc] initWithDouble:[_coder decodeDouble]] autorelease];
}

- (NSString *)xmlRpcType {
  return @"double";
}

@end /* NSDoubleNumber(XmlRpcCoding) */

#endif
