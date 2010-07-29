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

#include "EODataSource+NGExtensions.h"
#import <EOControl/EOFetchSpecification.h>
#include "common.h"

NGExtensions_DECLARE NSString *EODataSourceDidChangeNotification =
  @"EODataSourceDidChangeNotification";
NGExtensions_DECLARE NSString *EONoFetchWithEmptyQualifierHint =
  @"EONoFetchWithEmptyQualifierHint";

@implementation EODataSource(NGExtensions)

- (void)setFetchSpecification:(EOFetchSpecification *)_fetchSpec {
  [self doesNotRecognizeSelector:_cmd];
}
- (EOFetchSpecification *)fetchSpecification {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)updateObject:(id)_obj {
  [self doesNotRecognizeSelector:_cmd];
}

- (void)postDataSourceChangedNotification {
  static NSNotificationCenter *nc = nil;
  
  if (nc == nil)
    nc = [[NSNotificationCenter defaultCenter] retain];
  
  [nc postNotificationName:EODataSourceDidChangeNotification object:self];
}


@end /* EODataSource(NGExtensions) */

/* static linking */

void __link_EODataSource_NGExtensions(void) {
  __link_EODataSource_NGExtensions();
}
