/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "common.h"

@implementation NSObject(SxXmlRpcValue)

- (NSArray *)asXmlRpcArray {
  if ([self respondsToSelector:@selector(objectEnumerator)]) {
    return [[[NSArray alloc]
                      initWithObjectsFromEnumerator:
                        [(id)self objectEnumerator]]
                      autorelease];
  }
  return nil;
}

- (NSDictionary *)asXmlRpcStruct {
  return [self valuesForKeys:[[self classDescription] attributeKeys]];
}

- (NSString *)asXmlRpcString {
  return [self stringValue];
}
- (int)asXmlRpcInt {
  return [self intValue];
}

- (NSData *)asXmlRpcBase64 {
  return [[self stringValue] dataUsingEncoding:NSUTF8StringEncoding];
}
- (NSDate *)asXmlRpcDateTime {
  return [[[NSDate alloc] initWithString:[self stringValue]] autorelease];
}

- (id)asXmlRpcValueOfType:(NSString *)_xmlRpcValueType {
  unsigned len;
  
  if ((len = [_xmlRpcValueType length]) == 0)
    return self;

  if ([_xmlRpcValueType isEqualToString:@"string"])
    return [self asXmlRpcString];
  if ([_xmlRpcValueType isEqualToString:@"int"])
    return [NSNumber numberWithInt:[self asXmlRpcInt]];
  if ([_xmlRpcValueType isEqualToString:@"array"])
    return [self asXmlRpcArray];
  if ([_xmlRpcValueType isEqualToString:@"struct"])
    return [self asXmlRpcStruct];
  if ([_xmlRpcValueType isEqualToString:@"datetime"])
    return [self asXmlRpcDateTime];
  if ([_xmlRpcValueType isEqualToString:@"base64"])
    return [self asXmlRpcBase64];
  
  return self;
}

@end /* NSObject(SxXmlRpcValue) */

@implementation NSArray(SxXmlRpcValue)

- (NSArray *)asXmlRpcArray {
  return self;
}

- (id)asXmlRpcValueOfType:(NSString *)_xmlRpcValueType {
  return self;
}

@end /* NSArray(SxXmlRpcValue) */

@implementation NSDictionary(SxXmlRpcValue)

- (NSArray *)asXmlRpcArray {
  return [self allValues];
}

- (NSDictionary *)asXmlRpcStruct {
  return self;
}

@end /* NSDictionary(SxXmlRpcValue) */

@implementation NSDate(SxXmlRpcValue)

- (NSDate *)asXmlRpcDateTime {
  return self;
}

@end /* NSDate(SxXmlRpcValue) */

@implementation NSData(SxXmlRpcValue)

- (NSData *)asXmlRpcBase64 {
  return self;
}

@end /* NSCalendarDate(SxXmlRpcValue) */
