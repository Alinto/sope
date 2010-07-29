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

#include "common.h"

@implementation NSCalendarDate(RFC822Dates)

static NSString *dateFormats[] = {
  /*
    short-weekday, day short-month year hour:minute:second timezoneoffset
    eg: Mon, 01 Mar 1999 13:13:13 +0000
  */
  @"%a, %d %b %Y %H:%M:%S %z",

  /*
    short-weekday, day short-month year hour:minute:second timezonename
    eg: Mon, 01 Mar 1999 13:13:13 GMT
  */
  @"%a, %d %b %Y %H:%M:%S %Z",

  /*
    short-weekday, day short-month year hour:minute:second timezonename
    eg: Mon, 01 Mar 1999 13:13 +0000
  */
  @"%a, %d %b %Y %H:%M %z",

  /*
    short-weekday, day short-month year hour:minute:second timezonename
    eg: Mon, 01 Mar 1999 13:13 (+0000)
  */
  @"%a, %d %b %Y %H:%M (%z)",

  /*
    short-weekday, day short-month year hour:minute:second timezonename
    eg: Mon, 01 Mar 1999 13:13 (GMT)
  */
  @"%a, %d %b %Y %H:%M (%Z)",

  /*
    short-weekday, day short-month year hour:minute:second
    eg: Mon, 01 Mar 1999 13:13:13
  */
  @"%a, %d %b %Y %H:%M:%S",

  /*
    day short-month year hour:minute:second timezoneoffset
    eg: 01 Oct 1999 18:20:12 +0200
  */
  @"%d %b %Y %H:%M:%S %z",
  
  /*
    day short-month year hour:minute:second timezonename
    eg: 01 Oct 1999 18:20:12 EST
  */
  @"%d %b %Y %H:%M:%S %Z",
  
  /*
    day short-month year hour:minute:second (timezoneoffset)
    eg: 30 Sep 1999 21:00:05  (+0200)
  */
  @"%d %b %Y %H:%M:%S  (%z)",

  /*
    day short-month year hour:minute:second (timezonename)
    eg: 30 Sep 1999 21:00:05  (MEST)
  */
  @"%d %b %Y %H:%M:%S  (%Z)",
  /*
    day short-month year hour:minute:second (timezonename)
    eg: 30 Sep 1999 21:00:05  (MEST)
  */
  @"%d %b %Y %H:%M:%S  (%Z)",

  /*
    short-weekday, day short-month year hour:minute:second timezoneoffset
    eg: Mon, 01 Mar 1999 13:13:13 +0000
  */
  @"%a %b %d %H:%M:%S %Y  (%Z)",

  /*
    eg: '16 Jun 2002 10:28 GMT'
  */
  @"%d %b %Y %H:%M %Z",

  /*
    eg: '16 Jun 2002 10:28 +0000'
  */
  @"%d %b %Y %H:%M %z",

  /* terminate list */
  nil
};

+ (NSCalendarDate *)calendarDateWithRfc822DateString:(NSString *)_str {
  // TODO: optimize MUCH more - calformat parsing is *slow*
  NSCalendarDate *date       = nil;
  NSString       *dateString = nil;
  int i;  
  
  dateString = [_str stringByTrimmingSpaces];
  if ([dateString length] == 0)
    return nil;
  
  /* check various date formats */
  
  for (i = 0, date = nil; (date == nil) && (dateFormats[i] != nil); i++) {
    date = [NSCalendarDate dateWithString:dateString
			   calendarFormat:dateFormats[i]];
  }
  return [date y2kDate];
}

@end /* NSCalendarDate(RFC822Dates) */
