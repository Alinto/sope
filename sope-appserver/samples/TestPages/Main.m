/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include <NGObjWeb/WOComponent.h>

@class NSArray;

@interface Main : WOComponent
{
  NSArray *items;
  id      item;
}

@end

#include "common.h"

@implementation Main

- (id)initWithContext:(id)_ctx {
  if ((self = [super initWithContext:_ctx])) {
    NSMutableArray *ma;
    int i;

    ma = [[NSMutableArray alloc] init];
    for (i = 0; i < 1000; i++) {
      char buf[16];
      NSString *s;
      sprintf(buf, "%i", i);
      s = [[NSString alloc] initWithCString:buf];
      [ma addObject:s];
      [s release];
    }
    self->items = ma;
  }
  return self;
}

- (void)dealloc {
  [self->items release];
  [self->item  release];
  [super dealloc];
}

/* accessors */

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (NSArray *)list {
  return self->items;
}

/* response generation */

- (void)appendToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  NSDate *s;

  s = [NSDate date];
  [super appendToResponse:_r inContext:_ctx];
  printf("duration: %.3f\n", [[NSDate date] timeIntervalSinceDate:s]);
}

@end /* Main */
