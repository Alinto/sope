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

#include "NSEntityDescription+EO.h"
#include "common.h"

@implementation NSEntityDescription(EO)

- (id)relationshipNamed:(NSString *)_qname {
  return [[self relationshipsByName] objectForKey:_qname];
}

- (id)attributeNamed:(NSString *)_qname {
  return [[self attributesByName] objectForKey:_qname];
}

- (BOOL)isReadOnly {
  return NO; /* always read/write, no? */
}
- (NSArray *)classPropertyNames {
  return [[self propertiesByName] allKeys];
}
- (NSArray *)primaryKeyAttributeNames {
  /* such are transparent with CoreData */
  return nil;
}

- (NSArray *)attributes {
  return [[self attributesByName] allValues];
}
- (NSArray *)relationships {
  return [[self relationshipsByName] allValues];
}

@end /* NSEntityDescription(EO) */
