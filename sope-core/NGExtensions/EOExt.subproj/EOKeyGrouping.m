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

@implementation EOKeyGrouping

- (id)initWithKey:(NSString *)_key {
  if ((self = [super initWithDefaultName:nil]) != nil) {
    self->key = [_key copy];
    
    // TODO: create on-demand?
    self->groupNames = [[NSMutableArray alloc] initWithCapacity:32];
  }
  return self;
}

- (void)dealloc {
  [self->key        release];
  [self->groupNames release];
  [super dealloc];
}

/* accessors */

- (void)setKey:(NSString *)_key {
  NSAssert1(_key != nil, @"%s: nil _key parameter", __PRETTY_FUNCTION__);
  ASSIGNCOPY(self->key, _key);
}
- (NSString *)key {
  return self->key;
}

/* operations */

- (NSString *)groupNameForObject:(id)_object {
  NSString *result = nil;

  if ([self->key length] == 0)
    return @"";
  
  result = [[_object valueForKey:self->key] stringValue];
  result = (result != nil) ? result : self->defaultName;
  
  if (result == nil)
    return nil;
  
  if (![self->groupNames containsObject:result])
    [self->groupNames addObject:result];
  
  return result;
}

- (NSArray *)orderedGroupNames {
  if ([self->key length] == 0)
    return [NSArray arrayWithObject:@""];
  
  return self->groupNames;
}

@end /* EOKeyGrouping */
