/* 
   MySQL4Adaptor.h

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

#import <Foundation/NSValue.h>
#include "MySQL4Channel.h"
#include "common.h"
#include <mysql/mysql.h>

@implementation NSNumber(MySQL4Values)

- (id)initWithMySQL4Field:(MYSQL_FIELD *)_field value:(const void *)_v length:(int)_len {
  if (_v == NULL) {
    [self release];
    return nil;
  }

  switch (_field->type) {
  case FIELD_TYPE_TINY:
    return ((_field->flags & UNSIGNED_FLAG)
            ? [self initWithUnsignedChar:atoi(_v)]
            : [self initWithChar:atoi(_v)]);
  case FIELD_TYPE_SHORT:
    return ((_field->flags & UNSIGNED_FLAG)
            ? [self initWithUnsignedShort:atoi(_v)]
            : [self initWithShort:atoi(_v)]);
  case FIELD_TYPE_LONG:
    return ((_field->flags & UNSIGNED_FLAG)
            ? [self initWithUnsignedLong:strtoul(_v, NULL, 10)]
            : [self initWithLong:strtol(_v, NULL, 10)]);
  case FIELD_TYPE_LONGLONG: 
    return ((_field->flags & UNSIGNED_FLAG)
            ? [self initWithUnsignedLong:strtoull(_v, NULL, 10)]
            : [self initWithLongLong:strtoll(_v, NULL, 10)]);

  case FIELD_TYPE_FLOAT:  return [self initWithFloat:atof(_v)];
  case FIELD_TYPE_DOUBLE: return [self initWithDouble:atof(_v)];
    
  default:
    NSLog(@"ERROR(%s): unsupported MySQL type: %i (len=%d)", 
          __PRETTY_FUNCTION__, _field->type, _len);
    [self release];
    return nil;
  }
}

/* generation */

- (NSString *)stringValueForMySQL4Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
  // TODO: can we avoid the lowercaseString?
  unsigned len;
  unichar  c1;
  
  if ((len = [_type length]) == 0)
    return [self stringValue];
  if (len < 4)
    {
#if GNUSTEP_BASE_LIBRARY
    /*
       on gstep-base -stringValue of bool's return YES or NO, which seems to
       be different on Cocoa and liBFoundation.
    */
    {
      static Class BoolClass = Nil;
      
      if (BoolClass == Nil) BoolClass = NSClassFromString(@"NSBoolNumber");
      if ([self isKindOfClass:BoolClass])
	return [self boolValue] ? @"1" : @"0";
    }
#endif
      return [self stringValue];
    }

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

@end /* NSNumber(MySQL4Values) */
