/* 
   EOAttributeOrdering.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: 1996

   This file is part of the GNUstep Database Library.

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

// $Id: EOCustomValues.m 1 2004-08-20 10:38:46Z znek $

#import "common.h"
#import "EOCustomValues.h"

#if LIB_FOUNDATION_LIBRARY
@implementation NSTemporaryString(EOCustomValues)

- initWithString:(NSString*)string type:(NSString*)type {
  return [self initWithString:string];
}

@end
#endif

@implementation NSString(EOCustomValues)

+ stringWithString:(NSString*)string type:(NSString*)type {
  // If mutable return a copy if not return self
    
  if ([string isKindOfClass:[NSMutableString class]])
    return [[NSString alloc] initWithString:string type:type];
  else
    return RETAIN(self);
}

- initWithString:(NSString*)string type:(NSString*)type {
  return [self initWithString:string];
}

- (NSString*)stringForType:(NSString*)type {
  // If mutable return a copy if not return self (handled in NSString)
  return [self copyWithZone:[self zone]];
}

- (id)initWithData:(NSData*)data type:(NSString*)type {
  return [self initWithCString:[data bytes] length:[data length]];
}

- (NSData *)dataForType:(NSString *)type {
  unsigned len = [self cStringLength];
  char buf[len + 1];
  [self getCString:buf];
  return [NSData dataWithBytes:buf length:len];
}

@end /* NSString(EOCustomValues) */


@implementation NSData(EOCustomValues)

- (id)initWithString:(NSString*)string type:(NSString*)type {
  unsigned len = [string cStringLength];
  char buf[len + 1];
  [string getCString:buf];
  
  return [self initWithBytes:buf length:len];
}

- (NSString*)stringForType:(NSString*)type {
  return [NSString stringWithCString:[self bytes] length:[self length]];
}

- initWithData:(NSData*)data type:(NSString*)type {
  return [self initWithBytes:[data bytes] length:[data length]];
}

- (NSData*)dataForType:(NSString*)type {
  return [self copyWithZone:[self zone]];
}

@end /* NSData(EOCustomValues) */


@implementation NSNumber(EOCustomValues)

+ (id)numberWithString:(NSString*)string type:(NSString*)type {
  char buf[[string cStringLength] + 1];
  const char *cstring;

  [string getCString:buf];
  cstring = buf;
  
  if ([type cStringLength] == 1)
    switch ((unsigned char)[type characterAtIndex:0]) {
      case 'c' : {
        char value = atoi(cstring);
        return [NSNumber numberWithChar:value];
      }
      case 'C' : {
        unsigned char value = atoi(cstring);
        return [NSNumber numberWithUnsignedChar:value];
      }
      case 's' : {
        short value = atoi(cstring);
        return [NSNumber numberWithShort:value];
      }
      case 'S' : {
        unsigned short value = atoi(cstring);
        return [NSNumber numberWithUnsignedShort:value];
      }
      case 'i' : {
        int value = atoi(cstring);
        return [NSNumber numberWithInt:value];
      }
      case 'I' : {
        unsigned int value = atoi(cstring);
        return [NSNumber numberWithUnsignedInt:value];
      }
      case 'l' : {
        long value = atol(cstring);
        return [NSNumber numberWithLong:value];
      }
      case 'L' : {
        unsigned long value = atol(cstring);
        return [NSNumber numberWithUnsignedLong:value];
      }
      case 'q' : {
        long long value = atol(cstring);
        return [NSNumber numberWithLongLong:value];
      }
      case 'Q' : {
        unsigned long long value = atol(cstring);
        return [NSNumber numberWithUnsignedLongLong:value];
      }
      case 'f' : {
        float value = atof(cstring);
        return [NSNumber numberWithFloat:value];
      }
      case 'd' : {
        double value = atof(cstring);
        return [NSNumber numberWithDouble:value];
      }
    }

  [NSException raise:NSInvalidArgumentException
	       format:@"invalid type `%@' for NSNumber in "
	         @"numberWithString:type:", type];
  return nil;
}

- initWithString:(NSString*)string type:(NSString*)type {
  (void)AUTORELEASE(self);
  return RETAIN([NSNumber numberWithString:string type:type]);
}

- (NSString*)stringForType:(NSString*)type {
  return [self stringValue];
}

@end /* NSNumber(EOCustomValues) */

void EOAccess_EOCustomValues_link(void) {
  EOAccess_EOCustomValues_link();
}
