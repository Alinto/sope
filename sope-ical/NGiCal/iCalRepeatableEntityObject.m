/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "iCalRepeatableEntityObject.h"
#include <NGExtensions/NGCalendarDateRange.h>
#include "iCalRecurrenceRule.h"
#include "iCalRecurrenceCalculator.h"
#include "common.h"

@implementation iCalRepeatableEntityObject

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void)dealloc {
  [self->rRules  release];
  [self->exRules release];
  [self->exDates release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  iCalRepeatableEntityObject *new;

  new = [super copyWithZone:_zone];
  
  new->rRules  = [self->rRules  copyWithZone:_zone];
  new->exRules = [self->exRules copyWithZone:_zone];
  new->exDates = [self->exDates copyWithZone:_zone];

  return new;
}

/* Accessors */

- (void)removeAllRecurrenceRules {
  [self->rRules removeAllObjects];
}
- (void)addToRecurrenceRules:(id)_rrule {
  if (_rrule == nil) return;
  if (self->rRules == nil)
    self->rRules = [[NSMutableArray alloc] initWithCapacity:1];
  [self->rRules addObject:_rrule];
}
- (void)setRecurrenceRules:(NSArray *)_rrules {
  if (_rrules == self->rRules)
    return;
  [self->rRules release];
  self->rRules = [_rrules mutableCopy];
}
- (BOOL)hasRecurrenceRules {
  return [self->rRules count] > 0 ? YES : NO;
}
- (NSArray *)recurrenceRules {
  return self->rRules;
}

- (void)removeAllExceptionRules {
  [self->exRules removeAllObjects];
}
- (void)addToExceptionRules:(id)_rrule {
  if (_rrule == nil) return;
  if (self->exRules == nil)
    self->exRules = [[NSMutableArray alloc] initWithCapacity:1];
  [self->exRules addObject:_rrule];
}
- (void)setExceptionRules:(NSArray *)_rrules {
  if (_rrules == self->exRules)
    return;
  [self->exRules release];
  self->exRules = [_rrules mutableCopy];
}
- (BOOL)hasExceptionRules {
  return [self->exRules count] > 0 ? YES : NO;
}
- (NSArray *)exceptionRules {
  return self->exRules;
}

- (void)removeAllExceptionDates {
  [self->exDates removeAllObjects];
}
- (void)setExceptionDates:(NSArray *)_exDates {
  if (_exDates == self->exDates)
    return;
  [self->exDates release];
  self->exDates = [_exDates mutableCopy];
}
- (void)addToExceptionDates:(id)_date {
  if (_date == nil) return;
  if (self->exDates == nil)
    self->exDates = [[NSMutableArray alloc] initWithCapacity:4];
  [self->exDates addObject:_date];
}
- (BOOL)hasExceptionDates {
  return [self->exDates count] > 0 ? YES : NO;
}
- (NSArray *)exceptionDates {
  return self->exDates;
}

/* Convenience */

- (BOOL)isRecurrent {
  return [self hasRecurrenceRules] ? YES : NO;
}

/* Matching */

- (BOOL)isWithinCalendarDateRange:(NGCalendarDateRange *)_range
  firstInstanceCalendarDateRange:(NGCalendarDateRange *)_fir
{
  NSArray *ranges;
  
  ranges = [self recurrenceRangesWithinCalendarDateRange:_range
                 firstInstanceCalendarDateRange:_fir];
  return [ranges count] > 0;
}

- (NSArray *)recurrenceRangesWithinCalendarDateRange:(NGCalendarDateRange *)_r
  firstInstanceCalendarDateRange:(NGCalendarDateRange *)_fir
{
  return [iCalRecurrenceCalculator recurrenceRangesWithinCalendarDateRange:_r
                                   firstInstanceCalendarDateRange:_fir
                                   recurrenceRules:self->rRules
                                   exceptionRules:self->exRules
                                   exceptionDates:self->exDates];
}


/* this is the outmost bound possible, not necessarily the real last date */
- (NSCalendarDate *)lastPossibleRecurrenceStartDateUsingFirstInstanceCalendarDateRange:(NGCalendarDateRange *)_r
{
  NSCalendarDate *date;
  unsigned       i, count;
  
  count = [self->rRules count];
  if (!count)
    return nil;

  date  = nil;
  for (i = 0; i < count; i++) {
    iCalRecurrenceRule       *rule;
    iCalRecurrenceCalculator *calc;
    NSCalendarDate           *rdate;

    rule = [self->rRules objectAtIndex:i];
    if ([rule isInfinite])
      return nil; /* rule is not bound, hence no limit */
    calc  = [iCalRecurrenceCalculator recurrenceCalculatorForRecurrenceRule:rule
                                      withFirstInstanceCalendarDateRange:_r];
    rdate = [[calc lastInstanceCalendarDateRange] startDate];
    if (date == nil || [date compare:rdate] == NSOrderedAscending)
      date = rdate;
  }
  return date;
}

@end
