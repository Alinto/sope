/* 
   NSCalendarDate+MySQL4Val.m

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


#import <Foundation/NSCalendarDate.h>
#include <mysql/mysql.h>
#include "MySQL4Channel.h"
#include "common.h"

#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSCalendarDate(UsedPrivates)
- (id)initWithTimeIntervalSince1970:(NSTimeInterval)_tv;
@end
#endif

static NSString *MYSQL4_DATETIME_FORMAT = @"%b %d %Y %I:%M:%S:000%p";

@implementation NSCalendarDate(MySQL4Values)

/*
  Format: '2001-07-26 14:00:00+02'
          '2001-07-26 14:00:00+09:30'
           0123456789012345678901234
  
  Matthew: "07/25/2003 06:00:00 CDT".
*/

static NSTimeZone *DefServerTimezone = nil;
#if 0
static NSTimeZone *gmt   = nil;
static NSTimeZone *gmt01 = nil;
static NSTimeZone *gmt02 = nil;
#endif

- (id)initWithMySQL4Field:(MYSQL_FIELD *)_field value:(const void *)_v length:(int)_len {
  NSString *s;
  NSString *calfmt;
  
  s      = [[NSString alloc] initWithCString:_v length:_len]; // Unicode
  calfmt = nil;

  // TODO: avoid using format strings
  
  switch (_len) { // as suggested by SQLClient
  case 14: calfmt = @"%Y%m%d%H%M%S"; break;
  case 12: calfmt = @"%y%m%d%H%M%S"; break;
  case 10: calfmt = @"%y%m%d%H%M";   break;
  case  8: calfmt = @"%y%m%d%H";     break;
  case  6: calfmt = @"%y%m%d";       break;
  case  4: calfmt = @"%y%m";         break;
  default:
    calfmt = _len > 14 ? @"%Y-%m-%d %H:%M:%S" : @"%y";
    break;
  }

  if ((self = [self initWithString:s calendarFormat:calfmt]) == nil) {
    NSLog(@"WARNING(%s): got no value for string '%@' format '%@'.",
	  __PRETTY_FUNCTION__, s, calfmt);
  }
  
  [s release];
  [self setCalendarFormat:MYSQL4_DATETIME_FORMAT];
  return self;
}

#if 0
- (id)initWithMySQL4Data:(const void *)_value length:(int)_length {
  static unsigned char buf[28]; // reused buffer, THREAD
  const char *_cstr = _value;
  unsigned char  *p;
  NSTimeZone     *attrTZ;
  NSCalendarDate *date;
  int            year, month, day, hour, min, sec, tzOffset;
  
  if (_length == 0)
    return nil;
  
  if (_length != 22 && _length != 25) {
    NSLog(@"ERROR(%s): unexpected date string '%s', returning now"
	  @" (expected format: '2001-07-26 14:00:00+02')", 
	  __PRETTY_FUNCTION__, _cstr);
    return [NSCalendarDate date];
  }
  strncpy(buf, _cstr, 25);
  buf[25] = '\0';
  
  /* perform on reverse, so that we don't overwrite with null-terminators */
  
  if (_length == 22) {
    p = &(buf[19]);
    tzOffset = atoi(p) * 60;
  }
  else if (_length >= 25) {
    int mins;
    p = &(buf[23]);
    mins = atoi(p);
    buf[22] = '\0'; // the ':'
    p = &(buf[19]);
    tzOffset = atoi(p) * 60;
    tzOffset = tzOffset > 0 ? (tzOffset + mins) : (tzOffset - mins);
  }
  
  p = &(buf[17]); buf[19] = '\0'; sec   = atoi(p);
  p = &(buf[14]); buf[16] = '\0'; min   = atoi(p);
  p = &(buf[11]); buf[13] = '\0'; hour  = atoi(p);
  p = &(buf[8]);  buf[10] = '\0'; day   = atoi(p);
  p = &(buf[5]);  buf[7]  = '\0'; month = atoi(p);
  p = &(buf[0]);  buf[4]  = '\0'; year  = atoi(p);
  
  /* TODO: cache all timezones (just 26 ;-) */
  switch (tzOffset) {
  case 0:
    if (gmt == nil) {
      gmt = [[NSTimeZone timeZoneForSecondsFromGMT:0] retain];
      NSAssert(gmt, @"could not create GMT timezone?!");
    }
    attrTZ = gmt;
    break;
  case 60:
    if (gmt01 == nil) {
      gmt01 = [[NSTimeZone timeZoneForSecondsFromGMT:3600] retain];
      NSAssert(gmt01, @"could not create GMT+01 timezone?!");
    }
    attrTZ = gmt01;
    break;
  case 120:
    if (gmt02 == nil) {
      gmt02 = [[NSTimeZone timeZoneForSecondsFromGMT:7200] retain];
      NSAssert(gmt02, @"could not create GMT+02 timezone?!");
    }
    attrTZ = gmt02;
    break;
    
  default: {
    /* cache the first, "alternative" timezone */
    static int firstTZOffset = 0; // can use 0 since GMT is a separate case
    static NSTimeZone *firstTZ = nil;
    if (firstTZOffset == 0) {
      firstTZOffset = tzOffset;
      firstTZ = [[NSTimeZone timeZoneForSecondsFromGMT:(tzOffset*60)] retain];
    }
    
    attrTZ = (firstTZOffset == tzOffset)
      ? firstTZ
      : [NSTimeZone timeZoneForSecondsFromGMT:(tzOffset * 60)];
    break;
  }
  }
  
  if (NSCalDateClass == Nil) NSCalDateClass = [NSCalendarDate class];
  date = [NSCalDateClass dateWithYear:year month:month day:day
			 hour:hour minute:min second:sec
			 timeZone:attrTZ];
  if (date == nil) {
    NSLog(@"ERROR(%s): could not construct date from string '%s': "
          @"year=%i,month=%i,day=%i,hour=%i,minute=%i,second=%i, tz=%@",
          __PRETTY_FUNCTION__, _cstr,
          year, month, day, hour, min, sec, attrTZ);
  }
  return date;
}
#endif

/* generating value */

- (NSString *)stringValueForMySQL4Type:(NSString *)_type
  attribute:(EOAttribute *)_attribute
{
#if 0
  NSString   *format;
#endif
  EOQuotedExpression *expr;
  NSTimeZone *serverTimeZone;
  NSString   *format;
  NSString   *val;
  unsigned len;
  unichar  c1;
  
  if ((len = [_type length]) == 0)
    c1 = 0;
  else
    c1 = [_type characterAtIndex:0];

  if (c1 == 'i' || c1 == 'I') { // INTEGER
    char buf[64];
    sprintf(buf, "%d", ((unsigned int)[self timeIntervalSince1970]));
    return [NSString stringWithCString:buf];
  }
  if (c1 == 'r' || c1 == 'R') { // REAL
    char buf[64]; // TODO: check format
    sprintf(buf, "%f", [self timeIntervalSince1970]);
    return [NSString stringWithCString:buf];
  }

  if ((serverTimeZone = [_attribute serverTimeZone]) == nil ) {
    if (DefServerTimezone == nil) {
      DefServerTimezone = [[NSTimeZone localTimeZone] retain];
      NSLog(@"Note: MySQL4 adaptor using timezone '%@' as default",
	    DefServerTimezone);
    }
    serverTimeZone = DefServerTimezone;
  }
  
#if 0
  format = [_attribute calendarFormat];
#else /* hm, why is that? */
  format = @"%Y-%m-%d %H:%M:%S%z";
#endif
  if (format == nil)
    format = MYSQL4_DATETIME_FORMAT;
  
  [self setTimeZone:serverTimeZone];
  
  val = [self descriptionWithCalendarFormat:format];
  expr = [[EOQuotedExpression alloc] initWithExpression:val
				     quote:@"\'" escape:@"\\'"];
  val = [[expr expressionValueForContext:nil] retain];
  [expr release];
  
  return [val autorelease];
}

@end /* NSCalendarDate(MySQL4Values) */
