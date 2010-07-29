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

#include "iCalView.h"
#include <NGObjWeb/WODirectAction.h>

@interface iCalPortalMonthView : iCalView
{
  id currentDay;
}

@end

@interface iCalPortalMonthViewAction : WODirectAction
@end

#include "common.h"

@implementation iCalPortalMonthView

+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (void)dealloc {
  [self->currentDay release];
  [super dealloc];
}

/* accessors */

- (void)setCurrentDay:(id)_day {
  ASSIGN(self->currentDay, _day);
}
- (id)currentDay {
  return self->currentDay;
}

/* datasource */

- (NSString *)entityName {
  return @"vevent";
}

/* actions */

@end /* iCalPortalMonthView */

@implementation iCalPortalMonthViewAction
@end /* iCalPortalMonthViewAction */

