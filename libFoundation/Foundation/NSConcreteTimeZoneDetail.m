/* 
   NSConcreteTimeZoneDetail.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
	   Ovidiu Predescu <ovidiu@bx.logicnet.ro>

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
#include <Foundation/NSString.h>
#include <Foundation/NSScanner.h>
#include <Foundation/NSCoder.h>

#include "NSConcreteTimeZoneDetail.h"

@implementation NSConcreteTimeZoneDetail

+ (id)detailFromPropertyList:(id)propList name:(NSString*)_name
  parentZone:(NSTimeZone *)_zone
{
    id   abbrev;
    int  offset;
    BOOL _isDST;
    
    abbrev = [propList objectForKey:@"abbrev"];
    offset = [self _offsetFromString:[propList objectForKey:@"offset"]];
    _isDST = [[propList objectForKey:@"isDST"] isEqual:@"1"];
#if 0
    printf("%s is DST %s -> %s\n",
           [abbrev cString],
           [[propList objectForKey:@"isDST"] cString],
           _isDST ? "yes" : "no");
#endif
    return AUTORELEASE([[self alloc]
                              initWithAbbreviation:abbrev
                              secondsFromGMT:offset
                              isDaylightSaving:_isDST
                              name:_name
                              parentZone:_zone]);
}

- (id)initWithAbbreviation:(NSString *)anAbbreviation
  secondsFromGMT:(int)aDifference
  isDaylightSaving:(BOOL)aDst
  name:(NSString *)_name
  parentZone:(NSTimeZone *)_zone
{
    [super init];
    self->abbreviation  = [anAbbreviation copyWithZone:[self zone]];
    self->name          = [_name          copyWithZone:[self zone]];
    self->offsetFromGMT = aDifference;
    self->isDST         = aDst;
    self->parentZone    = _zone;
    return self;
}

- (void)dealloc
{
    RELEASE(self->abbreviation);
    RELEASE(self->name);
    [super dealloc];
}

- (id)copyWithZone:(NSZone*)zone
{
    if ([self zone] == zone)
	return RETAIN(self);
    return [[[self class] alloc]
                   initWithAbbreviation:self->abbreviation
                   secondsFromGMT:self->offsetFromGMT
                   isDaylightSaving:self->isDST
                   name:self->name
                   parentZone:self->parentZone];
}

- (BOOL)isDaylightSavingTimeZone
{
    return self->isDST;
}
- (NSString *)timeZoneAbbreviation
{
    return self->abbreviation;
}
- (NSString *)name
{
    return self->name;
}
- (int)timeZoneSecondsFromGMT
{
    return self->offsetFromGMT;
}
- (NSString *)timeZoneName
{
    return self->name;
}
- (NSArray *)timeZoneDetailArray
{
    return [self->parentZone timeZoneDetailArray];
}

- (NSTimeZone *)timeZoneForDate:(NSDate *)date
{
    /* new in MacOSXS */
#if 0
    NSLog(@"detail for %@, tz %@, self %@",
          date, self->parentZone, self);
#endif
    return [self->parentZone timeZoneForDate:date];
}

- (NSString *)description
{
    int offset = abs(offsetFromGMT);
    int hours = offset / 3600;
    int minutes = (offset - 3600 * hours) / 60;
    int seconds = (offset - 3600 * hours - 60 * minutes);

    return [NSString stringWithFormat:@"%@ %c%02d:%02d:%02d",
                       abbreviation,
                       offsetFromGMT < 0 ? '-' : '+',
                       hours, 
                       minutes,
                       seconds];
}

+ (int)_offsetFromString:(NSString*)string
{
    NSScanner *scanner;
    int       hours, minutes, seconds, offset;
    BOOL      isNegative, errors;

    scanner = [NSScanner scannerWithString:string];
    errors  = NO;
    if ([scanner scanInt:&hours]
	&& [scanner scanString:@":" intoString:NULL]
	&& [scanner scanInt:&minutes]
	&& [scanner scanString:@":" intoString:NULL]
	&& [scanner scanInt:&seconds]) {

	isNegative = (hours < 0);
	hours = abs(hours);

	if (hours < 0 || hours > 23) {
	    NSLog (@"Hours should be between 0 and 23 in '%@'", string);
	    errors = YES;
	}

	if (minutes < 0 || minutes > 59) {
	    NSLog (@"Minutes should be between 0 and 59 in '%@'", string);
	    errors = YES;
	}

	if (seconds < 0 || seconds > 59) {
	    NSLog (@"Seconds should be between 0 and 59 in '%@'", string);
	    errors = YES;
	}

	if (errors)
	    return 0;

	offset = 3600 * hours + 60 * minutes + seconds;
	return isNegative ? -offset : offset;
    }
    else {
	NSLog (@"Cannot parse offset definition '%@'", string);
	return 0;
    }
}

@end /* NSConcreteTimeZoneDetail */
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

