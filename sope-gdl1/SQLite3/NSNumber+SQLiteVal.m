/* 
   SQLiteAdaptor.h

   Copyright (C) 2003-2005 SKYRIX Software AG

   Author: Helge Hess (helge.hess@skyrix.com)

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

#import <Foundation/NSString.h>
#include "SQLiteChannel.h"
#include "common.h"

@implementation NSNumber(SQLiteValues)
  
- (id)initWithSQLiteInt:(int)_value {
  return [self initWithInt:_value];
}
- (id)initWithSQLiteDouble:(double)_value {
  return [self initWithDouble:_value];
}
- (id)initWithSQLiteText:(const unsigned char *)_value {
  return index((char *)_value, '.') != NULL
    ? [self initWithDouble:atof((char *)_value)]
    : [self initWithInt:atoi((char *)_value)];
}

- (id)initWithSQLiteData:(const void *)_value length:(int)_length {
  switch (_length) {
  case 1: return [self initWithUnsignedChar:*(char *)_value];
  case 2: return [self initWithShort:*(short *)_value];
  case 4: return [self initWithInt:*(int *)_value];
  case 8: return [self initWithDouble:*(double *)_value];
  }
  
  [self release];
  return nil;
}

- (NSString *)stringValueForSQLite3Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
  // TODO: can we avoid the lowercaseString?
  unsigned len;
  unichar  c1;
  
  if ((len = [_type length]) == 0)
    return [self stringValue];
  if (len < 4)
    return [self stringValue];

  c1 = [_type characterAtIndex:0];
  switch (c1) {
  case 'b': case 'B':
    if (![[_type lowercaseString] hasPrefix:@"bool"])
      break;
    return [self boolValue] ? @"true" : @"false";
    
  case 'm': case 'M': {
    if (![[_type lowercaseString] hasPrefix:@"money"])
      break;
    return [@"$" stringByAppendingString:[self stringValue]];
  }
  
  case 'c': case 'C':
  case 't': case 'T':
  case 'v': case 'V': {
    static NSMutableString *ms = nil; // reuse mstring, THREAD
    
    _type = [_type lowercaseString];
    if (!([_type hasPrefix:@"char"] ||
	  [_type hasPrefix:@"varchar"] ||
	  [_type hasPrefix:@"text"]))
      break;
    
    // TODO: can we get this faster?!
    if (ms == nil) ms = [[NSMutableString alloc] initWithCapacity:256];
    [ms setString:@"'"];
    [ms appendString:[self stringValue]];
    [ms appendString:@"'"];
    return [[ms copy] autorelease];
  }
  }
  return [self stringValue];
}

@end /* NSNumber(SQLiteValues) */
