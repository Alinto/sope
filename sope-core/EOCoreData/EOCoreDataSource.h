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

#ifndef __EOCoreDataSource_H__
#define __EOCoreDataSource_H__

#include <EOControl/EODataSource.h>

/*
  EOCoreDataSource
  
  This wraps a NSManagedObjectContext in an EODataSource. It corresponds to
  the EODatabaseDataSource available in EOF.
  
  Note: if you use -setFetchRequest: all the EO related methods will be reset!
*/

@class NSArray, NSDictionary;
@class NSManagedObjectContext, NSEntityDescription, NSFetchRequest;
@class EOQualifier, EOFetchSpecification;

@interface EOCoreDataSource : EODataSource
{
  NSManagedObjectContext *managedObjectContext;
  NSEntityDescription    *entity;
  EOFetchSpecification   *fetchSpecification;
  EOQualifier            *auxiliaryQualifier;
  NSDictionary           *qualifierBindings;
  NSFetchRequest         *fetchRequest;
  struct {
    int isFetchEnabled:1;
    int isEntityFromFetchSpec:1;
    int reserved:30;
  } ecdFlags;
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)_moc
  entity:(NSEntityDescription *)_entity;

/* fetch-spec */

- (void)setFetchSpecification:(EOFetchSpecification *)_fspec;
- (EOFetchSpecification *)fetchSpecification;
- (EOFetchSpecification *)fetchSpecificationForFetch;

- (void)setAuxiliaryQualifier:(EOQualifier *)_qualifier;
- (EOQualifier *)auxiliaryQualifier;

- (void)setIsFetchEnabled:(BOOL)_flag;
- (BOOL)isFetchEnabled;

- (NSArray *)qualifierBindingKeys;
- (void)setQualifierBindings:(NSDictionary *)_bindings;
- (NSDictionary *)qualifierBindings;

/* directly access a CoreData fetch request */

- (void)setFetchRequest:(NSFetchRequest *)_fr;
- (NSFetchRequest *)fetchRequest;

/* accessors */

- (NSEntityDescription *)entity;
- (NSManagedObjectContext *)managedObjectContext;

@end

#endif /* __EOCoreDataSource_H__ */
