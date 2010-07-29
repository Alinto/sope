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

#include "iCalDeleteAction.h"
#include "iCalPortalUser.h"
#include "common.h"

@implementation iCalDeleteAction

- (WOResponse *)run {
  iCalPortalUser *user;
  WOResponse  *r;
  NSException *e;
  
  if ((user = [self user]) == nil) {
    return nil;
  }
  
  [self logWithFormat:@"delete a calendar of user: %@", user];
  [self logWithFormat:@"  url of:   %@", [self requestUser]];
  [self logWithFormat:@"  calendar: %@", [self requestCalendarPath]];
  
  r = [WOResponse responseWithRequest:[self request]];
  
  if ((e = [user deleteCalendarWithPath:[self requestCalendarPath]])) {
    /* failed */
    [self logWithFormat:@"calendar deletion failed: %@", e];
    
    [r setStatus:500 /* server error */];
    [r appendContentString:@"<h3>calendar deletion failed !</h3>"];
    [r appendContentHTMLString:[e description]];
  }
  else {
    [r setStatus:204 /* no content */];
    [r appendContentString:@"the calendar has been deleted ..."];
  }
  
  return r;
}

@end /* iCalDeleteAction */
