/* 
   EOAttributeOrdering.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

// $Id: EOEntity+Factory.m 1 2004-08-20 10:38:46Z znek $

#include <GDLAccess/EOEntity+Factory.h>
#include <GDLAccess/EOAttribute.h>
#include <EOControl/EONull.h>
#include <EOControl/EOKeyValueCoding.h>
#include "common.h"

@interface NSObject(PKeyInitializer)
- (id)initWithPrimaryKey:(NSDictionary *)_pkey entity:(EOEntity *)_entity;
@end

@implementation EOEntity(AttributeNames)

- (NSArray *)attributeNames {
  NSMutableArray *attrNames = [[[NSMutableArray alloc] init] autorelease];
  NSEnumerator   *attrs     = [self->attributes objectEnumerator];
  EOAttribute    *attr      = nil;

  while ((attr = [attrs nextObject])) 
    [attrNames addObject:[attr name]];

  return attrNames;
}

@end /* EOEntity(AttributeNames) */

@implementation EOEntity(PrimaryKeys)

- (BOOL)isPrimaryKeyAttribute:(EOAttribute *)_attribute {
  NSEnumerator *pkeys = [self->primaryKeyAttributeNames objectEnumerator];
  NSString     *aname = [_attribute name];
  NSString     *n     = nil;

  while ((n = [pkeys nextObject])) {
    if ([aname isEqualToString:n])
      return YES;
  }
  return NO;
}

- (unsigned)primaryKeyCount {
  return [self->primaryKeyAttributeNames count];
}

@end /* EOEntity(PrimaryKeys) */

@implementation EOEntity(ObjectFactory)

- (id)produceNewObjectWithPrimaryKey:(NSDictionary *)_key {
  /* Note: used by LSDBObjectNewCommand */
  Class objectClass = Nil;
  id    obj;

  objectClass = NSClassFromString([self className]);
  NSAssert(objectClass != nil, @"no enterprise object class set in entity");

  obj = [objectClass alloc];
  NSAssert(objectClass != nil, @"could not allocate enterprise object");
  
  if ([obj respondsToSelector:@selector(initWithPrimaryKey:entity:)])
    [obj initWithPrimaryKey:_key entity:self];
  else
    [obj init];
  
  return AUTORELEASE(obj);
}

- (void)setAttributesOfObjectToEONull:(id)_object {
  static EONull *null = nil;
  NSEnumerator *attrs;
  EOAttribute  *attr;
  int          pkeyCount;
  
  if (null == nil)
    null = [[NSNull null] retain];

  attrs     = [self->attributes objectEnumerator];
  attr      = nil;
  pkeyCount = [self->primaryKeyAttributeNames count];
  
  NSAssert(NSClassFromString([self className]) == [_object class],
           @"object does not belong to entity");
  
  while ((attr = [attrs nextObject])) {
    if (pkeyCount > 0) {
      if ([self isPrimaryKeyAttribute:attr]) {
        pkeyCount--;
        continue;
      }
    }
    
    [_object takeValue:null forKey:[attr name]];
  }
}

@end /* EOEntity(ObjectFactory) */
