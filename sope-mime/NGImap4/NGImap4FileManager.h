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

#ifndef  __NGImap4FileManager_H__
#define __NGImap4FileManager_H__

#import <Foundation/NSObject.h>
#include <NGExtensions/NGFileManager.h>

@class NSArray, NSString, NSData, NSDictionary, NSURL;
@class NGImap4Context, NGImap4Folder, NGImap4Message;
@class EODataSource;

@interface NGImap4FileManager : NGFileManager
{
  NGImap4Context *imapContext;
  NGImap4Folder  *rootFolder;
  NGImap4Folder  *currentFolder;
}

- (id)initWithURL:(NSURL *)_url;
- (id)initWithUser:(NSString *)_user
  password:(NSString *)_pwd
  host:(NSString *)_host;

/* operations */

- (id)imapContext;

- (BOOL)createDirectoryAtPath:(NSString *)_path
  attributes:(NSDictionary *)_attributes;
- (BOOL)changeCurrentDirectoryPath:(NSString *)_path;
- (NSString *)currentDirectoryPath;
- (NGImap4Folder *)currentFolder;

- (NGImap4Message *)messageAtPath:(NSString *)_path;
- (NSData *)contentsAtPath:(NSString *)_path part:(NSString *)_part;
- (NSData *)contentsAtPath:(NSString *)_path;
- (NSArray *)directoryContentsAtPath:(NSString *)_path;
- (NSArray *)directoriesAtPath:(NSString *)_path;
- (NSArray *)filesAtPath:(NSString *)_path;
- (NSArray *)directoryContentsAtPath:(NSString *)_path
  directories:(BOOL)_dirs
  files:(BOOL)_files;
- (EODataSource *)dataSourceAtPath:(NSString *)_path;

- (BOOL)fileExistsAtPath:(NSString *)_path;
- (BOOL)fileExistsAtPath:(NSString *)_path isDirectory:(BOOL *)_isDir;
- (BOOL)isReadableFileAtPath:(NSString *)_path;
- (BOOL)isWritableFileAtPath:(NSString *)_path;
- (BOOL)isExecutableFileAtPath:(NSString *)_path;
- (BOOL)isDeletableFileAtPath:(NSString *)_path;

- (BOOL)syncMode;
- (void)setSyncMode:(BOOL)_bool;

@end

#endif /* __NGImap4FileManager_H__ */
