/*
  Copyright (C) 2004-2007 Marcus Mueller
  Copyright (C) 2007      Helge Hess

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

#include "NGCalendarDateRange.h"
#include <NGExtensions/NSCalendarDate+misc.h>
#include <NGExtensions/NSNull+misc.h>
#include "common.h"

@implementation NGCalendarDateRange

+ (id)calendarDateRangeWithStartDate:(NSCalendarDate *)start
  endDate:(NSCalendarDate *)end
{
  return [[[self alloc] initWithStartDate:start endDate:end] autorelease];
}

- (id)initWithStartDate:(NSCalendarDate *)start endDate:(NSCalendarDate *)end {
  NSAssert(start != nil, @"startDate MUST NOT be nil!");
  NSAssert(end   != nil, @"endDate MUST NOT be nil!");
  
  if ((self = [super init])) {
    if ([start compare:end] == NSOrderedAscending) {
      self->startDate = [start copy];
      self->endDate   = [end   copy];
    }
    else {
      self->startDate = [end   copy];
      self->endDate   = [start copy];
    }
  }
  return self;
}

- (void)dealloc {
  [self->startDate release];
  [self->endDate  release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)zone {
  /* object is immutable */
  return [self retain];
}

/* accessors */

- (NSCalendarDate *)startDate {
  return self->startDate;
}

- (NSCalendarDate *)endDate {
  return self->endDate;
}

- (NGCalendarDateRange *)intersectionDateRange:(NGCalendarDateRange *)other {
  NSCalendarDate *a, *b, *c, *d;
    
  if ([self compare:other] == NSOrderedAscending) {
    a = self->startDate;
    b = self->endDate;
    c = [other startDate];
    d = [other endDate];
  }
  else {
    a = [other startDate];
    b = [other endDate];
    c = self->startDate;
    d = self->endDate;
  }
  // [a;b[ ?< [c;d[
  if ([b compare:c] == NSOrderedAscending)
    return nil; // no intersection
  // b ?< d
  if ([b compare:d] == NSOrderedAscending) {
    // c !< b  && b !< d -> [c;b[
    if([c compare:b] == NSOrderedSame)
      return nil; // no real range, thus return nil!
    else
      return [NGCalendarDateRange calendarDateRangeWithStartDate:c endDate:b];
  }
  if([c compare:d] == NSOrderedSame)
    return nil; // no real range, thus return nil!
  // b !> d -> [c;d[
  return [NGCalendarDateRange calendarDateRangeWithStartDate:c endDate:d];
}

- (BOOL)doesIntersectWithDateRange:(NGCalendarDateRange *)_other {
  // TODO: improve
  if (_other == nil) return NO;
  return [self intersectionDateRange:_other] != nil ? YES : NO;
}

- (NGCalendarDateRange *)unionDateRange:(NGCalendarDateRange *)other {
  NSCalendarDate *a, *b, *c, *d;
    
  if ([self compare:other] == NSOrderedAscending) {
    a = self->startDate;
    b = self->endDate;
    c = [other startDate];
    d = [other endDate];
  }
  else {
    a = [other startDate];
    b = [other endDate];
    c = self->startDate;
    d = self->endDate;
  }
  if ([b compare:d] == NSOrderedAscending)
    return [NGCalendarDateRange calendarDateRangeWithStartDate:a endDate:d];
  
  return [NGCalendarDateRange calendarDateRangeWithStartDate:a endDate:b];
}

- (BOOL)containsDate:(NSCalendarDate *)_date {
  NSComparisonResult result;
  
  result = [self->startDate compare:_date];
  if (!((result == NSOrderedSame) || (result == NSOrderedAscending)))
    return NO;
  result = [self->endDate compare:_date];
  if (result == NSOrderedAscending)
    return NO;
  return YES;
}

- (BOOL)containsDateRange:(NGCalendarDateRange *)_range {
  NSComparisonResult result;

  result = [self->startDate compare:[_range startDate]];
  if (!((result == NSOrderedSame) || (result == NSOrderedAscending)))
    return NO;
  result = [self->endDate compare:[_range endDate]];
  if (result == NSOrderedAscending)
    return NO;
  return YES;
}

- (NSTimeInterval)duration {
  return [self->endDate timeIntervalSinceDate:self->startDate];
}

/* comparison */

- (BOOL)isEqual:(id)other {
  if (other == nil)
    return NO;
  if (other == self)
    return YES;
  
  if ([other isKindOfClass:self->isa] == NO)
    return NO;
  
  return ([self->startDate isEqual:[other startDate]] && 
	  [self->endDate isEqual:[other endDate]]) ? YES : NO;
}

- (unsigned)hash {
  return [self->startDate hash] ^ [self->endDate hash];
}

- (NSComparisonResult)compare:(NGCalendarDateRange *)other {
  return [self->startDate compare:[other startDate]];
}

/* KVC */

- (id)valueForUndefinedKey:(NSString *)_key {
  /* eg this is used in OGo on 'dateId' to probe for event objects */
  return nil;
}

/* description */

- (NSString *)description {
  NSMutableString *description;
    
  description = [NSMutableString stringWithCapacity:64];

  [description appendFormat:@"<%@[0x%x]: startDate:%@ endDate: ", 
	         NSStringFromClass(self->isa), self, self->startDate];
  
  if ([self->startDate isEqual:self->endDate])
    [description appendString:@"== startDate"];
  else
    [description appendFormat:@"%@", self->endDate];
  [description appendString:@">"];
  return description;
}

@end /* NGCalendarDateRange */


@implementation NSArray(NGCalendarDateRanges)

- (NSArray *)arrayByCreatingDateRangesFromObjectsWithStartDateKey:(NSString *)s
  andEndDateKey:(NSString *)e
{
  NSMutableArray *ma;
  unsigned i, count;
  
  count = [self count];
  ma    = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NGCalendarDateRange *daterange;
    NSCalendarDate *start, *end;
    id object;
    
    object = [self objectAtIndex:i];
    start  = [object valueForKey:s];
    end    = [object valueForKey:e];
    
    /* skip invalid data */
    if (![start isNotNull]) continue;
    if (![end   isNotNull]) continue;
    
    daterange =
      [[NGCalendarDateRange alloc] initWithStartDate:start endDate:end];
    if (daterange) [ma addObject:daterange];
    [daterange release];
  }
  return ma;
}

- (BOOL)dateRangeArrayContainsDate:(NSCalendarDate *)_date {
  unsigned i, count;
  
  if (_date == nil) 
    return NO;
  if ((count = [self count]) == 0)
    return NO;

  for (i = 0; i < count; i++) {
    if ([[self objectAtIndex:i] containsDate:_date])
      return YES;
  }
  return NO;
}
- (unsigned)indexOfFirstIntersectingDateRange:(NGCalendarDateRange *)_range {
  unsigned i, count;
  
  if (_range == nil)
    return NO;
  
  if ((count = [self count]) == 0)
    return NSNotFound;

  for (i = 0; i < count; i++) {
    if ([[self objectAtIndex:i] doesIntersectWithDateRange:_range])
      return i;
  }
  return NSNotFound;
}

- (NSArray *)arrayByCompactingContainedDateRanges {
  // TODO: this is a candidate for unit testing ...
  // TODO: pretty "slow" algorithm, improve
  NSMutableArray *ma;
  unsigned i, count;
  
  count = [self count];
  if (count < 2)
    return [[self copy] autorelease];
  
  ma = [NSMutableArray arrayWithCapacity:count];
  [ma addObject:[self objectAtIndex:0]]; /* add first range */
  
  for (i = 1; i < count; i++) {
    NGCalendarDateRange *rangeToAdd;
    NGCalendarDateRange *availRange;
    NGCalendarDateRange *newRange;
    unsigned idx;
    
    rangeToAdd = [self objectAtIndex:i];
    idx = [ma indexOfFirstIntersectingDateRange:rangeToAdd];
    
    if (idx == NSNotFound) {
      /* range not yet covered in array */
      [ma addObject:rangeToAdd];
      continue;
    }
    
    /* union old range and replace the entry */
    
    availRange = [ma objectAtIndex:idx];
    newRange   = [availRange unionDateRange:rangeToAdd];
    
    [ma replaceObjectAtIndex:idx withObject:newRange];
  }
  /* Note: we might want to join ranges up to some "closeness" (eg 1s)? */
  return [ma sortedArrayUsingSelector:@selector(compare:)];
}

@end /* NSArray(NGCalendarDateRanges) */
