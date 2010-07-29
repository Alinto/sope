/*
  Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

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

#include "NSCalendarDate+Extensions.h"

@implementation NSCalendarDate (ChangeLogSaxDriverExtensions)

/* set to 'Zulu', i.e. 1994-11-05T13:15:30Z */
- (NSString *)w3OrgDateTimeRepresentation {
  static NSTimeZone *zulu = nil;
  NSCalendarDate *date;
  NSString       *desc;

  if(!zulu)
    zulu = [[NSTimeZone timeZoneForSecondsFromGMT:0] retain];

  date = [self copy];
  [date setTimeZone:zulu];
  desc = [NSString stringWithFormat:@"%04d-%02d-%02dT%02d:%02d:%02dZ",
    [date yearOfCommonEra], [date monthOfYear], [date dayOfMonth],
    [date hourOfDay], [date minuteOfHour], [date secondOfMinute]];
  [date release];
  return desc;
}

@end
