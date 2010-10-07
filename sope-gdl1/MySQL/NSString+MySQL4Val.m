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

#include "MySQL4Channel.h"
#include <NGExtensions/NSString+Ext.h>
#import <Foundation/NSString.h>
#include "common.h"
#include <mysql/mysql.h>

@implementation NSString(MySQL4Values)

static Class EOExprClass = Nil;

- (id)initWithMySQL4Field:(MYSQL_FIELD *)_field value:(const void *)_v length:(int)_len {
  // Note: never used on lF (NSTemporaryString!)
  if (_v == NULL) {
    [self release];
    return nil;
  }

  switch (_field->type) {
  case FIELD_TYPE_BLOB:
  case FIELD_TYPE_TINY_BLOB:
  case FIELD_TYPE_MEDIUM_BLOB:
  case FIELD_TYPE_LONG_BLOB:
    ; /* fall through */
    
  default:
    /* we always fallback to the UTF-8 string ... */
    return [self initWithUTF8String:_v];
  }
}

#if 0
- (id)initWithMySQL4Int:(int)_value {
  char buf[256];
  sprintf(buf, "%i", _value);
  return [self initWithCString:buf];
}
- (id)initWithMySQL4Double:(double)_value {
  char buf[256];
  sprintf(buf, "%g", _value);
  return [self initWithCString:buf];
}

- (id)initWithMySQL4Text:(const unsigned char *)_value {
  return [self initWithUTF8String:_value];
}

- (id)initWithMySQL4Data:(const void *)_value length:(int)_length {
  NSData *d;
  
  d = [[NSData alloc] initWithBytes:_value length:_length];
  self = [self initWithData:d encoding:NSUTF8StringEncoding];
  [d release];
  return self;
}
#endif

/* generate SQL value */

- (NSString *)stringValueForMySQL4Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
  // TODO: all this looks slow ...
  unsigned len;
  unichar  c1;
  
  if ((len = [_type length]) == 0)
    return self;
  
  c1 = [_type characterAtIndex:0];
  switch (c1) {
  case 'c': case 'C': // char
  case 'v': case 'V': // varchar
  case 't': case 'T': { // text
    NSString *s;
    id expr;
    
    if (len < 4)
      return self;
    
    _type = [_type lowercaseString];
  
    if (!([_type hasPrefix:@"char"] ||
	[_type hasPrefix:@"varchar"] ||
	[_type hasPrefix:@"text"]))
      break;
    
    /* TODO: creates too many autoreleased strings :-( */
      
    expr = [self stringByReplacingString:@"\\" withString:@"\\\\"];
      
    if (EOExprClass == Nil) EOExprClass = [EOQuotedExpression class];
    expr = [[EOExprClass alloc] initWithExpression:expr 
				quote:@"'" escape:@"\\'"];
    s = [[(EOQuotedExpression *)expr expressionValueForContext:nil] retain];
    [expr release];
    return [s autorelease];
  }
  case 'i': case 'I': { // int
    char buf[128];
    sprintf(buf, "%i", [self intValue]);
    return [NSString stringWithCString:buf];
  }
  default:
    NSLog(@"WARNING(%s): return string as is for type %@", 
	  __PRETTY_FUNCTION__, _type);
    break;
  }
  return self;
}

@end /* NSString(MySQL4Values) */
