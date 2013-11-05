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

#ifndef __SoObjects_SoClassSecurityInfo_H__
#define __SoObjects_SoClassSecurityInfo_H__

#import <Foundation/NSObject.h>

@class NSString, NSMutableSet, NSMutableDictionary, NSArray;

/*
  SoClassSecurityInfo

  Storing security info for a SoClass.

  Declaring Roles: mapping permissions to roles is the task of the system
  administrator. Programmers should only declare default roles for:
  - Anonymous
  - Manager
  - Owner
  
  TODO: default access (this is done in the meantime ?)
  
  Adding security information to a class
  ======================================
  
  Per default classes are protected from outside access. Defining incorrect
  protections is one of the most common problems when writing SOPE applications
  since "security is hard" (Jim Fulton) ;-)
  
  Because of that, we provide some user-defaults to control logging of
  security:
    SoSecurityManagerDebugEnabled (bool) - debugging access
    SoLogSecurityDeclarations     (bool) - track information
  
  To declare security information on an Objective-C class which you are using
  as a SoClass, it's based to implemented the +initialize method:
  
    + (void)initialize {
      // to mark the object public (not restricted to a user/role)
      [[self soClassSecurityInfo] declareObjectPublic];
      
      // to allow public access to all contained objects (subkeys)
      [[self soClassSecurityInfo] setDefaultAccess:@"allow"];

      // to protect a specific object
      [[self soClassSecurityInfo] 
             declareProtected:SoPerm_View:@"test.html",nil];
    }
  
  For products it's much easier to declare the products' SoClasses and
  their protections in the "product.plist" file.
*/

@class SoClass;

@interface SoClassSecurityInfo : NSObject
{
  NSMutableSet        *publicNames;
  NSMutableSet        *privateNames;
  NSMutableDictionary *nameToPerm;
  NSMutableDictionary *defRoles;
  NSString            *defaultAccess;
  
  NSString *objectPermission;
  BOOL     isObjectPublic;
  BOOL     isObjectPrivate;
  
  NSString *className;
}

- (id)initWithSoClass:(SoClass *)_class;

/* attribute security */

- (BOOL)hasProtectionsForKey:(NSString *)_key;
- (BOOL)isKeyPrivate:(NSString *)_key;
- (BOOL)isKeyPublic:(NSString *)_key;
- (NSString *)permissionRequiredForKey:(NSString *)_key;

- (void)setDefaultAccess:(NSString *)_access;
- (NSString *)defaultAccess;
- (BOOL)hasDefaultAccessDeclaration;
- (void)declarePublic:(NSString *)_firstName, ...;
- (void)declarePrivate:(NSString *)_firstName, ...;
- (void)declareProtected:(NSString *)_perm:(NSString *)_firstName, ...;

/* object security */

- (BOOL)hasObjectProtections;
- (BOOL)isObjectPublic;
- (BOOL)isObjectPrivate;
- (NSString *)permissionRequiredForObject;
- (void)declareObjectPublic;
- (void)declareObjectPrivate;
- (void)declareObjectProtected:(NSString *)_perm;

/* default role mappings */

- (BOOL)hasDefaultRoleForPermission:(NSString *)_p;

- (void)declareRole:(NSString *)_role  asDefaultForPermission:(NSString *)_p;
- (void)declareRoles:(NSArray *)_roles asDefaultForPermission:(NSString *)_p;
- (NSArray *)defaultRolesForPermission:(NSString *)_p;

- (void)declareRole:(NSString *)_role 
  asDefaultForPermissions:(NSString *)_firstPerm,...;

@end

@interface NSObject(ObjCClassSecurityInfo)

+ (SoClassSecurityInfo *)soClassSecurityInfo;

@end

#endif /* __SoObjects_SoClassSecurityInfo_H__ */
