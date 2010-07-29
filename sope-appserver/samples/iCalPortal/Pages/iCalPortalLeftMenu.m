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

#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WODirectAction.h>

@interface iCalPortalLeftMenu : WOComponent
{
  /* transient */
  id item;
}

@end

@interface iCalPortalLeftMenuAction : WODirectAction
@end

#include "iCalPortalUser.h"
#include "common.h"

@implementation iCalPortalLeftMenu

- (void)dealloc {
  [self->item release];
  [super dealloc];
}

/* accessors */

- (iCalPortalUser *)user {
  if (![self hasSession]) return nil;
  return [[self session] valueForKey:@"user"];
}

- (NSArray *)allCalendars {
  return [[self user] calendarNames];
}

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

/* notifications */

- (void)sleep {
  [super sleep];
  [self setItem:nil];
}

/* actions */

@end /* iCalPortalLeftMenu */

@implementation iCalPortalLeftMenuAction
@end /* iCalPortalLeftMenuAction */

