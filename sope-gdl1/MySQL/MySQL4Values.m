/* 
   MySQL4Values.m

   Copyright (C) 1999-2005 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

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
#include "common.h"
#include <mysql/mysql.h>

@implementation MySQL4DataTypeMappingException

- (id)initWithObject:(id)_obj
  forAttribute:(EOAttribute *)_attr
  andMySQL4Type:(NSString *)_dt
  inChannel:(MySQL4Channel *)_channel;
{  
  NSDictionary *ui;
  NSString *typeName = nil;
  NSString *r;

  typeName = _dt;

  if (typeName == nil)
    typeName = [NSString stringWithFormat:@"Oid[%i]", _dt];

  r = [NSString stringWithFormat:
                              @"mapping between %@<Class:%@> and "
                              @"MySQL4 type %@ is not supported",
                              [_obj description],
                              NSStringFromClass([_obj class]),
		typeName];
  ui = [NSDictionary dictionaryWithObjectsAndKeys:
                                    _attr,    @"attribute",
                                    _channel, @"channel",
                                    _obj,     @"object",
		     nil];
  
  return [self initWithName:@"DataTypeMappingNotSupported" reason:r
	       userInfo:ui];
}

@end /* MySQL4DataTypeMappingException */

@implementation NSNull(MySQL4Values)

- (NSString *)stringValueForMySQL4Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
  return @"null";
}

@end /* NSNull(MySQL4Values) */

@implementation NSObject(MySQL4Values)

- (id)initWithMySQL4Field:(MYSQL_FIELD *)_field value:(const void *)_v length:(int)_len {
  /* Note: called for NSTemporaryString! */

  if (![self respondsToSelector:@selector(initWithUTF8String:)]) {
    if (_v == NULL) {
      [self release];
      return nil;
    }
    NSLog(@"WARNING(%s): %@ falling back to NSString for MySQL4 value"
          @" (type %i, 0x%p, len=%d)",
          __PRETTY_FUNCTION__, NSStringFromClass([self class]),
          _field->type, _v, _len);
    
    [self release];
    return [[NSString alloc] initWithMySQL4Field:_field value:_v length:_len];
  }

  /* we assume NSTemporaryString here */
  
  switch (_field->type) {
  case FIELD_TYPE_BLOB:
  case FIELD_TYPE_TINY_BLOB:
  case FIELD_TYPE_MEDIUM_BLOB:
  case FIELD_TYPE_LONG_BLOB:
    ; /* fall through */
    
  default:
    /* we always fallback to the UTF-8 string ... */
    return [(NSString *)self initWithUTF8String:_v];
  }
}

#if 0
- (id)initWithMySQL4Int:(int)_value {
  if ([self respondsToSelector:@selector(initWithInt:)])
    return [(NSNumber *)self initWithInt:_value];
  
  if ([self respondsToSelector:@selector(initWithDouble:)])
    return [(NSNumber *)self initWithDouble:_value];
  
  if ([self respondsToSelector:@selector(initWithString:)]) {
    NSString *s;
    char buf[256];

    sprintf(buf, "%i", _value);
    s = [[NSString alloc] initWithCString:buf];
    self = [(NSString *)self initWithString:s];
    [s release];
    return self;
  }
  
  [self release];
  return nil;
}

- (id)initWithMySQL4Double:(double)_value {
  if ([self respondsToSelector:@selector(initWithDouble:)])
    return [(NSNumber *)self initWithDouble:_value];
  
  [self release];
  return nil;
}

- (id)initWithMySQL4Text:(const unsigned char *)_value {
  if ([self respondsToSelector:@selector(initWithString:)]) {
    NSString *s;
    
    s = [[NSString alloc] initWithUTF8String:_value];
    self = [(NSString *)self initWithString:s];
    [s release];
    return self;
  }
  
  [self release];
  return nil;
}

- (id)initWithMySQL4Data:(const void *)_data length:(int)_length {
  if ([self respondsToSelector:@selector(initWithBytes:length:)])
    return [(NSData *)self initWithBytes:_data length:_length];
  
  if ([self respondsToSelector:@selector(initWithData:)]) {
    NSData *d;
    
    d = [[NSData alloc] initWithBytes:_data length:_length];
    self = [(NSData *)self initWithData:d];
    [d release];
    return self;
  }
  
  [self release];
  return nil;
}
#endif

@end /* NSObject(MySQL4Values) */

void __link_MySQL4Values() {
  // used to force linking of object file
  __link_MySQL4Values();
}
