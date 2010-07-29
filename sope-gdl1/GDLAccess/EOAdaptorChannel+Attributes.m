/* 
   EOAdaptorChannel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

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
// $Id: EOAdaptorChannel+Attributes.m 1 2004-08-20 10:38:46Z znek $

#import "common.h"
#import "EOAdaptorChannel+Attributes.h"
#import "EOAdaptorContext.h"
#import "EOEntity.h"
#import "EOAdaptor.h"
#import "EOModel.h"

@implementation EOAdaptorChannel(Attributes)

- (EOEntity *)_entityForTableName:(NSString *)_tableName {
  EOModel  *model  = nil;
  EOEntity *entity = nil;
  
  if (_tableName == nil || [_tableName length] == 0)
    return nil;

  model = [[self->adaptorContext adaptor] model];

  if ((entity = [model entityNamed:_tableName]) == nil) {
    NSEnumerator *enumerator = nil;
    enumerator = [[model entities] objectEnumerator];
    while ((entity = [enumerator nextObject])) {
      if ([[entity externalName] isEqualToString:_tableName])
        break;
    }
  }
  if (entity == nil) {
    model = [self describeModelWithTableNames:
                  [NSArray arrayWithObject:_tableName]];

    if ((entity = [model entityNamed:_tableName]) == nil) {
      NSEnumerator *enumerator = nil;
      enumerator = [[model entities] objectEnumerator];
      while ((entity = [enumerator nextObject])) {
        if ([[entity externalName] isEqualToString:_tableName])
          break;
      }
    }
  }
  return entity;
}

- (NSArray *)attributesForTableName:(NSString *)_tableName {
  return [[self _entityForTableName:_tableName] attributes];
}

- (NSArray *)primaryKeyAttributesForTableName:(NSString *)_tableName {
  return [[self _entityForTableName:_tableName] primaryKeyAttributes];  
}

@end /* EOAdaptorChannel(Attributes) */
