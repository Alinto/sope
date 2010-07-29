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
#include "XmlRpcCoder.h"
#include "NSObject+XmlRpc.h"
#include "common.h"

@implementation NSEnumerator(XmlRpcCoding)

- (NSString *)xmlRpcType {
  return @"array";
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  NSMutableArray *objs;
  id obj;
  
  /* make a copy to keep the enum state */
  self = [self copy];
  
  objs = [[NSMutableArray alloc] initWithCapacity:16];
  
  while ((obj = [self nextObject]))
    [objs addObject:obj];
  
  [_coder encodeArray:objs];
  [objs release];
  [self release];
}

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [[_coder decodeArray] objectEnumerator];
}

@end /* NSEnumerator(XmlRpc) */

@implementation NSArray(XmlRpcCoding)

- (NSString *)xmlRpcType {
  return @"array";
}
- (NSArray *)xmlRpcElementSignature {
  unsigned i, count;
  NSMutableArray *ma;
  
  if ((count = [self count]) == 0)
    return [NSArray array];
  
  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++)
    [ma addObject:[[self objectAtIndex:i] xmlRpcType]];
  return ma;
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeArray:self];
}

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [_coder decodeArray];
}

@end /* NSArray(XmlRpc) */

@implementation NSSet(XmlRpcCoding)

- (NSString *)xmlRpcType {
  return @"array";
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  [_coder encodeArray:[self allObjects]];
}

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  return [NSSet setWithArray:[_coder decodeArray]];
}

@end /* NSSet(XmlRpcCoding) */
