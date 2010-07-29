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

#ifndef __NGExtensions_NSCalendarDate_misc_H__
#define __NGExtensions_NSCalendarDate_misc_H__

#import <Foundation/NSDate.h>
#import <Foundation/NSString.h>

#if NeXT_Foundation_LIBRARY || GNUSTEP_BASE_LIBRARY
#  import <Foundation/NSCalendarDate.h>
#endif

@class NSArray, NSTimeZone;

@interface NSCalendarDate(misc)

- (int)weekOfMonth;
- (int)weekOfYear;
- (short)numberOfWeeksInYear;
+ (NSArray *)mondaysOfYear:(int)_year timeZone:(NSTimeZone *)_tz;
- (NSArray *)mondaysOfYear;
- (NSCalendarDate *)firstMondayAndLastWeekInYear:(short *)_lastWeek;
+ (NSCalendarDate *)mondayOfWeek:(int)_weekNumber inYear:(int)_year
  timeZone:(NSTimeZone *)_tz;
- (NSCalendarDate *)mondayOfWeek:(int)_weekNumber;

+ (NSCalendarDate *)dateForJulianNumber:(long)_jn;
- (long)julianNumber;

- (NSCalendarDate *)firstDayOfMonth;
- (NSCalendarDate *)lastDayOfMonth;
- (NSCalendarDate *)mondayOfWeek;
- (NSCalendarDate *)beginOfDay;
- (NSCalendarDate *)endOfDay;
- (int)numberOfDaysInMonth;

- (BOOL)isDateOnSameDay:(NSCalendarDate *)_date;
- (BOOL)isDateInSameWeek:(NSCalendarDate *)_date;
- (BOOL)isInLeapYear;

- (BOOL)isToday;
- (NSCalendarDate *)yesterday;
- (NSCalendarDate *)tomorrow;
- (BOOL)isForenoon;
- (BOOL)isAfternoon;

- (NSCalendarDate *)nextYear;
- (NSCalendarDate *)lastYear;

/* returns a date on the same day with the specified time */
- (NSCalendarDate *)hour:(int)_hour minute:(int)_minute second:(int)_second;
- (NSCalendarDate *)hour:(int)_hour minute:(int)_minute;

/*
  applies the following modifications:
    if year >= 70 && year < 135
      year = 1900 + year
    elif year >= 0 && year < 70
      year = 2000 + year
*/

- (NSCalendarDate *)y2kDate;

/*
  adding years, months and days while *keeping* the clock time, eg:

    d1 = [NSCalendarDate dateWithYear:2000 month:2 day:15
                         hour:12 minute:0 second:0
                         timeZone:@"MET"];
    d2 = [d1 dateByAddingYear:0 month:3 day:0];

    [d2 hourOfDay] will be '15' though the timezone changed from
    MET to MET-DST.

    -dateByAddingYears:months:days:hours:minutes:seconds: which can
    be found in NSCalendarDate will not keep the clock time (the time
    will be adjusted in the new DST timezone
*/

- (NSCalendarDate *)dateByAddingYears:(int)_years
  months:(int)_months
  days:(int)_days;

/* calculate easter ... */

- (NSCalendarDate *)easterOfYear;

@end


@interface NSCalendarDate(CalMatrix)

- (NSArray *)calendarMatrixWithStartDayOfWeek:(short)_caldow
  onlyCurrentMonth:(BOOL)_onlyThisMonth;

@end


@interface NSString(FuzzyDayOfWeek)

- (int)dayOfWeekInEnglishOrGerman;

@end


#endif /* __NGExtensions_NSCalendarDate_misc_H__ */
