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

#include "../common.h"
#include <NGExtensions/NSCalendarDate+misc.h>

static NSString *JSDateFormat = @"%a, %d %b %Y %H:%M:%S %Z";

@implementation NSDate(NGJavaScript)
@end /* NSDate(NGJavaScript) */

@implementation NSObject(DateCreation)

- (NSTimeZone *)jsDateTimeZone {
  return [NSTimeZone defaultTimeZone];
}

- (id)_jsfunc_SkyDate:(NSArray *)_args {
  unsigned count;
  NSCalendarDate *date;
  NSTimeZone     *tz;
  
  tz = [self jsDateTimeZone];
  
  if ((count = [_args count]) == 0) {
    date = [NSCalendarDate date];
  }
  else if (count == 1) {
    // new Date( milliseconds)
    // new Date( dateString)
    id arg0;

    arg0 = [_args objectAtIndex:0];
    
    if ([arg0 isKindOfClass:[NSNumber class]]) {
      NSTimeInterval ti;

      ti = [arg0 unsignedIntValue] * 1000.0;
      date = [NSCalendarDate dateWithTimeIntervalSince1970:ti];
    }
    else {
      /* 1. "Mon, 25 Dec 1995 13:30:00 GMT". */
      /* 2. "2001-01-04 13:23:45 GMT" */

      arg0 = [arg0 stringValue];
      date = [NSCalendarDate dateWithString:arg0 calendarFormat:JSDateFormat];
      if (date == nil) {
        date = [NSCalendarDate dateWithString:arg0
                               calendarFormat:@"%Y-%m-%d %H:%M:%S %Z"];
      }
    }
  }
  else {
    // new Date( yr_num, mo_num, day_num[, hr_num, min_num, sec_num])
    short year = 2000, month = 1, day = 1, hour = 0, minute = 0, second = 0;

    if (count > 5) second = [[_args objectAtIndex:5] intValue];
    if (count > 4) minute = [[_args objectAtIndex:4] intValue];
    if (count > 3) hour   = [[_args objectAtIndex:3] intValue];
    if (count > 2) day    = [[_args objectAtIndex:2] intValue];
    if (count > 1) month  = ([[_args objectAtIndex:1] intValue] + 1);
    if (count > 0) year   = [[_args objectAtIndex:0] intValue];
    
    if (year < 100) year += 1900;
    
    date = [[NSCalendarDate alloc] initWithYear:year month:month day:day
                                   hour:hour minute:minute second:second
                                   timeZone:tz];
    AUTORELEASE(date);
  }
  
  [date setTimeZone:tz];
  [date setCalendarFormat:JSDateFormat];
  return date;
}

@end /* NSObject(DateCreation) */

@implementation NSCalendarDate(NGJavaScript)

static NSNumber *shortNum(short num) {
  static NSNumber *zero = nil;

  switch (num) {
    case 0:
      if (zero == nil) zero = [[NSNumber numberWithShort:num] retain];
      return zero;
    default:
      return [NSNumber numberWithShort:num];
  }
}

- (id)_jsfunc_getDate:(NSArray *)_args {
  return shortNum([self dayOfMonth]);
}
- (id)_jsfunc_getDay:(NSArray *)_args {
  return shortNum([self dayOfWeek]);
}
- (id)_jsfunc_getFullYear:(NSArray *)_args {
  return shortNum([self yearOfCommonEra]);
}
- (id)_jsfunc_getYear:(NSArray *)_args {
  return shortNum([self yearOfCommonEra] - 1900);
}
- (id)_jsfunc_getHours:(NSArray *)_args {
  return shortNum([self hourOfDay]);
}
- (id)_jsfunc_getMilliseconds:(NSArray *)_args {
  return shortNum(0);
}
- (id)_jsfunc_getMinutes:(NSArray *)_args {
  return shortNum([self minuteOfHour]);
}
- (id)_jsfunc_getMonth:(NSArray *)_args {
  /* JS counts from 0 to 11 */
  return shortNum([self monthOfYear] - 1);
}
- (id)_jsfunc_getSeconds:(NSArray *)_args {
  return shortNum([self secondOfMinute]);
}
- (id)_jsfunc_getTime:(NSArray *)_args {
  return [NSNumber numberWithInt:(int)[self timeIntervalSince1970]];
}
- (id)_jsfunc_getTimezoneOffset:(NSArray *)_args {
  return shortNum([[self timeZone] secondsFromGMTForDate:self]);
}

/* UTC */

- (NSCalendarDate *)_utcDate {
  NSCalendarDate *d;
  
  d = [[self copy] autorelease];
  [d setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
  return d;
}

- (id)_jsfunc_getUTCDate:(NSArray *)_args {
  return shortNum([[self _utcDate] dayOfMonth]);
}
- (id)_jsfunc_getUTCDay:(NSArray *)_args {
  return shortNum([[self _utcDate] dayOfWeek]);
}
- (id)_jsfunc_getUTCFullYear:(NSArray *)_args {
  return shortNum([[self _utcDate] yearOfCommonEra]);
}
- (id)_jsfunc_getUTCHours:(NSArray *)_args {
  return shortNum([[self _utcDate] hourOfDay]);
}
- (id)_jsfunc_getUTCMilliseconds:(NSArray *)_args {
  return shortNum(0);
}
- (id)_jsfunc_getUTCMinutes:(NSArray *)_args {
  return shortNum([[self _utcDate] minuteOfHour]);
}
- (id)_jsfunc_getUTCMonth:(NSArray *)_args {
  /* JS counts from 0 to 11 */
  return shortNum([[self _utcDate] monthOfYear] - 1);
}
- (id)_jsfunc_getUTCSeconds:(NSArray *)_args {
  return shortNum([[self _utcDate] secondOfMinute]);
}

/* descriptions */

- (id)_jsfunc_toGMTString:(NSArray *)_args {
  return [[self _utcDate] descriptionWithCalendarFormat:JSDateFormat];
}
- (id)_jsfunc_toUTCString:(NSArray *)_args {
  return [[self _utcDate] descriptionWithCalendarFormat:JSDateFormat];
}
- (id)_jsfunc_toLocaleString:(NSArray *)_args {
  return [self descriptionWithCalendarFormat:JSDateFormat];
}

- (id)_jsfunc_toString:(NSArray *)_args {
  return [self _jsfunc_toGMTString:_args];
}

/* NGJavaScript additions */

- (id)_jsfunc_getWeekOfMonth:(NSArray *)_args {
  return shortNum([self weekOfMonth]);
}
- (id)_jsfunc_getWeekOfYear:(NSArray *)_args {
  return shortNum([self weekOfYear]);
}
- (id)_jsfunc_getNumberOfWeeksInYear:(NSArray *)_args {
  return shortNum([self numberOfWeeksInYear]);
}
- (id)_jsfunc_getNumberOfDaysInMonth:(NSArray *)_args {
  return shortNum([self numberOfDaysInMonth]);
}

- (id)_jsfunc_getFirstDayOfMonth:(NSArray *)_args {
  return [self firstDayOfMonth];
}
- (id)_jsfunc_getLastDayOfMonth:(NSArray *)_args {
  return [self lastDayOfMonth];
}
- (id)_jsfunc_getMondayOfWeek:(NSArray *)_args {
  return [self mondayOfWeek];
}
- (id)_jsfunc_getBeginOfDay:(NSArray *)_args {
  return [self beginOfDay];
}
- (id)_jsfunc_getEndOfDay:(NSArray *)_args {
  return [self endOfDay];
}

- (id)_jsfunc_isDateOnSameDay:(NSArray *)_args {
  unsigned count;

  if ((count = [_args count]) == 0)
    return nil;

  return [self isDateOnSameDay:[_args objectAtIndex:0]]
    ? [NSNumber numberWithBool:YES]
    : [NSNumber numberWithBool:NO];
}
- (id)_jsfunc_isDateInSameWeek:(NSArray *)_args {
  unsigned count;

  if ((count = [_args count]) == 0)
    return nil;

  return [self isDateInSameWeek:[_args objectAtIndex:0]]
    ? [NSNumber numberWithBool:YES]
    : [NSNumber numberWithBool:NO];
}

- (id)_jsfunc_isToday:(NSArray *)_args {
  return [self isToday]
    ? [NSNumber numberWithBool:YES]
    : [NSNumber numberWithBool:NO];
}
- (id)_jsfunc_isForenoon:(NSArray *)_args {
  return [self isForenoon]
    ? [NSNumber numberWithBool:YES]
    : [NSNumber numberWithBool:NO];
}
- (id)_jsfunc_isAfternoon:(NSArray *)_args {
  return [self isAfternoon]
    ? [NSNumber numberWithBool:YES]
    : [NSNumber numberWithBool:NO];
}

- (id)_jsfunc_getYesterday:(NSArray *)_args {
  return [self yesterday];
}
- (id)_jsfunc_getTomorrow:(NSArray *)_args {
  return [self tomorrow];
}

- (id)_jsfunc_getNextYear:(NSArray *)_args {
  return [self nextYear];
}
- (id)_jsfunc_getLastYear:(NSArray *)_args {
  return [self lastYear];
}

- (id)_jsfunc_getDateByAdding:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0)
    return [[self copy] autorelease];
  
  if (count <= 3) {
    short year = 0, month = 0, day = 0;

    if (count > 0) year  = [[_args objectAtIndex:0] intValue];
    if (count > 1) month = [[_args objectAtIndex:1] intValue];
    if (count > 2) day   = [[_args objectAtIndex:2] intValue];
    
    return [self dateByAddingYears:year months:month days:day];
  }
  
  return nil;
}

@end /* NSCalendarDate(NGJavaScript) */
