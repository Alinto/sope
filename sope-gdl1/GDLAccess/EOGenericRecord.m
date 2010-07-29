/* 
   EOGenericRecord.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>
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

#include <stdio.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSArray.h>
#import "common.h"
#import "EOEntity.h"
#import "EOGenericRecord.h"
#import "EODatabase.h"
#import <GDLAccess/EOFault.h>
#import <EOControl/EOClassDescription.h>

@interface EOClassDescription(ClassDesc)
/* TODO: check, whether this can be removed */
+ (NSClassDescription *)classDescriptionForEntityName:(NSString *)_entityName;
@end

@implementation EOGenericRecord(EOAccess)

- (id)initWithPrimaryKey:(NSDictionary *)_key entity:(EOEntity *)_entity {
  /* TODO: is this method ever used? Maybe remove */
  EOClassDescription *cd;
  NSEnumerator *e;
  NSString     *key;
  
  if (_entity == nil) {
    AUTORELEASE(self);
    NSLog(@"WARNING: tried to create generic record with <nil> entity !");
    return nil;
  }
  
  cd = (id)[EOClassDescription classDescriptionForEntityName:[_entity name]];
#if DEBUG
  NSAssert1(cd, @"did not find class description for entity %@", _entity);
#endif
  
  self = [self initWithEditingContext:nil
               classDescription:cd
               globalID:nil];
  
  e = [_key keyEnumerator];

  while ((key = [e nextObject]))
    [self setObject:[_key objectForKey:key] forKey:key];
  
  return self;
}

- (void)_letDatabasesForget {
  [EODatabase forgetObject:self];
}

/* model */

- (EOEntity *)entity {
  return [(EOEntityClassDescription *)[self classDescription] entity];
}

@end /* EOGenericRecord(EOAccess) */
