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

#ifndef __SoObjects_SoUser_H__
#define __SoObjects_SoUser_H__

#import <Foundation/NSObject.h>

/*
  SoUser
  
  A protocol and a basic implementation of a user object for the SOPE
  authentication system.
  
  Note: the "context" is usually the WOContext, not the "object context"
  like in Zope. You can get the roles for an object by using 
  -rolesForObject:inContext:.
*/

@class NSException, NSString, NSArray;

@protocol SoUser

- (NSString *)login;

/* returns the names of the roles assigned to the user */
- (NSArray *)rolesInContext:(id)_ctx;

/* 
   Returns the names of the roles assigned to the user including
   local roles from the object.
*/
- (NSArray *)rolesForObject:(id)_object inContext:(id)_ctx;

@end

@interface SoUser : NSObject < SoUser >
{
  NSString *login;
  NSArray  *roles;
}

- (id)initWithLogin:(NSString *)_login roles:(NSArray *)_roles;

@end

#endif /* __SoObjects_SoUser_H__ */
