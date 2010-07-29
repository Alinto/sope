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

@class NSArray;

@interface MonthOverview: WOComponent
{
  NSArray *list;
}
@end

#include "common.h"

@implementation MonthOverview

static inline void setDateWithKey(id obj, NSString *key) {
  NSString *str;

  str = [(NSDictionary *)obj objectForKey:key];

  if ([str isNotNull]) {
    NSCalendarDate *date;

    date = [NSCalendarDate dateWithString:str
                           calendarFormat:@"%Y-%m-%d %H:%M:%S %Z"];
    [(NSMutableDictionary *)obj setObject:date forKey:key];
  }
}

- (void)dealloc {
  [self->list release];
  [super dealloc];
}

- (NSCalendarDate *)weekStart {
  return [NSCalendarDate dateWithString:@"2000-11-06 00:00:00 +0100"
                         calendarFormat:@"%Y-%m-%d %H:%M:%S %Z"];
}

- (NSArray *)list {
  if (self->list == nil) {
    WOResourceManager *rm;
    NSString          *path;

    rm = [[self application] resourceManager];
    path = [rm pathForResourceNamed:@"appointments.plist"
               inFramework:nil
               languages:nil];

    self->list = [[NSArray alloc] initWithContentsOfFile:path];

    {
      int i, cnt;
      
      for (i = 0, cnt = [self->list count]; i < cnt; i++) {
        setDateWithKey([self->list objectAtIndex:i], @"startDate");
        setDateWithKey([self->list objectAtIndex:i], @"endDate");
      }
    }
  }
  return self->list;
}

- (NSString *)contentColor {
  NSCalendarDate *day = nil;

  day = [self valueForKey:@"currentDay"];
  return ([day monthOfYear] == 11) ? @"#CCCCCC" : @"EEEEEE";
}

@end
