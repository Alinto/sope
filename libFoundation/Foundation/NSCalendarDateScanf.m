/* 
   NSCalendarDateScanf.m

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
#include <Foundation/NSCharacterSet.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSScanner.h>

#include "NSCalendarDateScanf.h"

@interface NSScanner (NSCalendarDateScanf)
- (BOOL)scanInt:(int *)_value exactNumberOfDigits:(unsigned int)_exactLen;
@end

@implementation NSScanner (NSCalendarDateScanf)
- (BOOL)scanInt:(int *)_value exactNumberOfDigits:(unsigned int)_exactLen {
  static NSCharacterSet *decimals = nil;
  id string = [self string];
  unsigned int orig, location, last, result = 0;
  unichar c;
  unichar zeroChar = '0';

  if ([self isAtEnd])
    return NO;

  /* First skip the blank characters */
  [self scanCharactersFromSet:[self charactersToBeSkipped] intoString:NULL];

  orig = [self scanLocation];
  last = orig + _exactLen;

  if ([string length] < last)
    return NO;

  if(decimals == nil)
    decimals = [[NSCharacterSet decimalDigitCharacterSet] retain];

  for(location = orig; location < last; location++) {
    c = [string characterAtIndex:location];
    if ([decimals characterIsMember:c]) {
      result = result * 10 + (c - zeroChar);
    }
    else {
      break;
    }
  }

  if(location != orig)
    [self setScanLocation:location];

  if(location == last) {
    *_value = result;
    return YES;
  }
  return NO;
}
@end


@implementation NSCalendarDateScanf

static NSCharacterSet *blanks = nil;
static id timeZoneCharSet = nil;

+ (void)initialize
{
    if (blanks == nil) {
        blanks = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        blanks = RETAIN(blanks);

        timeZoneCharSet = [NSMutableCharacterSet
                             characterSetWithCharactersInString:@"+-"];
        [timeZoneCharSet formUnionWithCharacterSet:
                             [NSCharacterSet alphanumericCharacterSet]];
        timeZoneCharSet = [timeZoneCharSet copy];
    }
}

- (id)init
{
    /* Set an acceptable value for day. If it is not read from description this
       prevents a failed assertion in NSCalendarDate. */
    self = [super init];
    self->day = 1;
    self->scanner   = [[NSScanner allocWithZone:[self zone]] init];
    self->temporary = [[NSScanner allocWithZone:[self zone]] init];
    return self;
}

- (void)dealloc
{
    RELEASE(self->locale);
    RELEASE(self->scannedString);
    RELEASE(self->scanner);
    RELEASE(self->temporary);
    RELEASE(self->timeZone);

    [super dealloc];
}

- (id)setString:(NSString *)description withLocale:(NSDictionary *)_locale
{
    ASSIGN(self->scannedString, (NSMutableString*)description);
    ASSIGN(self->locale, _locale);

    [scanner initWithString:scannedString];
    [scanner scanCharactersFromSet:blanks intoString:NULL];

    return self;
}

- (BOOL)handleOrdinaryString:(NSString *)string
{
    id substring;
    NSRange range;

    /* Skip the blanks in scannedString */
    [scanner scanCharactersFromSet:blanks intoString:NULL];

    /* Determine the substring from string that doesn't begin with blanks. */
    [temporary initWithString:string];
    [temporary setScanLocation:0];
    [temporary scanCharactersFromSet:blanks intoString:NULL];
    range.location = [temporary scanLocation];
    if (range.location) {
        range.length = [string length] - range.location;
        substring = [string substringWithRange:range];
    }
    else
        substring = string;

    /* Match the current part of `scannedString' with `substring'. */
    if ([scanner scanString:substring intoString:NULL])
        return YES;

    return NO;
}

- (int)_searchInArray:(NSArray*)array
{
    int i, count = [array count];

    for (i = 0; i < count; i++) {
        id name = [array objectAtIndex:i];

        if ([scanner scanString:name intoString:NULL])
            return i;
    }

    return -1;
}

/* This method skips the weekday name and the day of the year, so if you supply
   a wrong name of day related to the actual date this will not be an error. */
- (BOOL)handleFormatSpecifierWithContext:(void*)context
{
    char    specifier = [self characterSpecifier];
    NSArray *days = nil;
    NSArray *months = nil;
    int     result;

    /* Skip the blanks in scannedString */
    [self->scanner scanCharactersFromSet:blanks intoString:NULL];

    switch (specifier) {
        case 'a': {
            days = [locale objectForKey:@"NSShortWeekDayNameArray"];
            if ((result = [self _searchInArray:days]) != -1)
                return YES;
            break;
        }
        case 'A': {
            days = [locale objectForKey:@"NSWeekDayNameArray"];
            if ((result = [self _searchInArray:days]) != -1)
                return YES;
            break;
        }
        case 'b': {
            months = [locale objectForKey:@"NSShortMonthNameArray"];
            if ((result = [self _searchInArray:months]) != -1) {
                month = result + 1;
                return YES;
            }
            break;
        }
        case 'B': {
            months = [locale objectForKey:@"NSMonthNameArray"];
            if ((result = [self _searchInArray:months]) != -1) {
                month = result + 1;
                return YES;
            }
            break;
        }
        case 'd': {
            if ([self->scanner scanInt:&day exactNumberOfDigits:2])
                return YES;
            break;
        }
        case 'I':
            self->hourIsUnder12 = YES;
            /* No `break' here */
        case 'H': {
            if ([self->scanner scanInt:&(self->hour) exactNumberOfDigits:2])
                return YES;
            break;
        }
        case 'j': {
            int dayOfYear;

            if ([self->scanner scanInt:&dayOfYear exactNumberOfDigits:3]
                && (dayOfYear >= 1 && dayOfYear <= 366))
                return YES;
            break;
        }
        case 'm': {
            if ([self->scanner scanInt:&month exactNumberOfDigits:2] && (month >= 1 && month <= 12))
                return YES;
            break;
        }
        case 'M': {
            if ([self->scanner scanInt:&minute exactNumberOfDigits:2] && (minute >= 0 && minute <= 59))
                return YES;
            break;
        }
        case 'p': {
            NSArray* ampm = [locale objectForKey:@"NSAMPMDesignation"];
            if ((result = [self _searchInArray:ampm]) != -1) {
                isPM = (result == 1);
                return YES;
            }
            break;
        }
        case 'S': {
            if ([self->scanner scanInt:&second exactNumberOfDigits:2] && (second >= 0 && second <= 61))
                return YES;
            break;
        }
        case 'w': {
            int weekday;

            if ([self->scanner scanInt:&weekday exactNumberOfDigits:1] &&
                (weekday >= 0 && weekday <= 6))
                return YES;
            break;
        }
        case 'Y': {
            if ([self->scanner scanInt:&year exactNumberOfDigits:4])
                return YES;
            break;
        }
        case 'Z': {
            NSString *timeZoneName;

            if ([self->scanner scanCharactersFromSet:timeZoneCharSet
                         intoString:&timeZoneName]) {
                timeZone = [NSTimeZone timeZoneWithAbbreviation:timeZoneName];
                (void)RETAIN(timeZone);
                return YES;
            }
            break;
        }
        case 'z': {
            int hourMinute, hours, minutes;
            BOOL is_negative;

            if ([self->scanner scanInt:&hourMinute]) {
                is_negative = (hourMinute < 0);
                hourMinute = abs (hourMinute);
                hours = hourMinute / 100;
                minutes = hourMinute % 100;
                if (!(hours < 24 && minutes < 60))
                    return NO;
                hourMinute = (hours * 3600 + minutes * 60);
                if (is_negative)
                    hourMinute = -hourMinute;
                timeZone = RETAIN([NSTimeZone
                                      timeZoneForSecondsFromGMT:hourMinute]);
                return YES;
            }
        }
    }

    return NO;
}

- (int)year
{
    return self->year;
}
- (int)month
{
    return self->month;
}
- (int)day
{
    return self->day;
}

- (int)hour
{
    register int realHour = self->hour;

    if (self->hourIsUnder12) {
        if(self->isPM) { // hour value is below 12, but PM is specified
          if (realHour != 12)
            realHour += 12;
        }
        else { // hour value is below 12, PM isn't specified
          if (realHour == 12)
            realHour = 0;
        }
    }
    // else hour value is above 12
    return realHour;
}

- (int)minute
{
    return self->minute;
}
- (int)second
{
    return self->second;
}

- (NSTimeZone *)timeZone
{
    return self->timeZone;
}

@end /* NSCalendarDateScanf */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
