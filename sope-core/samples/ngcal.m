/*
  Copyright (C) 2005 SKYRIX Software AG

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

#if 0
@interface NSCalendarDate(CalMatrix)

- (NSArray *)calendarMatrixWithStartDayOfWeek:(unsigned)_caldow
  onlyCurrentMonth:(BOOL)_onlyThisMonth;

@end



@interface NSString(DayOfWeek)
- (int)dayOfWeek;
@end

@implementation NSString(DayOfWeek)

- (int)dayOfWeek {
  NSString *s;
  
  if ([self length] == 0)
    return -1;
  
  if (isdigit([self characterAtIndex:0]))
    return [self intValue];
  
  s = [self lowercaseString];
  switch ([s characterAtIndex:0]) {
  case 'm': // Monday, Montag, Mittwoch
    return ([s characterAtIndex:1] == 'i') ? 3 : 1;
  case 't': // Tue, Thu
    return ([s characterAtIndex:1] == 'u') ? 2 : 4;
  case 'f': // Fri, Frei
    return 5;
  case 's': // Sat, Sun, Sam, Sonn
    return ([s characterAtIndex:1] == 'a') ? 6 : 0;
  case 'w': // Wed
    return 3;
  }
  
  return -1;
}

@end /* NSString(DayOfWeek) */
#endif

static void usage(NSArray *args) {
  printf("Usage: %s [[[month] year] startday]\n\n"
         "Arguments:\n"
         "  month    - month as a decimal (1-12)\n"
         "  year     - year  as a decimal (1976-2030)\n"
         "  startday - first column in matrix (Sunday=0...Saturday=6)\n"
         , [[args objectAtIndex:0] cString]);
}


static void printMatrix(NSArray *weeks, int dow) {
  unsigned week, weekCount;

  if (weeks == nil) {
    NSLog(@"ERROR: got no week matrix!");
    return;
  }

  for (week = 0; week < 7; week++) {
    int dd = dow + week;
    char c;
    if (dd > 7 ) dd -= 7;
    switch (dd) {
    case 0: c = 'S'; break;
    case 1: c = 'M'; break;
    case 2: c = 'T'; break;
    case 3: c = 'W'; break;
    case 4: c = 'T'; break;
    case 5: c = 'F'; break;
    case 6: c = 'S'; break;
    }
    printf(" %2c", c);
  }
  puts("");
  
  for (week = 0, weekCount = [weeks count]; week < weekCount; week++) {
    NSArray *days;
    unsigned day, dayCount;
    
    days     = [weeks objectAtIndex:week];
    dayCount = [days count];
    
    /* pad first week (could also print old dates) */
    if (week == 0) {
      for (day = 7; day > dayCount; day--)
	printf("   ");
    }
    
    for (day = 0; day < dayCount; day++) {
      NSCalendarDate *dayDate;
      
      dayDate = [days objectAtIndex:day];
      printf(" %2i", [dayDate dayOfMonth]);
    }
    puts("");
  }
}


static int doCalArgs(NSArray *args) {
  NSCalendarDate *now, *start;
  unsigned startDayOfWeek, month, year;

  /* defaults */
  
  now = [NSCalendarDate date];
  startDayOfWeek = 1 /* Monday */;
  month          = [now monthOfYear];
  year           = [now yearOfCommonEra];

  /* arguments */

  if ([args count] > 1)
    month = [[args objectAtIndex:1] intValue];
  if ([args count] > 2) {
    year = [[args objectAtIndex:2] intValue];
    if (year < 100)
      year += 2000;
  }
  if ([args count] > 3)
    startDayOfWeek = [[args objectAtIndex:3] dayOfWeekInEnglishOrGerman];

  /* focus date */
  
  start = [NSCalendarDate dateWithYear:year month:month day:1
			  hour:0 minute:0 second:0
			  timeZone:[now timeZone]];

  printMatrix([start calendarMatrixWithStartDayOfWeek:startDayOfWeek
		     onlyCurrentMonth:NO], 
	      startDayOfWeek);
  
  return 0;
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  int res;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  /* 
     Note: we cannot check for those in the tool function because the - args
           are stripped out
  */
  if ([[[NSProcessInfo processInfo] arguments] containsObject:@"--help"]) {
    usage([[NSProcessInfo processInfo] arguments]);
    exit(0);
  }
  if ([[[NSProcessInfo processInfo] arguments] containsObject:@"-h"]) {
    usage([[NSProcessInfo processInfo] arguments]);
    exit(0);
  }
  
  res = doCalArgs([[NSProcessInfo processInfo] argumentsWithoutDefaults]);
  
  [pool release];
  exit(0);
  /* static linking */
  [NGExtensions class];
  return 0;
}
