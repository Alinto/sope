/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#ifndef __ICal2_NSCalendarDate_ICal_H__
#define __ICal2_NSCalendarDate_ICal_H__

#import <Foundation/NSCalendarDate.h>
#ifdef XCODE_BUILD
#import <libical/ical.h>
#else
#include <ical.h>
#endif

@class NSTimeZone;

@interface NSCalendarDate(ICalValue)

- (id)initWithICalTime:(struct icaltimetype)_dt timeZone:(NSTimeZone *)_tz;
- (id)initWithICalTime:(struct icaltimetype)_dt;

- (id)initWithICalDate:(struct icaltimetype)_dt timeZone:(NSTimeZone *)_tz;
- (id)initWithICalDate:(struct icaltimetype)_dt;

- (NSTimeZone *)timeZoneFromICalTime:(struct icaltimetype *)_dt
  defaultTimeZone:(NSTimeZone *)_tz;

/* libical values */

- (id)initWithICalValueHandle:(icalvalue *)_handle;
- (id)initWithICalValueOfProperty:(icalproperty *)_prop;

/* durations */

- (NSCalendarDate *)dateByApplyingICalDuration:(struct icaldurationtype)_dur;

/* represention */

- (NSString *)icalStringWithTimeZone:(NSTimeZone *)_tz;
- (NSString *)icalString;

@end

#endif /* __ICal2_NSCalendarDate_ICal_H__ */
