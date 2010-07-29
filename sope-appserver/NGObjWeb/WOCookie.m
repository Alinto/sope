/*
  Copyright (C) 2000-2008 SKYRIX Software AG

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

#include <NGObjWeb/WOCookie.h>
#include "common.h"

@interface WOCookie(PrivateMethods)

- (id)initWithName:(NSString *)_name value:(NSString *)_value
  path:(NSString *)_path domain:(NSString *)_domain
  expires:(NSDate *)_date
  isSecure:(BOOL)_secure;

@end

@implementation WOCookie

static WOCookie *_parseCookie(const char *_bytes, unsigned _len);

// abbr weekday, day-of-month, abbr-month, year hour:min:sec GMT
static NSString *cookieDateFormat =  @"%a, %d-%b-%Y %H:%M:%S %Z";

+ (id)cookieWithString:(NSString *)_string {
  /* private method ! */
  const char *utf8 = [_string UTF8String];
  if (utf8 == NULL) return nil;
  return _parseCookie(utf8, strlen(utf8));
}

+ (id)cookieWithName:(NSString *)_name value:(NSString *)_value {
  return [[[self alloc] initWithName:_name value:_value
                        path:nil domain:nil
                        expires:nil isSecure:NO]
                        autorelease];
}

+ (id)cookieWithName:(NSString *)_name value:(NSString *)_value
  path:(NSString *)_path domain:(NSString *)_domain
  expires:(NSDate *)_date
  isSecure:(BOOL)_secure
{
  return [[[self alloc] initWithName:_name value:_value
                        path:_path domain:_domain
                        expires:_date isSecure:_secure]
                        autorelease];
}

- (id)initWithName:(NSString *)_name value:(NSString *)_value
  path:(NSString *)_path domain:(NSString *)_domain
  expires:(NSDate *)_date
  isSecure:(BOOL)_secure
{
  if ((self = [super init]) != nil) {
    NSZone *z = [self zone];
    self->name         = [_name   copyWithZone:z];
    self->value        = [_value  copyWithZone:z];
    self->path         = [_path   copyWithZone:z];
    self->domainName   = [_domain copyWithZone:z];
    self->expireDate   = [_date   retain]; // TBD: should be copy?
    self->onlyIfSecure = _secure;
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

/* accessors */

- (NSString *)cookieName {
  /* ?? */
  return self->name;
}

- (void)setName:(NSString *)_name {
  ASSIGNCOPY(self->name, _name);
}
- (NSString *)name {
  return self->name;
}

- (void)setValue:(NSString *)_value {
  ASSIGNCOPY(self->value, _value);
}
- (NSString *)value {
  return self->value;
}

- (void)setPath:(NSString *)_path {
  ASSIGNCOPY(self->path, _path);
}
- (NSString *)path {
  return self->path;
}

- (void)setExpires:(NSDate *)_date {
  ASSIGNCOPY(self->expireDate, _date);
}
- (NSDate *)expires {
  return self->expireDate;
}

- (void)setDomain:(NSString *)_domain {
  ASSIGNCOPY(self->domainName, _domain);
}
- (NSString *)domain {
  return self->domainName;
}

- (void)setIsSecure:(BOOL)_flag {
  self->onlyIfSecure = _flag ? YES : NO;
}
- (BOOL)isSecure {
  return self->onlyIfSecure;
}

- (NSDate *)expireDate {
  // DEPRECATED
  return self->expireDate;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [[WOCookie alloc] initWithName:self->name value:self->value 
			   path:self->path domain:self->domainName
			   expires:self->expireDate
			   isSecure:self->onlyIfSecure];
}

/* description */

- (NSString *)headerString {
  return [@"set-cookie: " stringByAppendingString:[self stringValue]];
}

- (NSString *)stringValue {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:512];
  [str appendString:[self->name stringByEscapingURL]];
  [str appendString:@"="];
  [str appendString:[[self->value stringValue] stringByEscapingURL]];
  
  if (self->expireDate) {
    static NSTimeZone *gmt = nil;
    static NSMutableDictionary *localeDict = nil;
    NSString *s;
    if (gmt == nil) 
      gmt = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];
    if (localeDict == nil)
      {
        localeDict = [NSMutableDictionary new];

        [localeDict setObject: [NSArray arrayWithObjects: @"Jan", @"Feb",
                                        @"Mar", @"Apr", @"May", @"Jun",
                                        @"Jul", @"Aug", @"Sep", @"Oct",
                                        @"Nov", @"Dec", nil]
                       forKey: @"NSShortMonthNameArray"];
        [localeDict setObject: [NSArray arrayWithObjects: @"Sun", @"Mon",
                                        @"Tue", @"Wed", @"Thu", @"Fri",
                                        @"Sat", nil]
                       forKey: @"NSShortWeekDayNameArray"];
      }
   
    // TODO: replace, -descriptionWithCalendarFormat is *slow*
    s = [self->expireDate descriptionWithCalendarFormat:cookieDateFormat
                          timeZone:gmt
	                  locale:localeDict];
    
    [str appendString:@"; expires="];
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
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:128];
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

/* cookie parsing */

static WOCookie *_parseCookie(const char *_bytes, unsigned _len) {
  WOCookie *cookie   = nil;
  unsigned pos, toGo;
  
  for (pos = 0, toGo = _len; (toGo > 0) && (_bytes[pos] != '='); toGo--, pos++)
    ;

  if (toGo > 0) {
    NSString *name   = nil;
    NSString *value  = nil;

    // NSLog(@"pos=%i toGo=%i", pos, toGo);
    
    name  = [[NSString alloc]
                       initWithCString:_bytes
                       length:pos];
    value = [[NSString alloc]
                       initWithCString:&(_bytes[pos + 1])
                       length:(toGo - 1)];
    
    //NSLog(@"pair='%@'", [NSString stringWithCString:_bytes length:_len]);
    //NSLog(@"name='%@' value='%@'", name, value);
    
    if ((name == nil) || (value == nil)) {
      NSLog(@"ERROR: invalid cookie pair%s%s: %@",
            value ? "" : ", no value",
            name  ? "" : ", no name",
            [NSString stringWithCString:_bytes length:_len]);
      [name  release];
      [value release];
      return nil;
    }
    else {
      cookie = [WOCookie cookieWithName:[name stringByUnescapingURL]
                         value:[value stringByUnescapingURL]];
    }
    
    [name  release];  name  = nil;
    [value release]; value = nil;
  }
#if DEBUG
  else {
    NSLog(@"ERROR(%s:%i): invalid cookie pair: %@",
          __PRETTY_FUNCTION__, __LINE__,
          [NSString stringWithCString:_bytes length:_len]);
  }
#endif
  return cookie;
}

@end /* WOCookie */
