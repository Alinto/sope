/* 
   NSConcreteTimeZone.m

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

#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSException.h>
#include <Foundation/NSUtilities.h>

#include "NSConcreteTimeZone.h"
#include "NSConcreteTimeZoneDetail.h"

static NSString* FORMAT = @"%a %b %d %H:%M:%S %Y";
static NSString* FORMAT2 = @"%a %b %d %H:%M:%S %Y GMT";
static BOOL warnings = NO;

@implementation NSConcreteTimeZone

+ (id)allocWithZone:(NSZone *)zone
{
    return NSAllocateObject(self, 0, zone);
}

+ (id)timeZoneWithOffset:(int)time
{
    NSConcreteTimeZone *timezone;
    int                hour, minute, second;
    BOOL               isNegative;
    NSTimeZoneDetail   *detail;
    
    timezone   = [[self alloc] init];
    isNegative = (time < 0);
    
    time   = abs (time);
    hour   = time / 3600;
    minute = (time - hour * 3600) / 60;
    second = time - hour * 3600 - minute * 60;
    
    timezone->name = RETAIN(([NSString stringWithFormat:@"GMT%c%02d%02d%02d",
				    (isNegative ? '-' : '+'),
				    hour,
				    minute,
				    second]));
    
    detail = [[NSConcreteTimeZoneDetail alloc]
                                        initWithAbbreviation:nil
                                        secondsFromGMT:time
                                        isDaylightSaving:NO
                                        name:timezone->name
                                        parentZone:timezone];
    
    timezone->timeZoneDetails = RETAIN([NSArray arrayWithObject:detail]);
    RELEASE(detail); detail = nil;
    
    return timezone;
}

- (id)initWithName:(NSString *)_name
{
    if (self->name != _name) {
        RELEASE(self->name); self->name = nil;
        self->name = [_name copyWithZone:[self zone]];
    }
    return self;
}

- (void)dealloc
{
    RELEASE(name);
    RELEASE(timeZoneDetails);
    [super dealloc];
}

- (NSString *)timeZoneName
{
    return name;
}
- (NSArray *)timeZoneDetailArray
{
    return timeZoneDetails;
}

- (NSTimeZone *)timeZoneForDate:(NSDate *)date
{
    /* new in MacOSX-S */
    return [timeZoneDetails objectAtIndex:0];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)zone
{
    /* TimeZone's are immutable, right ? hh */
    return RETAIN(self);
}

@end /* NSConcreteTimeZone */


@implementation NSConcreteTimeZoneFile

static NSTimeZone* gmtTimeZone = nil;

+ (void)initialize
{
    gmtTimeZone = RETAIN([NSConcreteTimeZone timeZoneWithOffset:0]);
}

- (id)initFromFile:(NSString *)_filename withName:(NSString *)_name
{
    [self initWithName:_name];
    ASSIGNCOPY(self->filename, _filename);
    return self;
}

- (void)_initFromFile
{
    id propertyList, detailsDict, rulesArray, transitionsArray;
    int i = 0, count;
    NSEnumerator* enumerator;
    id detailName, detailDict;
    id *details;
    CREATE_AUTORELEASE_POOL(pool);
    
    propertyList = [[NSString stringWithContentsOfFile:filename]
                              propertyList];
    detailsDict = AUTORELEASE([[propertyList objectForKey:@"details"]
                                  mutableCopy]);
    rulesArray       = [propertyList objectForKey:@"rules"];
    transitionsArray = [propertyList objectForKey:@"transitions"];
    count            = [detailsDict count];
    details          = alloca(count * sizeof (id));
    enumerator       = [detailsDict keyEnumerator];

    while ((detailName = [enumerator nextObject])) {
	detailDict = [detailsDict objectForKey:detailName];
	details[i++]
	    = [NSConcreteTimeZoneDetail detailFromPropertyList:detailDict
					name:detailName
                                        parentZone:self];
    }
    timeZoneDetails = [[NSArray alloc] initWithObjects:details count:i];
    
    transitions
        = RETAIN([NSMutableArray arrayWithCapacity:
                               [rulesArray count] + [transitionsArray count]]);
    for (i = 0, count = [rulesArray count]; i < count; i++) {
	[transitions addObject:
               [NSTimeZoneTransitionRule transitionRuleFromPropertyList:
                                             [rulesArray objectAtIndex:i]
                                         timezone:self]];
    }

    for (i = 0, count = [transitionsArray count]; i < count; i++) {
	[transitions addObject:
               [NSTimeZoneTransitionDate transitionDateFromPropertyList:
                                             [transitionsArray objectAtIndex:i]
                                         timezone:self]];
    }
    
    /* Now the transitions array contains NSTimeZoneTransitionRule and
       NSTimeZoneTransitionDate objects. We sort these instances in ascending
       order because the algorithm in timeZoneDetailForDate: is based on this
       fact. It is an error to have transition dates included in the time
       covered by a rule and also to have overlaping rules. */

    /* Turn on the warnings during sort */
    warnings = YES;
    [transitions sortUsingSelector:@selector(compare:)];
    warnings = NO;

    RELEASE(pool);
}

- (id)detailWithName:(NSString *)detailName
{
    int i, count = [timeZoneDetails count];

    for (i = 0; i < count; i++) {
	id detail;

        detail = [timeZoneDetails objectAtIndex:i];
	if ([detailName isEqual:[detail name]])
	    return detail;
    }
    return nil;
}

- (void)dealloc
{
    RELEASE(filename);
    RELEASE(transitions);
    [super dealloc];
}

- (NSArray *)timeZoneDetailArray
{
    if (!timeZoneDetails)
	[self _initFromFile];
    return timeZoneDetails;
}

- (NSTimeZone *)timeZoneForDate:(NSDate *)date
{
    int down, up, i = 0;
    /* Create a transition date instance to be the key for searching in the
       transitions array. */
    NSTimeZoneTransitionDate *tranDate;
    NSComparisonResult       result;
    id                       detail;
    
    if (!date)
	return nil;

    if (!timeZoneDetails)
	[self _initFromFile];

    if (![transitions count])
	return [timeZoneDetails objectAtIndex:0];

    tranDate = AUTORELEASE([[NSTimeZoneTransitionDate alloc]
                               initWithDate:date detail:nil]);
    down = 0;
    up = [transitions count] - 1;

    /* First check with the head and the end of the interval. */
    if ([tranDate compare:[transitions objectAtIndex:0]]
	    == NSOrderedAscending) {
	/* Find a detail that has no saving time in effect and return it. */
	int count = [timeZoneDetails count];

	for (i = 0; i < count; i++) {
	    detail = [timeZoneDetails objectAtIndex:i];
	    if (![detail isDaylightSavingTimeZone])
		return detail;
	}
	/* If we cannot find such a detail just return nil. */
	return nil;
    }

    if ([tranDate compare:[transitions objectAtIndex:up]]
	    == NSOrderedDescending)
	return [[transitions objectAtIndex:up] detailAfterLastDate];

    /* Use a binary search algorithm to find the position. */
    i = (down + up) / 2;
    while (down <= up) {
	result = [tranDate compare:[transitions objectAtIndex:i]];
	if (result == NSOrderedSame)
	    break;
	else if (result == NSOrderedAscending)
	    up = i - 1;
	else if (result == NSOrderedDescending)
	    down = i + 1;
	i = (down + up) / 2;
    }
    
    /* Send the -detailForDate: message to the transition object at index i */
    if (![date isKindOfClass:[NSCalendarDate class]]) {
        date = [[NSCalendarDate alloc]
                                initWithTimeIntervalSinceReferenceDate:
                                  [date timeIntervalSinceReferenceDate]];
        [(NSCalendarDate *)date setTimeZone:self];
        AUTORELEASE(date);
    }
    return [[transitions objectAtIndex:i] detailForDate:(NSCalendarDate *)date];
}

- (NSString *)filename
{
    return self->filename;
}
- (NSArray *)transitions
{
    return self->transitions;
}

@end /* NSConcreteTimeZoneFile */


@implementation NSTimeZoneTransitionDate

+ (NSTimeZoneTransitionDate *)transitionDateFromPropertyList:(id)plist
  timezone:(id)tz
{
    NSTimeZoneTransitionDate *tranDate;
    NSString *dateString;
    NSString *detailName;

    tranDate   = AUTORELEASE([[self alloc] init]);
    dateString = [plist objectForKey:@"date"];
    
    tranDate->date = RETAIN([NSCalendarDate dateWithString:dateString
                                            calendarFormat:FORMAT]);
    if (!tranDate->date)
	NSLog (@"Unable to parse transition date from '%@'!", [tz filename]);

    detailName = [plist objectForKey:@"detail"];
    if (!detailName)
	NSLog (@"No detail is specified for transition with date '%@' in "
		@"'%@'!",  dateString, [tz filename]);
    else {
	tranDate->detail = [tz detailWithName:detailName];
	if (!tranDate->detail)
	    NSLog (@"No detail '%@' in '%@'!", detailName, [tz filename]);
    }

    return tranDate;
}

- (id)initWithDate:(NSDate *)_date detail:(id)_detail
{
    self->detail = RETAIN(_detail);
    if ([_date isKindOfClass:[NSCalendarDate class]])
        self->date = RETAIN(_date);
    else {
        self->date = [[NSCalendarDate alloc]
                                      initWithTimeIntervalSinceReferenceDate:
                                        [_date timeIntervalSinceReferenceDate]];
        if (_detail)
            [self->date setTimeZone:_detail];
    }
    return self;
}

- (id)detailForDate:(NSCalendarDate *)date
{
    return self->detail;
}

- (void)dealloc
{
    RELEASE(self->date);
    RELEASE(self->detail);
    [super dealloc];
}

- (NSCalendarDate *)date
{
    return self->date;
}

- (NSComparisonResult)compare:(id)tranDateOrTranRule
{
    NSComparisonResult result;

    /* Send the comparision to TransitionRule and return the negated result */
    if ([tranDateOrTranRule isKindOfClass:[NSTimeZoneTransitionRule class]])
	return -[tranDateOrTranRule compare:self];

    if ([tranDateOrTranRule isKindOfClass:isa]) {
	if (tranDateOrTranRule == self)
	    return NSOrderedSame;
	else {
	    result = [date compare:[tranDateOrTranRule date]];
	    if (warnings && result == NSOrderedSame)
		NSLog (@"Duplicate dates for transitions '%@' and '%@'",
			self, tranDateOrTranRule);
	    return result;
	}
    }

    NSAssert (0, @"Cannot compare NSTimeZoneTransitionDate with %@",
		[tranDateOrTranRule class]);
    return NSOrderedSame;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"{ date = \"%@\"; detail = %@; }",
			[date descriptionWithCalendarFormat:FORMAT2],
			[[detail timeZoneAbbreviation] stringRepresentation]];
}

- detailAfterLastDate
{
    return detail;
}

@end /* NSTimeZoneTransitionDate */


@implementation NSTimeZoneTransitionRule

+ (NSTimeZoneTransitionRule *)transitionRuleFromPropertyList:(id)plist
  timezone:(id)tz
{
    NSTimeZoneTransitionRule* tranRule = AUTORELEASE([self new]);
    NSArray* transitionsArray = [plist objectForKey:@"transitions"];
    NSCalendarDate *date1, *date2;

    date1 = [NSCalendarDate dateWithString:[plist objectForKey:@"startDate"]
			  calendarFormat:FORMAT];
    if (!date1)
	NSLog (@"Unable to parse start date from '%@'!", [tz filename]);

    date2 = [NSCalendarDate dateWithString:[plist objectForKey:@"endDate"]
			  calendarFormat:FORMAT];
    if (!date2)
	NSLog (@"Unable to parse end date from '%@'!", [tz filename]);

    if (date1 && date2 && [date1 compare:date2] != NSOrderedAscending)
	NSLog (@"Start date '%@' should be less than end date '%@'",
		[plist objectForKey:@"startDate"],
		[plist objectForKey:@"endDate"]);

    tranRule->startRule
	= RETAIN([NSTimeZoneRule ruleFromPropertyList:
                                     [transitionsArray objectAtIndex:0]
                                 timezone:tz]);
    tranRule->endRule
	= RETAIN([NSTimeZoneRule ruleFromPropertyList:
                                     [transitionsArray objectAtIndex:1]
                                 timezone:tz]);
    tranRule->startDate = RETAIN(date1);
    tranRule->endDate = RETAIN(date2);

    return tranRule;
}

- (id)detailForDate:(NSCalendarDate *)date
{
    int            year;
    NSCalendarDate *startDateInYear;
    NSCalendarDate *endDateInYear;

    year            = [date yearOfCommonEra];
    startDateInYear = [startRule dateInYear:year];
    endDateInYear   = [endRule dateInYear:year];
    
    /* Check to see if date is outside the domain of this rule. Compare only
       with endDate, because the comparison with startDate was performed in
       timeZoneDetailForDate: method. */
    if ([endDate compare:date] == NSOrderedAscending) {
	/* Date is to the right of time interval of this rule. */
	return [endRule detail];
    }
    
    if ([date compare:startDateInYear] == NSOrderedAscending) {
	/* Date is before the first change in year, so is after the last change
	   in the preceding year. */
	return [endRule detail];
    }
    else if ([date compare:endDateInYear] == NSOrderedAscending) {
	/* Date is between the two dates of the year. */
	return [startRule detail];
    }
    else {
	/* Date is after the second change in the year */
	return [endRule detail];
    }
}

- (NSCalendarDate *)startDate
{
    return self->startDate;
}
- (NSCalendarDate *)endDate
{
    return self->endDate;
}

- (NSComparisonResult)relativePositionOfDate:(NSDate *)date
{
    NSComparisonResult result;

    result = [endDate compare:date];
    if (result == NSOrderedAscending)
	return NSOrderedAscending;

    /* Date is less than or equal with endDate. Test with startDate. */
    result = [startDate compare:date];
    if (result == NSOrderedSame || result == NSOrderedAscending) {
	/* Date is between startDate and endDate. */
	return NSOrderedSame;
    }
    else {
	/* Date is less than startDate */
	return NSOrderedDescending;
    }
}

- (NSComparisonResult)compare:(id)tranDateOrTranRule
{
    /* If the object is a date return its position relative to start and end
       date. Note that we should return the value of comparison relative to
       self. */
    if ([tranDateOrTranRule isKindOfClass:[NSTimeZoneTransitionDate class]]) {
	NSDate             *date = [tranDateOrTranRule date];
	NSComparisonResult result;

	result = [endDate compare:date];

	if (result == NSOrderedAscending || result == NSOrderedSame) {
	    /* Date is greater than or equal with endDate so we consider the
	       date greater than the interval time of self. */
	    return NSOrderedAscending;
	}
	else {
	    /* Date is less than endDate. Compare date with startDate. */
	    result = [startDate compare:date];
	    if (result == NSOrderedAscending || result == NSOrderedSame) {
		/* Date is between startDate and endDate. This is an error
		   since we require dates to not be included in time intervals
		   of rules. */
		if (warnings) {
		    NSLog (@"Date '%@' is included in the time interval "
			    @"described by rule %@",
			    [date descriptionWithCalendarFormat:FORMAT2
                                  timeZone:nil locale:nil],
			    self);
                }
		return NSOrderedSame;
	    }
	    else {
		/* Date is less than or equal with startDate so we consider the
		   interval greater than date. */
		return NSOrderedDescending;
	    }
	}
    }
    else if ([tranDateOrTranRule isKindOfClass:isa]) {
	/* Determine the relative position of the other's time interval
	   comparative with self. */
	NSComparisonResult result1;
	NSComparisonResult result2;

	result1 = [self relativePositionOfDate:[tranDateOrTranRule startDate]];
	result2 = [self relativePositionOfDate:[tranDateOrTranRule endDate]];

	if (result1 != result2) {
	    /* We have two overlaping intervals */
	    if (warnings)
		NSLog (@"Time intervals or rules '%@' and '%@' overlap!",
			self, tranDateOrTranRule);
	    return NSOrderedSame;
	}
	else {
	    /* We have result1 == result2. We should also check if they are
	       equal with NSOrderedSame, which means the second interval in
	       inside self. */
	    if (result1 == NSOrderedSame) {
		if (warnings)
		    NSLog (@"Time interval of '%@' is inside '%@'",
			    tranDateOrTranRule, self);
		return NSOrderedSame;
	    }
	    return result1;
	}
    }
    else
	NSAssert (0, @"Cannot compare NSTimeZoneTransitionRule with %@",
		    [tranDateOrTranRule class]);
    return NSOrderedSame;
}

- detailAfterLastDate
{
    return [endRule detail];
}

- (NSString*)descriptionWithIndent:(unsigned)indent
{
    id plist = [NSMutableDictionary dictionaryWithCapacity:3];
    id tranArray = [NSMutableArray arrayWithCapacity:2];

    [plist setObject:[startDate descriptionWithCalendarFormat:FORMAT2]
	   forKey:@"startDate"];
    [plist setObject:[endDate descriptionWithCalendarFormat:FORMAT2]
	   forKey:@"endDate"];
    [plist setObject:tranArray forKey:@"transitions"];

    [tranArray addObject:startRule];
    [tranArray addObject:endRule];

    return [plist descriptionWithIndent:indent];
}

- (NSString *)description
{
    return [self descriptionWithIndent:0];
}

@end /* NSTimeZoneTransitionRule */


@implementation NSTimeZoneRule

+ (NSTimeZoneRule *)ruleFromPropertyList:(id)plist
  timezone:(id)tz
{
    id months[] = {
	@"January", @"February", @"March", @"April", @"May", @"June", 
	@"July", @"August", @"September", @"October", @"November", @"December"
    };
    id days[] = {
	@"Sunday", @"Monday", @"Tuesday", @"Wednesday",
	@"Thusday", @"Friday", @"Saturday"
    };
    id weeks[] = {
	@"first", @"second", @"third", @"fourth", @"last"
    };
    NSTimeZoneRule* rule = AUTORELEASE([self new]);
    NSString* dateString = [plist objectForKey:@"date"];
    NSCharacterSet* blanks = [NSCharacterSet whitespaceCharacterSet];
    NSScanner* scanner;
    NSString* monthName;
    NSString* weekName;
    NSString* dayName;
    NSString* detailName;
    unsigned i;

    if (!dateString) {
	NSLog (@"No date rule specified in '%@'!", [tz filename]);
	return rule;
    }

    scanner = [NSScanner scannerWithString:dateString];
    if ([scanner scanUpToString:@"/" intoString:&monthName]
	&& [scanner scanString:@"/" intoString:NULL]
	&& [scanner scanUpToCharactersFromSet:blanks intoString:&weekName]
	&& [scanner scanUpToString:@"/" intoString:&dayName]
	&& [scanner scanString:@"/" intoString:NULL]
	&& [scanner scanInt:&rule->hours]
	&& [scanner scanString:@":" intoString:NULL]
	&& [scanner scanInt:&rule->minutes]
	&& [scanner scanString:@":" intoString:NULL]
	&& [scanner scanInt:&rule->seconds]) {

	for (i = 0; i < sizeof (months) / sizeof (id); i++)
	    if ([monthName isEqual:months[i]]) {
		rule->monthOfYear = i + 1;
		break;
	    }
	if (rule->monthOfYear == -1)
	    NSLog (@"Unknown month name '%@' in '%@'",
		    monthName, [tz filename]);

	for (i = 0; i < sizeof (weeks) / sizeof (id); i++)
	    if ([weekName isEqual:weeks[i]]) {
		rule->weekOfMonth = i;
		break;
	    }
	if (rule->weekOfMonth == -1)
	    NSLog (@"Unknown week name '%@' in '%@'", weekName, [tz filename]);

	for (i = 0; i < sizeof (days) / sizeof (id); i++)
	    if ([dayName isEqual:days[i]]) {
		rule->dayOfWeek = i;
		break;
	    }
	if (rule->dayOfWeek == -1)
	    NSLog (@"Unknown day name '%@' in '%@'", dayName, [tz filename]);

	if (rule->hours < 0 || rule->hours > 23)
	    NSLog (@"Hours should be between 0 and 23 in '%@'", [tz filename]);

	if (rule->minutes < 0 || rule->minutes > 59)
	    NSLog (@"Minutes should be between 0 and 59 in '%@'",
		    [tz filename]);

	if (rule->seconds < 0 || rule->seconds > 59)
	    NSLog (@"Seconds should be between 0 and 59 in '%@'",
		    [tz filename]);
    }
    else
	NSLog (@"Unable to parse date rule from '%@'!", [tz filename]);

    detailName = [plist objectForKey:@"detail"];
    if (!detailName)
	NSLog (@"No detail is specified for rule with date '%@' in '%@'!",
		    dateString, [tz filename]);
    else {
	rule->detail = [tz detailWithName:detailName];
	if (!rule->detail)
	    NSLog (@"No detail '%@' in '%@'!", detailName, [tz filename]);
    }

    return rule;
}

- (id)init
{
    self->monthOfYear = -1;
    self->weekOfMonth = -1;
    self->dayOfWeek   = -1;
    self->hours       = -1;
    self->minutes     = -1;
    self->seconds     = -1;
    return self;
}

- (NSCalendarDate *)dateInYear:(int)year
{
    NSCalendarDate* firstOfMonth
	= [NSCalendarDate dateWithYear:year month:monthOfYear day:1 hour:hours
			  minute:minutes second:seconds timeZone:gmtTimeZone];
    int firstOfMonthInWeekDay = [firstOfMonth dayOfWeek];
    int additionalDays = 0;
    int nDays[12] = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31};

#define isLeap(y) \
	((y) % 4 == 0 && ((y) % 400 == 0 || (y) % 100 ))

    if (firstOfMonthInWeekDay != dayOfWeek) {
	/* Add the number needed to have the same day of week as rule says */
	if (dayOfWeek < firstOfMonthInWeekDay)
	    additionalDays = 7 - (firstOfMonthInWeekDay - dayOfWeek);
	else additionalDays = (dayOfWeek - firstOfMonthInWeekDay);
    }
    /* Add the number of days according to the number of weeks in month */
    additionalDays += 7 * weekOfMonth;
    if (isLeap (year))
	nDays[1]++;
    if (additionalDays > nDays[monthOfYear]) {
	if (weekOfMonth == 4)
	    additionalDays -= 7;
	else
	    NSAssert (0, @"additionalDays is greater than %d and week in "
			@"month is different than last", additionalDays);
    }

    /* Adjust additionalDays if it's greater than the number of days in month
       and weekOfMonth is last. */

    /* Return the date with the number of additional days added to it. */
    return [firstOfMonth dateByAddingYears:0 months:0 days:additionalDays
		    hours:0 minutes:0 seconds:0];
#undef isLeap
}

- (NSString *)description
{
    id months[] = {
	@"January", @"February", @"March", @"April", @"May", @"June", 
	@"July", @"August", @"September", @"October", @"November", @"December"
    };
    id days[] = {
	@"Sunday", @"Monday", @"Tuesday", @"Wednesday",
	@"Thusday", @"Friday", @"Saturday"
    };
    id weeks[] = {
	@"first", @"second", @"third", @"fourth", @"last"
    };

    return [NSString stringWithFormat:@"{ date = \"%@/%@ %@/%d:%02d:%02d\"; "
			@"detail = %@; }",
			months[monthOfYear - 1],
			weeks[weekOfMonth],
			days[dayOfWeek],
			hours,
			minutes,
			seconds,
			[[detail timeZoneAbbreviation] stringRepresentation]];
}

- detail		{ return detail; }

@end /* NSTimeZoneRule */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

