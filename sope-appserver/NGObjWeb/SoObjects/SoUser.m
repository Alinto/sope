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

#include "SoUser.h"
#include "common.h"

@implementation SoUser

- (id)initWithLogin:(NSString *)_login roles:(NSArray *)_roles {
  if (_login == nil) {
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    self->login = [_login copy];
    self->roles = [_roles copy];
  }
  return self;
}
- (id)init {
  return [self initWithLogin:nil roles:nil];
}

- (void)dealloc {
  [self->login release];
  [self->roles release];
  [super dealloc];
}

/* accessors */

- (NSString *)login {
  return self->login;
}

/* roles */

- (NSArray *)rolesInContext:(id)_ctx {
  return self->roles;
}

- (NSArray *)rolesForObject:(id)_object inContext:(id)_ctx {
  NSArray *aroles, *localRoles;
  
  aroles = [self rolesInContext:_ctx];
  if (aroles == nil) aroles = [NSArray array];
  
  /* 
     TODO: collect all local roles (of the object and its parents, local
     roles are stored in __ac_local_roles__ of the object in Zope. Note
     that this attribute can be a callable returning the roles !
  */
  localRoles = nil;
  
  return aroles;
}

/* KVC */

- (id)valueForUndefinedKey:(NSString *)_key {
  return nil;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:16];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" login=%@", self->login];
  [ms appendFormat:@" roles=%@", [self->roles componentsJoinedByString:@","]];
  [ms appendString:@">"];
  return ms;
}

@end /* SoUser */
