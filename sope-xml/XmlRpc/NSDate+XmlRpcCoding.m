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
#import <Foundation/NSCalendarDate.h>
#include "common.h"

@implementation NSDate(XmlRpcCoding)

- (NSString *)xmlRpcType {
  return @"dateTime.iso8601";
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeDateTime:self];
}

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [_coder decodeDateTime];
}

@end /* NSDate(XmlRpcCoding) */

@implementation NSTimeZone(XmlRpcCoding)

- (NSString *)xmlRpcType {
  return @"string";
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
#if NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY
  [_coder encodeString:[self name]];
#else
  [_coder encodeString:[self timeZoneName]];
#endif
}

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [NSTimeZone timeZoneWithName:[_coder decodeString]];
}

@end /* NSTimeZone(XmlRpcCoding) */
