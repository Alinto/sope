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

#include "NGImap4MessageGlobalID.h"
#include "imCommon.h"

@implementation NGImap4MessageGlobalID

+ (id)imap4MessageGlobalIDWithFolderGlobalID:(EOGlobalID *)_gid 
  andUid:(unsigned int)_uid
{
  NGImap4MessageGlobalID *gid;
  
  gid = [[self alloc] initWithFolderGlobalID:_gid andUid:_uid];
  return [gid autorelease];
}

- (id)initWithFolderGlobalID:(EOGlobalID *)_gid andUid:(unsigned int)_uid {
  if ((self = [super init])) {
    self->folderGlobalID = [_gid retain];
    self->uid            = _uid;
  }
  return self;
}
- (id)init {
  return [self initWithFolderGlobalID:nil andUid:0];
}

- (void)dealloc {
  [self->folderGlobalID release];
  [super dealloc];
}

/* accessors */

- (EOGlobalID *)folderGlobalID {
  return self->folderGlobalID;
}
- (unsigned int)uid {
  return self->uid;
}

/* comparison */

- (unsigned)hash {
  return self->uid;
}

- (BOOL)isEqualToImap4MessageGlobalID:(NGImap4MessageGlobalID *)_other {
  if (_other == nil)
    return NO;
  if (self == _other)
    return YES;
  if (self->uid != _other->uid)
    return NO;
  
  return (self->folderGlobalID == _other->folderGlobalID)
    ? YES
    : [self->folderGlobalID isEqual:_other->folderGlobalID];
}

- (BOOL)isEqual:(id)_otherObject {
  if (_otherObject == self)
    return YES;
  if (![_otherObject isKindOfClass:[self class]])
    return NO;
  
  return [self isEqualToImap4MessageGlobalID:_otherObject];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}

/* compatibility to some older stuff */

- (NSString *)entityName {
  return @"NGImap4Message";
}

// TODO: emulate EOKeyGlobalID

@end /* NGImap4MessageGlobalID */
