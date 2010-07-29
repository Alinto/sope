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

#include <XmlRpc/XmlRpcMethodResponse.h>
#include <XmlRpc/XmlRpcCoder.h>
#include <XmlRpc/NSObject+XmlRpc.h>
#include "common.h"

@interface NSObject(Misc)
- (id)initWithString:(NSString *)_s;
@end

@interface NSString(XmlRpcParsing)
- (id)initWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars
  length:(int)_len;
@end

@interface NSDate(XmlRpcParsing)
- (id)initWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars
  length:(int)_len;
@end

@interface NSNumber(XmlRpcParsing)
- (id)initWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars
  length:(int)_len;
@end

@interface NSData(XmlRpcParsing)
- (id)initWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars
  length:(int)_len;
@end

@interface NSData(UsedNGExtensions)
- (NSData *)dataByDecodingBase64;
@end

@implementation NSObject(XmlRpcParsing)

- (id)initWithXmlRpcCoder:(XmlRpcDecoder *)_coder {
  NSClassDescription *cd;
  
  if ((cd = [self classDescription])) {
    NSEnumerator *e;
    NSString     *k;

    if ((self = [self init])) {
      e = [[cd attributeKeys] objectEnumerator];
      while ((k = [e nextObject]))
        [self takeValue:[_coder decodeObjectForKey:k] forKey:k];
    
      e = [[cd toOneRelationshipKeys] objectEnumerator];
      while ((k = [e nextObject]))
        [self takeValue:[_coder decodeObjectForKey:k] forKey:k];
    
      e = [[cd toManyRelationshipKeys] objectEnumerator];
      while ((k = [e nextObject]))
        [self takeValue:[_coder decodeArrayForKey:k] forKey:k];
    }
  }
  else if ([self respondsToSelector:@selector(initWithString:)]) {
    self = [(id)self initWithString:[_coder decodeString]];
  }
  else {
    [NSException raise:@"XmlRpcCodingException"
                 format:
                 @"in initWithXmlRpcCoder: cannot decode class '%@'",
                 NSStringFromClass([self class])];
    [self release];
    return nil;
  }
  return self;
}
+ (id)decodeObjectWithXmlRpcCoder:(XmlRpcDecoder *)_decoder {
  return [[[self alloc] initWithXmlRpcCoder:_decoder] autorelease];
}

- (NSString *)xmlRpcType {
  return @"struct";
}

- (void)encodeWithXmlRpcCoder:(XmlRpcEncoder *)_coder {
  NSClassDescription *cd;
  
  if ((cd = [self classDescription])) {
    NSEnumerator *e;
    NSString     *k;
    
    e = [[cd attributeKeys] objectEnumerator];
    while ((k = [e nextObject]))
      [_coder encodeObject:[self valueForKey:k] forKey:k];
    
    e = [[cd toOneRelationshipKeys] objectEnumerator];
    while ((k = [e nextObject]))
      [_coder encodeObject:[self valueForKey:k] forKey:k];
    
    e = [[cd toManyRelationshipKeys] objectEnumerator];
    while ((k = [e nextObject]))
      [_coder encodeArray:[self valueForKey:k] forKey:k];
  }
  else if ([self respondsToSelector:@selector(initWithString:)]) {
    [_coder encodeString:[self description]];
  }
  else {
    [NSException raise:@"XmlRpcCodingException"
                 format:
                   @"in encodeWithXmlRpcCoder: "
                   @"cannot encode class '%@', object=%@B",
                 NSStringFromClass([self class]), self];
  }
}

+ (id)objectWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars length:(int)_len
{
  static NSDictionary *typeToClass = nil;
  Class ObjClass = Nil;
  id obj;

  if ([@"nil" isEqualToString:_type]) /* Python with allow_none */
    return nil;
  
  if (typeToClass == nil) {
    typeToClass = [[NSDictionary alloc] initWithObjectsAndKeys:
                                          [NSNumber class], @"i4",
                                          [NSNumber class], @"int",
                                          [NSNumber class], @"double",
                                          [NSNumber class], @"boolean",
                                          [NSString class], @"string",
                                          [NSString class], @"value",
                                          [NSData   class], @"base64",
                                          [NSCalendarDate class],
                                          @"dateTime.iso8601",
                                          nil];
  }
  
  /* determine basetype class */
  
  if ((ObjClass = [typeToClass objectForKey:_type]) == Nil) {
    NSLog(@"WARNING(%s): unknown XML-RPC type '%@', using String ...",
          __PRETTY_FUNCTION__, _type);
    ObjClass = [NSString class];
  }
  
  /* construct object */
  
  obj =
    [[ObjClass alloc] initWithXmlRpcType:_type characters:_chars length:_len];
  return [obj autorelease];
}

- (id)initWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars length:(int)_len
{
  if ([self respondsToSelector:@selector(initWithString:)]) {
    NSString *s;

    s = [[NSString alloc] initWithCharacters:_chars length:_len];
    self = [self initWithString:s];
    [s release];
    return self;
  }
  
  /* don't know how to init with given type ... */
  [self release];
  return nil;
}

@end /* NSObject(XmlRpc) */

@implementation NSData(XmlRpcParsing)

/* NSData represents the xml-rpc base type 'base64' */

- (id)initWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars length:(int)_len
{
  NSString *v;

  [self release]; self = nil;
  
  v    = [NSString stringWithCharacters:_chars length:_len];
  self = [v dataUsingEncoding:NSUTF8StringEncoding];
  
  if ([_type isEqualToString:@"base64"])
    self = [self dataByDecodingBase64];
  
  return [self copy];
}

@end /* NSData(XmlRpcParsing) */

@implementation NSDate(XmlRpcParsing)

/* NSDate represents the xml-rpc type dateTime.iso8601: */
- (id)initWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars length:(int)_len
{
  /* eg 19980717T14:08:55 */
  if (_len < 17) {
    [self release];
    return nil;
  }
  
  {
    unsigned char buf[8];
    int year, month, day, hour, min, sec;
        
    buf[0] = _chars[0]; buf[1] = _chars[1];
    buf[2] = _chars[2]; buf[3] = _chars[3];
    buf[4] = '\0';
    year = atoi((char *)buf);
    buf[0] = _chars[4]; buf[1] = _chars[5]; buf[2] = '\0';
    month = atoi((char *)buf);
    buf[0] = _chars[6]; buf[1] = _chars[7]; buf[2] = '\0';
    day = atoi((char *)buf);

    buf[0] = _chars[9]; buf[1] = _chars[10]; buf[2] = '\0';
    hour = atoi((char *)buf);
    buf[0] = _chars[12]; buf[1] = _chars[13]; buf[2] = '\0';
    min = atoi((char *)buf);
    buf[0] = _chars[15]; buf[1] = _chars[16]; buf[2] = '\0';
    sec = atoi((char *)buf);
    
    if (year > 2033) {
      NSString *s;

      s = [[NSString alloc] initWithCharacters:_chars length:_len];
      NSLog(@"WARNING: got a date value '%@' with year >2033, "
            @"which cannot be represented, silently using 2033  ...",
            s);
      [s release];
      year = 2033;
    }
    else if (year < 1900) {
      NSString *s;

      s = [[NSString alloc] initWithCharacters:_chars length:_len];
      NSLog(@"WARNING: got a date value '%@' with year < 1900, "
            @"which cannot be represented, silently using 1900  ...",
            s);
      [s release];
      year = 1900;
    }
    
    if (![self isKindOfClass:[NSCalendarDate class]]) {
      [self release];
      self = [NSCalendarDate alloc];
    }
    
    return [(NSCalendarDate *)self
                              initWithYear:year month:month day:day
                              hour:hour minute:min second:sec
                              timeZone:[NSTimeZone timeZoneWithName:@"GMT"]];
  }
}

@end /* NSDate(XmlRpcParsing) */

@implementation NSNumber(XmlRpcParsing)

/* NSNumber represents the xml-rpc base types: 'int', 'double', 'boolean': */

- (id)initWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars length:(int)_len
{
  if ([_type isEqualToString:@"boolean"]) {
    BOOL v;
      
    v = (_len > 0)
      ? ((_chars[0] == '1') ? YES : NO)
      : NO;
    return [self initWithBool:v];
  }
  else {
    NSString *v;
    BOOL isInt = NO;
    
    v = [NSString stringWithCharacters:_chars length:_len];
    
    if ([_type isEqualToString:@"i4"] || [_type isEqualToString:@"int"])
      isInt = YES;
    else if ([_type isEqualToString:@"double"])
      isInt = NO;
    else
      isInt = ([v rangeOfString:@"."].length == 0) ? YES : NO;
    
    return isInt
      ? [self initWithInt:[v intValue]]
      : [self initWithDouble:[v doubleValue]];
  }
}

@end /* NSNumber(XmlRpcParsing */


@implementation NSString(XmlRpcParsing)

- (id)initWithXmlRpcType:(NSString *)_type
  characters:(unichar *)_chars length:(int)_len
{
  /* this is *never* called, since NSString+alloc returns a NSTemporaryString*/
  return [self initWithCharacters:_chars length:_len];
}

@end /* NSString(XmlRpcParsing) */
