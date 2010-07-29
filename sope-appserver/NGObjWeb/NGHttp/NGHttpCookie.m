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

#import "common.h"
#import "NGHttpCookie.h"

@implementation NGHttpCookie

// abbr weekday, day-of-month, abbr-month, year hour:min:sec GMT
static NSString *cookieDateFormat =  @"%a, %d-%b-%Y %H:%M:%S %Z";

+ (id)cookieWithName:(NSString *)_name {
  return [[[self alloc] initWithName:_name value:nil] autorelease];
}

- (id)initWithName:(NSString *)_name value:(id)_value {
  if ((self = [super init])) {
    self->name  = [_name copy];
    self->value = [_value retain];
  }
  return self;
}

- (void)dealloc {
  [self->name       release];
  [self->value      release];
  [self->expireDate release];
  [self->path       release];
  [self->domainName release];
  [super dealloc];
}

// accessors

- (void)setCookieName:(NSString *)_name {
  if (_name != self->name) {
    [self->name autorelease];
    self->name = [_name copy];
  }
}
- (NSString *)cookieName {
  return self->name;
}

- (void)setValue:(id)_value {
  if (_value != self->value) {
    [self->value autorelease];
    self->value = [_value retain];
  }
}
- (id)value {
  return self->value;
}

- (void)addAdditionalValue:(id)_value {
  if (![self->value isKindOfClass:[NSMutableArray class]]) {
    NSMutableArray *array = [[NSMutableArray alloc] init];

    if (self->value) [array addObject:self->value];
    [self->value release];

    self->value = array;
  }

  NSAssert([self->value isKindOfClass:[NSMutableArray class]],
           @"invalid object state, value should be mutable array");

  if (_value)
    [self->value addObject:_value];
}

- (void)setExpireDate:(NSDate *)_date {
  if (_date != self->expireDate) {
    [self->expireDate autorelease];
    self->expireDate = [_date copy];
  }
}
- (NSDate *)expireDate {
  return self->expireDate;
}
- (BOOL)doesExpireWhenUserSessionEnds {
  return (self->expireDate == nil) ? YES : NO;
}

- (void)setPath:(NSString *)_path {
  if (_path != self->path) {
    RELEASE(self->path);
    self->path = [_path copyWithZone:[self zone]];
  }
}
- (NSString *)path {
  return self->path;
}

- (void)setDomainName:(NSString *)_domainName {
  if (_domainName != self->domainName) {
    RELEASE(self->domainName);
    self->domainName = [_domainName copyWithZone:[self zone]];
  }
}
- (NSString *)domainName {
  return self->domainName;
}

- (void)setNeedsSecureChannel:(BOOL)_flag {
  self->onlyIfSecure = _flag;
}
- (BOOL)needsSecureChannel {
  return self->onlyIfSecure;
}

/* description */

- (NSString *)stringValue {
  NSMutableString *str = [NSMutableString stringWithCapacity:64];
  
  [str appendString:[self->name stringByEscapingURL]];
  [str appendString:@"="];
  [str appendString:[[self->value stringValue] stringByEscapingURL]];

  if (self->expireDate) {
    // TODO: may deliver in wrong timezone due to buggy NSDate
    NSString *s;
    [str appendString:@"; expires="];
    s = [self->expireDate
	     descriptionWithCalendarFormat:cookieDateFormat
	     timeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]
	     locale:nil];
    [str appendString:s];
  }
  if (self->path) {
    [str appendString:@"; path="];
    [str appendString:self->path];
  }
  if (self->domainName) {
    [str appendString:@"; domain="];
    [str appendString:self->domainName];
  }
  if (self->onlyIfSecure)
    [str appendString:@"; secure"];

  return str;
}

- (NSString *)description {
  NSMutableString *str = [NSMutableString stringWithCapacity:128];

  [str appendFormat:@"<%@[0x%p]: name=%@ value=%@",
         NSStringFromClass([self class]), self,
         self->name, self->value];

  if (self->expireDate) {
    [str appendString:@" expires="];
    [str appendString:[self->expireDate description]];
  }
  
  if (self->path) {
    [str appendString:@" path="];
    [str appendString:self->path];
  }
  if (self->domainName) {
    [str appendString:@" domain="];
    [str appendString:self->domainName];
  }
  if (self->onlyIfSecure)
    [str appendString:@" secure"];

  [str appendString:@">"];

  return str;
}

@end /* NGHttpCookie */
