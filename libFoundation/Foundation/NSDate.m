/* 
   NSDate.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

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

#include "common.h"

#if HAVE_SYS_TIME_H
# include <sys/time.h>
#endif
#include <time.h>

#if HAVE_LIBC_H
# include <libc.h>
#else
# include <unistd.h>
#endif

#if HAVE_WINDOWS_H
# include <windows.h>
#endif

#include <Foundation/NSString.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSUtilities.h>

#include "NSConcreteDate.h"
#include "NSCalendarDate.h"

#if HAVE_GETLOCALTIME || defined(__MINGW32__)
static void Date2Long(int theMonth, int theDay, int theYear, long *theDate);
#define DATE_OFFSET 730486  /* Number of days from January 1, 1
                        to January 1, 2001 */
#endif

@implementation NSDate

static NSDate *distantFuture = nil, *distantPast = nil;

#if defined(__svr4__)
+ (void)initialize {
    tzset();
}
#endif

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject( (self == [NSDate class]) ? 
			     [NSConcreteDate class] : (Class)self, 0, zone);
}

+ (id)date
{
    return AUTORELEASE([[self alloc] init]);
}

+ (id)dateWithTimeIntervalSinceNow:(NSTimeInterval)secs
{
    return AUTORELEASE([[self alloc] initWithTimeIntervalSinceNow:secs]);
}

+ (id)dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)secs
{
    return AUTORELEASE([[self alloc]
                           initWithTimeIntervalSinceReferenceDate:secs]);
}

+ (id)dateWithTimeIntervalSince1970:(NSTimeInterval)seconds
{
    return AUTORELEASE([[self alloc] initWithTimeIntervalSince1970:seconds]);
}

+ (id)distantFuture
{
    if (distantFuture == nil) {
        distantFuture = [[self alloc]
                       initWithTimeIntervalSinceReferenceDate:DISTANT_FUTURE];
    }
    return distantFuture;
}

+ (id)distantPast
{
    if (distantPast == nil) {
        distantPast = [[self alloc] 
                         initWithTimeIntervalSinceReferenceDate:DISTANT_PAST];
    }
    return distantPast;
}

- (id)init
{
    return [super init];
}

- (id)initWithTimeIntervalSinceReferenceDate:(NSTimeInterval)secsToBeAdded
{
    [self subclassResponsibility:_cmd];
    return self;
}

- (id)initWithString:(NSString *)description
{
    id cal = [[NSCalendarDate alloc] initWithString:description];
    [self initWithTimeIntervalSinceReferenceDate:
	    [cal timeIntervalSinceReferenceDate]];
    RELEASE(cal); cal = nil;
    return self;
}

- (id)initWithTimeInterval:(NSTimeInterval)secsToBeAdded 
  sinceDate:(NSDate *)anotherDate
{
    return [self initWithTimeIntervalSinceReferenceDate:
	    (secsToBeAdded + [anotherDate timeIntervalSinceReferenceDate])];
}

- (id)initWithTimeIntervalSinceNow:(NSTimeInterval)secsToBeAddedToNow
{
    [self initWithTimeIntervalSinceReferenceDate:
	(secsToBeAddedToNow + [NSDate timeIntervalSinceReferenceDate])];
    return self;
}

- (id)initWithTimeIntervalSince1970:(NSTimeInterval)seconds
{
    [self initWithTimeIntervalSinceReferenceDate: seconds + UNIX_OFFSET];
    return self;
}

/* Copying */

- (id)copyWithZone:(NSZone *)zone
{
    if (NSShouldRetainWithZone(self, zone))
	return RETAIN(self);
    else
	return [[[self class] alloc] initWithTimeIntervalSinceReferenceDate:
		[self timeIntervalSinceReferenceDate]];
}

/* Representing Dates */

- (NSString *)propertyListStringWithLocale:(NSDictionary *)_locale
  indent:(unsigned int)_indent
{
    return [[self descriptionWithLocale:_locale] stringRepresentation];
}

- (NSString *)stringRepresentation {
    return [[self description] stringRepresentation];
}

- (NSString *)description
{
    return [[NSCalendarDate dateWithTimeIntervalSinceReferenceDate:
		[self timeIntervalSinceReferenceDate]] description];
}	

- (NSString *)descriptionWithCalendarFormat:(NSString *)formatString
	timeZone:(NSTimeZone *)aTimeZone
	locale:(NSDictionary *)locale	
{
    id calendar = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:
	[self timeIntervalSinceReferenceDate]];
    [calendar setTimeZone:aTimeZone];
    return [calendar descriptionWithCalendarFormat:formatString
	timeZone:aTimeZone locale:locale];
} 

- (NSString *)descriptionWithLocale:(NSDictionary *)locale
{
    id calendar = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate:
	[self timeIntervalSinceReferenceDate]];
    return [calendar descriptionWithLocale:locale];
}

/* Adding and Getting Intervals */

+ (NSTimeInterval)timeIntervalSinceReferenceDate
{
#if HAVE_GETTIMEOFDAY
    /* eg: used on SuSE Linux */
    NSTimeInterval  theTime = UNIX_OFFSET;
    struct timeval  tp;
    struct timezone tzp = { 0, 0 };

    gettimeofday(&tp, &tzp);

    /* theTime contains 1970 (Unix ref time) and gets added seconds and micros */
    theTime += tp.tv_sec;
    theTime += (double)tp.tv_usec / 1000000.0;

#if 0 && defined(__svr4__)
    {
        extern time_t timezone, altzone;
        theTime -= (double)altzone;
    }
#else
#  if !defined(__linux__)
    /* this is not to be used on Linux, see 'gettimeofday' man page */
    theTime -= tzp.tz_minuteswest * 60 + (tzp.tz_dsttime ? 3600 : 0);
#  endif
#endif

    return theTime;

#elif HAVE_GETLOCALTIME

    NSTimeInterval  theTime = 0;
    SYSTEMTIME      tp;
    long            date;

    GetLocalTime(&tp);
    Date2Long(tp.wMonth, tp.wDay, tp.wYear, &date);

    theTime = ((NSTimeInterval)date - DATE_OFFSET) * 86400 +
        tp.wHour * 3600 + tp.wMinute * 60 + tp.wSecond +
        tp.wMilliseconds / 1000.0 ;
    return theTime;

#elif defined(__MINGW32__)
    NSTimeInterval theTime = 0;
    SYSTEMTIME     tp;
    long           date;

    GetSystemTime(&tp);
    Date2Long(tp.wMonth, tp.wDay, tp.wYear, &date);

    theTime = ((NSTimeInterval)date - DATE_OFFSET) * 86400 +
        tp.wHour * 3600 + tp.wMinute * 60 + tp.wSecond +
        tp.wMilliseconds / 1000.0 ;
    return theTime;
#else
#error no time function
#endif
}

- (NSTimeInterval)timeIntervalSinceReferenceDate
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (NSTimeInterval)timeIntervalSinceDate:(NSDate *)anotherDate;
{
    return [self timeIntervalSinceReferenceDate] -
	    [anotherDate timeIntervalSinceReferenceDate];
}

- (NSTimeInterval)timeIntervalSinceNow
{
    return [self timeIntervalSinceReferenceDate] -
	    [NSDate timeIntervalSinceReferenceDate];
}

- (id)addTimeInterval:(NSTimeInterval)seconds
{
    return AUTORELEASE([[[self class] alloc]
                           initWithTimeInterval:seconds sinceDate:self]);
}

- (NSTimeInterval)timeIntervalSince1970
{
    return [self timeIntervalSinceReferenceDate] - UNIX_OFFSET;
}

/* Comparing Dates */

- (NSDate *)earlierDate:(NSDate *)anotherDate
{
    if (!anotherDate) return self;

    return [self compare:anotherDate] == NSOrderedAscending?
	    self : anotherDate;
}

- (NSDate *)laterDate:(NSDate *)anotherDate
{
    if (!anotherDate) return self;

    return [self compare:anotherDate] == NSOrderedAscending ?
	    anotherDate : self;
}

- (NSComparisonResult)compare:(id)other
{
    [self subclassResponsibility:_cmd];
    return NSOrderedSame;
}

- (BOOL)isEqual:other
{
    return [other isKindOfClass:[NSDate class]] &&
	   [self isEqualToDate:other];
}

- (BOOL)isEqualToDate:other
{
    return [self compare:other] == NSOrderedSame;
}

/* Converting to an NSCalendar Object */
- (id)dateWithCalendarFormat:(NSString *)aFormatString
  timeZone:(NSTimeZone *)aTimeZone
{
    id new = AUTORELEASE([[NSCalendarDate alloc] 
                             initWithTimeIntervalSinceReferenceDate:
                                 [self timeIntervalSinceReferenceDate]]);
    [new setCalendarFormat:aFormatString];
    [new setTimeZone:aTimeZone];
    return new;
}

/* new in MacOSX */
+ (id)dateWithNaturalLanguageString:(NSString *)_string
{
    return [self dateWithNaturalLanguageString:_string
                 locale:nil];
}

+ (id)dateWithNaturalLanguageString:(NSString *)_string
  locale:(NSDictionary *)_locale
{
    return [self notImplemented:_cmd];
}

/* Encoding */
- (Class)classForCoder
{
    return [NSDate class];
}

- (void)encodeWithCoder:(NSCoder *)aCoder
{
    NSTimeInterval timeDiff = [self timeIntervalSinceReferenceDate];

    [aCoder encodeValueOfObjCType:@encode(NSTimeInterval) at:&timeDiff];
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    NSTimeInterval timeDiff;

    [aDecoder decodeValueOfObjCType:@encode(NSTimeInterval) at:&timeDiff];
    [self initWithTimeIntervalSinceReferenceDate:timeDiff];
    return self;
}

@end /* NSDate */

#if HAVE_GETLOCALTIME || defined(__MINGW32__)

static int nDays[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};
#define bisect(a)   ((a) % 4 == 0 && ((a) % 400 == 0 || (a) % 100 ))
#define nr_bisect(a)    ((a - 1) / 4 - nr_nebisect(a - 1))

static int nr_nebisect(int a)
{
    int i;
    int ret = 0;

    for(i = 100; i <= a; i += 100)
    ret += (i % 400 != 0);
    return ret;
}

static void Date2Long(int theMonth, int theDay, int theYear, long *theDate)
{
    long base, offset = 0;
    int i;

    base = ((long)theYear - 1) * 365 + nr_bisect(theYear);
    for (i = 1; i < theMonth; i++)
    offset += nDays[i - 1];
    offset += theDay;
    if (theMonth > 2 && bisect(theYear))
    offset++;
    *theDate = base + offset;
}
#endif
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

