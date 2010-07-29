/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "NSCalendarDate+ICal.h"
#include "common.h"
#ifdef XCODE_BUILD
#import <libical/ical.h>
#else
#include <ical.h>
#endif

static NSTimeZone *gmt = nil;
static inline void _setupGMT(void) {
  if (gmt == nil)
    gmt = [[NSTimeZone timeZoneWithAbbreviation:@"GMT"] retain];
}

@implementation NSCalendarDate(ICalValue)

- (NSTimeZone *)timeZoneFromICalTime:(struct icaltimetype *)_dt
  defaultTimeZone:(NSTimeZone *)_tz
{
  _setupGMT();

  if (_dt->is_utc)
    return gmt;

  if (_tz)
    return _tz;
  
  NSLog(@"WARNING(%s): using localtimezone !", __PRETTY_FUNCTION__);
  return [NSTimeZone localTimeZone];
}

- (id)initWithICalDate:(struct icaltimetype)_dt timeZone:(NSTimeZone *)_tz {
  NSTimeZone *tz;
  
  tz = [self timeZoneFromICalTime:&_dt defaultTimeZone:_tz];
  
  self = [self initWithYear:_dt.year month:_dt.month day:_dt.day
               hour:12 minute:0 second:0
               timeZone:_tz];
  return self;
}

- (id)initWithICalTime:(struct icaltimetype)_dt timeZone:(NSTimeZone *)_tz {
  NSTimeZone *tz;
  
  if (_dt.is_date)
    return [self initWithICalDate:_dt timeZone:_tz];
  
  tz = [self timeZoneFromICalTime:&_dt defaultTimeZone:_tz];
  
  
  self = [self initWithYear:_dt.year month:_dt.month day:_dt.day
               hour:_dt.hour minute:_dt.minute second:_dt.second
               timeZone:tz];
  return self;
}

- (id)initWithICalDate:(struct icaltimetype)_dt {
  _setupGMT();
  return [self initWithICalDate:_dt timeZone:gmt];
}
- (id)initWithICalTime:(struct icaltimetype)_dt {
  _setupGMT();
  return [self initWithICalTime:_dt timeZone:gmt];
}

- (id)initWithICalValueHandle:(icalvalue *)_handle {
  if (_handle == NULL) {
    RELEASE(self);
    return nil;
  }
  return [self initWithICalTime:icalvalue_get_datetime(_handle)];
}
- (id)initWithICalValueOfProperty:(icalproperty *)_prop {
  icalvalue *val;
  
  if (_prop == NULL) {
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

/* durations */

- (NSCalendarDate *)dateByApplyingICalDuration:(struct icaldurationtype)_dur {
  if (_dur.is_neg) {
    return [self dateByAddingYears:0 months:0
                 days:-(_dur.days + (_dur.weeks * 7))
                 hours:-(_dur.hours)
                 minutes:-(_dur.minutes)
                 seconds:-(_dur.seconds)];
  }
  else {
    return [self dateByAddingYears:0 months:0
                 days:(_dur.days + (_dur.weeks * 7))
                 hours:_dur.hours minutes:_dur.minutes seconds:_dur.seconds];
  }
}

/* represention */

static NSString *gmtcalfmt = @"%Y%m%dT%H%M00Z";

- (NSString *)icalStringInGMT {
  NSTimeZone *oldtz;
  NSString   *s;
  _setupGMT();
  
  /* set GMT as timezone */
  oldtz = [[self timeZone] retain];
  if (oldtz == gmt) {
    [oldtz release];
    oldtz = nil;
  }
  else {
    [self setTimeZone:gmt];
  }
  
  /* calc string */
  s = [self descriptionWithCalendarFormat:gmtcalfmt];
  
  /* restore old timezone */
  if (oldtz) {
    [self setTimeZone:oldtz];
    [oldtz release];
  }
  
  return s;
}

- (NSString *)icalStringWithTimeZone:(NSTimeZone *)_tz {
  _setupGMT();
  
  if (_tz == gmt || _tz == nil)
    return [self icalStringInGMT];
  else if ([_tz isEqual:gmt])
    return [self icalStringInGMT];
  else {
    /* not in GMT */
    NSLog(@"WARNING(%s): arbitary timezones not supported yet: %@",
          __PRETTY_FUNCTION__, _tz);
    return [self icalStringInGMT];
  }
}

- (NSString *)icalString {
  _setupGMT();
  return [self icalStringWithTimeZone:gmt];
}

@end /* NSDate(ICalValue) */
