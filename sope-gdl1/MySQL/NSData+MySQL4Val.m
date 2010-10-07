/* 
   NSData+MySQL4Val.m

   Copyright (C) 2003-2005 SKYRIX Software AG

   Author: Helge Hess (helge.hess@skyrix.com)

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

#include "MySQL4Values.h"
#include "MySQL4Channel.h"
#import <Foundation/NSData.h>
#include "common.h"

@implementation NSData(MySQL4Values)

- (id)initWithMySQL4Field:(MYSQL_FIELD *)_field value:(const void *)_v length:(int)_len {
  // Note: never used on lF (NSTemporaryString!)
  if (_v == NULL) {
    [self release];
    return nil;
  }

  return [self initWithBytes:_v length:_len];
}

#if 0 // unused?
- (id)initWithMySQL4Int:(int)_value {
  return [self initWithBytes:&_value length:sizeof(int)];
}
- (id)initWithMySQL4Double:(double)_value {
  return [self initWithBytes:&_value length:sizeof(double)];
}
- (id)initWithMySQL4Text:(const unsigned char *)_value {
  return [self initWithBytes:_value length:strlen((char *)_value)];
}
- (id)initWithMySQL4Data:(const void *)_value length:(int)_length {
  return [self initWithBytes:_value length:_length];
}
#endif

- (NSString *)stringValueForMySQL4Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
  // TODO: UNICODE
  // TODO: this method looks slow
  static NSStringEncoding enc = 0;
  NSString *str, *t;
  unsigned len;
  unichar  c1;
  
  if ((len = [self length]) == 0)
    return @"";
  
  if (enc == 0) {
    enc = [NSString defaultCStringEncoding];
    NSLog(@"Note: MySQL4 adaptor using '%@' encoding for data=>string "
	  @"conversion.",
	  [NSString localizedNameOfStringEncoding:enc]);
  }
  
  str = [[NSString alloc] initWithData:self encoding:enc];
  
  if (((len = [_type length]) == 0) || (len != 4 && len != 5 && len != 7))
    return [str autorelease];

  c1 = [_type characterAtIndex:0];
  switch (c1) {
  case 'c': case 'C':
  case 'v': case 'V':
  case 'm': case 'M':
  case 't': case 'T':
    t = [_type lowercaseString];
    if ([t hasPrefix:@"char"]    ||
	[t hasPrefix:@"varchar"] ||
	[t hasPrefix:@"money"]   ||
	[t hasPrefix:@"text"]) {
      t = [[str stringValueForMySQL4Type:_type 
		attribute:_attribute] retain];
      [str release];
      return [t autorelease];
    }
  }
  
  return [str autorelease];;
}

@end /* NSData(MySQL4Values) */
