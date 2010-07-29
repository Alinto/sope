/* 
   SQLiteValues.m

   Copyright (C) 1999-2005 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge@mdlink.de)

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

#import "SQLiteValues.h"
#import "common.h"

@implementation SQLiteDataTypeMappingException

- (id)initWithObject:(id)_obj
  forAttribute:(EOAttribute *)_attr
  andSQLite3Type:(NSString *)_dt
  inChannel:(SQLiteChannel *)_channel;
{  
  NSDictionary *ui;
  NSString *typeName = nil;
  NSString *r;

  typeName = _dt;

  if (typeName == nil)
    typeName = [NSString stringWithFormat:@"Oid[%i]", _dt];

  r = [NSString stringWithFormat:
                              @"mapping between %@<Class:%@> and "
                              @"SQLite type %@ is not supported",
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

@end /* SQLiteDataTypeMappingException */

@implementation NSNull(SQLiteValues)

- (NSString *)stringValueForSQLite3Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
  return @"null";
}

@end /* NSNull(SQLiteValues) */

@implementation NSObject(SQLiteValues)

- (id)initWithSQLiteInt:(int)_value {
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

- (id)initWithSQLiteDouble:(double)_value {
  if ([self respondsToSelector:@selector(initWithDouble:)])
    return [(NSNumber *)self initWithDouble:_value];
  
  [self release];
  return nil;
}

- (id)initWithSQLiteText:(const unsigned char *)_value {
  if ([self respondsToSelector:@selector(initWithString:)]) {
    NSString *s;
    
    s = [[NSString alloc] initWithUTF8String:(char *)_value];
    self = [(NSString *)self initWithString:s];
    [s release];
    return self;
  }
  
  [self release];
  return nil;
}

- (id)initWithSQLiteData:(const void *)_data length:(int)_length {
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

@end /* NSObject(SQLiteValues) */

void __link_SQLiteValues() {
  // used to force linking of object file
  __link_SQLiteValues();
}
