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

#ifndef __NGLdapFileManager_H__
#define __NGLdapFileManager_H__

#import <Foundation/NSObject.h>
#import <NGExtensions/NGFileManager.h>
#import <NGExtensions/NSFileManager+Extensions.h>

@class NSString, NSDictionary, NSData, NSArray, NSURL;
@class NGLdapConnection;

@interface NGLdapFileManager : NGFileManager
{
  NGLdapConnection *connection;
  NSString *rootDN;
  NSString *currentDN;
  NSString *currentPath;
}

- (id)initWithURLString:(NSString *)_url;
- (id)initWithURL:(id)_url;

- (id)initWithHostName:(NSString *)_host port:(int)_port
  bindDN:(NSString *)_login credentials:(NSString *)_pwd
  rootDN:(NSString *)_rootDN;

/* operations */

- (BOOL)changeCurrentDirectoryPath:(NSString *)_path;
- (NSString *)currentDirectoryPath;

- (NSArray *)directoryContentsAtPath:(NSString *)_path;
- (NSArray *)subpathsAtPath:(NSString *)_path;

- (NSDictionary *)fileAttributesAtPath:(NSString *)_path traverseLink:(BOOL)_fl;

/* determine access */

- (BOOL)fileExistsAtPath:(NSString *)_path isDirectory:(BOOL *)_isDir;
- (BOOL)fileExistsAtPath:(NSString *)_path;
- (BOOL)isReadableFileAtPath:(NSString *)_path;
- (BOOL)isWritableFileAtPath:(NSString *)_path;
- (BOOL)isExecutableFileAtPath:(NSString *)_path;
- (BOOL)isDeletableFileAtPath:(NSString *)_path;

/* reading contents */

- (BOOL)contentsEqualAtPath:(NSString *)_path1 andPath:(NSString *)_path2;
- (NSData *)contentsAtPath:(NSString *)_path;

/* modifications */

- (BOOL)removeFileAtPath:(NSString *)_path handler:(id)handler;

- (BOOL)copyPath:(NSString *)_source toPath:(NSString *)_destination
  handler:(id)_handler;
- (BOOL)movePath:(NSString *)_source toPath:(NSString *)_destination 
  handler:(id)_handler;
- (BOOL)linkPath:(NSString *)_source toPath:(NSString *)_destination 
  handler:(id)_handler;

- (BOOL)createFileAtPath:(NSString *)path
  contents:(NSData *)contents
  attributes:(NSDictionary *)attributes;

/* internals */

- (NGLdapConnection *)ldapConnection;
- (NSString *)dnForPath:(NSString *)_path;
- (NSString *)pathForDN:(NSString *)_dn;

@end

@class EODataSource;

@interface NGLdapFileManager(ExtendedFileManager) < NGFileManagerDataSources >

/* feature check */

- (BOOL)supportsVersioningAtPath:(NSString *)_path;
- (BOOL)supportsLockingAtPath:(NSString *)_path;
- (BOOL)supportsFolderDataSourceAtPath:(NSString *)_path;

/* writing */

- (BOOL)writeContents:(NSData *)_content atPath:(NSString *)_path;

@end

#endif /* __NGLdapFileManager_H__ */
