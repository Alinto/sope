/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "EOJavaScriptGrouping.h"
#include <NGScripting/NSObject+Scripting.h>
#include "../common.h"

@implementation EOJavaScriptGrouping

- (id)initWithJavaScript:(NSString *)_script name:(NSString *)_name {
  if ((self = [super initWithDefaultName:nil])) {
    self->name     = [_name copy];
    self->language = @"javascript";
    self->script   = [_script copy];
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->language);
  RELEASE(self->script);
  RELEASE(self->name);
  [super dealloc];
}

// accessors

- (void)setName:(NSString *)_name {
  NSAssert1(_name != nil, @"%s: name is nil", __PRETTY_FUNCTION__);
  ASSIGNCOPY(self->name, _name);
}
- (NSString *)name {
  return self->name;
}

- (void)setJavaScript:(NSString *)_script {
  RELEASE(self->language);
  self->language = @"javascript";
  ASSIGNCOPY(self->script, _script);
}
- (NSString *)script {
  return self->script;
}

// -----------------------------------

- (NSString *)groupNameForObject:(id)_object {
  if (self->script == nil)
    return self->name;

  if ([[_object evaluateScript:self->script language:self->language] boolValue])
    return self->name;
  
  return self->defaultName;
}

- (NSArray *)orderedGroupNames {
  return [NSArray arrayWithObjects:[self name], [self defaultName], nil];
}

@end /* EOJavaScriptGrouping */
