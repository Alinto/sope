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

#ifndef __iCalPortal_iCalPortalDatabase_H__
#define __iCalPortal_iCalPortalDatabase_H__

#import <Foundation/NSObject.h>

@class NSFileManager, NSString, NSDictionary;
@class iCalPortalUser;

@interface iCalPortalDatabase : NSObject
{
  NSFileManager *fileManager;
  NSString      *rootPath;
}

- (id)initWithPath:(NSString *)_path;

/* operations */

- (iCalPortalUser *)userWithName:(NSString *)_name password:(NSString *)_pwd;
- (iCalPortalUser *)userWithName:(NSString *)_name;

- (BOOL)createUser:(NSString *)_login
  info:(NSDictionary *)_userInfo
  password:(NSString *)_pwd;

- (BOOL)isLoginNameValid:(NSString *)_name;
- (BOOL)isPasswordValid:(NSString *)_name;
- (BOOL)isLoginNameUsed:(NSString *)_name;

/* accessors */

- (NSFileManager *)fileManager;

@end

#endif /* __iCalPortal_iCalPortalDatabase_H__ */
