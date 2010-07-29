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

#ifndef __EOFetchSpecification_CoreData_H__
#define __EOFetchSpecification_CoreData_H__

#include <EOControl/EOFetchSpecification.h>

/*
  EOFetchSpecification(CoreData)
  
  Convert an libEOControl EOFetchSpecification to a CoreData compliant fetch
  specification.
  
  A major difference is that a CoreData NSFetchRequest takes the entity object
  while in EOF we just pass the name of it.
*/

@class NSArray;
@class NSFetchRequest, NSManagedObjectModel, NSEntityDescription;

@interface EOFetchSpecification(CoreData)

- (id)initWithFetchRequest:(NSFetchRequest *)_fr;

- (NSFetchRequest *)fetchRequestWithEntity:(NSEntityDescription *)_entity;
- (NSFetchRequest *)fetchRequestWithModel:(NSManagedObjectModel *)_model;
- (NSArray *)sortOrderingsAsSortDescriptors;

@end

#endif /* __EOFetchSpecification_CoreData_H__ */
