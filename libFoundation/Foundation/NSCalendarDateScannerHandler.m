/* 
   NSCalendarDateScannerHandler.m

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

#include <stdio.h>

#include <Foundation/NSValue.h>
#include <Foundation/NSString.h>
#include <Foundation/NSCalendarDateScannerHandler.h>

@implementation NSCalendarDateScannerHandler

id twoDigit[] = {
    @"00", @"01", @"02", @"03", @"04", @"05", @"06", @"07", @"08", @"09",
    @"10", @"11", @"12", @"13", @"14", @"15", @"16", @"17", @"18", @"19",
    @"20", @"21", @"22", @"23", @"24", @"25", @"26", @"27", @"28", @"29",
    @"30", @"31", @"32", @"33", @"34", @"35", @"36", @"37", @"38", @"39",
    @"40", @"41", @"42", @"43", @"44", @"45", @"46", @"47", @"48", @"49",
    @"50", @"51", @"52", @"53", @"54", @"55", @"56", @"57", @"58", @"59",
    @"60", @"61", @"62", @"63", @"64", @"65", @"66", @"67", @"68", @"69",
    @"70", @"71", @"72", @"73", @"74", @"75", @"76", @"77", @"78", @"79",
    @"80", @"81", @"82", @"83", @"84", @"85", @"86", @"87", @"88", @"89",
    @"90", @"91", @"92", @"93", @"94", @"95", @"96", @"97", @"98", @"99",
    nil
};

- init
{
    [super init];

    specHandler['a']
	    = [self methodForSelector:@selector(shortDayOfWeek:scanner:)];
    specHandler['A']
	    = [self methodForSelector:@selector(fullDayOfWeek:scanner:)];
    specHandler['b']
	    = [self methodForSelector:@selector(shortMonthOfYear:scanner:)];
    specHandler['B']
	    = [self methodForSelector:@selector(fullMonthOfYear:scanner:)];
    specHandler['c']
	    = [self methodForSelector:
			@selector(localeFormatForDateAndTime:scanner:)];
    specHandler['d']
	    = [self methodForSelector:@selector(decimalDayOfMonth:scanner:)];
    specHandler['H']
	    = [self methodForSelector:@selector(decimal24HourOfDay:scanner:)];
    specHandler['I']
	    = [self methodForSelector:@selector(decimal12HourOfDay:scanner:)];
    specHandler['j']
	    = [self methodForSelector:@selector(decimalDayOfYear:scanner:)];
    specHandler['m']
	    = [self methodForSelector:@selector(decimalMonthOfYear:scanner:)];
    specHandler['M']
	    = [self methodForSelector:@selector(decimalMinuteOfHour:scanner:)];
    specHandler['p']
	    = [self methodForSelector:@selector(AM_PM:scanner:)];
    specHandler['S']
	    = [self methodForSelector:
			@selector(decimalSecondOfMinute:scanner:)];
    specHandler['w']
	    = [self methodForSelector:@selector(decimalDayOfWeek:scanner:)];
    specHandler['x']
	    = [self methodForSelector:@selector(localeDate:scanner:)];
    specHandler['X']
	    = [self methodForSelector:@selector(localeTime:scanner:)];
    specHandler['y']
	    = [self methodForSelector:@selector(yearWithoutCentury:scanner:)];
    specHandler['Y']
	    = [self methodForSelector:@selector(yearWithCentury:scanner:)];
    specHandler['Z']
	    = [self methodForSelector:@selector(timeZoneName:scanner:)];
    specHandler['z']
	    = [self methodForSelector:
			@selector(timeZoneOffsetFromGMT:scanner:)];
    return self;
}

- (id)initForCalendarDate:(NSCalendarDate*)_date
  timeZoneDetail:(NSTimeZoneDetail*)_detail
{
    [self init];
    self->date           = _date;
    self->detail         = _detail;

    if (self->detail == nil)
        self->detail = (id)[[NSTimeZone localTimeZone] timeZoneForDate:_date];
    
    self->year           = [self->date yearOfCommonEra];
    self->month          = [self->date monthOfYear];
    self->day            = [self->date dayOfMonth];
    self->hour           = [self->date hourOfDay];
    self->minute         = [self->date minuteOfHour];
    self->second         = [self->date secondOfMinute];
    self->weekDay        = [self->date dayOfWeek];
    self->timeZoneOffset = [self->detail timeZoneSecondsFromGMT];

    return self;
}

- (NSString*)shortDayOfWeek:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return [NSCalendarDate shortDayOfWeek:self->weekDay];
}

- (NSString*)fullDayOfWeek:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return [NSCalendarDate fullDayOfWeek:self->weekDay];
}

- (NSString*)shortMonthOfYear:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return [NSCalendarDate shortMonthOfYear:self->month];
}

- (NSString*)fullMonthOfYear:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return [NSCalendarDate fullMonthOfYear:self->month];
}

- (NSString*)localeFormatForDateAndTime:(va_list*)arg
  scanner:(FormatScanner*)scanner
{
    return [NSCalendarDate descriptionForCalendarDate:self->date
                           withFormat:@"%X %x"
                           timeZoneDetail:self->detail locale:nil];
}

- (NSString*)decimalDayOfMonth:(va_list*)arg scanner:(FormatScanner*)scanner
{
    char buffer[5];

    sprintf (buffer, "%02d", self->day);
    return [NSString stringWithCString:buffer];
}

- (NSString*)decimal24HourOfDay:(va_list*)arg scanner:(FormatScanner*)scanner
{
    char buffer[5];

    sprintf (buffer, "%02d", self->hour);
    return [NSString stringWithCString:buffer];
}

- (NSString*)decimal12HourOfDay:(va_list*)arg scanner:(FormatScanner*)scanner
{
    char buffer[5];

    sprintf (buffer, "%02d", hour > 12 ? hour - 12 : hour);
    return [NSString stringWithCString:buffer];
}

- (NSString*)decimalDayOfYear:(va_list*)arg scanner:(FormatScanner*)scanner
{
    char buffer[5];

    sprintf (buffer, "%03d",
	     [NSCalendarDate decimalDayOfYear:year month:month day:day]);
    return [NSString stringWithCString:buffer];
}

- (NSString*)decimalMonthOfYear:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return twoDigit[self->month];
}

- (NSString*)decimalMinuteOfHour:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return twoDigit[self->minute];
}

- (NSString*)AM_PM:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return (hour >= 12) ? @"PM" : @"AM";
}

- (NSString*)decimalSecondOfMinute:(va_list*)arg
  scanner:(FormatScanner*)scanner
{
    return twoDigit[self->second];
}

- (NSString*)decimalDayOfWeek:(va_list*)arg scanner:(FormatScanner*)scanner
{
    char buffer[5];

    sprintf (buffer, "%d", self->weekDay);
    return [NSString stringWithCString:buffer];
}

- (NSString*)localeDate:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return [NSCalendarDate descriptionForCalendarDate:date
                           withFormat:@"%b %d %Y"
                           timeZoneDetail:self->detail
                           locale:nil];
}

- (NSString*)localeTime:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return [NSCalendarDate descriptionForCalendarDate:date
                           withFormat:@"%H:%M:%S %z"
                           timeZoneDetail:self->detail
                           locale:nil];
}

- (NSString *)yearWithoutCentury:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return twoDigit[self->year % 100];
}

- (NSString *)yearWithCentury:(va_list*)arg scanner:(FormatScanner*)scanner
{
    char buffer[5];
    
    sprintf (buffer, "%d", self->year);
    return [NSString stringWithCString:buffer];
}

- (NSString*)timeZoneName:(va_list*)arg scanner:(FormatScanner*)scanner
{
    return [self->detail timeZoneAbbreviation];
}

- (NSString*)timeZoneOffsetFromGMT:(va_list*)arg
  scanner:(FormatScanner*)scanner
{
    int i = self->timeZoneOffset > 0;
    int j = (timeZoneOffset > 0 ? timeZoneOffset : -timeZoneOffset) / 60;
    return [NSString stringWithFormat:@"%s%02d%02d",
					i ? "+":"-", j / 60, j % 60];
}

@end /* NSCalendarDateScannerHandler */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

