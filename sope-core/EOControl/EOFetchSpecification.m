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

#include "EOFetchSpecification.h"
#include "EOQualifier.h"
#include "EOSortOrdering.h"
#include "common.h"

@implementation EOFetchSpecification

+ (EOFetchSpecification *)fetchSpecificationWithEntityName:(NSString *)_ename
  qualifier:(EOQualifier *)_qualifier
  sortOrderings:(NSArray *)_sortOrderings
{
  EOFetchSpecification *fs = nil;

  fs = [[self alloc] initWithEntityName:_ename
                     qualifier:_qualifier
                     sortOrderings:_sortOrderings
                     usesDistinct:NO isDeep:NO
		     hints:nil];
  return [fs autorelease];
}

- (id)initWithEntityName:(NSString *)_name
  qualifier:(EOQualifier *)_qualifier
  sortOrderings:(NSArray *)_sortOrderings
  usesDistinct:(BOOL)_dflag isDeep:(BOOL)_isDeep
  hints:(NSDictionary *)_hints
{
  if ((self = [super init])) {
    self->entityName    = [_name copyWithZone:[self zone]];
    self->qualifier     = [_qualifier     retain];
    self->sortOrderings = [_sortOrderings retain];
    self->fetchLimit    = 0;
    self->hints         = [_hints retain];
    
    self->fsFlags.usesDistinct = _dflag  ? 1 : 0;
    self->fsFlags.deep         = _isDeep ? 1 : 0;
  }
  return self;
}
- (id)initWithEntityName:(NSString *)_name
  qualifier:(EOQualifier *)_qualifier
  sortOrderings:(NSArray *)_sortOrderings
  usesDistinct:(BOOL)_dflag
{
  // DEPRECATED
  // Note: this does not work with GDL2! (and probably not with EOF 4)
  return [self initWithEntityName:_name qualifier:_qualifier 
	       sortOrderings:_sortOrderings usesDistinct:_dflag
               isDeep:NO hints:nil];
}

- (id)init {
  if ((self = [super init])) {
  }
  return self;
}

- (void)dealloc {
  [self->hints         release];
  [self->entityName    release];
  [self->qualifier     release];
  [self->sortOrderings release];
  [super dealloc];
}

/* accessors */

- (void)setEntityName:(NSString *)_name {
  id tmp;
  
  if (_name == self->entityName)
    return;
  
  tmp = self->entityName;
  self->entityName = [_name copyWithZone:[self zone]];
  [tmp release];
}
- (NSString *)entityName {
  return self->entityName;
}

- (void)setQualifier:(EOQualifier *)_qualifier {
  ASSIGN(self->qualifier, _qualifier);
}
- (EOQualifier *)qualifier {
  return self->qualifier;
}

- (void)setSortOrderings:(NSArray *)_orderings {
  ASSIGN(self->sortOrderings, _orderings);
}
- (NSArray *)sortOrderings {
  return self->sortOrderings;
}

- (void)setUsesDistinct:(BOOL)_flag {
  self->fsFlags.usesDistinct = _flag ? 1 : 0;
}
- (BOOL)usesDistinct {
  return self->fsFlags.usesDistinct ? YES : NO;
}

- (void)setLocksObjects:(BOOL)_flag {
  self->fsFlags.locksObjects = _flag ? 1 : 0;
}
- (BOOL)locksObjects {
  return self->fsFlags.locksObjects ? YES : NO;
}

- (void)setIsDeep:(BOOL)_flag {
  self->fsFlags.deep = _flag ? 1 : 0;
}
- (BOOL)isDeep {
  return self->fsFlags.deep ? YES : NO;
}

- (void)setFetchLimit:(unsigned)_limit {
  self->fetchLimit = _limit;
}
- (unsigned)fetchLimit {
  return self->fetchLimit;
}

- (void)setHints:(NSDictionary *)_hints {
  ASSIGN(self->hints, _hints);
}
- (NSDictionary *)hints {
  return self->hints;
}

/* bindings */

- (EOFetchSpecification *)
  fetchSpecificationWithQualifierBindings:(NSDictionary *)_bindings
{
  EOQualifier          *q     = nil;
  EOFetchSpecification *newfs = nil;

  q     = [[self qualifier] qualifierWithBindings:_bindings
                            requiresAllVariables:NO];
  newfs = [[[self class] alloc]
                  initWithEntityName:[self entityName]
                  qualifier:q
                  sortOrderings:[self sortOrderings]
                  usesDistinct:[self usesDistinct]];
  
  [newfs setLocksObjects:[self locksObjects]];
  [newfs setFetchLimit:[self fetchLimit]];
  
  return [newfs autorelease];
}

/* GDL2 compatibility */

- (EOFetchSpecification *)
  fetchSpecificationByApplyingBindings:(NSDictionary *)_bindings
{
  return [self fetchSpecificationWithQualifierBindings:_bindings];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  EOFetchSpecification *fspec;
  NSDictionary *hdict;
  
  hdict = [[self hints] copy];
  
  fspec = [[[self class] alloc] initWithEntityName:[self entityName]
                                qualifier:[self qualifier]
                                sortOrderings:[self sortOrderings]
                                usesDistinct:[self usesDistinct]
				isDeep:[self isDeep] hints:hdict];
  [fspec setLocksObjects:[self locksObjects]];
  [fspec setFetchLimit:[self fetchLimit]];
  [hdict release];
  
  return fspec;
}

/* Equality */

- (BOOL)isEqualToFetchSpecification:(EOFetchSpecification *)_fspec {
  id t1, t2;
  if (_fspec == self)
    return YES;

  t1 = [self entityName];
  t2 = [_fspec entityName];
  if (t1 != t2) {
    if (![t1 isEqualToString:t2])
      return NO;
  }
  
  t1 = [self sortOrderings];
  t2 = [_fspec sortOrderings];
  if (t1 != t2) {
    if (![t1 isEqual:t2])
      return NO;
  }

  t1 = [self qualifier];
  t2 = [_fspec qualifier];
  if (t1 != t2) {
    if (![t1 isEqual:t2])
      return NO;
  }
  
  if ([self usesDistinct] != [_fspec usesDistinct])
    return NO;
  if ([self locksObjects] != [_fspec locksObjects])
    return NO;
  if ([self fetchLimit] != [_fspec fetchLimit])
    return NO;

  t1 = [self hints];
  t2 = [_fspec hints];
  if (t1 != t2) {
    if (![t1 isEqual:t2])
      return NO;
  }
  
  return YES;
}
- (BOOL)isEqual:(id)_other {
  if ([_other isKindOfClass:[EOFetchSpecification class]])
    return [self isEqualToFetchSpecification:_other];
  
  return NO;
}

/* remapping keys */

- (EOFetchSpecification *)fetchSpecificationByApplyingKeyMap:(NSDictionary *)_m {
  NSAutoreleasePool    *pool;
  EOFetchSpecification *fs;
  NSMutableDictionary  *lHints;
  EOQualifier    *q = nil;
  NSMutableArray *o = nil;

  pool = [[NSAutoreleasePool alloc] init];
  
  /* process qualifier */
  
  q = [self->qualifier qualifierByApplyingKeyMap:_m];
  
  /* process attributes */
  
  if (self->hints) {
    NSArray  *a;
    unsigned len;
    
    a = [self->hints objectForKey:@"attributes"];
    if ((len = [a count]) > 0) {
      NSMutableArray *ma;
      unsigned i;
      
      ma = [[NSMutableArray alloc] initWithCapacity:(len + 1)];
      for (i = 0; i < len; i++) {
	NSString *key, *tkey;
	
	key  = [a objectAtIndex:i];
	tkey = [_m objectForKey:key];
	
	[ma addObject:(tkey ? tkey : key)];
      }
      
      lHints = [self->hints mutableCopy];
      [lHints setObject:ma forKey:@"attributes"];
      [ma release];
    }
    else
      lHints = [self->hints retain];
  }
  else 
    lHints = nil;
  
  /* process orderings */
  
  if (self->sortOrderings) {
    unsigned i, len;
    
    len = [self->sortOrderings count];
    o   = [[NSMutableArray alloc] initWithCapacity:len];
    for (i = 0; i < len; i++) {
      EOSortOrdering *so, *tso;
      
      so  = [self->sortOrderings objectAtIndex:i];
      tso = [so sortOrderingByApplyingKeyMap:_m];
      [o addObject:tso ? tso : so];
    }
  }
  else
    o = nil;
  
  /* construct result */
  
  fs = [[EOFetchSpecification alloc] initWithEntityName:self->entityName
				     qualifier:q
				     sortOrderings:o
				     usesDistinct:[self usesDistinct]
				     isDeep:[self isDeep]
				     hints:[self hints]];
  [fs setLocksObjects:[self locksObjects]];
  [fs setFetchLimit:self->fetchLimit];
  if (lHints) {
    [fs setHints:lHints];
    [lHints release];
  }
  [o release];
  [pool release];
  return [fs autorelease];
}

/* key/value archiving */

- (id)initWithKeyValueUnarchiver:(EOKeyValueUnarchiver *)_unarchiver {
  if ((self = [super init]) != nil) {
    self->entityName = [[_unarchiver decodeObjectForKey:@"entityName"] copy];
    self->qualifier  = [[_unarchiver decodeObjectForKey:@"qualifier"]  retain];
    self->hints      = [[_unarchiver decodeObjectForKey:@"hints"] copy];
    self->sortOrderings = 
      [[_unarchiver decodeObjectForKey:@"sortOrderings"] retain];
    
    self->fetchLimit = [_unarchiver decodeIntForKey:@"fetchLimit"];
    
    self->fsFlags.usesDistinct = 
      [_unarchiver decodeBoolForKey:@"usesDistinct"] ? 1 : 0;
    self->fsFlags.locksObjects = 
      [_unarchiver decodeBoolForKey:@"locksObjects"] ? 1 : 0;
    self->fsFlags.deep = 
      [_unarchiver decodeBoolForKey:@"deep"] ? 1 : 0;
  }
  return self;
}
- (void)encodeWithKeyValueArchiver:(EOKeyValueArchiver *)_archiver {
  [_archiver encodeObject:[self entityName]    forKey:@"entityName"];
  [_archiver encodeObject:[self qualifier]     forKey:@"qualifier"];
  [_archiver encodeObject:[self hints]         forKey:@"hints"];
  [_archiver encodeObject:[self sortOrderings] forKey:@"sortOrderings"];

  [_archiver encodeInt:[self fetchLimit] forKey:@"fetchLimit"];
  
  [_archiver encodeBool:self->fsFlags.usesDistinct forKey:@"usesDistinct"];
  [_archiver encodeBool:self->fsFlags.locksObjects forKey:@"locksObjects"];
  [_archiver encodeBool:self->fsFlags.deep         forKey:@"deep"];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  id tmp;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];

  if ((tmp = [self entityName]))
    [ms appendFormat:@" entity=%@", tmp];
  if ((tmp = [self qualifier]))
    [ms appendFormat:@" qualifier=%@", tmp];
  
  if ((tmp = [self sortOrderings]))
    [ms appendFormat:@" orderings=%@", tmp];
  
  if ([self locksObjects]) [ms appendString:@" locks"];
  if ([self usesDistinct]) [ms appendString:@" distinct"];
  
  if ([self fetchLimit] > 0)
    [ms appendFormat:@" limit=%i", [self fetchLimit]];

  if ((tmp = [self hints])) {
    NSEnumerator *e;
    NSString *hint;
    BOOL isFirst = YES;
    
    [ms appendString:@" hints:"];
    e = [tmp keyEnumerator];
    while ((hint = [e nextObject])) {
      if (isFirst) isFirst = NO;
      else [ms appendString:@","];
      [ms appendString:hint];
      [ms appendString:@"="];
      [ms appendString:[[(NSDictionary *)tmp objectForKey:hint] stringValue]];
    }
  }
  
  [ms appendString:@">"];
  return ms;
}

@end /* EOFetchSpecification */
