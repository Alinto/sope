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

#include "XmlRpcCoder.h"
#include "XmlRpcMethodCall.h"
#include "XmlRpcMethodResponse.h"
#include "common.h"

@interface NSMutableString(XmlRpcDecoder)
- (void)appendXmlRpcString:(NSString *)_value;
@end

@interface NSData(UsedNGExtensions)
- (NSData *)dataByEncodingBase64;
@end

@implementation XmlRpcEncoder

static NSTimeZone *gmt     = nil;
static BOOL profileOn      = NO;
static Class NSNumberClass = Nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  profileOn = [ud boolForKey:@"ProfileXmlRpcCoding"];
  gmt       = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];
  NSNumberClass = [NSNumber class];
}

- (id)initForWritingWithMutableString:(NSMutableString *)_string {
  if ((self = [super init])) {
    self->string = [_string retain];
    self->timeZone = [gmt retain];
  }
  return self;
}

- (void)dealloc {
  [self->string release];
  
  [self->objectStack release];
  [self->objectHasStructStack release];

  [self->timeZone release];
  [super dealloc];
}

- (BOOL)profileXmlRpcCoding {
  return profileOn;
}

/* accessors */

- (void)setDefaultTimeZone:(NSTimeZone *)_timeZone {
  [self->timeZone autorelease];
  self->timeZone = [_timeZone retain];
}

/*"
  This returns the timezone which will be associated with XML-RPC
  datetime objects. Note: XML-RPC datetime values have no! associated timezone,
  it's recommended that you always use UTC though.
"*/
- (NSTimeZone *)defaultTimeZone {
  return self->timeZone;
}

/* *** */

- (void)encodeMethodCall:(XmlRpcMethodCall *)_methodCall {
  NSEnumerator *paramEnum = [[_methodCall parameters] objectEnumerator];
  id           param;
  NSTimeInterval st     = 0.0;

  if ([self profileXmlRpcCoding])
    st = [[NSDate date] timeIntervalSince1970];
  
  [self->string appendString:@"<?xml version='1.0'?>"];
  [self->string appendString:@"<methodCall>"];
  
  [self->string appendString:@"<methodName>"];
  [self->string appendString:[_methodCall methodName]];
  [self->string appendString:@"</methodName>"];
  
  [self->string appendString:@"<params>"];
  
  while ((param = [paramEnum nextObject])) {
    [self->string appendString:@"<param>"];
    [self->string appendString:@"<value>"];

    [self encodeObject:param];
    
    [self->string appendString:@"</value>"];
    [self->string appendString:@"</param>"];
  }

  [self->string appendString:@"</params>"];
  [self->string appendString:@"</methodCall>"];

  if ([self profileXmlRpcCoding]) {
    NSTimeInterval diff;
    diff = [[NSDate date] timeIntervalSince1970] - st;
    
    printf("+++     encodeMethodCall: %0.5fs\n", diff);
  }
}

- (void)encodeMethodResponse:(XmlRpcMethodResponse *)_methodResponse {
  id result = [_methodResponse result];
  static Class ExceptionClass = Nil;
  NSTimeInterval st           = 0.0;

  if ([self profileXmlRpcCoding])
    st = [[NSDate date] timeIntervalSince1970];

  if (ExceptionClass == Nil)
    ExceptionClass = [NSException class];

  [self->string appendString:@"<?xml version='1.0'?>"];
  [self->string appendString:@"<methodResponse>"];

  if ([result isKindOfClass:ExceptionClass]) {
    [self->string appendString:@"<fault>"];
    [self->string appendString:@"<value>"];

    [self encodeObject:result];
    
    [self->string appendString:@"</value>"];
    [self->string appendString:@"</fault>"];
  }
  else {
    [self->string appendString:@"<params>"];
    [self->string appendString:@"<param>"];
    [self->string appendString:@"<value>"];

    [self encodeObject:result];
    
    [self->string appendString:@"</value>"];
    [self->string appendString:@"</param>"];
    [self->string appendString:@"</params>"];
  }

  [self->string appendString:@"</methodResponse>"];

  if ([self profileXmlRpcCoding]) {
    NSTimeInterval diff;
    diff = [[NSDate date] timeIntervalSince1970] - st;
    
    printf("+++ enocdeMethodResponse: %0.5fs\n", diff);
  }
}


- (void)_reset {
  [self->objectStack release];          self->objectStack          = nil;
  [self->objectHasStructStack release]; self->objectHasStructStack = nil;
}

- (void)_ensureStacks {
  if (self->objectStack == nil)
    self->objectStack = [[NSMutableArray alloc] initWithCapacity:8];
  if (self->objectHasStructStack == nil)
    self->objectHasStructStack = [[NSMutableArray alloc] initWithCapacity:8];
}

- (void)_encodeObject:(id)_object {
  if (_object) {
    [self _ensureStacks];
    [self->objectStack addObject:_object];
    [self->objectHasStructStack addObject:@"NO"];

    [_object encodeWithXmlRpcCoder:self];

    if ([[self->objectHasStructStack lastObject] boolValue]) {
      [self->string appendString:@"</struct>"];
    }
    [self->objectHasStructStack removeLastObject];
    [self->objectStack removeLastObject];
  }
}

- (NSString *)_className {
  id obj;
  
  if ((obj = [self->objectStack lastObject]) == nil)
    return nil;

  if ([obj isKindOfClass:[NSString class]])
    return @"NSString";
  
  return NSStringFromClass([obj classForCoder]);
}

- (void)encodeObject:(id)_obj {
  [self _encodeObject:_obj];
}

- (BOOL)isObjectClassAttributeEnabled {
  // adding of NSObjectClass removed due to compatibility issues !
  return NO;
}

- (void)_appendTagName:(NSString *)_tagName attributes:(NSDictionary *)_attrs {
  NSEnumerator *keyEnum   = [_attrs keyEnumerator];
  NSString     *key       = nil;
  
  [self->string appendString:@"<"];
  [self->string appendString:_tagName];
  
  if ([self isObjectClassAttributeEnabled]) {
    NSString *className = [self _className];
    
    if ([className length] > 0) {
      [self->string appendString:@" NSObjectClass=\""];
      [self->string appendXmlRpcString:className];
      [self->string appendString:@"\""];
    }
  }
  
  while ((key = [keyEnum nextObject])) {
    [self->string appendString:@" "];
    [self->string appendString:key];
    [self->string appendString:@"=\""];
    [self->string appendXmlRpcString:[_attrs objectForKey:key]];
    [self->string appendString:@"\""];
  }
  [self->string appendString:@">"];  
}

- (void)_appendTagName:(NSString *)_tagName {
  [self _appendTagName:_tagName attributes:nil];
}

- (void)_encodeNumber:(NSNumber *)_number tagName:(NSString *)_tagName {
  [self _appendTagName:_tagName];
  
  if ([_tagName isEqualToString:@"boolean"])
    [self->string appendString:[_number boolValue] ? @"1" : @"0"];
  else if ([_tagName isEqualToString:@"int"])
    [self->string appendFormat:@"%i", [_number intValue]];
  else
    [self->string appendXmlRpcString:[_number stringValue]];
  
  [self->string appendString:@"</"];
  [self->string appendString:_tagName];
  [self->string appendString:@">"];
  
}

- (void)encodeStruct:(NSDictionary *)_struct {
  NSEnumerator *keys = nil;
  id           key   = nil;
  
  [self _appendTagName:@"struct"];
  
  keys = [_struct keyEnumerator];
  while ((key = [keys nextObject])) {
    [self->string appendString:@"<member>"];
    
    [self->string appendString:@"<name>"];
    [self->string appendXmlRpcString:key];
    [self->string appendString:@"</name>"];

    [self->string appendString:@"<value>"];

    [self _encodeObject:[_struct objectForKey:key]];
    
    [self->string appendString:@"</value>"];
    
    [self->string appendString:@"</member>"];
  }
  
  [self->string appendString:@"</struct>"];
}

- (void)encodeArray:(NSArray *)_array {
  NSEnumerator    *valueEnum = [_array objectEnumerator];
  id value;

  [self _appendTagName:@"array"];

  [self->string appendString:@"<data>"];
  
  while ((value = [valueEnum nextObject])) {
    [self->string appendString:@"<value>"];

    [self _encodeObject:value];
    
    [self->string appendString:@"</value>"];
  }
  
  [self->string appendString:@"</data>"];
  [self->string appendString:@"</array>"];
}

- (void)encodeBase64:(NSData *)_data {
  NSString *base64;
  
  base64 = [[NSString alloc] initWithData:[_data dataByEncodingBase64]
                             encoding:NSASCIIStringEncoding];

  [self _appendTagName:@"base64"];
  [self->string appendString:base64];
  [self->string appendString:@"</base64>"];

  [base64 release]; base64 = nil;
}

- (void)encodeBoolean:(BOOL)_number {
  [self _encodeNumber:[NSNumberClass numberWithBool:_number] tagName:@"boolean"];
}
- (void)encodeInt:(int)_number {
  [self _encodeNumber:[NSNumberClass numberWithInt:_number] tagName:@"int"];
}
- (void)encodeDouble:(double)_number {
  [self _encodeNumber:[NSNumberClass numberWithDouble:_number] tagName:@"double"];
}

- (void)encodeString:(NSString *)_string {
  [self _appendTagName:@"string"];
  [self->string appendXmlRpcString:_string];
  [self->string appendString:@"</string>"];
}

- (void)encodeDateTime:(NSDate *)_date {
  static NSDictionary *attrs = nil;
  NSCalendarDate *date;
  NSString *s;
  
  if (attrs == nil) {
    attrs = [[NSDictionary alloc] 
              initWithObjectsAndKeys:@"GMT",@"timeZone",nil];
  }
  
  /* convert parameter to GMT */
  
#if LIB_FOUNDATION_LIBRARY
  /* TODO: not sure whether lF handles reference-date correctly ... */
  date = [[NSCalendarDate alloc] initWithTimeIntervalSince1970:
                                   [_date timeIntervalSince1970]];
#else
  date = [[NSCalendarDate alloc] initWithTimeIntervalSinceReferenceDate:
                                   [_date timeIntervalSinceReferenceDate]];
#endif
  [date setTimeZone:gmt];

  /* format in XML-RPC date format */
  
  s = [[NSString alloc] initWithFormat:@"%04i%02i%02iT%02i:%02i:%02i",
                 [date yearOfCommonEra], [date monthOfYear], [date dayOfMonth],
                 [date hourOfDay], [date minuteOfHour], [date secondOfMinute]];
  
  [date release]; date = nil;
  
  [self _appendTagName:@"dateTime.iso8601" attributes:attrs];
  [self->string appendString:s];
  [self->string appendString:@"</dateTime.iso8601>"];
  
  [s release];
}

- (void)_appendMember:(id)_obj forKey:(NSString *)_key selector:(SEL)_sel {
  [self _ensureStacks];
  
  if (![[self->objectHasStructStack lastObject] boolValue]) {
    [self->objectHasStructStack removeLastObject];
    [self->objectHasStructStack addObject:@"YES"];
    [self _appendTagName:@"struct"];
  }  
  if (_obj != nil) {
    [self->objectStack addObject:_obj];
    [self->string appendString:@"<member><name>"];
    [self->string appendString:_key];
    [self->string appendString:@"</name><value>"];
    
    /* 
      this does not work for int/double on OSX, since OSX doesn't coerce the
      argument to the receivers parameter type
    */
    [self performSelector:_sel withObject:_obj];
    
    [self->string appendString:@"</value></member>"];
    [self->objectStack removeLastObject];
  }
}
- (void)_appendInt:(int)_i forKey:(NSString *)_key selector:(SEL)_sel {
  /* special methods required for OSX */
  void (*m)(id,SEL,int);
  [self _ensureStacks];
  
  if (![[self->objectHasStructStack lastObject] boolValue]) {
    [self->objectHasStructStack removeLastObject];
    [self->objectHasStructStack addObject:@"YES"];
    [self _appendTagName:@"struct"];
  }  
  
  [self->objectStack addObject:[NSNumberClass numberWithInt:_i]];
  [self->string appendString:@"<member><name>"];
  [self->string appendString:_key];
  [self->string appendString:@"</name><value>"];
  
  m = (void *)[self methodForSelector:_sel];
  m(self, _sel, _i);
  
  [self->string appendString:@"</value></member>"];
  [self->objectStack removeLastObject];
}
- (void)_appendDouble:(double)_d forKey:(NSString *)_key selector:(SEL)_sel {
  /* special methods required for OSX */
  void (*m)(id,SEL,double);
  [self _ensureStacks];
  
  if (![[self->objectHasStructStack lastObject] boolValue]) {
    [self->objectHasStructStack removeLastObject];
    [self->objectHasStructStack addObject:@"YES"];
    [self _appendTagName:@"struct"];
  }  
  
  [self->objectStack addObject:[NSNumberClass numberWithDouble:_d]];
  [self->string appendString:@"<member><name>"];
  [self->string appendString:_key];
  [self->string appendString:@"</name><value>"];
  
  m = (void *)[self methodForSelector:_sel];
  m(self, _sel, _d);
  
  [self->string appendString:@"</value></member>"];
  [self->objectStack removeLastObject];
}

- (void)encodeStruct:(NSDictionary *)_struct forKey:(NSString *)_key {
  [self _appendMember:_struct forKey:_key selector:@selector(encodeStruct:)];
}
- (void)encodeArray:(NSArray *)_array  forKey:(NSString *)_key {
  [self _appendMember:_array forKey:_key selector:@selector(encodeArray:)];
}
- (void)encodeBase64:(NSData *)_data forKey:(NSString *)_key {
  [self _appendMember:_data forKey:_key selector:@selector(encodeBase64:)];
}
- (void)encodeBoolean:(BOOL)_number forKey:(NSString *)_key {
  [self _appendInt:(int)_number forKey:_key selector:@selector(encodeBoolean:)];
}
- (void)encodeInt:(int)_number forKey:(NSString *)_key {
  [self _appendInt:_number forKey:_key selector:@selector(encodeInt:)];
}
- (void)encodeDouble:(double)_number forKey:(NSString *)_key {
  [self _appendDouble:_number forKey:_key selector:@selector(encodeDouble:)];
}
- (void)encodeString:(NSString *)_string forKey:(NSString *)_key {
  [self _appendMember:_string forKey:_key selector:@selector(encodeString:)];
}
- (void)encodeDateTime:(NSDate *)_date forKey:(NSString *)_key {
  [self _appendMember:_date forKey:_key selector:@selector(encodeDateTime:)];
}
- (void)encodeObject:(id)_object forKey:(NSString *)_key {
  [self _appendMember:_object forKey:_key selector:@selector(encodeObject:)];
}

@end /* XmlRpcEncoder */
