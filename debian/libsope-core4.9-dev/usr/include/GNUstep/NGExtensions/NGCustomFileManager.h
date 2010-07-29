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

#ifndef __NGCustomFileManager_H__
#define __NGCustomFileManager_H__

#include <NGExtensions/NGFileManager.h>

/*
  An abstract baseclass for developing custom filemanagers which are ideally
  based on other filemanager classes.
*/

@class NGCustomFileManagerInfo;

@interface NGCustomFileManager : NGFileManager
{
}

/* customization */

- (NSString *)makeAbsolutePath:(NSString *)_path;
- (NGCustomFileManagerInfo *)fileManagerInfoForPath:(NSString *)_path;

@end

@interface NGCustomFileManager(NGFileManagerVersioning)

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

@interface NGCustomFileManager(NGFileManagerDataSources)

/* datasources (work on folders) */

- (EODataSource *)dataSourceAtPath:(NSString *)_path;
- (EODataSource *)dataSource; // works on current-directory-path

@end

@interface NGCustomFileManager(NGFileManagerLocking)

- (BOOL)lockFileAtPath:(NSString *)_path handler:(id)_handler;
- (BOOL)unlockFileAtPath:(NSString *)_path handler:(id)_handler;
- (BOOL)isFileLockedAtPath:(NSString *)_path;

/* access rights */
- (BOOL)isLockableFileAtPath:(NSString *)_path;
- (BOOL)isUnlockableFileAtPath:(NSString *)_path;

@end

@interface NGCustomFileManagerInfo : NSObject
{
@private
  NGCustomFileManager        *master;      /* non retained */
  id<NGFileManager,NSObject> fileManager;
}

- (id)initWithCustomFileManager:(NGCustomFileManager *)_master
  fileManager:(id<NGFileManager,NSObject>)_fm;

- (void)resetMaster;

/* accessors */

- (NGCustomFileManager *)master;
- (id<NGFileManager,NSObject>)fileManager;

/* operations */

- (NSString *)rewriteAbsolutePath:(NSString *)_path;

/* capabilities */

- (BOOL)supportsGlobalIDs;

@end

#endif /* __NGCustomFileManager_H__ */
