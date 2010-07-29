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

#include "EOGrouping.h"
#include "common.h"

@interface EOGroupingSet(PrivateMethodes)
- (void)_updateDefaultNames;
@end


@implementation EOGroupingSet

- (void)dealloc {
  [self->groupings release];
  [super dealloc];
}

- (void)setGroupings:(NSArray *)_groupings {
  ASSIGN(self->groupings, _groupings);
  [self _updateDefaultNames];
}
- (NSArray *)groupings {
  return self->groupings;
}

- (void)setDefaultName:(NSString *)_defaultName {
  [super setDefaultName:_defaultName];
  [self _updateDefaultNames];
}

- (NSString *)groupNameForObject:(id)_object {
  NSString *result;
  int      i, cnt;

  for (i = 0, cnt = [self->groupings count]; i < cnt; i++) {
    EOGrouping *group;

    group = [self->groupings objectAtIndex:i];
    if ((result = [group groupNameForObject:_object]))
      return result;
  }
  return self->defaultName;
}

- (NSArray *)orderedGroupNames {
  NSMutableArray *result;
  unsigned int   i, cnt;

  result = [NSMutableArray arrayWithCapacity:8];
  
  for (i = 0, cnt = [self->groupings count]; i < cnt; i++) {
    EOGrouping *group;

    group = [self->groupings objectAtIndex:i];
    [result addObjectsFromArray:[group orderedGroupNames]];
  }
  
  return result;
}

/* PrivateMethodes */

- (void)_updateDefaultNames {
  unsigned int i, cnt;

  for (i = 0, cnt = [self->groupings count]; i < cnt; i++) {
    EOGrouping *group;

    group = [self->groupings objectAtIndex:i];
    [group setDefaultName:nil];
  }
}

@end /* EOGroupingSet */
