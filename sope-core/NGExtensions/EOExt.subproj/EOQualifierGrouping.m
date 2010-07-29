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

#include "EOGrouping.h"
#import <EOControl/EOQualifier.h>
#include "common.h"

@implementation EOQualifierGrouping

- (id)initWithQualifier:(EOQualifier *)_qualifier name:(NSString *)_name {
  if ((self = [super initWithDefaultName:nil])) {
    self->name      = [_name copy];
    self->qualifier = [_qualifier retain];
  }
  return self;
}

- (void)dealloc {
  [self->qualifier release];
  [self->name      release];
  [super dealloc];
}

/* accessors */

- (void)setName:(NSString *)_name {
  NSAssert1(_name != nil, @"%s: name is nil", __PRETTY_FUNCTION__);
  ASSIGNCOPY(self->name, _name);
}
- (NSString *)name {
  return self->name;
}

- (void)setQualifier:(EOQualifier *)_qualifier {
  ASSIGN(self->qualifier, _qualifier);
}
- (EOQualifier *)qualifier {
  return self->qualifier;
}

/* operations */

- (NSString *)groupNameForObject:(id)_object {
  if (self->qualifier == nil)
    return self->name;
  
  if ([(id<EOQualifierEvaluation>)self->qualifier evaluateWithObject:_object])
    return self->name;
  
  return self->defaultName;
}

- (NSArray *)orderedGroupNames {
  return [NSArray arrayWithObjects:[self name], [self defaultName], nil];
}

@end /* EOQualifierGrouping */
