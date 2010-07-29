/*
  Copyright (C) 2004 Marcus Mueller <znek@mulle-kybernetik.com>

  This file is part of OpenGroupware.org.

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

#include <NGExtensions/NGExtensions.h>

@interface SOPEXConsoleEventFormatter : NGLogEventFormatter
{

}

@end

#include "common.h"

@implementation SOPEXConsoleEventFormatter

static __inline__ char * levelPrefixForEvent(NGLogEvent *_event) {
  switch ([_event level]) {
    case NGLogLevelWarn:  return "[WARN ] ";
    case NGLogLevelError: return "[ERROR] ";
    case NGLogLevelFatal: return "[FATAL] ";
    default:              return "";
  }
}

- (NSString *)formattedEvent:(NGLogEvent *)_event {
  NSMutableString *fe;
  NSCalendarDate  *date;
  
  fe = [NSMutableString stringWithCapacity:160];
  /* timestamp, level prefix */
  date = [_event date];
  [fe appendFormat:@"%02i:%02i:%02i %s",
    [date hourOfDay], [date minuteOfHour], [date secondOfMinute],
    levelPrefixForEvent(_event)];
  /* message */
  [fe appendString:[_event message]];
  return fe;
}

@end
