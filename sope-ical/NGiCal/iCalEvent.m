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

#include "iCalEvent.h"
#include "iCalPerson.h"
#include "iCalEventChanges.h"
#include "iCalRecurrenceRule.h"
#include "iCalRenderer.h"
#include <NGExtensions/NGCalendarDateRange.h>
#include "common.h"

@interface NSString(DurationTimeInterval)
- (NSTimeInterval)durationAsTimeInterval;
@end

@implementation iCalEvent

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void)dealloc {
  [self->endDate      release];
  [self->duration     release];
  [self->transparency release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  iCalEvent *new;
  
  new = [super copyWithZone:_zone];
  
  new->endDate      = [self->endDate      copyWithZone:_zone];
  new->duration     = [self->duration     copyWithZone:_zone];
  new->transparency = [self->transparency copyWithZone:_zone];

  return new;
}

/* accessors */

- (void)setEndDate:(NSCalendarDate *)_date {
  id tmp;
  if (self->endDate == _date) return;
  tmp = self->endDate;
  self->endDate = [_date retain];
  [tmp release];
}
- (NSCalendarDate *)endDate {
  if ([self hasEndDate])
    return self->endDate;
  
  if ([self hasDuration] && (self->startDate != nil)) {
    return [[self startDate] dateByAddingYears:0 months:0 days:0
			     hours:0 minutes:0 
			     seconds:[self durationAsTimeInterval]];
  }
  return nil;
}
- (BOOL)hasEndDate {
  return self->endDate ? YES : NO;
}

- (void)setDuration:(NSString *)_value {
  ASSIGNCOPY(self->duration, _value);
}
- (NSString *)duration {
  // eg: "DURATION:PT1H"
  if ([self hasDuration])
    return self->duration;
  
  // TODO: calculate
  return nil;
}
- (BOOL)hasDuration {
  return self->duration ? YES : NO;
}
- (NSTimeInterval)durationAsTimeInterval {
  /*
    eg: DURATION:PT1H
    P      - "period"
    P2H30M - "2 hours 30 minutes"

     dur-value  = (["+"] / "-") "P" (dur-date / dur-time / dur-week)

     dur-date   = dur-day [dur-time]
     dur-time   = "T" (dur-hour / dur-minute / dur-second)
     dur-week   = 1*DIGIT "W"
     dur-hour   = 1*DIGIT "H" [dur-minute]
     dur-minute = 1*DIGIT "M" [dur-second]
     dur-second = 1*DIGIT "S"
     dur-day    = 1*DIGIT "D"
  */
  
  if (self->duration)
    return [self->duration durationAsTimeInterval];
  
  if (self->endDate != nil && self->startDate != nil)
    /* calculate duration using enddate */
    return [[self endDate] timeIntervalSinceDate:[self startDate]];
  
  return 0.0;
}

- (void)setTransparency:(NSString *)_transparency {
  ASSIGNCOPY(self->transparency, _transparency);
}
- (NSString *)transparency {
  return self->transparency;
}

/* convenience */

- (BOOL)isOpaque {
  NSString *s;
  
  s = [self transparency];
  if (s && [[s uppercaseString] isEqualToString:@"TRANSPARENT"])
    return NO;
  return YES; /* default is OPAQUE, see RFC2445, Section 4.8.2.7 */
}

/* TODO: FIX THIS!
   The problem is, that startDate/endDate are inappropriately modelled here.
   We'd need to have a special iCalDate in order to fix all the mess.
   For the time being, we chose allday to mean 00:00 - 23:59 in startDate's
   timezone.
*/
- (BOOL)isAllDay {
  NSCalendarDate *ed;

  if (![self hasEndDate])
    return NO;
  
  ed = [[[self endDate] copy] autorelease];
  [ed setTimeZone:[self->startDate timeZone]];
  if (([self->startDate hourOfDay]    ==  0) &&
      ([self->startDate minuteOfHour] ==  0) &&
      ([ed hourOfDay]                 == 23) &&
      ([ed minuteOfHour]              == 59))
      return YES;
  return NO;
}

- (BOOL)isWithinCalendarDateRange:(NGCalendarDateRange *)_range {
  if (![self isRecurrent]) {
    if (self->startDate && self->endDate) {
      NGCalendarDateRange *r;
      
      r = [NGCalendarDateRange calendarDateRangeWithStartDate:self->startDate
                               endDate:self->endDate];
      return [_range containsDateRange:r];
    }
    else {
      return [_range containsDate:self->startDate];
    }
  }
  else {
    NGCalendarDateRange *fir;

    fir = [NGCalendarDateRange calendarDateRangeWithStartDate:self->startDate
                               endDate:self->endDate];
    
    return [self isWithinCalendarDateRange:_range
                 firstInstanceCalendarDateRange:fir];
  }
  return NO;
}

- (NSArray *)recurrenceRangesWithinCalendarDateRange:(NGCalendarDateRange *)_r {
  NGCalendarDateRange *fir;
  
  if (![self isRecurrent])
    return nil;
  
  fir = [NGCalendarDateRange calendarDateRangeWithStartDate:self->startDate
                             endDate:self->endDate];
  return [self recurrenceRangesWithinCalendarDateRange:_r
               firstInstanceCalendarDateRange:fir];
}

- (NSCalendarDate *)lastPossibleRecurrenceStartDate {
  NGCalendarDateRange *fir;

  if (![self isRecurrent])
    return nil;

  fir = [NGCalendarDateRange calendarDateRangeWithStartDate:self->startDate
                             endDate:self->endDate];
  return [self lastPossibleRecurrenceStartDateUsingFirstInstanceCalendarDateRange:fir];
}

/* ical typing */

- (NSString *)entityName {
  return @"vevent";
}

/* descriptions */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->uid)       [ms appendFormat:@" uid=%@", self->uid];
  if (self->startDate) [ms appendFormat:@" from=%@", self->startDate];
  if (self->endDate)   [ms appendFormat:@" to=%@", self->endDate];
  if (self->summary)   [ms appendFormat:@" summary=%@", self->summary];
  
  if (self->organizer)
    [ms appendFormat:@" organizer=%@", self->organizer];
  if (self->attendees)
    [ms appendFormat:@" attendees=%@", self->attendees];
  
  if ([self hasAlarms])
    [ms appendFormat:@" alarms=%@", self->alarms];
  
  [ms appendString:@">"];
  return ms;
}

/* changes */

- (iCalEventChanges *)getChangesRelativeToEvent:(iCalEvent *)_event {
  return [iCalEventChanges changesFromEvent:_event
                           toEvent:self];
}

/* generating iCal content */

- (NSString *)vEventString {
  return [[iCalRenderer sharedICalendarRenderer] vEventStringForEvent:self];
}

@end /* iCalEvent */

@implementation NSString(DurationTimeInterval)

- (NSTimeInterval)durationAsTimeInterval {
  /*
    eg: DURATION:PT1H
    P      - "period"
    P2H30M - "2 hours 30 minutes"

     dur-value  = (["+"] / "-") "P" (dur-date / dur-time / dur-week)

     dur-date   = dur-day [dur-time]
     dur-time   = "T" (dur-hour / dur-minute / dur-second)
     dur-week   = 1*DIGIT "W"
     dur-hour   = 1*DIGIT "H" [dur-minute]
     dur-minute = 1*DIGIT "M" [dur-second]
     dur-second = 1*DIGIT "S"
     dur-day    = 1*DIGIT "D"
  */
  unsigned       i, len;
  NSTimeInterval ti;
  BOOL           isTime;
  int            val;
    
  if (![self hasPrefix:@"P"]) {
    NSLog(@"Cannot parse iCal duration value: '%@'", self);
    return 0.0;
  }
    
  ti  = 0.0;
  val = 0;
  for (i = 1, len = [self length], isTime = NO; i < len; i++) {
    unichar c;
      
    c = [self characterAtIndex:i];
    if (c == 't' || c == 'T') {
      isTime = YES;
      val = 0;
      continue;
    }
      
    if (isdigit(c)) {
      val = (val * 10) + (c - 48);
      continue;
    }
      
    switch (c) {
    case 'W': /* week */
      ti += (val * 7 * 24 * 60 * 60);
      break;
    case 'D': /* day  */
      ti += (val * 24 * 60 * 60);
      break;
    case 'H': /* hour */
      ti += (val * 60 * 60);
      break;
    case 'M': /* min  */
      ti += (val * 60);
      break;
    case 'S': /* sec  */
      ti += val;
      break;
    default:
      [self logWithFormat:@"cannot process duration unit: '%c'", c];
      break;
    }
    val = 0;
  }
  return ti;
}

@end /* NSString(DurationTimeInterval) */
