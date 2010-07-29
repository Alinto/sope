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
#import <EOControl/EOSortOrdering.h>
#include "common.h"

@implementation NSArray(EOGrouping)

static BOOL ProfileComponents = NO;

- (NSDictionary *)arrayGroupedBy:(EOGrouping *)_grouping {
  NSMutableDictionary *result;
  NSEnumerator        *keyEnum;
  NSString            *key;
  NSArray             *sortings;
  int                 i, cnt;
  IMP                 objAtIndex;
  IMP                 groupForObj;
  NSTimeInterval      st = 0.0;
  
  if (ProfileComponents)
    st = [[NSDate date] timeIntervalSince1970];
  
  cnt    = [self count];
  result = [NSMutableDictionary dictionaryWithCapacity:cnt];

  objAtIndex  = [self methodForSelector:@selector(objectAtIndex:)];
  groupForObj = [_grouping methodForSelector:@selector(groupNameForObject:)];
  
  for (i = 0; i < cnt; i++) {
    NSString       *gName = nil; // groupName
    NSMutableArray *tmp   = nil;
    id   obj              = nil;

    obj   = objAtIndex(self, @selector(objectAtIndex:), i);
    gName = groupForObj(_grouping, @selector(groupNameForObject:), obj);

    if (gName == nil) continue;

    if (!(tmp = [result objectForKey:gName])) {
      tmp = [[[NSMutableArray alloc] initWithCapacity:4] autorelease];
      [result setObject:tmp forKey:gName];
    }
    [tmp addObject:obj];
  }
  
  sortings = [_grouping sortOrderings];

  if ([sortings count] > 0) {
    // sort each group
    keyEnum = [result keyEnumerator];
    while ((key = [keyEnum nextObject])) {
      NSArray *tmp;
    
      tmp = [result objectForKey:key];
      tmp = [tmp  sortedArrayUsingKeyOrderArray:sortings];
      [result setObject:tmp forKey:key];
    }
  }
  
  if (ProfileComponents) {
    NSTimeInterval diff;
    diff = [[NSDate date] timeIntervalSince1970] - st;
    
    printf("NSArray+Grouping: %0.4fs\n", diff);
  }
  
  return result;
}

@end /* NSArray(EOGrouping) */
