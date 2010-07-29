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

@interface ShiftClick : WOComponent
@end

#include "common.h"

@implementation ShiftClick

- (NSArray *)items {
  static NSArray *items = nil;
  if (items == nil)
    items = [[NSArray alloc] initWithObjects:
              @"one", @"two", @"three", @"four", 
              @"five", @"six", @"seven", @"eight", nil];
  return items;
}

- (BOOL)isChecked {
  return [[self valueForKey:[self valueForKey:@"item"]] boolValue];
}
- (void)setIsChecked:(BOOL)_flag {
  [self takeValue:[NSNumber numberWithBool:_flag]
        forKey:[self valueForKey:@"item"]];
}
- (NSString *)scriptCall {
  return [NSString stringWithFormat:@"%@(%d)",
                   [self valueForKey:@"scriptName"],
                   [[self valueForKey:@"index"] intValue]];
}
@end /* ShiftClick */
