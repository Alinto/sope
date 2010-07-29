/*
  Copyright (C) 2004 Marcus Mueller

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

#ifndef	__NGExtensions_NGCalendarDateRange_H_
#define	__NGExtensions_NGCalendarDateRange_H_

#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDate.h>

@class NSString, NSCalendarDate;

@interface NGCalendarDateRange : NSObject <NSCopying>
{
  NSCalendarDate *startDate;
  NSCalendarDate *endDate;
}

+ (id)calendarDateRangeWithStartDate:(NSCalendarDate *)_start
  endDate:(NSCalendarDate *)_end;
- (id)initWithStartDate:(NSCalendarDate *)_start
  endDate:(NSCalendarDate *)_end;

/* accessors */

- (NSCalendarDate *)startDate;
- (NSCalendarDate *)endDate;

/* comparison */

- (NSComparisonResult)compare:(NGCalendarDateRange *)other;

/* operations */

- (NGCalendarDateRange *)intersectionDateRange:(NGCalendarDateRange *)other;
- (NGCalendarDateRange *)unionDateRange:(NGCalendarDateRange *)other;

- (BOOL)doesIntersectWithDateRange:(NGCalendarDateRange *)_other;

- (BOOL)containsDate:(NSCalendarDate *)date;
- (BOOL)containsDateRange:(NGCalendarDateRange *)_range;

- (NSTimeInterval)duration;

@end

@interface NSArray(NGCalendarDateRanges)

- (NSArray *)arrayByCreatingDateRangesFromObjectsWithStartDateKey:(NSString *)s
  andEndDateKey:(NSString *)e;

- (unsigned)indexOfFirstIntersectingDateRange:(NGCalendarDateRange *)_range;
- (BOOL)dateRangeArrayContainsDate:(NSCalendarDate *)_date;

- (NSArray *)arrayByCompactingContainedDateRanges;

@end

#endif	/* __NGExtensions_NGCalendarDateRange_H_ */
