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

#include <EOControl/EOArrayDataSource.h>
#include <EOControl/EOFetchSpecification.h>
#include <EOControl/EOSortOrdering.h>
#include <EOControl/EOQualifier.h>
#include "common.h"

@interface EODataSource(PostChange)
- (void)postDataSourceChangedNotification;
@end

@implementation EOArrayDataSource

- (id)init {
  if ((self = [super init])) {
    self->objects = [[NSMutableArray alloc] init];
  }
  return self;
}
- (void)dealloc {
  [self->fetchSpecification release];
  [self->objects            release];
  [super dealloc];
}

/* accessors */

- (void)setFetchSpecification:(EOFetchSpecification *)_fspec {
  if ([self->fetchSpecification isEqual:_fspec])
    return;
  
  [self->fetchSpecification autorelease];
  self->fetchSpecification = [_fspec copy];
  
  [self postDataSourceChangedNotification];
}
- (EOFetchSpecification *)fetchSpecification {
  return self->fetchSpecification;
}

- (void)setArray:(NSArray *)_array {
  [self->objects removeAllObjects];
  [self->objects addObjectsFromArray:_array];
}

/* fetching */

- (NSArray *)fetchObjects {
  NSArray *result;
  
  if (self->fetchSpecification == nil) {
    result = [[self->objects copy] autorelease];
  }
  else {
    EOQualifier *q;
    NSArray     *sort;
    
    q    = [self->fetchSpecification qualifier];
    sort = [self->fetchSpecification sortOrderings];
    
    if (q == nil) {
      if (sort)
        result = [self->objects sortedArrayUsingKeyOrderArray:sort];
      else
        result = [[self->objects copy] autorelease];
    }
    else {
      result = [self->objects filteredArrayUsingQualifier:q];
      if (sort) result = [result sortedArrayUsingKeyOrderArray:sort];
    }
  }
  return result;
}

/* operations */

- (void)deleteObject:(id)_object {
  [self->objects removeObjectIdenticalTo:_object];
  [self postDataSourceChangedNotification];
}

- (void)insertObject:(id)_object {
  [self->objects addObject:_object];
  [self postDataSourceChangedNotification];
}

- (id)createObject {
  return [NSMutableDictionary dictionaryWithCapacity:16];
}

@end /* EOArrayDataSource */
