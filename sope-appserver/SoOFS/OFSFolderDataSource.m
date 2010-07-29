/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "OFSFolderDataSource.h"
#include <EOControl/EOQualifier.h>
#include <EOControl/EOSortOrdering.h>
#include "common.h"

@interface OFSFolderFetchEnum : NSEnumerator
{
  id           folder;
  NSEnumerator *names;
  EOQualifier  *qualifier;
  unsigned     limit;
  unsigned     count;
}

- (id)initWithFolder:(id)_folder 
  fetchSpecification:(EOFetchSpecification *)_fs;

@end

@implementation OFSFolderDataSource

- (id)initWithFolder:(id)_folder {
  if ((self = [super init])) {
    self->folder = [_folder retain];
  }
  return self;
}
- (id)init {
  return [self initWithFolder:nil];
}
+ (id)dataSourceOnFolder:(id)_folder {
  return [[[self alloc] initWithFolder:_folder] autorelease];
}

- (void)dealloc {
  [self->fetchSpecification release];
  [self->folder             release];
  [super dealloc];
}

/* accessors */

- (id)folder {
  return self->folder;
}

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

/* operations */

- (NSEnumerator *)fetchEnumerator {
  OFSFolderFetchEnum   *e;
  EOFetchSpecification *fs;
  NSArray              *sortOrderings;
  NSAutoreleasePool    *pool;
  NSArray              *array;
  unsigned    limit;
  EOQualifier *q;
  
  if ((fs = [self fetchSpecification]) == nil) {
    e = [[OFSFolderFetchEnum alloc] initWithFolder:[self folder]
				       fetchSpecification:nil];
    return [e autorelease];
  }
    
  sortOrderings = [fs sortOrderings];
  if ([sortOrderings count] == 0) {
    /* can do incremental fetch ... */
    e = [[OFSFolderFetchEnum alloc] initWithFolder:[self folder]
				       fetchSpecification:fs];
    return [e autorelease];
  }
  
  /* fetch => filter => limit => sort, then return enum ... */
  
  pool = [[NSAutoreleasePool alloc] init];
	
  array = [[self folder] allValues];
  
  if ((q = [fs qualifier])) 
    array = [array filteredArrayUsingQualifier:q];

  if ((limit = [fs fetchLimit]) > 0) {
    /* limit ... */
    if (limit < [array count])
      array = [array subarrayWithRange:NSMakeRange(0, limit)];
  }
  
  array = [array sortedArrayUsingKeyOrderArray:sortOrderings];
  
  e = [[array objectEnumerator] retain];
  
  [pool release];
  return [e autorelease];
}

- (NSArray *)fetchObjects {
  NSEnumerator *e;
  
  e = [self fetchEnumerator];
  return [[[NSArray alloc] initWithObjectsFromEnumerator:e] autorelease];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  OFSFolderDataSource *ds;
  
  ds = [[[self class] alloc] initWithFolder:[self folder]];
  [ds setFetchSpecification:[self fetchSpecification]];
  return ds;
}

@end /* OFSFolderDataSource */

@implementation OFSFolderFetchEnum

- (id)initWithFolder:(id)_folder 
  fetchSpecification:(EOFetchSpecification *)_fs
{
  if ((self = [super init])) {
    self->folder    = [_folder retain];
    self->names     = [[[self->folder allKeys] objectEnumerator] retain];
    self->qualifier = [[_fs qualifier] retain];
    self->limit     = [_fs fetchLimit];
  }
  return self;
}
- (id)init {
  return [self initWithFolder:nil fetchSpecification:nil];
}

- (void)dealloc {
  [self->qualifier release];
  [self->names     release];
  [self->folder    release];
  [super dealloc];
}

/* state */

- (void)clear {
  [self->qualifier release]; self->qualifier = nil;
  [self->names     release]; self->names     = nil;
  [self->folder    release]; self->folder    = nil;
}

/* enumerator */

- (id)_nextObjectToBeFiltered {
  NSString *nextName;
  id object;
  
  if ((nextName = [self->names nextObject]) == nil) {
    [self clear];
    return nil;
  }
  if ((object = [(NSDictionary *)self->folder objectForKey:nextName]) == nil) {
    [self clear];
    return nil;
  }
  return object;
}

- (id)nextObject {
  id obj;

  if(self->qualifier != nil) {
    do {
      if ((obj = [self _nextObjectToBeFiltered]) == nil) {
        [self clear];
        return nil;
      }
    }
    while (![(id<EOQualifierEvaluation>)self->qualifier
      evaluateWithObject:obj]);
  }
  else {
    if ((obj = [self _nextObjectToBeFiltered]) == nil) {
      [self clear];
      return nil;
    }
  }

  self->count++;
  if (self->limit > 0 && self->count > self->limit) {
    [self clear];
    return nil;
  }
  
  return obj;
}

@end /* OFSFolderFetchEnum */
