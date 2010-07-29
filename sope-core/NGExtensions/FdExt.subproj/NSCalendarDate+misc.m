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

#include "NSCalendarDate+misc.h"
#include "common.h"
#include <math.h>

#define NUMBER_OF_SECONDS_IN_DAY (24 * 60 * 60)

@implementation NSCalendarDate(misc)

+ (NSCalendarDate *)mondayOfWeek:(int)_weekNumber inYear:(int)_year
  timeZone:(NSTimeZone *)_tz
{
  NSCalendarDate *janFirst;
  
  janFirst  = [NSCalendarDate dateWithYear:_year month:1 day:1 
                            hour:0 minute:0 second:0
                            timeZone:_tz];
  return [janFirst mondayOfWeek:_weekNumber];
}

- (NSCalendarDate *)mondayOfWeek:(int)_weekNumber {
  NSCalendarDate *mondayOfWeek;
  short          lastWeek;
  
  mondayOfWeek = [self firstMondayAndLastWeekInYear:&lastWeek];
  
  if (_weekNumber == 1)
    return mondayOfWeek;
  
  return [mondayOfWeek dateByAddingYears:0
                       months:0
                       days:(7 * (_weekNumber - 1))];
}

+ (NSArray *)mondaysOfYear:(int)_year timeZone:(NSTimeZone *)_tz {
  NSCalendarDate *janFirst;
  
  janFirst  = [NSCalendarDate dateWithYear:_year month:1 day:1 
                            hour:0 minute:0 second:0
                            timeZone:_tz];
  return [janFirst mondaysOfYear];
}

- (NSArray *)mondaysOfYear {
  NSArray        *array;
  NSMutableArray *mondays;
  NSCalendarDate *mondayOfWeek;
  short          lastWeek;
  int            i;
  
  mondayOfWeek = [self firstMondayAndLastWeekInYear:&lastWeek];
  mondays = [[NSMutableArray alloc] initWithCapacity:55];
  
  for (i = 0; i < lastWeek; i++) {
#if 0 // hh: can someone explain this ?!
    if (i > 0) {
      mondayOfWeek =
        [mondayOfWeek addYear:0 month:0 day:7 hour:0 minute:0 second:0];
    }
    mondayOfWeek = [[mondayOfWeek copy] autorelease];
    [mondays addObject:mondayOfWeek];
#else
    NSCalendarDate *tmp;
    tmp = [mondayOfWeek dateByAddingYears:0 months:0 days:(i * 7)];
    [mondays addObject:tmp];
#endif
  }
  
  array = [mondays copy];
  [mondays release];
  return [array autorelease];
}

- (NSCalendarDate *)firstMondayAndLastWeekInYear:(short *)_lastWeek {
  NSTimeZone     *tz;
  int            currentYear;
  short          lastWeek;
  NSCalendarDate *janFirst;
  NSCalendarDate *silvester;
  NSCalendarDate *mondayOfWeek;
  
  tz          = [self timeZone];
  currentYear = [self yearOfCommonEra];
  
  if ([self weekOfYear] == 53) {
    NSCalendarDate *nextJanFirst = nil;

    nextJanFirst = [NSCalendarDate dateWithYear:(currentYear + 1)
                                 month:1 day:1
                                 hour:0 minute:0 second:0
                                 timeZone:tz];

    if ([nextJanFirst weekOfYear] == 1)
      currentYear++;
  }
  
  janFirst  = [NSCalendarDate dateWithYear:currentYear
                            month:1 day:1
                            hour:0 minute:0 second:0
                            timeZone:tz];
  silvester = [NSCalendarDate dateWithYear:currentYear
                            month:12 day:31
                            hour:23 minute:59 second:59
                            timeZone:tz];

  lastWeek = [silvester weekOfYear];

  if (lastWeek == 53) {
    NSCalendarDate *nextJanFirst = nil;
    
    nextJanFirst = [NSCalendarDate dateWithYear:currentYear+1
                                 month:1 day:1
                                 hour:0 minute:0 second:0
                                 timeZone:tz];
    
    if ([nextJanFirst weekOfYear] == 1)
      lastWeek = 52;
  }
  
  if ([janFirst weekOfYear] != 1) {
    mondayOfWeek = [janFirst mondayOfWeek];
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
    mondayOfWeek =
      [mondayOfWeek dateByAddingYears:0 months:0 days:7 
		    hours:0 minutes:0 seconds:0];
#else
    mondayOfWeek =
      [mondayOfWeek addYear:0 month:0 day:7 hour:0 minute:0 second:0];
#endif
  }
  else {
    mondayOfWeek = [janFirst mondayOfWeek];
  }

  if (_lastWeek) *_lastWeek = lastWeek;
  return mondayOfWeek;
}

- (NSCalendarDate *)firstDayOfMonth {
  NSTimeInterval tv;
  NSCalendarDate *first;
  int            dayOfMonth;
  NSTimeZone     *tz;
  
  dayOfMonth = [self dayOfMonth];
  tz = [self timeZone];
  
  tv = (1 - dayOfMonth) * NUMBER_OF_SECONDS_IN_DAY;
  tv = [self timeIntervalSince1970] + tv;
  first = [NSCalendarDate dateWithTimeIntervalSince1970:tv];
  [first setTimeZone:tz];
  return first;
}

- (NSCalendarDate *)lastDayOfMonth {
  int offset = [self numberOfDaysInMonth] - [self dayOfMonth];
  return [self dateByAddingYears:0 months:0 days:offset];
}

- (int)numberOfDaysInMonth {
  static int leapYearMonths[12] = {31,29,31,30,31,30,31,31,30,31,30,31};
  static int nonLeapYearMonths[12] = {31,28,31,30,31,30,31,31,30,31,30,31};
  int *numberOfDaysInMonth = [self isInLeapYear] ? leapYearMonths :
                                                   nonLeapYearMonths;
  return numberOfDaysInMonth[[self monthOfYear] - 1];
}

- (BOOL)isInLeapYear
{
  unsigned year = [self yearOfCommonEra];
  return (((year % 4) == 0) && ((year % 100) != 0)) || ((year % 400) == 0);
}

- (int)weekOfMonth {
  /* returns 1-6 */
  int dayOfMonth;
  int weekOfYear;
  int firstWeekOfYear;
  
  dayOfMonth = [self dayOfMonth]; /* 1-31 */
  if (dayOfMonth == 1)
    return 1;

  /* could be done smarter (by calculating on dayOfWeek) */
  weekOfYear      = [self weekOfYear];
  firstWeekOfYear = [[self firstDayOfMonth] weekOfYear];
  
  return (weekOfYear - firstWeekOfYear + 1);
}

- (int)weekOfYear {
  static int whereToStart[] = { 6, 7, 8, 9, 10, 4, 5 };
  NSCalendarDate *janFirst;
  int            year, day, weekOfYear;
  NSTimeZone     *tz;
  
  year = [self yearOfCommonEra];
  day  = [self dayOfYear] - 1; 
  
  tz = [self timeZone];

  janFirst  = [NSCalendarDate dateWithYear:year month:1 day:1 
                            hour:0 minute:0 second:0
                            timeZone:tz];
  
  weekOfYear = (day + whereToStart[[janFirst dayOfWeek]]) / 7;

  if (weekOfYear == 0) {
    NSCalendarDate *silvesterLastYear;

    silvesterLastYear = [NSCalendarDate dateWithYear:(year - 1)
                                      month:12 day:31 
                                      hour:0 minute:0 second:0
                                      timeZone:tz];
    return [silvesterLastYear weekOfYear];
  }
  
#if 0  
  if (weekOfYear == 53) {
    NSCalendarDate *nextJanFirst = nil;
    int            janYear       = year + 1;
    int            janDay;
    int            week;

    nextJanFirst = [NSCalendarDate dateWithYear:janYear
                                 month:1 day:1
                                 hour:0 minute:0 second:0
                                 timeZone:[self timeZone]];

    janDay = [nextJanFirst dayOfYear];
    week   = (janDay + whereToStart[[nextJanFirst dayOfWeek]]) / 7;

    if (week == 1)
      return 52;
  }
#endif  
  return weekOfYear;
}

- (short)numberOfWeeksInYear {
  NSCalendarDate *silvester;
  NSCalendarDate *dayOfLastWeek;
  NSTimeZone     *tz;
  short currentYear;

  currentYear = [self yearOfCommonEra];
  tz          = [self timeZone];

  silvester = [NSCalendarDate dateWithYear:currentYear
                              month:12 day:31
                              hour:23 minute:59 second:59
                              timeZone:tz];
  dayOfLastWeek = [silvester dateByAddingYears:0 months:0 days:-3 hours:0
                             minutes:0 seconds:0];

  return [dayOfLastWeek weekOfYear];
}

- (NSCalendarDate *)mondayOfWeek {
  NSTimeInterval tv;
  NSCalendarDate *monday;
  int            dayOfWeek;
  NSTimeZone     *tz;
  
  dayOfWeek = [self dayOfWeek];
  tz = [self timeZone];
  
  if (dayOfWeek == 0) dayOfWeek = 7; // readjust Sunday
  
  tv = (1 - dayOfWeek) * NUMBER_OF_SECONDS_IN_DAY;
  tv = [self timeIntervalSince1970] + tv;
  monday = [NSCalendarDate dateWithTimeIntervalSince1970:tv];
  [monday setTimeZone:tz];
  return monday;
}

- (NSCalendarDate *)beginOfDay {
  NSTimeZone     *tz;

  tz = [self timeZone];
  
  return [NSCalendarDate dateWithYear:[self yearOfCommonEra]
                         month:       [self monthOfYear]
                         day:         [self dayOfMonth]
                         hour:0 minute:0 second:0
                         timeZone:    tz];
}

- (NSCalendarDate *)endOfDay {
  NSTimeZone     *tz;

  tz = [self timeZone];
  
  return [NSCalendarDate dateWithYear:[self yearOfCommonEra]
                         month:       [self monthOfYear]
                         day:         [self dayOfMonth]
                         hour:23 minute:59 second:59
                         timeZone:    tz];
}

- (BOOL)isDateOnSameDay:(NSCalendarDate *)_date {
  if ([self dayOfYear]       != [_date dayOfYear])       return NO;
  if ([self yearOfCommonEra] != [_date yearOfCommonEra]) return NO;
  return YES;
}
- (BOOL)isDateInSameWeek:(NSCalendarDate *)_date {
  if ([self weekOfYear]      != [_date weekOfYear])      return NO;
  if ([self yearOfCommonEra] != [_date yearOfCommonEra]) return NO;
  return YES;
}

- (BOOL)isToday {
  NSCalendarDate *d;
  BOOL result;
  
  d = [[NSCalendarDate alloc] init];
  [d setTimeZone:[self timeZone]];
  result = [self isDateOnSameDay:d];
  [d release];
  return result;
}

- (BOOL)isForenoon {
  return [self hourOfDay] >= 12 ? NO : YES;
}
- (BOOL)isAfternoon {
  return [self hourOfDay] >= 12 ? YES : NO;
}

- (NSCalendarDate *)yesterday {
  return [self dateByAddingYears:0 months:0 days:-1 
	       hours:0 minutes:0 seconds:0];
}
- (NSCalendarDate *)tomorrow {
  return [self dateByAddingYears:0 months:0 days:1 
	       hours:0 minutes:0 seconds:0];
}

- (NSCalendarDate *)lastYear {
  return [self dateByAddingYears:-1 months:0 days:0 
	       hours:0 minutes:0 seconds:0];
}
- (NSCalendarDate *)nextYear {
  return [self dateByAddingYears:1 months:0 days:0 
	       hours:0 minutes:0 seconds:0];
}

- (NSCalendarDate *)hour:(int)_hour minute:(int)_minute second:(int)_second {
  NSTimeZone *tz;

  tz = [self timeZone];
  
  return [NSCalendarDate dateWithYear:[self yearOfCommonEra]
                         month:       [self monthOfYear]
                         day:         [self dayOfMonth]
                         hour:_hour minute:_minute second:_second
                         timeZone:    tz];
}
- (NSCalendarDate *)hour:(int)_hour minute:(int)_minute {
  return [self hour:_hour minute:_minute second:0];
}

/* Y2K support */

- (NSCalendarDate *)y2kDate {
  NSCalendarDate *newDate;
  int year;
  
  year = [self yearOfCommonEra];
  if (year >= 70 && year < 135) {
    newDate = [[NSCalendarDate
                      alloc]
                      initWithYear:(year + 1900)
                      month:[self monthOfYear]
                      day:[self dayOfMonth]
                      hour:[self hourOfDay]
                      minute:[self minuteOfHour]
                      second:[self secondOfMinute]
                      timeZone:[self timeZone]];
  }
  else if (year >= 0 && year < 70) {
    newDate = [[NSCalendarDate
                      alloc]
                      initWithYear:(year + 2000)
                      month:[self monthOfYear]
                      day:[self dayOfMonth]
                      hour:[self hourOfDay]
                      minute:[self minuteOfHour]
                      second:[self secondOfMinute]
                      timeZone:[self timeZone]];
  }
  else
    newDate = [self retain];
    
  return [newDate autorelease];
}

- (NSCalendarDate *)dateByAddingYears:(int)_years
  months:(int)_months
  days:(int)_days
{
#if 0
  /* this expects that NSCalendarDate accepts invalid days, like
     2000-02-31 */
  int newYear, newMonth, newDay;
  
  newYear  = [self yearOfCommonEra] + _years;
  newMonth = [self monthOfYear]     + _months;
  newDay   = [self dayOfMonth]      + _days;

  // this doesn't check month overflow !!
  return [NSCalendarDate dateWithYear:newYear month:newMonth day:newDay
                         hour:[self hourOfDay]
                         minute:[self minuteOfHour]
                         second:[self secondOfMinute]
                         timeZone:[self timeZone]];
#else
  // but this does it 
  return [self dateByAddingYears:_years months:_months days:_days
               hours:0 minutes:0 seconds:0];
#endif
}

/* calculate easter ... */

- (NSCalendarDate *)easterOfYear {
  /*
    algorithm taken from:
      http://www.uni-bamberg.de/~ba1lw1/fkal.html#Algorithmus
  */
  int      y;
  unsigned m, n;
  int      a, b, c, d, e;
  unsigned easterMonth, easterDay;
  
  y = [self yearOfCommonEra];

  if ((y > 1699) && (y < 1800)) {
    m = 23;
    n = 3;
  }
  else if ((y > 1799) && (y < 1900)) {
    m = 23;
    n = 4;
  }
  else if ((y > 1899) && (y < 2100)) {
    m = 24;
    n = 5;
  }
  else if ((y > 2099) && (y < 2200)) {
    m = 24;
    n = 6;
  }
  else
    return nil;
    
  a = y % 19;
  b = y % 4;
  c = y % 7;
  d = (19 * a + m) % 30;
  e = (2 * b + 4 * c + 6 * d + n) % 7;
  
  easterMonth = 3;
  easterDay   = 22 + d + e;
  if (easterDay > 31) {
    easterDay  -= 31;
    easterMonth = 4;
    if (easterDay == 26)
      easterDay = 19;
    if ((easterDay == 25) && (d == 28) && (a > 10))
      easterDay = 18;
  }
  
  return [NSCalendarDate dateWithYear:y
                         month:easterMonth
                         day:easterDay
                         hour:0 minute:0 second:0
                         timeZone:[self timeZone]];
}

#if !LIB_FOUNDATION_LIBRARY
- (id)valueForUndefinedKey:(NSString *)_key {
  NSLog(@"WARNING: tried to access undefined KVC key '%@' on date object: %@",
	_key, self);
  return nil;
}
#endif

/* Oct. 15, 1582 */
#define IGREG (15+31L*(10+12L*1582))

- (long)julianNumber {
  long jul;
  int  ja, jy, jm, year, month, day;

  year  = [self yearOfCommonEra];
  month = [self monthOfYear];
  day   = [self dayOfMonth];
  jy    = year;

  if (jy == 0)
    return 0;
  if (jy < 0)
    jy++;

  if (month > 2)
    jm = month + 1;
  else {
    jy--;
    jm = month + 13;
  }
  
  jul = (long) (floor(365.25 * jy) + floor(30.6001 * jm) + day + 1720995);
  
  if (day + 31L * (month + 12L * year) >= IGREG) {
    ja   = (int)(0.01 * jy);
    jul += 2 - ja + (int) (0.25 * ja);
  }
  return jul;
}

+ (NSCalendarDate *)dateForJulianNumber:(long)_jn {
  long     ja, jalpha, jb, jc, jd, je;
  unsigned day, month, year;

  if (_jn >= IGREG) {
    jalpha = (long)(((float) (_jn - 1867216) - 0.25) / 36524.25);
    ja = _jn + 1 + jalpha - (long)(0.25 * jalpha);
  } else {
    ja = _jn;
  }

  jb    = ja + 1524;
  jc    = (long)(6680.0 + ((float)(jb - 2439870) - 122.1) / 365.25);
  jd    = (long)(365 * jc + (0.25 * jc));
  je    = (long)((jb - jd) / 30.6001);
  day   = jb - jd - (long)(30.6001 * je);
  month = je - 1;
  if (month > 12)
    month -= 12;
  year = jc - 4715;
  if (month > 2)
    year--;
  if (year <= 0)
    year--;
  return [NSCalendarDate dateWithYear:year month:month day:day
                         hour:12 minute:0 second:0
                         timeZone:nil];
}

@end /* NSCalendarDate(misc) */


@implementation NSString(FuzzyDayOfWeek)

- (int)dayOfWeekInEnglishOrGerman {
  NSString *s;
  unichar  c1;
  unsigned len;
  
  if ((len = [self length]) == 0)
    return -1;
  
  if (isdigit([self characterAtIndex:0]))
    return [self intValue];

  if (len < 2) /* need at least two chars */
    return -1;
  
  s  = [self lowercaseString];
  c1 = [s characterAtIndex:1];
  switch ([s characterAtIndex:0]) {
  case 'm': // Monday, Montag, Mittwoch
    return (c1 == 'i') ? 3 /* Wednesday */ : 1 /* Monday */;

  case 't': // Tuesday, Thursday
    return (c1 == 'u') ? 2 /* Tuesday */ : 4 /* Thursday */;

  case 'f': // Friday, Freitag
    return 5 /* Friday */;

  case 's': // Saturday, Sunday, Samstag, Sonntag, Sonnabend
    if (c1 == 'a')
      return 6; /* Saturday */
    
    if (c1 == 'o' && [s hasPrefix:@"sonna"])
      return 6; /* Sonnabend */
    
    return 0 /* Sunday */;
    
  case 'w': // Wed
    return 3 /* Wednesday */;
  }
  
  return -1;
}

@end /* NSString(FuzzyDayOfWeek) */


/* static linking */

void __link_NSCalendarDate_misc(void) {
  __link_NSCalendarDate_misc();
}
