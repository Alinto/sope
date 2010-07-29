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

#include "EOFilterDataSource.h"
#include "EODataSource+NGExtensions.h"
#include "EOGrouping.h"
#import <EOControl/EOControl.h>
#include "common.h"

@interface NSDictionary(EOFilterDataSource)

- (NSArray *)flattenedArrayWithHint:(unsigned int)_hint
  andKeys:(NSArray *)_keys;

@end

@implementation EOFilterDataSource

- (id)initWithDataSource:(EODataSource *)_ds {
  if ((self = [super init])) {
    [self setSource:_ds];
  }
  return self;
}
- (id)init {
  return [self initWithDataSource:nil];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->sortOrderings      release];
  [self->groupings          release];
  [self->auxiliaryQualifier release];
  [self->source             release];
  [super dealloc];
}

/* accessors */

- (void)setSource:(EODataSource *)_source {
  NSNotificationCenter *nc;
  
  if (self->source == _source)
    return;
    
  nc = [NSNotificationCenter defaultCenter];

  if (self->source) {
      [nc removeObserver:self
          name:EODataSourceDidChangeNotification object:self->source];
  }
    
  ASSIGN(self->source, _source);
    
  if (self->source) {
      [nc addObserver:self selector:@selector(_sourceDidChange:)
          name:EODataSourceDidChangeNotification object:self->source];
  }
    
  [self postDataSourceChangedNotification];
}
- (EODataSource *)source {
  return self->source;
}

- (void)setAuxiliaryQualifier:(EOQualifier *)_q {
  if ([_q isEqual:self->auxiliaryQualifier])
    return;

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

- (void)setGroupings:(NSArray *)_groupings {
  if (self->groupings == _groupings)
    return;
  
  _groupings = [_groupings shallowCopy];
  [self->groupings release];
  self->groupings = _groupings;
  [self postDataSourceChangedNotification];  
}
- (NSArray *)groupings {
  return self->groupings;
}

- (void)setFetchSpecification:(EOFetchSpecification *)_fspec {
  [[self source] setFetchSpecification:_fspec];
}
- (EOFetchSpecification *)fetchSpecification {
  return [[self source] fetchSpecification];
}

/* notifications */

- (void)_sourceDidChange:(NSNotification *)_notification {
  [self postDataSourceChangedNotification];
}

/* operations */

- (NSArray *)fetchObjects {
  NSAutoreleasePool *pool;
  NSArray *objs;
  NSArray *groups;

  pool = [[NSAutoreleasePool alloc] init];
  
  objs = [[self source] fetchObjects];
  
  if ([self auxiliaryQualifier] != nil)
    objs = [objs filteredArrayUsingQualifier:[self auxiliaryQualifier]];

  if ((groups = [self groupings]) != nil) {
    unsigned int cnt;
    EOGrouping   *grouping;
    NSArray      *allKeys;
    NSArray      *sos;
    NSDictionary *groupDict;

    cnt = [objs count];

    grouping = [groups lastObject];
    
    if ((sos = [self sortOrderings]) != nil)
      [grouping setSortOrderings:sos];
    
    groupDict = [objs arrayGroupedBy:grouping];

    allKeys = [groupDict allKeys];
    allKeys = [allKeys sortedArrayUsingSelector:@selector(compare:)];
    objs    = [groupDict flattenedArrayWithHint:cnt andKeys:allKeys];
  }
  else if ([self sortOrderings] != nil)
    objs = [objs sortedArrayUsingKeyOrderArray:[self sortOrderings]];
  
  objs = [objs copy];
  [pool release];
  
  return [objs autorelease];
}

- (void)insertObject:(id)_obj {
  [[self source] insertObject:_obj];
}

- (void)deleteObject:(id)_obj {
  [[self source] deleteObject:_obj];
}

- (void)updateObject:(id)_obj {
  [self->source updateObject:_obj];
}

- (id)createObject {
  return [[self source] createObject];
}

- (EOClassDescription *)classDescriptionForObjects {
  return [[self source] classDescriptionForObjects];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->source != nil)
    [ms appendFormat:@" source=%@", self->source];
  if (self->auxiliaryQualifier != nil) 
    [ms appendFormat:@" qualifier=%@", self->auxiliaryQualifier];
  if (self->sortOrderings != nil)
    [ms appendFormat:@" orderings=%@", self->sortOrderings];
  if (self->groupings != nil)
    [ms appendFormat:@" groupings=%@", self->groupings];
  
  [ms appendString:@">"];
  return ms;
}

@end /* EOFilterDataSource */


@implementation NSDictionary(EOFilterDataSource)

- (NSArray *)flattenedArrayWithHint:(unsigned int)_hint
  andKeys:(NSArray *)_keys
{
  /*
    This works on a dictionary of arrays. It walks over the keys in the given
    order and flattenes the value arrays into one array.
  */
  NSMutableArray *result = nil;
  unsigned int   i, cnt;
  
  result =
    [[NSMutableArray alloc] initWithCapacity:_hint]; // should be improved
  
  for (i = 0, cnt = [_keys count]; i < cnt; i++) {
    NSString *key;
    NSArray  *tmp;
    
    key = [_keys objectAtIndex:i];
    tmp = [self objectForKey:key];
    [result addObjectsFromArray:tmp];
  }
  
  return [result autorelease];
}

@end /* NSDictionary(EOFilterDataSource) */
