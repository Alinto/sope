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

#include "NSCalendarDate+misc.h"
#include "common.h"

@implementation NSCalendarDate(CalMatrix)

static BOOL debugCalMatrix = NO;

- (NSArray *)calendarMatrixWithStartDayOfWeek:(short)_caldow
  onlyCurrentMonth:(BOOL)_onlyThisMonth
{
  // Note: we keep clock time!
  NSAutoreleasePool *pool;
  NSCalendarDate *firstInMonth;
  NSArray        *matrix;
  NSArray        *weeks[8] = { nil, nil, nil, nil, nil, nil, nil, nil };
  NSCalendarDate *week[8]  = { nil, nil, nil, nil, nil, nil, nil, nil };
  unsigned firstDoW, numDaysInLastMonth, i, j, curday, curweek, curmonth;

  /* all the date operations use autorelease, so we wrap it in a pool */
  pool = [[NSAutoreleasePool alloc] init];

  if (debugCalMatrix)
    NSLog(@"calmatrix for: %@", self);
  
  firstInMonth = [[self firstDayOfMonth] beginOfDay];
  firstDoW     = [firstInMonth dayOfWeek];
  curmonth     = [firstInMonth monthOfYear];
  
  numDaysInLastMonth = (firstDoW < _caldow)
    ? (firstDoW + 7 - _caldow)
    : (firstDoW - _caldow);

  if (debugCalMatrix) {
    NSLog(@"  LAST: %d FIRST-DOW: %d START-DOW: %d", 
	  numDaysInLastMonth, firstDoW, _caldow);
  }

  
  /* first week */
  
  if (_onlyThisMonth) {
    j = 0; /* this is the position where first week days are added */
  }
  else {
    /* add dates from last month */
    for (i = numDaysInLastMonth; i > 0; i--) {
      week[numDaysInLastMonth - i] = 
	[firstInMonth dateByAddingYears:0 months:0 days:-i];
    }
    j = numDaysInLastMonth;
  }
  week[j] = firstInMonth; j++;
  
  for (i = numDaysInLastMonth + 1; i < 7; i++, j++) {
    week[j] = [firstInMonth dateByAddingYears:0 months:0 
			    days:(i - numDaysInLastMonth)];
  }
  curday  = 7 - numDaysInLastMonth;
  curweek = 1;
  if (debugCalMatrix)
    NSLog(@"  current day after 1st week: %d, week: %d", curday, curweek);
  
  /* finish first week */
  weeks[0] = [[NSArray alloc] initWithObjects:week count:j];


  /* follow up weeks */

  while (curweek < 7) {
    BOOL foundNewMonth = NO;
    
    for (i = 0; i < 7; i++, curday++) {
      week[i] = [firstInMonth dateByAddingYears:0 months:0 days:curday];

      if (!foundNewMonth && curday > 27) {
	foundNewMonth = ([week[i] monthOfYear] != curmonth) ? YES : NO;
	if (foundNewMonth && _onlyThisMonth)
	  break;
      }
    }
    
    if (i > 0) {
      weeks[curweek] = [[NSArray alloc] initWithObjects:week count:i];
      curweek++;
    }
    if (foundNewMonth)
      break;
  }

  
  /* build final matrix */
  
  matrix = [[NSArray alloc] initWithObjects:weeks count:curweek];
  for (i = 0; i < 8; i++) {
    [weeks[i] release];
    weeks[i] = nil;
  }
  
  if (debugCalMatrix)
    NSLog(@"matrix for %@: %@", self, matrix);
  
  [pool release];
  return [matrix autorelease];
}

@end /* NSCalendarDate(CalMatrix) */
