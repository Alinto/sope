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

#include "iCalPortalPage.h"

@interface iCalPortalCalTabs : iCalPortalPage
{
  NSString *selection;
  NSString *calendarName;
}

@end

#include "common.h"

@implementation iCalPortalCalTabs

- (void)dealloc {
  [self->selection    release];
  [self->calendarName release];
  [super dealloc];
}

/* accessors */

- (void)setSelection:(NSString *)_sel {
  ASSIGN(self->selection, _sel);
}
- (NSString *)selection {
  return self->selection;
}

- (void)setCalendarName:(NSString *)_sel {
  ASSIGN(self->calendarName, _sel);
}
- (NSString *)calendarName {
  return self->calendarName;
}

/* tab state */

- (BOOL)isDaySelected {
  return [self->selection isEqualToString:@"day"] ? YES : NO;
}
- (BOOL)isWeekSelected {
  return [self->selection isEqualToString:@"week"] ? YES : NO;
}
- (BOOL)isMonthSelected {
  return [self->selection isEqualToString:@"month"] ? YES : NO;
}
- (BOOL)isToDoSelected {
  return [self->selection isEqualToString:@"todo"] ? YES : NO;
}

- (NSString *)_url:(NSString *)_name {
  return [NSString stringWithFormat:
		     @"/iCalPortal.woa/WebServerResources/English.lproj/"
		     @"tab_%@.gif", _name];
}

- (NSString *)dayTabURL {
  return [self _url:[self isDaySelected] ? @"selected":@"left"];
}
- (NSString *)weekTabURL {
  return [self _url:[self isWeekSelected] ? @"selected" : @""];
}
- (NSString *)monthTabURL {
  return [self _url:[self isMonthSelected] ? @"selected" : @""];
}
- (NSString *)todoTabURL {
  return [self _url:[self isToDoSelected] ? @"selected" : @""];
}

/* actions */

@end /* iCalPortalCalTabs */
