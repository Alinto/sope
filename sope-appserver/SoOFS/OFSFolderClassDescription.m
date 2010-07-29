/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "OFSFolderClassDescription.h"
#include "OFSFolder.h"
#include "common.h"

@implementation OFSFolderClassDescription

- (id)initWithFolder:(OFSFolder *)_folder {
  if ((self = [super init])) {
    self->object = [_folder retain];
  }
  return self;
}
- (void)dealloc {
  [self->object release];
  [super dealloc];
}

- (NSArray *)attributeKeys {
  return [self->object attributeKeys];
}

- (NSArray *)toOneRelationshipKeys {
  return [self->object toOneRelationshipKeys];
}

@end /* OFSFolderClassDescription */
