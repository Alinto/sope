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
#include "common.h"
#include "XmlRpcCoder.h"

@implementation NSNotification(XmlRpcCoding)

- (NSString *)xmlRpcType {
  return @"struct";
}

+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  self = [NSNotification notificationWithName:
                           [_coder decodeStringForKey:@"name"]
                         object:[_coder decodeObjectForKey:@"object"]
                         userInfo:[_coder decodeStructForKey:@"userInfo"]];
  return self;
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  NSString *n;
  
  n = [self name];
  [_coder encodeString:n               forKey:@"name"];
  [_coder encodeObject:[self object]   forKey:@"object"];
  [_coder encodeStruct:[self userInfo] forKey:@"userInfo"];
}

@end /* NSNotification(XmlRpcCoding) */
