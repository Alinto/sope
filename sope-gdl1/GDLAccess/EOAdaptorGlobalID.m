/* 
   EOArrayProxy.h

   Copyright (C) 1999 MDlink online service center GmbH, Helge Hess

   Author: Helge Hess (hh@mdlink.de)
   Date:   1999

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
// $Id: EOAdaptorGlobalID.m 1 2004-08-20 10:38:46Z znek $

#include <GDLAccess/EOAdaptorGlobalID.h>
#include "common.h"

@implementation EOAdaptorGlobalID

- (id)initWithGlobalID:(EOGlobalID *)_gid
  connectionDictionary:(NSDictionary *)_conDict
{
  if ((self = [super init])) {
    ASSIGN(self->gid, _gid);
    ASSIGN(self->conDict, _conDict);
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->gid);
  RELEASE(self->conDict);
  [super dealloc];
}

- (EOGlobalID *)globalID {
  return self->gid;
}

- (NSDictionary *)connectionDictionary {
  return self->conDict;
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return RETAIN(self);
}

/* equality */

- (BOOL)isEqual:(id)_obj {
  if ([_obj isKindOfClass:[EOAdaptorGlobalID class]])
    return [self isEqualToEOAdaptorGlobalID:_obj];
  return NO;
}

- (BOOL)isEqualToEOAdaptorGlobalID:(EOAdaptorGlobalID *)_gid {
  if ([[_gid globalID] isEqual:self->gid] &&
      [[_gid connectionDictionary] isEqual:self->conDict])
    return YES;
  
  return NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"%@: globalID: %@ connectionDictionary: %@",
                   [super description], self->gid, self->conDict];
}

@end /* SkyDBGlobalKey */
