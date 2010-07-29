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

#include <NGExtensions/EOQualifier+plist.h>
#include "common.h"

@implementation EOQualifier(plist)

- (id)initWithDictionary:(NSDictionary *)_dict {
  [self release];
  return [[EOQualifier qualifierToMatchAllValues:_dict] retain];
}

- (id)initWithArray:(NSArray *)_array {
  unsigned count;
  NSString *fmt;
  NSArray  *args;
  
  [self release];

  if ((count = [_array count]) == 0) {
    NSLog(@"%s: invalid array for qualifier: %@", __PRETTY_FUNCTION__, _array);
    return nil;
  }
  
  fmt = [_array objectAtIndex:0];
  if (count == 1)
    args = nil;
  else
    args = [_array subarrayWithRange:NSMakeRange(1, (count - 1))];
  
  return [[EOQualifier qualifierWithQualifierFormat:fmt arguments:args]
                       retain];
}

- (id)initWithString:(NSString *)_string {
  [self release];
  return [[EOQualifier qualifierWithQualifierFormat:_string] retain];
}

- (id)initWithPropertyList:(id)_plist owner:(id)_owner {
  if ([_plist isKindOfClass:[NSDictionary class]])
    return [self initWithDictionary:_plist];
  
  if ([_plist isKindOfClass:[NSString class]])
    return [self initWithString:_plist];
  
  if ([_plist isKindOfClass:[NSArray class]])
    return [self initWithArray:_plist];
  
  if ([_plist isKindOfClass:[self class]]) {
    [self release];
    return [_plist copy];
  }

  [self release];
  return nil;
}
- (id)initWithPropertyList:(id)_plist {
  return [self initWithPropertyList:_plist owner:nil];
}

@end /* EOQualifier(plist) */
