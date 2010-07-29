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

#include "NGLdapModification.h"
#include "NGLdapAttribute.h"
#include "common.h"

@implementation NGLdapModification

+ (id)addModification:(NGLdapAttribute *)_attribute {
  return [[[self alloc] initWithOperation:NGLdapAddAttribute
                        attribute:_attribute] autorelease];
}
+ (id)replaceModification:(NGLdapAttribute *)_attribute {
  return [[[self alloc] initWithOperation:NGLdapReplaceAttribute
                        attribute:_attribute] autorelease];
}
+ (id)deleteModification:(NGLdapAttribute *)_attribute {
  return [[[self alloc] initWithOperation:NGLdapDeleteAttribute
                        attribute:_attribute] autorelease];
}

- (id)initWithOperation:(int)_op attribute:(NGLdapAttribute *)_attribute {
  self->operation = _op;
  self->attribute = [_attribute retain];
  return self;
}

- (void)dealloc {
  [self->attribute release];
  [super dealloc];
}

- (int)operation {
  return self->operation;
}

- (NGLdapAttribute *)attribute {
  return self->attribute;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"%@ : self->attribute %@ operation %d",
                   [super description], self->attribute, self->operation];
}

@end /* NGLdapModification */
