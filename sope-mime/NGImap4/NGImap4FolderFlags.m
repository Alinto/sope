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

#include "NGImap4FolderFlags.h"
#include "imCommon.h"

@implementation NGImap4FolderFlags

- (id)initWithFlagArray:(NSArray *)_array {
  if ((self = [super init])) {
    self->flags = [_array copy];

    // TODO: this is pretty weird
    self->listFlags.noselect    = [self->flags containsObject:@"noselect"];
    self->listFlags.noinferiors = [self->flags containsObject:@"noinferiors"];
    self->listFlags.nonexistent = [self->flags containsObject:@"nonexistent"];
    self->listFlags.haschildren = [self->flags containsObject:@"haschildren"];
    self->listFlags.marked      = [self->flags containsObject:@"marked"];
    self->listFlags.unmarked    = [self->flags containsObject:@"unmarked"];
    
    self->listFlags.hasnochildren = 
      [self->flags containsObject:@"hasnochildren"];
  }
  return self;
}
- (id)init {
  return [self initWithFlagArray:nil];
}

- (void)dealloc {
  [self->flags release];
  [super dealloc];
}

/* accessors */

- (NSArray *)flagArray {
  return self->flags;
}

- (BOOL)doNotSelectFolder {
  return self->listFlags.noselect ? YES : NO;
}
- (BOOL)doesNotSupportSubfolders {
  return self->listFlags.noinferiors ? YES : NO;
}
- (BOOL)doesNotExist {
  return self->listFlags.nonexistent ? YES : NO;
}
- (BOOL)hasSubfolders {
  return self->listFlags.haschildren ? YES : NO;
}
- (BOOL)hasNoSubfolders {
  return self->listFlags.hasnochildren ? YES : NO;
}
- (BOOL)isMarked {
  return self->listFlags.marked ? YES : NO;
}
- (BOOL)isUnmarked {
  return self->listFlags.unmarked ? YES : NO;
}

/* operations */

- (void)allowFolderSelect {
  NSMutableArray *ma;
  NSArray *tmp;
  
  self->listFlags.noselect = NO;
  
  tmp = self->flags;
  ma = [tmp mutableCopy];
  [ma removeObject:@"noselect"];
  self->flags = [ma copy];
  [tmp release];
}

@end /* NGImap4FolderFlags */
