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

#include "iCalGetAction.h"
#include "iCalPortalCalendar.h"
#include "iCalPortalUser.h"
#include "iCalPortalDatabase.h"
#include "common.h"

@implementation iCalGetAction

- (WOResponse *)run {
  iCalPortalDatabase *db;
  iCalPortalUser     *user = nil;
  iCalPortalUser     *calUser;
  iCalPortalCalendar *cal;
  WOResponse         *r;
  
  if ((db = [self database]) == nil)
    return nil;
  
  if ((calUser = [db userWithName:[self requestUser]]) == nil) {
    [self debugWithFormat:@"did not find request user: %@", 
	    [self requestUser]];
    return [self notFoundResponse];
  }
  
  if ((cal = [calUser calendarAtPath:[self requestCalendarPath]]) == nil) {
    [self debugWithFormat:@"did not find request cal path: %@", 
	    [self requestUser]];
    return [self notFoundResponse];
  }
  
  if (![cal isPublic]) {
    if ((user = [self user]) == nil)
      return nil;

    /* check access */
  }
  
  r = [WOResponse responseWithRequest:[self request]];
  
  [self logWithFormat:@"access calendar as user: %@", user];
  [self logWithFormat:@"  cal owner: %@", calUser];
  [self logWithFormat:@"  calendar : %@", cal];
  
  [r setStatus:200 /* OK */];
  [r setHeader:@"text/calendar" forKey:@"content-type"];
  [r setContent:[cal rawContent]];
  return r;
}

@end /* iCalGetAction */
