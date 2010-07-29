/*
  Copyright (C) 2005 SKYRIX Software AG
  
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

#include "EOFetchSpecification+CoreData.h"
#include "EOSortOrdering+CoreData.h"
#include "EOQualifier+CoreData.h"
#include "common.h"


@implementation EOFetchSpecification(CoreData)

- (id)initWithFetchRequest:(NSFetchRequest *)_fr {
  NSMutableArray *so;
  EOQualifier *q;
  NSArray     *sd;
  unsigned    count;

  if (_fr == nil) {
    [self release];
    return nil;
  }

  /* convert sort descriptors */
  
  sd = [_fr sortDescriptors];
  so = nil;
  if ((count = [sd count]) > 0) {
    unsigned i;
    
    so = [[NSMutableArray alloc] initWithCapacity:count];
    for (i = 0; i < count; i++) {
      EOSortOrdering *soo;

      soo = [[EOSortOrdering alloc] initWithSortDescriptor:
				      [sd objectAtIndex:i]];
      if (soo == nil) {
	soo = [sd objectAtIndex:i]; /* oh well, this is sneaky */
	NSLog(@"WARNING(%s): could not convert NSSortDescriptor to "
	      @"EOSortOrdering: %@", __PRETTY_FUNCTION__, soo);
      }
      [so addObject:soo];
      [soo release];
    }
  }
  
  /* convert predicate */
  
  q = [EOQualifier qualifierForPredicate:[_fr predicate]];
  
  /* create object */
  
  // TODO: maybe add 'affectedStores' as a hint?
  self = [self initWithEntityName:[[_fr entity] name]
	       qualifier:q sortOrderings:so
	       usesDistinct:YES isDeep:NO
	       hints:nil];
  [so release]; so = nil;
  
  [self setFetchLimit:[_fr fetchLimit]];
  return self;
}

- (NSArray *)sortOrderingsAsSortDescriptors {
  NSMutableArray *ma;
  NSArray  *a;
  unsigned i, count;
  
  if ((a = [self sortOrderings]) == nil)
    return nil;
  if ((count = [a count]) == 0)
    return nil;
  
  if (count == 1) /* common, optimization */
    return [NSArray arrayWithObject:[[a objectAtIndex:0] asSortDescriptor]];
  
  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++)
    [ma addObject:[[a objectAtIndex:i] asSortDescriptor]];
  return ma;
}

- (NSFetchRequest *)fetchRequestWithEntity:(NSEntityDescription *)_entity {
  NSFetchRequest *fr;
  unsigned int limit;
  
  fr = [[[NSFetchRequest alloc] init] autorelease];
  [fr setEntity:_entity];
  
  if ((limit = [self fetchLimit]) > 0)
    [fr setFetchLimit:limit];
  
  [fr setPredicate:[[self qualifier] asPredicate]];
  [fr setSortDescriptors:[self sortOrderingsAsSortDescriptors]];
  return fr;
}

- (NSFetchRequest *)fetchRequestWithModel:(NSManagedObjectModel *)_model {
  NSEntityDescription *entity;
  NSString *s;
  
  entity = ((s = [self entityName]) != nil)
    ? [[_model entitiesByName] objectForKey:s]
    : nil;
  
  return [self fetchRequestWithEntity:entity];
}

@end /* EOFetchSpecification(CoreData) */


@implementation NSFetchRequest(EOCoreData)

- (NSFetchRequest *)fetchRequestWithEntity:(NSEntityDescription *)_entity {
  return self;
}
- (NSFetchRequest *)fetchRequestWithModel:(NSManagedObjectModel *)_model {
  return self;
}

@end /* NSFetchRequest(EOCoreData) */
