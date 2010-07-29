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

@implementation EOGrouping

- (id)initWithDefaultName:(NSString *)_defaultName {
  if ((self = [super init])) {
    self->defaultName = [_defaultName copy];
  }
  return self;
}

- (id)init {
  return [self initWithDefaultName:nil];
}

- (void)dealloc {
  [self->defaultName   release];
  [self->sortOrderings release];
  [super dealloc];
}

/* accessors */

- (void)setDefaultName:(NSString *)_defaultName {
  ASSIGN(self->defaultName, _defaultName);
}
- (NSString *)defaultName {
  return self->defaultName;
}

- (void)setSortOrderings:(NSArray *)_sortOrderings {
  ASSIGN(self->sortOrderings, _sortOrderings);
}

- (NSArray *)sortOrderings {
  return self->sortOrderings;
}

/* operations */

- (NSString *)groupNameForObject:(id)_object {
  [self doesNotRecognizeSelector:_cmd]; // subclass
  return nil;
}

- (NSArray *)orderedGroupNames {
  [self doesNotRecognizeSelector:_cmd]; // subclass
  return nil;
}

- (NSString *)description {
  return @"EOGrouping";
}

@end /* EOGrouping */


NSString *EOGroupingHint = @"EOGroupingHint";

@implementation EOFetchSpecification(Groupings)

- (void)setGroupings:(NSArray *)_groupings {
  NSDictionary        *lhints;
  NSMutableDictionary *md;
  
  lhints = [self hints];
  md = lhints ? [lhints mutableCopy] : [[NSMutableDictionary alloc] init];
  if (_groupings)
    [md setObject:_groupings forKey:EOGroupingHint];
  else
    [md removeObjectForKey:EOGroupingHint];
  lhints = [md copy];
  [md release];
  [self setHints:lhints];
  [lhints release];
}
- (NSArray *)groupings {
  return [[self hints] objectForKey:EOGroupingHint];
}

@end /* EOFetchSpecification(Groupings) */
