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

@interface WeekOverview : WOComponent
{
  NSArray *list;
}
@end

#include "common.h"

@implementation WeekOverview

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

/* accessors */

- (NSArray *)abList {
  return [NSArray arrayWithObjects:@"a", @"b", nil];
}
- (NSArray *)cdList {
  return [NSArray arrayWithObjects:@"c", @"d", nil];
}

- (NSCalendarDate *)weekStart {
  NSCalendarDate *ws;
  
  ws = [NSCalendarDate dateWithString:@"2000-11-06 00:00:00 +0100"
                       calendarFormat:@"%Y-%m-%d %H:%M:%S %z"];
  if (ws == nil)
    [self logWithFormat:@"couldn't create weekstart !"];
  return ws;
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

@end /* WeekOverview */
