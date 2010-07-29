/* 
   NSDate.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSDate_h__
#define __NSDate_h__

#include <Foundation/NSObject.h>

#ifndef NSTimeInterval__defined
#define NSTimeInterval__defined
typedef double NSTimeInterval;
#endif

@class NSArray, NSDictionary, NSString, NSCalendarDate;
@class NSTimeZone, NSTimeZoneDetail;

/* 
This module implements the 'date and time' concept.  Features:
    - it is easy to compare dates and deal with time intervals;
    - fast (can use the native representation);
    - accuracy (other date representations can be added to the framework);
    - can support user-oriented representations (Gregorian, etc ...);
    - dates are immutable;
    - an absolute reference date to ease conversion to other representations; 
Our absolute reference date is the first instant of Jan 1st, 2001.
All representations must be able to convert to/from that absolute reference.
We ignore leap second accounting (e.g. pretend that they don't happen).
Our reference date corresponds to 978307200 seconds after the UNIX base (e.g.
1/1/1970 to 1/1/2001 is (31*365 + 8 (leaps: 1972, .., 2000))*24*60*60)

Another interesting number is the number of seconds to the Julian Epoch, 
JD 0.0 = 12 noon on 1 Jan 4713 B.C.E., which is -51909.5L*24*60*60
*/

/*
 * NSDate abstract class
 */

@interface NSDate : NSObject <NSCopying, NSCoding>

/* Creating an NSDate Object */
+ allocWithZone:(NSZone*)zone;
+ (id)date;
+ (id)dateWithTimeIntervalSinceNow:(NSTimeInterval)secs;    
+ (id)dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)secs;
+ (id)dateWithTimeIntervalSince1970:(NSTimeInterval)seconds;
+ (id)distantFuture;
+ (id)distantPast;

- (id)init;
- (id)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)secsToBeAdded;
- (id)initWithString:(NSString*)description;
- (id)initWithTimeInterval:(NSTimeInterval)secsToBeAdded 
  sinceDate:(NSDate*)anotherDate;
- (id)initWithTimeIntervalSinceNow:(NSTimeInterval)secsToBeAddedToNow;
- (id)initWithTimeIntervalSince1970:(NSTimeInterval)seconds;

/* Representing Dates */
- (NSString*)description;
- (NSString*)descriptionWithCalendarFormat:(NSString*)formatString
  timeZone:(NSTimeZone*)aTimeZone locale:(NSDictionary*)localeDictionary;
- (NSString*)descriptionWithLocale:(NSDictionary*)localeDictionary;

/* Adding and Getting Intervals */
+ (NSTimeInterval)timeIntervalSinceReferenceDate;
- (NSTimeInterval)timeIntervalSinceReferenceDate;
- (NSTimeInterval)timeIntervalSinceDate:(NSDate*)anotherDate;
- (NSTimeInterval)timeIntervalSinceNow;
- (id)addTimeInterval:(NSTimeInterval)seconds;
- (NSTimeInterval)timeIntervalSince1970;

/* Comparing Dates */
- (NSDate *)earlierDate:(NSDate *)anotherDate;
- (NSDate *)laterDate:(NSDate *)anotherDate;
- (NSComparisonResult)compare:(id)other;
- (BOOL)isEqualToDate:other;

/* Converting to an NSCalendar Object */
- (id)dateWithCalendarFormat:(NSString*)formatString
  timeZone:(NSTimeZone*)timeZone;

/* new in MacOSX */
+ (id)dateWithNaturalLanguageString:(NSString *)_string;
+ (id)dateWithNaturalLanguageString:(NSString *)_string
  locale:(NSDictionary *)_locale;

@end

/*
 * Time Zone Classes 
 */

@class NSTimeZoneDetail;

@interface NSTimeZone : NSObject <NSCoding>

+ (void)setDefaultTimeZone:(NSTimeZone*)aTimeZone;
+ (NSTimeZone*)defaultTimeZone;
+ (NSTimeZone*)localTimeZone;
+ (NSDictionary*)abbreviationDictionary;
+ (NSArray*)timeZoneArray;
+ (NSTimeZone*)timeZoneWithName:(NSString*)aTimeZoneName;
+ (NSTimeZone*)timeZoneWithAbbreviation:(NSString*)abbreviation;
+ (NSTimeZone*)timeZoneForSecondsFromGMT:(int)seconds;

- (NSString *)timeZoneName;
- (NSArray *)timeZoneDetailArray;

// new methods in MacOSX

- (NSString *)abbreviation;
- (NSString *)abbreviationForDate:(NSDate *)_date;
- (BOOL)isDaylightSavingTime;
- (BOOL)isDaylightSavingTimeForDate:(NSDate *)_date;
- (int)secondsFromGMT;
- (int)secondsFromGMTForDate:(NSDate *)_date;
- (NSTimeZone *)timeZoneForDate:(NSDate *)date;

- (int)timeZoneSecondsFromGMT;
- (NSString *)timeZoneAbbreviation;
- (BOOL)isDaylightSavingTimeZone;
@end

@interface NSTimeZoneDetail : NSTimeZone /* deprecated in MacOSXS */
@end

/*
 * Calendar Utilities
 */


/* 
    Calendar formatting
    %% encode a '%' character
    %a abbreviated weekday name
    %A full weekday name
    %b abbreviated month name
    %B full month name
    %c shorthand for %X %x, the locale format for date and time
    %d day of the month as a decimal number (01-31)
    %H hour based on a 24-hour clock as a decimal number (00-23)
    %I hour based on a 12-hour clock as a decimal number (01-12)
    %j day of the year as a decimal number (001-366)
    %m month as a decimal number (01-12)
    %M minute as a decimal number (00-59)
    %p AM/PM designation associated with a 12-hour clock
    %S second as a decimal number (00-61)
    %w weekday as a decimal number (0-6), where Sunday is 0
    %x date using the date representation for the locale
    %X time using the time representation for the locale
    %y year without century (00-99)
    %Y year with century (e.g. 1990)
    %Z time zone name

    and additionally
    %z timezone offset in hours & minutes from GMT (HHMM)
    
    as a convenience, a '.' before the format characters dHIjmMSy will
    suppress the leading 0, a ' ' (space) will preserve the normal field
    width and supply spaces instead of 0's.
*/
   
@interface NSCalendarDate : NSDate 
{
    NSTimeInterval   timeSinceRef;
    NSTimeZoneDetail *timeZoneDetail;
    NSString         *formatString;
}

+ (id)calendarDate;
+ (id)dateWithYear:(int)year month:(unsigned)month 
  day:(unsigned)day hour:(unsigned)hour minute:(unsigned)minute 
  second:(unsigned)second timeZone:(NSTimeZone*)aTimeZone;
+ (id)dateWithString:(NSString*)string;
+ (id)dateWithString:(NSString*)description calendarFormat:(NSString*)format;
+ (id)dateWithString:(NSString*)description calendarFormat:(NSString*)format
  locale:(NSDictionary*)locale;

- initWithYear:(int)year month:(unsigned)month day:(unsigned)day 
  hour:(unsigned)hour minute:(unsigned)minute second:(unsigned)second 
  timeZone:(NSTimeZone*)aTimeZone;
- initWithString:(NSString*)description;
- initWithString:(NSString*)description
  calendarFormat:(NSString*)format;
- initWithString:(NSString*)description
  calendarFormat:(NSString*)format
  locale:(NSDictionary*)locale;

- (NSTimeZoneDetail*)timeZoneDetail; // not available in MacOSX
- (NSTimeZone *)timeZone;
- (void)setTimeZone:(NSTimeZone*)aTimeZone;     
- (NSString*)calendarFormat;
- (void)setCalendarFormat:(NSString*)format;

- (int)yearOfCommonEra;
- (int)monthOfYear;
- (int)dayOfMonth;
- (int)dayOfWeek;
- (int)dayOfYear;
- (int)hourOfDay;
- (int)minuteOfHour;
- (int)secondOfMinute;

- (NSCalendarDate*)addYear:(int)year month:(int)month day:(int)day
  hour:(int)hour minute:(int)minute second:(int)second;
- (id)dateByAddingYears:(int)year months:(int)months days:(int)days 
  hours:(int)hours minutes:(int)minutes seconds:(int)seconds;

- (NSString*)description;
- (NSString*)descriptionWithCalendarFormat:(NSString*)format;
- (NSString*)descriptionWithCalendarFormat:(NSString*)format 
  timeZone:(NSTimeZone*)timeZone;
- (NSString*)descriptionWithCalendarFormat:(NSString*)format
  locale:(NSDictionary*)locale;

@end

#endif /* __NSDate_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
