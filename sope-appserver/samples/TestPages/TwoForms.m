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

@interface TwoForms : WOComponent
{
  id selection1;
  id selection2;
  id item;
}

@end

#include "common.h"

@implementation TwoForms

- (id)initWithContext:(WOContext *)_ctx {
  if ((self = [super initWithContext:_ctx])) {
  }
  return self;
}

- (void)dealloc {
  [self->selection1 release];
  [self->selection2 release];
  [self->item       release];
  [super dealloc];
}

/* accessors */

- (void)setItem:(id)_item {
  ASSIGN(self->item, _item);
}
- (id)item {
  return self->item;
}

- (void)setSelection1:(id)_value {
  [self logWithFormat:@"set form 1 selection to: %@", _value];
  ASSIGN(self->selection1, _value);
}
- (id)selection1 {
  return self->selection1;
}

- (void)setSelection2:(id)_value {
  [self logWithFormat:@"set form 2 selection to: %@", _value];
  ASSIGN(self->selection2, _value);
}
- (id)selection2 {
  return self->selection2;
}

/* actions */

- (id)ok1 {
  [self logWithFormat:@"OK: Form 1"];
  return nil;
}
- (id)ok2 {
  [self logWithFormat:@"OK: Form 2"];
  return nil;
}

@end /* TwoForms */
