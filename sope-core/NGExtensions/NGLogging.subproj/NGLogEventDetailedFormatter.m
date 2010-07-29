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


#include "NGLogEventFormatter.h"
#include "NGLogLevel.h"

@class NSString;

@interface NGLogEventDetailedFormatter : NGLogEventFormatter
{
}

@end

#include "NGLogEvent.h"
#include "common.h"
#include "NSProcessInfo+misc.h"

@implementation NGLogEventDetailedFormatter

static unsigned char *processName = NULL;
static NSProcessInfo *processInfo = nil;

static char *monthNames[14] = {
  "Dec", 
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
  "Jan"
};

+ (void)initialize {
  static BOOL didInit = NO;
  unsigned    len;
  NSString    *pn;

  if (didInit) return;

  didInit     = YES;
  processInfo = [[NSProcessInfo processInfo] retain];
  /* NOTE: the processName isn't guaranteed to remain constant -
     NSProcessInfo even offers an API to change it during runtime.
     Looking at lF this seems to be unimplemented on an OS level though,
     and Apple's documentation explicitly states that changing the process
     name at runtime might be unwise to do. Let's treat it as constant.
  */
  pn          = [processInfo processName];
  len         = [pn cStringLength];
  processName = malloc(len + 4);
  [pn getCString:(char *)processName];
}

static __inline__ unsigned char *levelPrefixForEvent(NGLogEvent *_event) {
  switch ([_event level]) {
  case NGLogLevelWarn:  return (unsigned char *)"[WARN] ";
  case NGLogLevelError: return (unsigned char *)"[ERROR] ";
  case NGLogLevelFatal: return (unsigned char *)"[FATAL] ";
  default:              return (unsigned char *)"";
  }
}

- (NSString *)formattedEvent:(NGLogEvent *)_event {
  NSMutableString *fe;
  NSCalendarDate  *date;

  fe = [NSMutableString stringWithCapacity:160];
  /* timestamp, process name, process id, level prefix */
  date = [_event date];
  [fe appendFormat:@"%s %02i %02i:%02i:%02i %s [%d]: %s",
    monthNames[[date monthOfYear]],
    [date dayOfMonth],
    [date hourOfDay], [date minuteOfHour], [date secondOfMinute],
    processName,
    /* Note: pid can change after a fork() */
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
    [processInfo processIdentifier],
#else
    [[processInfo processId] intValue],
#endif
    levelPrefixForEvent(_event)];
    
  /* message */
  [fe appendString:[_event message]];
  return fe;
}

@end /* NGLogEventDetailedFormatter */
