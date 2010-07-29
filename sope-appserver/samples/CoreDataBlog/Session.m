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

#include <NGObjWeb/WOSession.h>

@interface Session : WOSession
@end

#include "WOSession+CoreData.h"
#include "WOCoreDataApplication.h"
#include "common.h"

@implementation Session

- (NSArray *)posts {
  NSFetchRequest *fs;
  NSArray *a;
  NSError *error = nil;
  
  fs = [[[NSFetchRequest alloc] init] autorelease];
  
  [fs setEntity:[[[[self application] managedObjectModel] 
		   entitiesByName] objectForKey:@"Post"]];
  // [self logWithFormat:@"entity: %@", [fs entity]];
  
  a = [[self defaultManagedObjectContext] executeFetchRequest:fs error:&error];
  [self logWithFormat:@"a: %@", a];
  
  if (error != nil)
    [self errorWithFormat:@"FETCH FAILED: %@", error];
  
  return a;
}

@end /* Session */
