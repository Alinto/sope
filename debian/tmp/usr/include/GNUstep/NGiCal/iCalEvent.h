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

#ifndef __NGiCal_iCalEvent_H__
#define __NGiCal_iCalEvent_H__

#include <NGiCal/iCalRepeatableEntityObject.h>
#import <Foundation/NSDate.h>

/*
  iCalEvent
  
  This class keeps the attributes of an iCalendar event record, that is,
  an appointment.
*/

@class NSString, NSMutableArray, NSCalendarDate, NGCalendarDateRange;
@class iCalPerson, iCalEventChanges, iCalRecurrenceRule;

@interface iCalEvent : iCalRepeatableEntityObject
{
  NSCalendarDate *endDate;
  NSString       *duration;
  NSString       *transparency;
}

/* accessors */

- (void)setEndDate:(NSCalendarDate *)_date;
- (NSCalendarDate *)endDate;
- (BOOL)hasEndDate;

- (void)setDuration:(NSString *)_value;
- (NSString *)duration;
- (BOOL)hasDuration;
- (NSTimeInterval)durationAsTimeInterval;

- (void)setTransparency:(NSString *)_transparency;
- (NSString *)transparency;

/* convenience */

- (BOOL)isOpaque;
- (BOOL)isAllDay;

- (BOOL)isWithinCalendarDateRange:(NGCalendarDateRange *)_range;
- (NSArray *)recurrenceRangesWithinCalendarDateRange:(NGCalendarDateRange *)_r;

- (NSCalendarDate *)lastPossibleRecurrenceStartDate;

/* calculating changes */

- (iCalEventChanges *)getChangesRelativeToEvent:(iCalEvent *)_event;

/* generating iCal content */

- (NSString *)vEventString;

@end 

#endif /* __NGiCal_iCalEvent_H__ */
