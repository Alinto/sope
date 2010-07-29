/* 
   NSCalendarDate.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
	   Ovidiu Predescu <ovidiu@bx.logicnet.ro>
	   Florin Mihaila <phil@pathcom.com>

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

#include <Foundation/common.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSCoder.h>

#include <extensions/PrintfFormatScanner.h>

#include "NSConcreteDate.h"
#include "NSCalendarDate.h"
#include "NSCalendarDateScannerHandler.h"
#include "NSCalendarDateScanf.h"

#include <math.h>

#define MIN_YEAR 1700
#define MAX_YEAR 2038

/*
 * Functions to deal with date conversions (phil & miki)
 * deal with dates in day:month:year reprezented in int form
 * as days since year 1st Jan year 1 ac
 */

static int  AdjustDay(int month, int day, int year);
static void DecDate(int *month, int *day, int *year);
static void IncDate(int *month, int *day, int *year);
static int  nr_nebisect(int a);
static int  day_in_year(int month, int day, int year);
static void Date2Long(int theMonth, int theDay, int theYear, long *theDate);
static void Long2Date(long theDate, int*theMonth, int*theDay, int*theYear);
static void SubFromDate(int *month, int *day, int *year, int dif);
static void AddToDate(int *month, int *day, int *year, int dif);
static void DecDate( int *month, int *day, int *year);
static void IncDate( int *month, int *day, int *year);

/*
 * Magic conversion offsets
 */

#define DATE_OFFSET 730486	/* Number of days from January 1, 1
				   to January 1, 2001 */
#define DAY_OFFSET 0

/*
 * NSCalendarDate implementation
 */

/* timeSinceRef is expressed in seconds relative to GMT from the reference day.
   The timeSinceRef is adjusted to represent this value when a date is created
   and a time zone is specified. Changing the time zone explicitly does not
   modify the timeSinceRef value. Only the methods that work with time
   components should take into consideration the time zone.
*/

@implementation NSCalendarDate

static NSString* DEFAULT_FORMAT = @"%Y-%m-%d %H:%M:%S %z";
static NSDictionary* defaultLocaleDictionary = nil;

+ (void)initialize
{
    id fullMonths[] = {
	@"January", @"February", @"March", @"April", @"May", @"June", 
	@"July", @"August", @"September", @"October", @"November", @"December"
    };
    id shortMonths[] = {
	@"Jan", @"Feb", @"Mar", @"Apr", @"May", @"Jun",
	@"Jul", @"Aug", @"Sep", @"Oct", @"Nov", @"Dec"
    };
    id fullDays[] = {
	@"Sunday", @"Monday", @"Tuesday", @"Wednesday",
	@"Thursday", @"Friday", @"Saturday"
    };
    id shortDays[] = {
	@"Sun", @"Mon", @"Tue", @"Wed", @"Thu", @"Fri", @"Sat"
    };
    defaultLocaleDictionary
      = RETAIN(([NSDictionary dictionaryWithObjectsAndKeys:
	@"%a %b %d %H:%M:%S %z %Y", @"NSTimeDateFormatString",
	[NSArray arrayWithObjects:@"AM", @"PM", nil], @"NSAMPMDesignation",
	AUTORELEASE([[NSArray alloc] initWithObjects:fullMonths
		 count:sizeof(fullMonths) / sizeof(id)]), @"NSMonthNameArray",
	AUTORELEASE([[NSArray alloc] initWithObjects:shortMonths
		 count:sizeof(shortMonths) / sizeof(id)]),
		@"NSShortMonthNameArray",
	AUTORELEASE([[NSArray alloc] initWithObjects:fullDays
		 count:sizeof(fullDays) / sizeof(id)]), @"NSWeekDayNameArray",
	AUTORELEASE([[NSArray alloc] initWithObjects:shortDays
		 count:sizeof(shortDays) / sizeof(id)]),
		@"NSShortWeekDayNameArray",
		nil]));
}

/*
 * Inherited from NSDate cluster
 */

- (id)copyWithZone:(NSZone*)zone
{
    NSCalendarDate* date = [[self class] allocWithZone:zone];
    
    date->timeSinceRef   = timeSinceRef;
    date->timeZoneDetail = RETAIN(timeZoneDetail);
    date->formatString   = RETAIN(formatString);
    return date;
}

- (void)dealloc
{
    RELEASE(timeZoneDetail);
    RELEASE(formatString);
    [super dealloc];
}

- (id)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)seconds
{
    [super init];
    self->timeSinceRef   = seconds;
    self->timeZoneDetail =
        (id)[[NSTimeZone localTimeZone] timeZoneForDate:self];
    self->timeZoneDetail = RETAIN(self->timeZoneDetail);
    self->formatString = DEFAULT_FORMAT;
    return self;
}

- (id)init
{
    return [self initWithTimeIntervalSinceReferenceDate:
                   [NSDate timeIntervalSinceReferenceDate]];
}

- (void)setTimeIntervalSinceReferenceDate:(NSTimeInterval)seconds
{
    self->timeSinceRef = seconds;
}
- (NSTimeInterval)timeIntervalSinceReferenceDate
{
    return self->timeSinceRef;
}

- (unsigned)hash
{
    return (unsigned)self->timeSinceRef;
}

- (NSComparisonResult)compare:(id)other
{
    if ([other isKindOfClass:[NSDate class]]) {
	NSTimeInterval diff
	    = timeSinceRef - [other timeIntervalSinceReferenceDate];

	return (diff < 0 ?
		  NSOrderedAscending
		: (diff == 0 ? NSOrderedSame : NSOrderedDescending));
    }
    else if (other == nil) {
	return NSOrderedSame;
    }
    
    NSLog(@"ERROR(%s): Cannot compare NSCalendarDate with %@<%@>",
	  __PRETTY_FUNCTION__, other, NSStringFromClass([other class]));
    return NSOrderedSame;
}

/*
* NSCalendarDate methods
*/

+ (id)calendarDate
{
    return AUTORELEASE([[self alloc] init]);
}

+ (id)dateWithYear:(int)year month:(unsigned)month 
  day:(unsigned)day hour:(unsigned)hour minute:(unsigned)minute 
  second:(unsigned)second timeZone:(NSTimeZone *)aTimeZone
{
    return AUTORELEASE([[self alloc]
                              initWithYear:year month:month day:day 
                              hour:hour minute:minute second:second 
                              timeZone:aTimeZone]); 
}

+ (id)dateWithString:(NSString*)string
{
    return AUTORELEASE([[self alloc]
	    initWithString:string calendarFormat:nil locale:nil]);
}

+ (id)dateWithString:(NSString*)string 
  calendarFormat:(NSString*)format
{
    return AUTORELEASE([[self alloc] initWithString:string
                                     calendarFormat:format locale:nil]);
}

+ (id)dateWithString:(NSString*)string calendarFormat:(NSString*)format
  locale:(NSDictionary*)locale
{
    return AUTORELEASE([[self alloc] initWithString:string
                                     calendarFormat:format
                                     locale:locale]);
}

- (id)initWithYear:(int)year month:(unsigned)month day:(unsigned)day 
  hour:(unsigned)hour minute:(unsigned)minute second:(unsigned)second 
  timeZone:(NSTimeZone*)timeZone
{
    // hour/minute is in timezone 'timeZone', not reference date
    long date;
    
    if (year == 0) {
        NSLog(@"ERROR(%s): replacing year 0 with year 2000!", 
              __PRETTY_FUNCTION__);
        year = 2000;
    }
    else if (year >= MAX_YEAR) {
        NSLog(@"%s: got out of range year %i (<%i), returning nil!", 
              __PRETTY_FUNCTION__, year, MAX_YEAR);
        [self release];
        return nil;
    }
#if DEBUG && 0
    NSAssert((year < 2101) && (year >= 0), @"year %i ???", year);
    
    if ((month < 1) || (month > 12))
        NSLog(@"WARNING(%s): month is %d", __PRETTY_FUNCTION__, month);
    if ((day < 1) || (day > 365))
        NSLog(@"WARNING(%s): day is %d", __PRETTY_FUNCTION__, day);
#endif
    
    Date2Long(month, day, year, &date);
    if (date == 0) {
        RELEASE(self);
        [NSException raise:NSRangeException
                     format:
                       @"could not calculate internal datevalue for "
                       @"year=%i, month=%i, day=%i", year, month, day];
        return nil;
    }
    
    if (timeZone == nil)
	timeZone = [NSTimeZone localTimeZone];

    self->timeSinceRef   = ((NSTimeInterval)date - DATE_OFFSET) * 86400 +
        hour * 3600 + minute * 60 + second;
    
    self->timeZoneDetail =  RETAIN([timeZone timeZoneForDate:self]);
    self->timeSinceRef   -= [self->timeZoneDetail timeZoneSecondsFromGMT];
    self->formatString   =  DEFAULT_FORMAT;
    
    return self;
}

- (id)initWithString:(NSString*)description
{
    return [self initWithString:description
		 calendarFormat:DEFAULT_FORMAT
		 locale:defaultLocaleDictionary];
}

- (id)initWithString:(NSString*)description calendarFormat:(NSString*)format
{
    return [self initWithString:description
		 calendarFormat:format
		 locale:defaultLocaleDictionary];
}

- (id)initWithString:(NSString*)description
  calendarFormat:(NSString*)format
  locale:(NSDictionary*)locale
{
    CREATE_AUTORELEASE_POOL(pool);
    {
        id formatScanner;
        formatScanner = AUTORELEASE([NSCalendarDateScanf new]);

        if (locale == nil)
            locale = defaultLocaleDictionary;
        if (format == nil)
            format = DEFAULT_FORMAT;
    
        [formatScanner setString:description withLocale:locale];
        
        if ([formatScanner parseFormatString:format context:NULL]) {
            int year;
            
            year = [formatScanner year];
            
            /* handle 2-digit years ... */
            if (year >= 0 && year < 10)
                /* 0-9 to 2000 till 2009 */
                year += 2000;
            else if (year >= 10 && year < 100)
                /* 10-99 to 1910 till 1999 */
                year += 1900;
            else if (year >= 100 && year < 110)
                /* 100-109 to 2000 till 2009 */
                year += 1900;
            
            if (year < MIN_YEAR || year >= MAX_YEAR) {
                NSLog(@"WARNING(%s): year %i "
                      @"parsed from string '%@' looks "
                      @"invalid (allowed range %i-%i), "
                      @"refusing date creation ...",
                      __PRETTY_FUNCTION__, year, description,
                      MIN_YEAR, MAX_YEAR);
                RELEASE(pool);
                RELEASE(self);
                return nil;
            }
            
            self = [self initWithYear:year
                         month:   [formatScanner month]
                         day:     [formatScanner day]
                         hour:    [formatScanner hour]
                         minute:  [formatScanner minute]
                         second:  [formatScanner second]
                         timeZone:[formatScanner timeZone]];
        }
        else {
            RELEASE(pool);
            RELEASE(self);
            return nil;
        }
        
        ASSIGN(self->formatString, format);
    }
    RELEASE(pool);
    return self;
}

- (NSTimeZoneDetail*)timeZoneDetail
{
    // not available in MacOSX anymore
    return self->timeZoneDetail;
}
- (NSTimeZone *)timeZone
{
    return self->timeZoneDetail;
}

- (void)setTimeZone:(NSTimeZone *)timeZone
{
    self->timeZoneDetail = AUTORELEASE(self->timeZoneDetail);
    self->timeZoneDetail = nil;
    
    if (timeZone)
        self->timeZoneDetail = RETAIN([timeZone timeZoneForDate:self]);
    else {
        self->timeZoneDetail =
            (id)[[NSTimeZone localTimeZone] timeZoneForDate:self];
        self->timeZoneDetail = RETAIN(self->timeZoneDetail);
    }
}
    
- (NSString*)calendarFormat
{
    return self->formatString;
}

- (void)setCalendarFormat:(NSString*)format
{
    if (self->formatString != format) {
        RELEASE(self->formatString); self->formatString = nil;
        self->formatString = [format copyWithZone:[self zone]];
    }
}

- (int)yearOfCommonEra
{
    NSTimeInterval tm = timeSinceRef + [timeZoneDetail timeZoneSecondsFromGMT];
    long date = floor (tm / 86400) + DATE_OFFSET;
    int d, m, y;
    
    Long2Date(date, &m, &d, &y);
    return y;
}

- (int)monthOfYear
{
    NSTimeInterval tm = timeSinceRef + [timeZoneDetail timeZoneSecondsFromGMT];
    long date = floor (tm / 86400) + DATE_OFFSET;
    int d, m, y;

    Long2Date(date, &m, &d, &y);
    return m;
}

- (int)dayOfMonth
{
    NSTimeInterval tm = timeSinceRef + [timeZoneDetail timeZoneSecondsFromGMT];
    long date = floor (tm / 86400) + DATE_OFFSET;
    int d, m, y;

    Long2Date(date, &m, &d, &y);
    return d;
}

- (int)dayOfWeek
{
    NSTimeInterval tm = timeSinceRef + [timeZoneDetail timeZoneSecondsFromGMT];
    long noOfDays = floor (tm / 86400) + DATE_OFFSET;
    int dayOfWeek = abs (noOfDays) % 7 + DAY_OFFSET;

    return dayOfWeek;
}

- (int)dayOfYear
{
    NSTimeInterval tm = timeSinceRef + [timeZoneDetail timeZoneSecondsFromGMT];
    long date = floor(tm / 86400) + DATE_OFFSET;
    int d, m, y;
    
    Long2Date(date, &m, &d, &y);
    if (y == -1) {
        NSLog(@"WARNING(%s): got -1 year-value for date's long (%i), "
              @"denying calculation of dayOfYear ...",
              __PRETTY_FUNCTION__, date);
        return -1;
    }
    
    return day_in_year(m, d, y);
}

- (int)hourOfDay
{
    NSTimeInterval tm = timeSinceRef + [timeZoneDetail timeZoneSecondsFromGMT];
    NSTimeInterval tr = tm / 3600;
    NSTimeInterval ti = floor(tr/24);
    int ts = (tr - ti * 24);

    return ts < 0 ? 24 + ts : ts;
}

- (int)minuteOfHour
{
    NSTimeInterval tm = timeSinceRef + [timeZoneDetail timeZoneSecondsFromGMT];
    NSTimeInterval tr = tm / 60;
    NSTimeInterval ti = floor (tr / 60);
    int ts = (tr - ti * 60);

    return ts < 0 ? 60 + ts : ts;
}

- (int)secondOfMinute
{
    NSTimeInterval tm = timeSinceRef + [timeZoneDetail timeZoneSecondsFromGMT];
    NSTimeInterval ti = floor (tm / 60);
    int ts = (tm - ti * 60);

    return ts < 0 ? 60 + ts : ts;
}

- (NSCalendarDate *)addYear:(int)years month:(int)months day:(int)days
  hour:(int)hours minute:(int)minutes second:(int)seconds
{
    // TODO: I guess this is a deprecated method? In which Foundation version
    //       was this used? OpenStep?
    return [self dateByAddingYears:years months:months days:days hours:hours
		 minutes:minutes seconds:seconds];
}

- (id)dateByAddingYears:(int)years months:(int)months days:(int)days
  hours:(int)hours minutes:(int)minutes seconds:(int)seconds
{
    NSTimeInterval tm;
    NSCalendarDate *date;
    long           monthDayYear, hourMinuteSecond;
    int            selfMonth, selfDay, selfYear;
    NSTimeInterval newInterval;
    
    tm = (timeSinceRef + [timeZoneDetail timeZoneSecondsFromGMT]);
    monthDayYear = floor(tm / 86400) + DATE_OFFSET;
    Long2Date(monthDayYear, &selfMonth, &selfDay, &selfYear);
    if (selfYear == -1) {
        NSLog(@"WARNING(%s): got -1 year-value for date's long (%i), "
              @"denying creation of date ...",
              __PRETTY_FUNCTION__, monthDayYear);
        return nil;
    }
    
    hourMinuteSecond
	= (long)(tm - 86400 * ((NSTimeInterval)monthDayYear - DATE_OFFSET));

    /* Add day */
    if (days >= 0)
	AddToDate(&selfMonth, &selfDay, &selfYear, days);
    else
	SubFromDate(&selfMonth, &selfDay, &selfYear, -days);

    /* Add month and year */
    selfYear += months / 12 + years;
    selfMonth += months % 12;

    if (selfMonth > 12) {
	selfYear++; selfMonth -= 12;
    }
    else if (selfMonth < 1) {
        selfYear--;
        selfMonth = (12 + selfMonth);
    }
    if (selfYear >= MAX_YEAR) {
        NSLog(@"%s: got out of range year %i (<%i), added %i/%i/%i, "
              @"returning nil!", __PRETTY_FUNCTION__, 
              selfYear, MAX_YEAR, years, months, days);
        return nil;
    }
    
    /* Adjust the day */
    selfDay = AdjustDay(selfMonth, selfDay, selfYear);

    /* Convert the (month, day, year) to long */
    Date2Long(selfMonth, selfDay, selfYear, &monthDayYear);
    if (monthDayYear == 0) {
        NSLog(@"WARNING(%s): got 0 long-value for year %i, month %i, day %i "
              @"denying creation of date ...",
              __PRETTY_FUNCTION__, selfYear, selfMonth, selfDay);
        return nil;
    }
    
    /* Compute the new interval */
    newInterval = ((NSTimeInterval)monthDayYear - DATE_OFFSET) * 86400
		    + hourMinuteSecond
		    + hours * 3600 + minutes * 60 + seconds;

    date = [[[self class] alloc] autorelease];
    
#if 1
    /* mh: trying (version 1.0.21) */
    /* mh's new code, first check whether it really works ... */
    date->timeSinceRef = newInterval;
    date->timeZoneDetail = [[timeZoneDetail timeZoneForDate:date] retain];
    date->timeSinceRef =
        newInterval - [date->timeZoneDetail timeZoneSecondsFromGMT];
#else
    date->timeSinceRef =
        newInterval - [timeZoneDetail timeZoneSecondsFromGMT];

    date->timeZoneDetail = RETAIN(timeZoneDetail);
#endif
    date->formatString   = [formatString copy];

    return date;
}

- (NSString*)description
{
    return [NSCalendarDate descriptionForCalendarDate:self
                           withFormat:self->formatString
                           timeZoneDetail:self->timeZoneDetail
                           locale:nil];
}

- (NSString*)descriptionWithLocale:(NSDictionary*)locale
{
    return [NSCalendarDate descriptionForCalendarDate:self
                           withFormat:self->formatString
                           timeZoneDetail:self->timeZoneDetail
                           locale:locale];
}

- (NSString*)descriptionWithCalendarFormat:(NSString*)format
{
    return [NSCalendarDate descriptionForCalendarDate:self
                           withFormat:format
                           timeZoneDetail:self->timeZoneDetail
                           locale:nil];
}

- (NSString*)descriptionWithCalendarFormat:(NSString*)format 
  timeZone:(NSTimeZone*)timeZone
{
    return [NSCalendarDate descriptionForCalendarDate:self
                           withFormat:format
                           timeZoneDetail:
                             timeZone
                             ? (id)[timeZone timeZoneForDate:self]
                             : (id)self->timeZoneDetail
                           locale:nil];
}

- (NSString*)descriptionWithCalendarFormat:(NSString*)format
  timeZone:(NSTimeZone*)timeZone
  locale:(NSDictionary*)locale	
{
    return [NSCalendarDate descriptionForCalendarDate:self
                           withFormat:format
                           timeZoneDetail:
                             timeZone
                             ? (id)[timeZone timeZoneForDate:self]
                             : (id)self->timeZoneDetail
                           locale:locale];
}

- (NSString*)descriptionWithCalendarFormat:(NSString*)format
  locale:(NSDictionary*)locale
{
    return [NSCalendarDate descriptionForCalendarDate:self
                           withFormat:format
                           timeZoneDetail:self->timeZoneDetail
                           locale:locale];
}

/* Encoding */
- (Class)classForCoder
{
    return [NSCalendarDate class];
}

- (void)encodeWithCoder:(NSCoder*)aCoder
{
    [aCoder encodeValueOfObjCType:@encode(NSTimeInterval)
            at:&(self->timeSinceRef)];
    [aCoder encodeObject:[self->timeZoneDetail abbreviationForDate:self]];
    [aCoder encodeObject:self->formatString];
}

- (id)initWithCoder:(NSCoder*)aDecoder
{
    NSTimeZone* timeZone;

    [aDecoder decodeValueOfObjCType:@encode(NSTimeInterval) at:&timeSinceRef];
    timeZone = [NSTimeZone timeZoneWithAbbreviation:[aDecoder decodeObject]];
    timeZoneDetail = RETAIN([timeZone timeZoneForDate:self]);
    formatString   = RETAIN([aDecoder decodeObject]);
    return self;
}

@end

/*
 * NSCalendarDateImplementation
 */

@implementation NSCalendarDate (NSCalendarDateImplementation)

+ (NSString *)descriptionForCalendarDate:(NSCalendarDate *)date
  withFormat:(NSString *)format
  timeZoneDetail:(NSTimeZoneDetail *)detail
  locale:(NSDictionary *)locale
{
    id formatScanner  = [[PrintfFormatScanner alloc] init];
    id scannerHandler = [NSCalendarDateScannerHandler alloc];
    id string;

    /* Use a dummy va_list so compilation doesn't crash under alpha */
    va_list list;
    
    NSAssert(date,   @"missing date ..");

    if (detail == nil)
        detail = (id)[[NSTimeZone localTimeZone] timeZoneForDate:date];
    //NSAssert(detail, @"missing timezone detail ..");
    
    [scannerHandler initForCalendarDate:date timeZoneDetail:detail];
    [formatScanner setFormatScannerHandler:scannerHandler];
    string = [formatScanner stringWithFormat:format arguments:list];
    RELEASE(scannerHandler); scannerHandler = nil;
    RELEASE(formatScanner);  formatScanner  = nil;
    return string;
}

+ (NSString*)shortDayOfWeek:(int)day
{
    return [[defaultLocaleDictionary objectForKey:@"NSShortWeekDayNameArray"]
		objectAtIndex:day];
}

+ (NSString*)fullDayOfWeek:(int)day
{
    return [[defaultLocaleDictionary objectForKey:@"NSWeekDayNameArray"]
		objectAtIndex:day];
}

+ (NSString*)shortMonthOfYear:(int)month
{
    return [[defaultLocaleDictionary objectForKey:@"NSShortMonthNameArray"]
		objectAtIndex:month - 1];
}

+ (NSString*)fullMonthOfYear:(int)month
{
    return [[defaultLocaleDictionary objectForKey:@"NSMonthNameArray"]
		objectAtIndex:month - 1];
}

+ (int)decimalDayOfYear:(int)year month:(int)month day:(int)day
{
    return day_in_year(month, day, year);
}

@end

/*
* Functions to deal with date conversions (phil & miki)
* deal with dates in day:month:year reprezented in int form
* as days since year 1st Jan year 1 ac
*/

static int nDays[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

#define bisect(a) 	((a) % 4 == 0 && ((a) % 400 == 0 || (a) % 100 ))
#define	nr_bisect(a) 	((a - 1) / 4 - nr_nebisect(a - 1))

static int  AdjustDay(int month, int day, int year)
{
    if(bisect(year) && month == 2 && day >= 29)
	return 29;
    if (day > nDays[month - 1])
	day = nDays[month - 1];
    return day;
}

static int nr_nebisect(int a)
{
    int i;
    int ret = 0;

    for(i = 100; i <= a; i += 100)
	ret += (i % 400 != 0);
    return ret;
}

static int day_in_year(int month, int day, int year)
{
    int ret = day + ((month > 2 && bisect(year)) ? 1 : 0);
    while (--month)
	ret += nDays[month - 1];
    return ret;
}

static void Date2Long(int theMonth, int theDay, int theYear, long *theDate)
{
    long base, offset = 0;
    int i;
    
    /* sanity checks */
    if (theYear < MIN_YEAR || theYear >= MAX_YEAR) {
        NSLog(@"WARNING(%s): got passed a year %i (month=%i,day=%i) out of "
              @"range %i-%i, this is probably an invalid value, "
              @"converted to 0 !",
              __PRETTY_FUNCTION__, theYear, theMonth, theDay,
              MIN_YEAR, MAX_YEAR);
        *theDate = 0;
#if 0
        abort();
        return;
#else
	// TODO: HACK HACK HACK
        theYear = 2037;
#endif
    }
    
    base = ((long)theYear - 1) * 365 + nr_bisect(theYear);
    for (i = 1; i < theMonth; i++)
	offset += nDays[i - 1];
    offset += theDay;
    if (theMonth > 2 && bisect(theYear))
	offset++;
    *theDate = base + offset;
}

static void Long2Date(long theDate, int *theMonth, int *theDay, int *theYear)
{
    int month = 1, day, year, offset, i, days = 0, dif;
    long aproxDate;

    year   = (theDate - 1) / 365 + 1;
    offset = (theDate - 1) % 365 + 1;
    for (i = 1; i <= 12; i++) {
	month = i;
	if (days + nDays[i - 1] >= offset)
	    break;
	days += nDays[i - 1];
    }
    
    day = offset - days;
    Assert (day <= nDays[month - 1] && day > 0);
    
    Date2Long(month, day, year, &aproxDate);
    if (aproxDate == 0) {
        NSLog(@"WARNING(%s): got 0 long-value for year %i, month %i, day %i "
              @"denying creation of date ...",
              __PRETTY_FUNCTION__, year, month, day);
        *theMonth = -1;
        *theDay   = -1;
        *theYear  = -1;
#if ABORT_ON_ERRORS
        abort();
#endif
        return;
    }
    
    dif = aproxDate - theDate;
    
    if (dif < 0) {
        printf("ERROR(%s): wrong dif %i: %li vs %li\n", __PRETTY_FUNCTION__,
               dif, aproxDate, theDate);
#if 0
        Assert(dif >= 0);
#else
	// TODO: HACK HACK HACK
#endif
    }
    
    SubFromDate(&month, &day, &year, dif);
    *theMonth = month;
    *theDay   = day;
    *theYear  = year;
}

static void SubFromDate(int *month, int *day, int *year, int dif)
{
    while (dif > 0) {
	if (*day > dif) {
	    *day -= dif;
	    break;
	}
	dif -= *day;
	*day = 1;
	DecDate(month, day, year);
    }
}

static void AddToDate(int *month, int *day, int *year, int dif)
{
    int rest, bi;

    while (dif > 0) {
	bi = bisect(*year);
	if ((*day + dif <= nDays[*month - 1])
		|| (*month == 2 && bi && *day + dif <= 29)) {
	    (*day) += dif;
	    break;
	}
	rest = nDays[*month - 1] - (*day) + (*month == 2 && bi) + 1;
	dif -= rest;
	*day = nDays[*month - 1] + (*month == 2 && bi);
	IncDate(month, day, year);
    }
}

static void DecDate( int *month, int *day, int *year)
{
    (*day)--;
    if (*day != 0)
	return;
    (*month)--;
    if (*month != 0) {
	if (*month == 2 && bisect(*year))
	    *day = 29;
	else
	    *day = nDays[*month - 1];
	return;
    }
    *month = 12;
    *day = 31;
    (*year)--;

    Assert(*year != 0);
}

static void IncDate( int *month, int *day, int *year)
{
    (*day)++;
    if (*day <= nDays[*month - 1] || 
	    (*month == 2 && bisect(*year) && *day == 29))
	return;

    *day = 1;
    (*month)++;
    if (*month <= 12)
	    return;
    *month = 1;
    (*year)++;
    Assert(*year != 0);
}
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

