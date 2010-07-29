/*
  Copyright (C) 2000-2005 SKYRIX Software AG

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

#include "NGImap4FolderGlobalID.h"
#include "imCommon.h"

@implementation NGImap4FolderGlobalID

+ (id)imap4FolderGlobalIDWithServerGlobalID:(EOGlobalID *)_gid 
  andAbsoluteName:(NSString *)_name
{
  NGImap4FolderGlobalID *gid;

  gid = [[self alloc] initWithServerGlobalID:_gid andAbsoluteName:_name];
  return [gid autorelease];
}
- (id)initWithServerGlobalID:(EOGlobalID *)_gid 
  andAbsoluteName:(NSString *)_name
{
  if ((self = [super init])) {
    self->serverGlobalID = [_gid  retain];
    self->absoluteName   = [_name copy];
  }
  return self;
}
- (id)init {
  return [self initWithServerGlobalID:nil andAbsoluteName:nil];
}

- (void)dealloc {
  [self->serverGlobalID release];
  [self->absoluteName   release];
  [super dealloc];
}

/* accessors */

- (EOGlobalID *)serverGlobalID {
  return self->serverGlobalID;
}
- (NSString *)absoluteName {
  return self->absoluteName;
}

/* comparison */

- (unsigned)hash {
  return [self->absoluteName hash];
}

- (BOOL)isEqualToImap4FolderGlobalID:(NGImap4FolderGlobalID *)_other {
  if (_other == nil)
    return NO;
  if (self == _other)
    return YES;
  
  if (self->absoluteName != _other->absoluteName) {
    if (![self->absoluteName isEqualToString:_other->absoluteName])
      return NO;
  }
  if (self->serverGlobalID != _other->serverGlobalID) {
    if (![self->serverGlobalID isEqual:_other->serverGlobalID])
      return NO;
  }
  
  return YES;
}

- (BOOL)isEqual:(id)_otherObject {
  if (_otherObject == self)
    return YES;
  if (![_otherObject isKindOfClass:[self class]])
    return NO;
  
  return [self isEqualToImap4FolderGlobalID:_otherObject];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* support for some older code expecting only EO global IDs */

- (NSString *)entityName {
  return @"NGImap4Folder";
}

@end /* NGImap4FolderGlobalID */
