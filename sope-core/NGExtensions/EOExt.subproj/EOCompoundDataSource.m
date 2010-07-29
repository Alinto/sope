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

#include "EOCompoundDataSource.h"
#import <EOControl/EOControl.h>
#import "EODataSource+NGExtensions.h"
#import "common.h"

@implementation EOCompoundDataSource

- (id)initWithDataSources:(NSArray *)_ds {
  if ((self = [super init])) {
    self->sources = [_ds shallowCopy];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->sortOrderings      release];
  [self->auxiliaryQualifier release];
  [self->sources            release];
  [super dealloc];
}

/* accessors */

- (void)setSources:(NSArray *)_sources {
  NSNotificationCenter *nc;
  NSEnumerator         *enumerator;
  id                   obj;
      
  if (self->sources == _sources)
    return;
  
  // BUG: this needs to unregister the old datssources!
  _sources = [_sources shallowCopy];
  [self->sources release];
  self->sources = _sources;

  nc         = [NSNotificationCenter defaultCenter];
  enumerator = [self->sources objectEnumerator];
      
  while ((obj = [enumerator nextObject]) != nil) {
    [nc addObserver:self
	selector:@selector(postDataSourceChangedNotification)
	name:EODataSourceDidChangeNotification object:obj];
  }
  [self postDataSourceChangedNotification];
}
- (NSArray *)sources {
  return self->sources;
}

- (void)setAuxiliaryQualifier:(EOQualifier *)_q {
  ASSIGN(self->auxiliaryQualifier, _q);
  [self postDataSourceChangedNotification];
}
- (EOQualifier *)auxiliaryQualifier {
  return self->auxiliaryQualifier;
}

- (void)setSortOrderings:(NSArray *)_so {
  if (self->sortOrderings == _so)
    return;

  _so = [_so shallowCopy];
  [self->sortOrderings release];
  self->sortOrderings = _so;
  
  [self postDataSourceChangedNotification];
}
- (NSArray *)sortOrderings {
  return self->sortOrderings;
}

/* operations */

- (NSArray *)fetchObjects {
  NSArray  *objs;
  unsigned count;

  if ((count = [[self sources] count]) == 0) {
    objs = nil;
  }
  else if (count == 1)
    objs = [[[self sources] objectAtIndex:0] fetchObjects];
  else {
    NSMutableArray *a;
    NSEnumerator   *e;
    EODataSource   *ds;
    
    a = nil;
    e = [[self sources] objectEnumerator];
    while ((ds = [e nextObject])) {
      NSArray *o;

      o = [ds fetchObjects];
      if ([o count] > 0) {
        if (a == nil)
          a = [NSMutableArray arrayWithCapacity:[o count]];
        [a addObjectsFromArray:o];
      }
    }

    objs = [[a shallowCopy] autorelease];
  }

  if (objs == nil)
    return [NSArray array];
  
  if ([self auxiliaryQualifier] != nil)
    objs = [objs filteredArrayUsingQualifier:[self auxiliaryQualifier]];
  
  if ([self sortOrderings] != nil)
    objs = [objs sortedArrayUsingKeyOrderArray:[self sortOrderings]];
  
  return objs;
}

- (void)insertObject:(id)_obj {
  unsigned count;

  if ((count = [[self sources] count]) == 0)
    [super insertObject:_obj];
  else if (count == 1)
    [[[self sources] objectAtIndex:0] insertObject:_obj];
  else {
    NSEnumerator *e;
    EODataSource *ds;

    e = [[self sources] objectEnumerator];
    while ((ds = [e nextObject])) {
      BOOL didFail = NO;
      
      NS_DURING
        [ds insertObject:_obj];
      NS_HANDLER
        didFail = YES;
      NS_ENDHANDLER;
      
      if (!didFail)
        return;
    }
    /* all datasources failed to insert .. */
    [super insertObject:_obj];
  }
  [self postDataSourceChangedNotification];
}

- (void)deleteObject:(id)_obj {
  unsigned count;

  if ((count = [[self sources] count]) == 0)
    [super deleteObject:_obj];
  else if (count == 1)
    [[[self sources] objectAtIndex:0] deleteObject:_obj];
  else {
    NSEnumerator *e;
    EODataSource *ds;

    e = [[self sources] objectEnumerator];
    while ((ds = [e nextObject])) {
      BOOL didFail = NO;
      
      NS_DURING
        [ds deleteObject:_obj];
      NS_HANDLER
        didFail = YES;
      NS_ENDHANDLER;
      
      if (!didFail)
        return;
    }
    /* all datasources failed to delete .. */
    [super deleteObject:_obj];
  }
  [self postDataSourceChangedNotification];  
}

- (id)createObject {
  unsigned count;
  id newObj = nil;
  
  if ((count = [[self sources] count]) == 0)
    newObj = [[super createObject] retain];
  else if (count == 1)
    newObj = [[[[self sources] objectAtIndex:0] createObject] retain];
  else {
    NSEnumerator *e;
    EODataSource *ds;
    
    e = [[self sources] objectEnumerator];
    while ((ds = [e nextObject]) != nil) {
      id obj;

      if ((obj = [ds createObject])) {
        newObj = [obj retain];
	break;
      }
    }
    /* all datasources failed to create .. */
    if (newObj == nil)
      newObj = [[super createObject] retain];
  }
  [self postDataSourceChangedNotification];  
  return [newObj autorelease];
}

- (void)updateObject:(id)_obj {
  unsigned count;

  if ((count = [[self sources] count]) == 0)
    [super updateObject:_obj];
  else if (count == 1)
    [[[self sources] objectAtIndex:0] updateObject:_obj];
  else {
    NSEnumerator *e;
    EODataSource *ds;

    e = [[self sources] objectEnumerator];
    while ((ds = [e nextObject])) {
      BOOL didFail = NO;
      
      NS_DURING
        [ds updateObject:_obj];
      NS_HANDLER
        didFail = YES;
      NS_ENDHANDLER;
      
      if (!didFail)
        return;
    }
    /* all datasources failed to update .. */
    [super updateObject:_obj];
  }
  [self postDataSourceChangedNotification];  
}

- (EOClassDescription *)classDescriptionForObjects {
  unsigned count;
  NSEnumerator *e;
  EODataSource *ds;
  
  if ((count = [[self sources] count]) == 0)
    return [super classDescriptionForObjects];

  if (count == 1)
    return [[[self sources] objectAtIndex:0] classDescriptionForObjects];
    
  e = [[self sources] objectEnumerator];
  while ((ds = [e nextObject]) != nil) {
    EOClassDescription *cd;

    if ((cd = [ds classDescriptionForObjects]) != nil)
      return cd;
  }
  /* all datasources failed to create .. */
  return [super classDescriptionForObjects];
}

@end /* EOCompoundDataSource */
