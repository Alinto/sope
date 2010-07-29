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

#include "NSString+ICal.h"
#include "common.h"
#include <ical.h>

@implementation NSString(ICalCString)

- (const char *)icalCString {
  NSStringEncoding enc;
  
  enc = [[self class] libicalStringEncoding];
  
  if (enc == NSUTF8StringEncoding)
    return [self UTF8String];
  else if (enc == [NSString defaultCStringEncoding])
    return [self cString];
  else
    return [[self dataUsingEncoding:enc] bytes];
}

- (NSString *)icalString {
  return self;
}

@end /* NSString(ICalCString) */

@implementation NSObject(TemporaryStringInit)

+ (NSStringEncoding)libicalStringEncoding {
  return NSUTF8StringEncoding;
}

- (id)initWithICalCString:(const char *)_cstr {
  NSStringEncoding enc;

  if (_cstr == NULL) {
    RELEASE(self);
    return nil;
  }
  
  enc = [[self class] libicalStringEncoding];
  
  if (enc == NSUTF8StringEncoding)
    return [(NSString *)self initWithUTF8String:_cstr];
  else if (enc == [[self class] defaultCStringEncoding])
    return [(NSString *)self initWithCString:_cstr];
  else {
    NSData *d;
    
    d = [[NSData alloc] initWithBytes:_cstr length:strlen(_cstr)];
    self = [(NSString *)self initWithData:d encoding:enc];
    RELEASE(d);
    
    return self;
  }
  
  return nil;
}

- (id)initWithICalValueHandle:(icalvalue *)_handle {
  const char *s;
  
  if (_handle == NULL) {
    RELEASE(self);
    return nil;
  }
  if ((s = icalvalue_as_ical_string(_handle)) == NULL) {
    RELEASE(self);
    return nil;
  }
  return [self initWithICalCString:s];
}

- (id)initWithICalValueOfProperty:(icalproperty *)_prop {
  icalvalue *val;

  if (_prop == nil) {
    RELEASE(self);
    return nil;
  }
  
  if ((val = icalproperty_get_value(_prop)) == NULL) {
    NSLog(@"%s: ical property has no value ??", __PRETTY_FUNCTION__);
    RELEASE(self);
    return nil;
  }
  
  return [self initWithICalValueHandle:val];
}

@end /* NSObject(TemporaryStringInit) */

