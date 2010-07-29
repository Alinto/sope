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

#include <NGObjWeb/WODirectAction.h>

@interface DirectAction : WODirectAction
@end

#include "iCalPortalUser.h"
#include "iCalPortalDatabase.h"
#include "iCalPortalPage.h"
#include "common.h"

@implementation WODirectAction(Ext)

- (id<WOActionResults>)indexPage {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  WOSession *sn;
  
  if ((sn = [self existingSession])) {
    [sn removeObjectForKey:@"user"];
    [sn terminate];
  }
  
  if ([ud boolForKey:@"DevMode"])
    return [[self pageWithName:@"iCalPortalWelcomePage"] performPage];
  
  {
    WOResponse *r;
    NSString *loc;
    
    r = [WOResponse responseWithRequest:[self request]];
    
    loc = @"/en/index.xhtml"; // TODO: make configurable!
    [self debugWithFormat:@"Deployment mode: redirecting to: %@", loc];
    [r setStatus:302];
    [r setHeader:loc forKey:@"location"];
    
    return r;
  }
}

- (id)logoutAction {
  return [self indexPage];
}

- (id)defaultAction {
  return [self indexPage];
}

@end /* WODirectAction(Ext) */

@implementation DirectAction

- (id)showLicenseAction {
  return [[self pageWithName:@"iCalPortalLicensePage"] performPage];
}

- (id)feedbackAction {
  return [[self pageWithName:@"iCalPortalFeedbackPage"] performPage];
}

- (id)editProfileAction {
  return [[self pageWithName:@"iCalPortalProfilePage"] performPage];
}

- (id)homeAction {
  return [[self pageWithName:@"iCalPortalHomePage"] performPage];
}

/* calendars */

- (id)weekOverviewAction {
  return [[self pageWithName:@"iCalPortalWeekOverview"] performPage];
}
- (id)dayOverviewAction {
  return [[self pageWithName:@"iCalPortalDayOverview"] performPage];
}
- (id)monthViewAction {
  return [[self pageWithName:@"iCalPortalMonthView"] performPage];
}
- (id)todoViewAction {
  return [[self pageWithName:@"iCalPortalToDoView"] performPage];
}

- (id)showCalendarAction {
  return [self weekOverviewAction];
}

@end /* DirectAction */
