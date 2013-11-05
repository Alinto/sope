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

#include "SoClassSecurityInfo.h"
#include "SoClass.h"
#include "common.h"

@implementation SoClassSecurityInfo

- (id)initWithSoClass:(SoClass *)_class {
  if ((self = [self init])) {
    self->className = [[_class className] copy];
  }
  return self;
}

- (void)dealloc {
  [self->defaultAccess release];
  [self->publicNames   release];
  [self->privateNames  release];
  [self->nameToPerm    release];
  [self->defRoles      release];
  [self->objectPermission release];
  [self->className     release];
  [super dealloc];
}

/* attribute security */

- (void)_logPermAlreadySetForName:(NSString *)_name {
  [self warnWithFormat:
          @"tried to declare permission for attribute '%@' twice!", _name];
}

- (void)setDefaultAccess:(NSString *)_access {
  if (self->defaultAccess)
    [self _logPermAlreadySetForName:@"<default>"];
  else {
    self->defaultAccess = [_access isNotNull] ? [_access copy] : nil;
    [self debugWithFormat:@"set default access: '%@'", self->defaultAccess];
  }
}
- (NSString *)defaultAccess {
  return self->defaultAccess;
}
- (BOOL)hasDefaultAccessDeclaration {
  return [self->defaultAccess length] > 0 ? YES : NO;
}

- (void)declarePublic:(NSString *)_firstName, ... {
  va_list va;
  NSString *aname;

  if (self->publicNames == nil)
    self->publicNames = [[NSMutableSet alloc] init];
  
  va_start(va, _firstName);
  for (aname = _firstName; aname != nil; aname = va_arg(va, id)) {
    if ([self->publicNames containsObject:aname])
      [self _logPermAlreadySetForName:aname];
    else if ([self->privateNames containsObject:aname])
      [self _logPermAlreadySetForName:aname];
    else if ([self->nameToPerm objectForKey:aname])
      [self _logPermAlreadySetForName:aname];
    else {
      [self->publicNames addObject:aname];
      [self debugWithFormat:@"set key public: '%@'", aname];
    }
  }
  va_end(va);
}

- (void)declarePrivate:(NSString *)_firstName, ... {
  va_list va;
  NSString *aname;
  
  if (self->privateNames == nil)
    self->privateNames = [[NSMutableSet alloc] init];
  
  va_start(va, _firstName);
  for (aname = _firstName; aname != nil; aname = va_arg(va, id)) {
    if ([self->publicNames containsObject:aname])
      [self _logPermAlreadySetForName:aname];
    else if ([self->privateNames containsObject:aname])
      [self _logPermAlreadySetForName:aname];
    else if ([self->nameToPerm objectForKey:aname])
      [self _logPermAlreadySetForName:aname];
    else {
      [self->privateNames addObject:aname];
      [self debugWithFormat:@"set key private: '%@'", aname];
    }
  }
  va_end(va);
}

- (void)declareProtected:(NSString *)_perm:(NSString *)_firstName, ... {
  va_list  va;
  NSString *aname;

  _perm = [_perm lowercaseString];
  
  if (self->nameToPerm == nil)
    self->nameToPerm = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  va_start(va, _firstName);
  for (aname = _firstName; aname != nil; aname = va_arg(va, id)) {
    if ([self->publicNames containsObject:aname])
      [self _logPermAlreadySetForName:aname];
    else if ([self->privateNames containsObject:aname])
      [self _logPermAlreadySetForName:aname];
    else if ([self->nameToPerm objectForKey:aname])
      [self _logPermAlreadySetForName:aname];
    else {
      [self->nameToPerm setObject:_perm forKey:aname];
      [self debugWithFormat:@"protect key by '%@': '%@'", _perm, aname];
    }
  }
  va_end(va);
}

- (BOOL)hasProtectionsForKey:(NSString *)_key {
  if (_key == nil) return NO;
  
  if ([self->publicNames  containsObject:_key]) return YES;
  if ([self->privateNames containsObject:_key]) return YES;
  if ([self->nameToPerm objectForKey:_key]) return YES;
  return NO;
}

- (BOOL)isKeyPrivate:(NSString *)_key {
  return [self->privateNames containsObject:_key];
}
- (BOOL)isKeyPublic:(NSString *)_key {
  return [self->publicNames containsObject:_key];
}
- (NSString *)permissionRequiredForKey:(NSString *)_key {
  return [self->nameToPerm objectForKey:_key];
}

/* object security */

- (void)_logObjPermAlreadySet {
  [self warnWithFormat:@"tried to declare object permission twice! "
          @"(perm=%@,private=%s,public=%s)",
          self->objectPermission, 
          self->isObjectPrivate?"yes":"no",
          self->isObjectPublic?"yes":"no"];
}

- (BOOL)hasObjectProtections {
  if (self->objectPermission) return YES;
  if (self->isObjectPrivate)  return YES;
  if (self->isObjectPublic)   return YES;
  return NO;
}
- (BOOL)isObjectPublic {
  return self->isObjectPublic;
}
- (BOOL)isObjectPrivate {
  return self->isObjectPrivate;
}
- (NSString *)permissionRequiredForObject {
  return self->objectPermission;
}

- (void)declareObjectPublic {
  if ([self->objectPermission isNotNull] || self->isObjectPrivate)
    [self _logObjPermAlreadySet];
  else {
    [self debugWithFormat:@"declared object public"];
    self->isObjectPublic = YES;
  }
}
- (void)declareObjectPrivate {
  if ([self->objectPermission isNotNull] || self->isObjectPublic)
    [self _logObjPermAlreadySet];
  else {
    [self debugWithFormat:@"declared object private"];
    self->isObjectPrivate = YES;
  }
}
- (void)declareObjectProtected:(NSString *)_perm {
  _perm = [_perm isNotNull] ? [_perm lowercaseString] : (NSString *)nil;
  
  if ([_perm length] == 0) {
    [self logWithFormat:@"tried to declare empty permission !", _perm];
    return;
  }
  
  if (self->isObjectPrivate || self->isObjectPublic || 
      (self->objectPermission != nil)) {
    [self _logObjPermAlreadySet];
  }
  else {
    [self debugWithFormat:@"declared object protected by: %@", _perm];
    self->objectPermission = [_perm copy];
  }
}

/* default role mappings */

- (BOOL)hasDefaultRoleForPermission:(NSString *)_p {
  if (_p == nil) return NO;
  _p = [_p lowercaseString];
  return [self->defRoles objectForKey:_p] == nil ? NO : YES;
}

- (void)declareRole:(NSString *)_role asDefaultForPermission:(NSString *)_per{
  id tmp;
  
  _per = [_per isNotNull] ? [_per lowercaseString] : (NSString *)nil;
  
  if (self->defRoles == nil)
    self->defRoles = [[NSMutableDictionary alloc] initWithCapacity:8];
  
  if ((tmp = [self->defRoles objectForKey:_per])) {
    [self warnWithFormat:@"tried to set default role of '%@' twice!"
            @" (set to %@)", _per, tmp];
    return;
  }
  
  tmp = [_role isNotNull] ? [NSArray arrayWithObject:_role] : [NSArray array];
  [self->defRoles setObject:tmp forKey:_per];
}
- (void)declareRole:(NSString *)_role
  asDefaultForPermissions:(NSString *)_p,...
{
  va_list va;
  NSString *aperm;
  
  va_start(va, _p);
  for (aperm = _p; aperm != nil; aperm = va_arg(va, id)) {
    [self declareRole:_role asDefaultForPermission:aperm];
  }
  va_end(va);
}

- (void)declareRoles:(NSArray *)_roles asDefaultForPermission:(NSString *)_p {
  id tmp;
  
  _p = [_p isNotNull] ? [_p lowercaseString] : (NSString *)nil;
  
  if (self->defRoles == nil)
    self->defRoles = [[NSMutableDictionary alloc] initWithCapacity:8];
  
  if ((tmp = [self->defRoles objectForKey:_p])) {
    [self warnWithFormat:@"tried to set default role of '%@' twice!"
            @" (set to %@)", _p, tmp];
    return;
  }
  
  tmp = [_roles isNotNull] ? _roles : (NSArray *)[NSArray array];
  [self->defRoles setObject:tmp forKey:_p];
}

- (NSArray *)defaultViewRoles {
  static NSArray *defViewRoles = nil;
  if (defViewRoles == nil) {
    defViewRoles = [[NSArray alloc] initWithObjects:
				      @"Anonymous", @"Manager", nil];
  }
  return defViewRoles;
}
- (NSArray *)defaultContentsRoles {
  static NSArray *defContentRoles = nil;
  if (defContentRoles == nil) {
    defContentRoles = [[NSArray alloc] initWithObjects:
					 @"Anonymous", @"Manager", nil];
  }
  return defContentRoles;
}
- (NSArray *)defaultRoles {
  static NSArray *defRolesA = nil;
  if (defRolesA == nil)
    defRolesA = [[NSArray alloc] initWithObjects:@"Manager", nil];
  return defRolesA;
}

- (NSArray *)defaultRolesForPermission:(NSString *)_p {
  NSArray *roles;
  
  _p = [_p lowercaseString];
  
  if ((roles = [self->defRoles objectForKey:_p]))
    ;
  else if ([_p isEqualToString:@"view"])
    roles = [self defaultViewRoles];
  else if ([_p isEqualToString:@"access contents information"])
    roles = [self defaultContentsRoles];
  else
    roles = [self defaultRoles];
  
  return roles;
}

@end /* SoClassSecurityInfo */

@implementation SoClassSecurityInfo(Logging)

- (NSString *)loggingPrefix {
  return [self->className length] > 0
    ? [NSString stringWithFormat:@"[so-secinfo %@]", self->className]
    : [NSString stringWithFormat:@"[so-secinfo 0x%p]", self];
}
- (BOOL)isDebuggingEnabled {
  static int debugOn = -1;
  if (debugOn == -1) {
    debugOn = [[NSUserDefaults standardUserDefaults]
		boolForKey:@"SoLogSecurityDeclarations"] ? 1 : 0;
  }
  return debugOn ? YES : NO;
}

@end /* SoClassSecurityInfo(Logging) */
