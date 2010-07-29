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

#ifndef __NGFileManager_H__
#define __NGFileManager_H__

#import <Foundation/NSFileManager.h>

@class NSString, NSData;
@class EODataSource, EOGlobalID;

@protocol NGFileManager

/* path operations */

- (NSString *)standardizePath:(NSString *)_path;
- (NSString *)resolveSymlinksInPath:(NSString *)_path;
- (NSString *)expandTildeInPath:(NSString *)_path;

/* directory operations */

- (BOOL)changeCurrentDirectoryPath:(NSString *)_path;
- (BOOL)createDirectoryAtPath:(NSString *)_path attributes:(NSDictionary *)_ats;
- (NSString *)currentDirectoryPath;

/* file operations */

- (BOOL)copyPath:(NSString *)_s toPath:(NSString *)_d handler:(id)_handler;
- (BOOL)movePath:(NSString *)_s toPath:(NSString *)_d handler:(id)_handler;
- (BOOL)linkPath:(NSString *)_s toPath:(NSString *)_d handler:(id)_handler;

- (BOOL)removeFileAtPath:(NSString *)_path handler:(id)_handler;

- (BOOL)createFileAtPath:(NSString *)_path contents:(NSData *)_contents
  attributes:(NSDictionary *)_attributes;

/* getting and comparing file contents */

- (NSData *)contentsAtPath:(NSString *)_path;
- (BOOL)contentsEqualAtPath:(NSString *)_path1 andPath:(NSString *)_path2;

/* determining access to files */

- (BOOL)fileExistsAtPath:(NSString *)_path;
- (BOOL)fileExistsAtPath:(NSString *)_path isDirectory:(BOOL*)_isDirectory;
- (BOOL)isReadableFileAtPath:(NSString *)_path;
- (BOOL)isWritableFileAtPath:(NSString *)_path;
- (BOOL)isExecutableFileAtPath:(NSString *)_path;
- (BOOL)isDeletableFileAtPath:(NSString *)_path;

/* Getting and setting attributes */

- (NSDictionary *)fileAttributesAtPath:(NSString *)_p traverseLink:(BOOL)_flag;
- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)_p;
- (BOOL)changeFileAttributes:(NSDictionary *)_attributes atPath:(NSString *)_p;

/* discovering directory contents */

- (NSArray *)directoryContentsAtPath:(NSString *)_path;
- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)_path;
- (NSArray *)subpathsAtPath:(NSString *)_path;

/* symbolic-link operations */

- (BOOL)createSymbolicLinkAtPath:(NSString *)_p pathContent:(NSString *)_dpath;
- (NSString *)pathContentOfSymbolicLinkAtPath:(NSString *)_path;

/* feature check */

- (BOOL)supportsVersioningAtPath:(NSString *)_path;
- (BOOL)supportsLockingAtPath:(NSString *)_path;
- (BOOL)supportsFolderDataSourceAtPath:(NSString *)_path;
- (BOOL)supportsFeature:(NSString *)_featureURI atPath:(NSString *)_path;

/* writing */

- (BOOL)writeContents:(NSData *)_content atPath:(NSString *)_path;

/* global-IDs */

- (EOGlobalID *)globalIDForPath:(NSString *)_path;
- (NSString *)pathForGlobalID:(EOGlobalID *)_gid;

/* trash */

- (BOOL)supportsTrashFolderAtPath:(NSString *)_path;
- (NSString *)trashFolderForPath:(NSString *)_path;

- (BOOL)trashFileAtPath:(NSString *)_path handler:(id)_handler;

@end

@protocol NGFileManagerVersioning < NGFileManager >

/* versioning */

- (BOOL)checkoutFileAtPath:(NSString *)_path handler:(id)_handler;
- (BOOL)releaseFileAtPath:(NSString *)_path  handler:(id)_handler;
- (BOOL)rejectFileAtPath:(NSString *)_path   handler:(id)_handler;
- (BOOL)checkoutFileAtPath:(NSString *)_path version:(NSString *)_version
  handler:(id)_handler;

/* versioning data */

- (NSString *)lastVersionAtPath:(NSString *)_path;
- (NSArray *)versionsAtPath:(NSString *)_path;
- (NSData *)contentsAtPath:(NSString *)_path version:(NSString *)_version;
- (NSDictionary *)fileAttributesAtPath:(NSString *)_path
  traverseLink:(BOOL)_followLink
  version:(NSString *)_version;

@end

@protocol NGFileManagerLocking < NGFileManager >

- (BOOL)lockFileAtPath:(NSString *)_path handler:(id)_handler;
- (BOOL)unlockFileAtPath:(NSString *)_path handler:(id)_handler;
- (BOOL)isFileLockedAtPath:(NSString *)_path;

/* access rights */
- (BOOL)isLockableFileAtPath:(NSString *)_path;
- (BOOL)isUnlockableFileAtPath:(NSString *)_path;

@end

@protocol NGFileManagerDataSources < NGFileManager >

/* datasources (work on folders) */

- (EODataSource *)dataSourceAtPath:(NSString *)_path;
- (EODataSource *)dataSource; // works on current-directory-path

@end

/* features */

#define NGFileManagerFeature_DataSources \
  @"http://www.skyrix.com/filemanager/datasources"
#define NGFileManagerFeature_Locking \
  @"http://www.skyrix.com/filemanager/locking"
#define NGFileManagerFeature_Versioning \
  @"http://www.skyrix.com/filemanager/versioning"

/* abstract superclass for filemanagers ... */

@class NSString, NSURL;

@interface NGFileManager : NSObject < NGFileManager >
{
@protected
  NSString *cwd;
}

/* paths */

/*
  This method removes all 'special' things:
    '.'
    '//'
    '..'
*/
- (NSString *)standardizePath:(NSString *)_path;

/* this does return _path in NGFileManager ... */
- (NSString *)resolveSymlinksInPath:(NSString *)_path;

/* this does return _path in NGFileManager ... */
- (NSString *)expandTildeInPath:(NSString *)_path;

/* URLs */

- (NSURL *)urlForPath:(NSString *)_path;

@end

#endif /* __NGFileManager_H__ */
