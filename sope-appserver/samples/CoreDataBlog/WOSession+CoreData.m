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

#include "WOSession+CoreData.h"
#include "WOCoreDataApplication.h"
#include "common.h"

@implementation WOSession(CoreData)

static NSString *NSManagedObjectContextKey = @"NSManagedObjectContext";

- (void)setDefaultManagedObjectContext:(NSManagedObjectContext *)_ctx {
  if ([_ctx isNotNull])
    [self setObject:_ctx forKey:NSManagedObjectContextKey];
  else
    [self removeObjectForKey:NSManagedObjectContextKey];
}

- (NSManagedObjectContext *)defaultManagedObjectContext {
  NSManagedObjectContext *ctx;
  
  if ([(ctx = [self objectForKey:NSManagedObjectContextKey]) isNotNull])
    return ctx;
  
  if ((ctx = [[self application] createManagedObjectContext]) == nil) {
    [self errorWithFormat:
	    @"Failed to create NSManagedObjectContext for session!"];
    return nil;
  }

  [self setObject:ctx forKey:NSManagedObjectContextKey];
  return ctx;
}

@end /* WOSession(CoreData) */

