/* 
   FBValues.m

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge.hess@mdlink.de)

   This file is part of the FB Adaptor Library

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
// $Id: FBValues.m 1 2004-08-20 10:38:46Z znek $

#include <string.h>
#if HAVE_STRINGS_H
#  include <strings.h>
#endif
#include <stdlib.h>
#import "common.h"
#include "FBException.h"
#import <Foundation/NSDate.h>

static Class NumberClass = Nil;

@interface FBDataTypeMappingException : FrontBaseException
@end

@interface NSTimeZone(UsedPrivates)
- (NSTimeZoneDetail *)timeZoneDetailForDate:(NSDate *)_date;
@end

@implementation FBDataTypeMappingException

- (id)initWithObject:(id)_obj forAttribute:(EOAttribute *)_attr
  andFrontBaseType:(int)_fb inChannel:(FrontBaseChannel *)_channel
{
  NSString *typeName = nil;

  typeName =
    [(id)[[_channel adaptorContext] adaptor] externalNameForTypeCode:_fb];

  if (typeName == nil)
    typeName = [NSString stringWithFormat:@"Type[%i]", _fb];
  
  [self setName:@"FBDataTypeMappingNotSupported"];
  [self setReason:[NSString stringWithFormat:
                              @"mapping between %@<Class:%@> and "
                              @"frontbase type %@ is not supported",
                              [_obj description],
                              NSStringFromClass([_obj class]),
                              typeName]];

  [self setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                    _attr,    @"attribute",
                                    _channel, @"channel",
                                    _obj,     @"object",
                                    nil]];
  return self;
}

@end /* FBDataTypeMappingException */

static inline void FmtRaiseMapExc(id _object,
                                  int _fb,
                                  EOAttribute *_attribute,
                                  id _channel) {
  NSLog(@"%s: FmtRaiseMapExc objectClass=%@ object=%@ "
        @"type=%i typeName=%@ attribute=%@",
        __PRETTY_FUNCTION__,
        NSStringFromClass([_object class]),
        _object,
        _fb,
        [(id)[[_channel adaptorContext] adaptor] externalNameForTypeCode:_fb],
        _attribute);
  
  [[[FBDataTypeMappingException alloc]
                                     initWithObject:_object
                                     forAttribute:_attribute
                                     andFrontBaseType:_fb
                                     inChannel:_channel] raise];
}
static inline void RaiseMapExc(id _object, int _type,
                               EOAttribute *_attribute,
                               id _channel) {
  NSLog(@"%s: RaiseMapExc objectClass=%@ object=%@ type=%i name=%@ attribute=%@",
        __PRETTY_FUNCTION__,
        NSStringFromClass([_object class]),
        _object,
        _type,
        [(id)[[_channel adaptorContext] adaptor] externalNameForTypeCode:_type],
        _attribute);
  
  [[[FBDataTypeMappingException alloc]
                                     initWithObject:_object
                                     forAttribute:_attribute
                                     andFrontBaseType:_type
                                     inChannel:_channel] raise];
}

@implementation NSString(FBValues)

+ (id)valueFromBytes:(const char *)_bytes length:(unsigned)_length
  frontBaseType:(int)_fb attribute:(EOAttribute *)_attribute
  adaptorChannel:(FrontBaseChannel *)_channel
{
  id result = nil;
    
  switch (_fb) {
    case FB_Character:
    case FB_VCharacter:
      result = [self stringWithCString:_bytes length:_length];
      break;

    case FB_BLOB:
    case FB_CLOB:
      result = [self stringWithCString:_bytes length:_length];
      break;

    case FB_SmallInteger:
      result = [NSString stringWithFormat:@"%i", *(short *)_bytes];
      break;
    case FB_Integer:
      result = [NSString stringWithFormat:@"%i", *(int *)_bytes];
      break;

    case FB_Real:
    case FB_Double:
      result = [NSString stringWithFormat:@"%g", *(double *)_bytes];
      break;

    case FB_Float:
      result = [NSString stringWithFormat:@"%g", *(float *)_bytes];
      break;
      
    default:
      FmtRaiseMapExc(self, _fb, _attribute, _channel);
  }

  return result;
}

- (NSData *)dataValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute
{
  /* NSString */
  return [NSData dataWithBytes:[self cString] length:[self cStringLength]];
}

- (NSString *)stringValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute
{
  /* NSString */
  switch (_type) {
    case FB_BLOB:
      return [[NSData dataWithBytes:[self cString] length:[self cStringLength]]
                      stringValueForFrontBaseType:_type attribute:_attribute];

    case FB_Character:
    case FB_VCharacter:
    case FB_CLOB: {
      id expr = nil;

      expr = [[[EOQuotedExpression alloc] initWithExpression:self
                                          quote:@"'" escape:@"''"]
                                   autorelease];
      expr = [expr expressionValueForContext:nil];
      return expr;
    }
     
    case FB_Bit:
    case FB_SmallInteger:
    case FB_Integer:
    case FB_Real:
    case FB_Double:
    case FB_Numeric:
    case FB_Decimal:
      /* NSLog(@"returning %@ for number type", self); */
      return self;
  }

  RaiseMapExc(self, _type, _attribute, nil);
  
  NSLog(@"impossible condition reached: %@", self);
  abort();
  return nil;
}

@end /* NSString(FBValues) */

@implementation NSNumber(FBValues)
  
#define ReturnNumber(sybtype, def) {\
  if (valueType == -1) \
    return [NumberClass def *(sybtype*)_bytes]; \
  else if (valueType == 'c') \
    return [NumberClass numberWithChar:*(sybtype*)_bytes]; \
  else if (valueType == 'C') \
    return [NumberClass numberWithUnsignedChar:*(sybtype*)_bytes]; \
  else if (valueType == 's') \
    return [NumberClass numberWithShort:*(sybtype*)_bytes]; \
  else if (valueType == 'S') \
    return [NumberClass numberWithUnsignedShort:*(sybtype*)_bytes]; \
  else if (valueType == 'i') \
    return [NumberClass numberWithInt:*(sybtype*)_bytes]; \
  else if (valueType == 'I') \
    return [NumberClass numberWithUnsignedInt:*(sybtype*)_bytes]; \
  else if (valueType == 'f') \
    return [NumberClass numberWithFloat:*(sybtype*)_bytes]; \
  else if (valueType == 'd') \
    return [NumberClass numberWithDouble:*(sybtype*)_bytes]; \
  else \
    [NSException raise:@"InvalidValueTypeException" \
                 format:@"value type %c is not recognized", valueType];\
    return nil; \
  }

+ (id)valueFromBytes:(const char *)_bytes length:(unsigned)_length
  frontBaseType:(int)_fb attribute:(EOAttribute *)_attribute
  adaptorChannel:(FrontBaseChannel *)_channel
{
  char valueType;

  if ([_attribute valueType])
    valueType = [[_attribute valueType] cString][0];
  else
    valueType = -1;
  
  switch (_fb) {
    case FB_Character:
    case FB_VCharacter: {
      switch (valueType) {
        case 'c': return [NumberClass numberWithChar:atoi(_bytes)];
        case 'C': return [NumberClass numberWithUnsignedChar:atol(_bytes)];
        case 's': return [NumberClass numberWithShort:atoi(_bytes)];
        case 'S': return [NumberClass numberWithUnsignedShort:atol(_bytes)];
        case 'i': return [NumberClass numberWithInt:atoi(_bytes)];
        case 'I': return [NumberClass numberWithUnsignedInt:atol(_bytes)];
        case 'f': return [NumberClass numberWithFloat:atof(_bytes)];
        case 'd': return [NumberClass numberWithDouble:atof(_bytes)];
        default:
          [NSException raise:@"InvalidValueTypeException"
                       format:@"value type %c is not recognized",
                         valueType];
          return nil;
      }
    }

    case FB_Boolean: {
      unsigned char v;
      v = *(unsigned char *)_bytes;
      return [NumberClass numberWithBool:v];
    }
      
    case FB_Integer: {
      int v;
      v = *(int *)_bytes;
      return [NumberClass numberWithInt:v];
    }
    case FB_SmallInteger: {
      short v;
      v = *(short *)_bytes;
      return [NumberClass numberWithShort:v];
    }

    case FB_Real:
    case FB_Double:
      ReturnNumber(double, numberWithDouble:);

    case FB_Float:
      ReturnNumber(float, numberWithFloat:);

    case FB_Numeric:
    case FB_Decimal:
#if 0
      if (_fmt->scale > 0) {
        ReturnNumber(CS_REAL, numberWithDouble:);
      }
      else {
        ReturnNumber(int, numberWithInt:);
      }
#endif
      ReturnNumber(double, numberWithDouble:);

    default:
      FmtRaiseMapExc(self, _fb, _attribute, _channel);
  }

  [NSException raise:@"InvalidFrontBaseValueStateException"
               format:@"reached invalid state in sybase NSNumber handler"];

  return nil;
}

#undef ReturnNumber

- (NSData *)dataValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute
{
  RaiseMapExc(self, _type, _attribute, nil);
  return nil;
}

- (NSString *)stringValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute
{
  /* NSNumber */
  switch (_type) {
    case FB_Boolean:
    case FB_Bit:
    case FB_SmallInteger:
    case FB_Integer:
    case FB_Real:
    case FB_Float:
    case FB_Numeric:
    case FB_Decimal:
      return [self stringValue];
      
    case FB_Character:
    case FB_VCharacter:
      return [NSString stringWithFormat:@"'%s'", [[self stringValue] cString]];
      
    default:
      RaiseMapExc(self, _type, _attribute, nil);
  }
  return nil;
}

@end /* NSNumber(FBValues) */

@implementation NSData(FBValues)

+ (id)valueFromBytes:(const char *)_bytes length:(unsigned)_length
  frontBaseType:(int)_fb attribute:(EOAttribute *)_attribute
  adaptorChannel:(FrontBaseChannel *)_channel
{
  switch (_fb) {
    case FB_Bit:
    case FB_SmallInteger:
    case FB_Integer:
    case FB_Real:
    case FB_Float:
    case FB_Numeric:
    case FB_Decimal:
    case FB_Character:
    case FB_VCharacter:
    case FB_BLOB:
    case FB_CLOB:
      return [[[self alloc] initWithBytes:_bytes length:_length] autorelease];

    default:
      FmtRaiseMapExc(self, _fb, _attribute, _channel);
  }
  return nil;
}

- (NSData *)dataValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute
{
  return self;
}

- (NSString *)stringValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute
{
  switch (_type) {
    case FB_Boolean:
      return [[NumberClass numberWithChar:*(char *)[self bytes]] stringValue];
      
    case FB_SmallInteger:
      return [[NumberClass numberWithShort:*(short *)[self bytes]] stringValue];
      
    case FB_Integer:
      return [[NumberClass numberWithInt:*(int *)[self bytes]] stringValue];

    case FB_Real:
    case FB_Double:
      return [[NumberClass numberWithDouble:*(double *)[self bytes]]
                           stringValue];

    case FB_Float:
      return [[NumberClass numberWithFloat:*(float *)[self bytes]] stringValue];

    case FB_Character:
    case FB_VCharacter:
    case FB_CLOB:
    case FB_BLOB: {
      unsigned   final_length = [self length];
      char       *cstr = NULL, *tmp = NULL;
      unsigned   cnt;
      const char *iBytes = [self bytes];

      if (final_length == 0) return @"NULL";

      final_length = 2 + 2 * final_length + 1;
      cstr = objc_atomic_malloc(final_length + 4);
      tmp = cstr + 2;

      cstr[0] = '\0';
      strcat(cstr, "0x");

      for (cnt = 0; cnt < [self length]; cnt++, tmp += 2)
        sprintf(tmp, "%02X", (unsigned char)iBytes[cnt]);
      *tmp = '\0';

      return [[[NSString alloc] initWithCStringNoCopy:cstr length:cstr?strlen(cstr):0 freeWhenDone:YES] autorelease];
    }
      
    default:
      RaiseMapExc(self, _type, _attribute, nil);
  }
  return nil;
}

@end /* NSData(FBValues) */

//                 1234567890123456789012345
// Frontbase Date: 1997-10-21 21:52:26+08:00
static NSString *FRONTBASE_DATE_FORMAT = @"%Y-%m-%d %H:%M:%S%z";

@implementation NSDate(FBValues)

+ (id)valueFromBytes:(const char *)_bytes length:(unsigned)_length
  frontBaseType:(int)_fb attribute:(EOAttribute *)_attribute
  adaptorChannel:(FrontBaseChannel *)_channel
{
  /* NSDate */
  return [NSCalendarDate valueFromBytes:_bytes length:_length
                         frontBaseType:_fb attribute:_attribute
                         adaptorChannel:_channel];
}

- (NSData *)dataValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attr
{
  /* NSDate */
  NSCalendarDate *cdate;

  cdate = [NSCalendarDate dateWithTimeIntervalSince1970:
                            [self timeIntervalSince1970]];
  
  return [cdate dataValueForFrontBaseType:_type attribute:_attr];
}

- (NSString *)stringValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attr
{
  /* NSDate */
  NSCalendarDate *cdate;

  cdate = [NSCalendarDate dateWithTimeIntervalSince1970:
                            [self timeIntervalSince1970]];
  
  return [cdate stringValueForFrontBaseType:_type attribute:_attr];
}

@end

@implementation NSCalendarDate(FBValues)

+ (id)valueFromBytes:(const char *)_bytes length:(unsigned)_length
  frontBaseType:(int)_fb attribute:(EOAttribute *)_attribute
  adaptorChannel:(FrontBaseChannel *)_channel
{
  /* NSCalendarDate */
  switch (_fb) {
    case FB_TimestampTZ: {
      /* a string of length 25 */
      NSCalendarDate *date;
      NSString *str, *stampstr, *tzstr;

#if DEBUG
      NSAssert2(_length >= 25,
		@"byte values for date creation are too short "
		@"(len required is 25, got %i), attribute=%@",
               _length, _attribute);
      
      if (_length != 25) {
        NSLog(@"WARNING: invalid length, should be '25', got %i, attribute %@",
              _length, _attribute);
      }
#endif

      stampstr = [NSString stringWithCString:_bytes length:19];
      tzstr    = [NSString stringWithCString:(_bytes + 19) length:3];
      str      = [NSString stringWithCString:(_bytes + 23) length:2];
      tzstr    = [tzstr stringByAppendingString:str];
      str      = [stampstr stringByAppendingString:tzstr];

      date = [NSCalendarDate dateWithString:str
                             calendarFormat:FRONTBASE_DATE_FORMAT];
#if DEBUG
      if (date == nil) {
        NSLog(@"ERROR: couldn't construct calendar date from "
              @"string %@ (src=%@) column %@.%@ "
              @"(%i bytes), format=%@",
              str, [NSString stringWithCString:_bytes length:19],
              [[_attribute entity] externalName],
              [_attribute columnName],
              _length, date);
      }
#if 0
      else {
        NSLog(@"info: could construct calendar date from string %@ (len=%i)",
              str, _length);
      }
#endif
#endif
      return date;
    }
    
    case FB_Character:
    case FB_VCharacter:
    case FB_Date:
    case FB_Timestamp: {
      NSTimeZone     *serverTimeZone;
      NSCalendarDate *date;
      NSString       *formattedDate;
      NSString       *format;

      formattedDate = [NSString stringWithCString:_bytes length:_length];

      serverTimeZone = [_attribute serverTimeZone];
      format         = [_attribute calendarFormat];
      
      if (serverTimeZone == nil)
        serverTimeZone = [NSTimeZone localTimeZone];
      if (format == nil)
        format = FRONTBASE_DATE_FORMAT;

      date = [NSCalendarDate dateWithString:formattedDate
                             calendarFormat:format];
      if (date == nil) {
        NSLog(@"ERROR(%s): could not construct date from "
              @"value '%@' with format '%@'",
              __PRETTY_FUNCTION__, formattedDate, format);
      }
      return date;
    }
    
    default:
      FmtRaiseMapExc(self, _fb, _attribute, _channel);
  }
  return nil;
}

- (NSData *)dataValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attr
{
  /* NSCalendarDate */
  RaiseMapExc(self, _type, _attr, nil);
  return nil;
}

- (NSString *)stringValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attr
{
  /* NSCalendarDate */

  self = [self copy]; /* copy to rescue timezone setting */
  [self autorelease];
  
  switch (_type) {
    case FB_TimestampTZ: {
      NSTimeZone *serverTimeZone;
      NSString *str;
      NSTimeInterval timeZoneOffset;
      int i, j;

      serverTimeZone = [_attr serverTimeZone];

      if (serverTimeZone == nil)
        serverTimeZone = [NSTimeZone localTimeZone];
      
#if NeXT_Foundation_LIBRARY
      timeZoneOffset = [serverTimeZone secondsFromGMTForDate:self];
#else
      timeZoneOffset = [[serverTimeZone timeZoneDetailForDate:self]
                                        timeZoneSecondsFromGMT];
#endif

      [self setTimeZone:serverTimeZone];
      
      i = timeZoneOffset > 0;
      j = (timeZoneOffset > 0 ? timeZoneOffset : -timeZoneOffset) / 60;

      str = [NSString stringWithFormat:
                        @"TIMESTAMP '%02i-%02i-%02i %02i:%02i:%02i%s%02i:%02i'",
                        [self yearOfCommonEra],
                        [self monthOfYear],
                        [self dayOfMonth],
                        [self hourOfDay],
                        [self minuteOfHour],
                        [self secondOfMinute],
                        i ? "+":"-",
                        j / 60, j % 60];
      return str;
    }
    
    case FB_Date: {
      NSTimeZone *serverTimeZone;
      NSString   *format;
      id         expr;

      serverTimeZone = [_attr serverTimeZone];
      format         = [_attr calendarFormat];
      expr           = nil;
      
      if (serverTimeZone == nil)
        serverTimeZone = [NSTimeZone localTimeZone];
      
      if (format == nil)
        format = FRONTBASE_DATE_FORMAT;

      [self setTimeZone:serverTimeZone];
      
      expr = [self descriptionWithCalendarFormat:format];
      expr = [[EOQuotedExpression alloc] initWithExpression:expr
                                         quote:@"'" escape:@"''"];
      [expr autorelease];
      expr = [expr expressionValueForContext:nil];
      expr = [@"TIMESTAMP " stringByAppendingString:expr];

      return expr;
    }
    
    default:
      RaiseMapExc(self, _type, _attr, nil);
  }
  return nil;
}

@end /* NSCalendarDate(FBValues) */

@implementation EONull(FBValues)

- (NSData *)dataValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attr
{
  return nil;
}

- (NSString *)stringValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attr
{
  return @"null";
}

@end /* EONull(FBValues) */

void __init_FBValues(void) {
  NumberClass = [NSNumber class];
}

void __link_FBValues() {
  // used to force linking of object file
  __link_FBValues();
  __init_FBValues();
}
