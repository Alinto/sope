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

#include <NGExtensions/NGCustomFileManager.h>
#include "common.h"

typedef struct {
  NSString                *sourcePath;
  NSString                *absolutePath;
  NSString                *path;
  NGCustomFileManagerInfo *info;
  id                      fileManager;
} NGCustomFMPath;

@interface NGCustomFileManager(Helpers)
- (NGCustomFMPath)_resolvePath:(NSString *)_path;
- (BOOL)_boolDo:(SEL)_sel onPath:(NSString *)_path;
- (BOOL)_boolDo:(SEL)_sel onPath:(NSString *)_path handler:(id)_handler;
- (id)_do:(SEL)_sel onPath:(NSString *)_path;
@end

@implementation NGCustomFileManager

+ (int)version {
  return [super version] + 0 /* v0 */;
}
+ (void)initialize {
  NSAssert2([super version] == 0,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

/* customization */

- (NSString *)makeAbsolutePath:(NSString *)_path {
  if ([_path isAbsolutePath])
    return _path;
  
  return [[self currentDirectoryPath] stringByAppendingPathComponent:_path];
}

- (NGCustomFileManagerInfo *)fileManagerInfoForPath:(NSString *)_path {
  return nil;
}

/* common ops */

- (NGCustomFMPath)_resolvePath:(NSString *)_path {
  NGCustomFMPath p;
  
  p.sourcePath   = _path;
  p.absolutePath = [self makeAbsolutePath:_path];
  p.info         = [self fileManagerInfoForPath:_path];
  p.path         = [p.info rewriteAbsolutePath:p.absolutePath];
  p.fileManager  = [p.info fileManager];
  return p;
}

- (BOOL)_boolDo:(SEL)_sel onPath:(NSString *)_path {
  NGCustomFMPath p;
  BOOL (*op)(id,SEL,NSString *);
  
  if (_sel == NULL) return NO;
  p = [self _resolvePath:_path];
  if ((_path = p.path) == nil) return NO;
  if ((op = (void *)[p.fileManager methodForSelector:_sel]) == NULL) return NO;
  
  return op(p.fileManager, _sel, _path);
}
- (BOOL)_boolDo:(SEL)_sel onPath:(NSString *)_path handler:(id)_handler {
  NGCustomFMPath p;
  BOOL (*op)(id,SEL,NSString *,id);
  
  if (_sel == NULL) return NO;
  p = [self _resolvePath:_path];
  if ((_path = p.path) == nil) return NO;
  if ((op = (void *)[p.fileManager methodForSelector:_sel]) == NULL) return NO;
  
  return op(p.fileManager, _sel, _path, _handler);
}
- (id)_do:(SEL)_sel onPath:(NSString *)_path {
  NGCustomFMPath p;
  id (*op)(id,SEL,NSString *);
  
  if (_sel == NULL) return NO;
  p = [self _resolvePath:_path];
  if ((_path = p.path) == nil) return NO;
  if ((op = (void *)[p.fileManager methodForSelector:_sel]) == NULL) return NO;
  
  return op(p.fileManager, _sel, _path);
}

/* directory operations */

- (BOOL)changeCurrentDirectoryPath:(NSString *)_path {
  BOOL isDir = NO;
  if ((_path = [self makeAbsolutePath:_path]) == nil) return NO;
  
  if (![self fileExistsAtPath:_path isDirectory:&isDir]) return NO;
  if (!isDir) return NO;
  
  ASSIGNCOPY(self->cwd, _path);
  return YES;
}
- (NSString *)currentDirectoryPath {
  return self->cwd;
}

- (BOOL)createDirectoryAtPath:(NSString *)_path
  attributes:(NSDictionary *)_ats
{
  NGCustomFMPath p;
  p = [self _resolvePath:_path];
  if (p.path == nil) return NO;
  
  return [p.fileManager createDirectoryAtPath:p.path attributes:_ats];
}

/* file operations */

- (BOOL)copyPath:(NSString *)_s toPath:(NSString *)_d handler:(id)_handler {
  NGCustomFileManagerInfo *sinfo, *dinfo;
  
  if ((_s = [self makeAbsolutePath:_s]) == nil) return NO;
  if ((_d = [self makeAbsolutePath:_d]) == nil) return NO;
  if ((sinfo = [self fileManagerInfoForPath:_s]) == nil) return NO;
  if ((dinfo = [self fileManagerInfoForPath:_d]) == nil) return NO;
  _s = [sinfo rewriteAbsolutePath:_s];
  _d = [dinfo rewriteAbsolutePath:_d];
  
  if ([sinfo isEqual:dinfo]) /* same filemanager */
    return [[sinfo fileManager] copyPath:_s toPath:_d handler:_handler];
  
  /* operation between different filemanagers ... */
  return NO;
}

- (BOOL)movePath:(NSString *)_s toPath:(NSString *)_d handler:(id)_handler {
  NGCustomFileManagerInfo *sinfo, *dinfo;
  
  if ((_s = [self makeAbsolutePath:_s]) == nil) return NO;
  if ((_d = [self makeAbsolutePath:_d]) == nil) return NO;
  if ((sinfo = [self fileManagerInfoForPath:_s]) == nil) return NO;
  if ((dinfo = [self fileManagerInfoForPath:_d]) == nil) return NO;
  _s = [sinfo rewriteAbsolutePath:_s];
  _d = [dinfo rewriteAbsolutePath:_d];
  
  if ([sinfo isEqual:dinfo]) /* same filemanager */
    return [[sinfo fileManager] movePath:_s toPath:_d handler:_handler];
    
  /* operation between different filemanagers ... */
  return NO;
}

- (BOOL)linkPath:(NSString *)_s toPath:(NSString *)_d handler:(id)_handler {
  NGCustomFileManagerInfo *sinfo, *dinfo;
  
  if ((_s = [self makeAbsolutePath:_s]) == nil) return NO;
  if ((_d = [self makeAbsolutePath:_d]) == nil) return NO;
  if ((sinfo = [self fileManagerInfoForPath:_s]) == nil) return NO;
  if ((dinfo = [self fileManagerInfoForPath:_d]) == nil) return NO;
  _s = [sinfo rewriteAbsolutePath:_s];
  _d = [dinfo rewriteAbsolutePath:_d];
  
  if ([sinfo isEqual:dinfo]) /* same filemanager */
    return [[sinfo fileManager] linkPath:_s toPath:_d handler:_handler];
    
  /* operation between different filemanagers ... */
  return NO;
}

- (BOOL)removeFileAtPath:(NSString *)_path handler:(id)_handler {
  return [self _boolDo:_cmd onPath:_path handler:_handler];
}

- (BOOL)createFileAtPath:(NSString *)_path contents:(NSData *)_contents
  attributes:(NSDictionary *)_attributes
{
  NGCustomFMPath p;
  p = [self _resolvePath:_path];
  if (p.path == nil) return NO;
  
  return [p.fileManager
                createFileAtPath:p.path
                contents:_contents
                attributes:_attributes];
}

/* getting and comparing file contents */

- (NSData *)contentsAtPath:(NSString *)_path {
  return [self _do:_cmd onPath:_path];
}

- (BOOL)contentsEqualAtPath:(NSString *)_path1 andPath:(NSString *)_path2 {
  NGCustomFileManagerInfo *info1, *info2;
  
  if ((_path1 = [self makeAbsolutePath:_path1]) == nil) return NO;
  if ((_path2 = [self makeAbsolutePath:_path2]) == nil) return NO;
  if ((info1 = [self fileManagerInfoForPath:_path1]) == nil) return NO;
  if ((info2 = [self fileManagerInfoForPath:_path2]) == nil) return NO;
  _path1 = [info1 rewriteAbsolutePath:_path1];
  _path2 = [info2 rewriteAbsolutePath:_path2];
  
  if ([info1 isEqual:info2]) /* same filemanager */
    return [[info1 fileManager] contentsEqualAtPath:_path1 andPath:_path2];
  
  /* operation between different filemanagers ... */
  return NO;
}

/* determining access to files */

- (BOOL)fileExistsAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}
- (BOOL)fileExistsAtPath:(NSString *)_path isDirectory:(BOOL *)_isDirectory {
  NGCustomFMPath p;
  p = [self _resolvePath:_path];
  if (p.path == nil) return NO;
  
  return [p.fileManager fileExistsAtPath:p.path isDirectory:_isDirectory];
}
- (BOOL)isReadableFileAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}
- (BOOL)isWritableFileAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}
- (BOOL)isExecutableFileAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}
- (BOOL)isDeletableFileAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}

/* Getting and setting attributes */

- (NSDictionary *)fileAttributesAtPath:(NSString *)_p traverseLink:(BOOL)_flag{
  NGCustomFMPath p;
  p = [self _resolvePath:_p];
  if (p.path == nil) return NO;
  
  /* special link handling required ??? */
  return [p.fileManager fileAttributesAtPath:p.path traverseLink:_flag];
}

- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)_p {
  return [self _do:_cmd onPath:_p];
}

- (BOOL)changeFileAttributes:(NSDictionary *)_attributes atPath:(NSString *)_p{
  NGCustomFMPath p;
  p = [self _resolvePath:_p];
  if (p.path == nil) return NO;
  
  return [p.fileManager changeFileAttributes:_attributes atPath:p.path];
}

/* discovering directory contents */

- (NSArray *)directoryContentsAtPath:(NSString *)_path {
  /* this returns relative path's, can be passed back */
  return [self _do:_cmd onPath:_path];
}

- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)_path {
  /* this needs to be wrapped ! */
  return nil;
}

- (NSArray *)subpathsAtPath:(NSString *)_path {
  /* this returns relative path's, can be passed back */
  return [self _do:_cmd onPath:_path];
}

/* symbolic-link operations */

- (BOOL)createSymbolicLinkAtPath:(NSString *)_p pathContent:(NSString *)_dpath{
  /* should that process the link-path somehow ??? */
  NGCustomFMPath p;
  p = [self _resolvePath:_p];
  if (p.path == nil) return NO;
  
  return [p.fileManager createSymbolicLinkAtPath:p.path pathContent:_dpath];
}
- (NSString *)pathContentOfSymbolicLinkAtPath:(NSString *)_path {
  /* should that process the link-path somehow ??? */
  return [self _do:_cmd onPath:_path];
}

/* feature check */

- (BOOL)supportsVersioningAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}
- (BOOL)supportsLockingAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}
- (BOOL)supportsFolderDataSourceAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}

- (BOOL)supportsFeature:(NSString *)_featureURI atPath:(NSString *)_path {
  NGCustomFMPath p;
  p = [self _resolvePath:_path];
  if (p.path == nil) return NO;
  
  return [p.fileManager supportsFeature:_featureURI atPath:p.path];
}

/* writing */

- (BOOL)writeContents:(NSData *)_content atPath:(NSString *)_path {
  NGCustomFMPath p;
  p = [self _resolvePath:_path];
  if (p.path == nil) return NO;
  
  return [p.fileManager writeContents:_content atPath:p.path];
}

/* global-IDs */

- (EOGlobalID *)globalIDForPath:(NSString *)_path {
  NGCustomFileManagerInfo *info;
  if ((_path = [self makeAbsolutePath:_path])      == nil) return NO;
  if ((info = [self fileManagerInfoForPath:_path]) == nil) return NO;

  if (![info supportsGlobalIDs])
    return nil;
  
  if ((_path = [info rewriteAbsolutePath:_path]) == nil)
    return NO;
  
  return [[info fileManager] globalIDForPath:_path];
}

- (NSString *)pathForGlobalID:(EOGlobalID *)_gid {
  return nil;
}

/* trash */

- (BOOL)supportsTrashFolderAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}
- (NSString *)trashFolderForPath:(NSString *)_path {
  return NO;
}

@end /* NGCustomFileManager */

@implementation NGCustomFileManager(NGFileManagerVersioning)

/* versioning */

- (BOOL)checkoutFileAtPath:(NSString *)_path handler:(id)_handler {
  return [self _boolDo:_cmd onPath:_path handler:_handler];
}
- (BOOL)releaseFileAtPath:(NSString *)_path handler:(id)_handler {
  return [self _boolDo:_cmd onPath:_path handler:_handler];
}
- (BOOL)rejectFileAtPath:(NSString *)_path handler:(id)_handler {
  return [self _boolDo:_cmd onPath:_path handler:_handler];
}
- (BOOL)checkoutFileAtPath:(NSString *)_path version:(NSString *)_version
  handler:(id)_handler
{
  NGCustomFMPath p;
  p = [self _resolvePath:_path];
  if (p.path == nil) return NO;
  
  return [p.fileManager
           checkoutFileAtPath:p.path version:_version handler:_handler];
}

/* versioning data */

- (NSString *)lastVersionAtPath:(NSString *)_path {
  return [self _do:_cmd onPath:_path];
}
- (NSArray *)versionsAtPath:(NSString *)_path {
  return [self _do:_cmd onPath:_path];
}

- (NSData *)contentsAtPath:(NSString *)_path version:(NSString *)_version {
  NGCustomFMPath p;
  p = [self _resolvePath:_path];
  if (p.path == nil) return NO;
  
  return [p.fileManager contentsAtPath:p.path version:_version];
}

- (NSDictionary *)fileAttributesAtPath:(NSString *)_path
  traverseLink:(BOOL)_followLink
  version:(NSString *)_version
{
  NGCustomFMPath p;
  p = [self _resolvePath:_path];
  if (p.path == nil) return NO;
  
  /* do something special to symlink ??? */
  
  return [p.fileManager
           fileAttributesAtPath:p.path
           traverseLink:_followLink
           version:_version];
}

@end /* NGCustomFileManager(NGFileManagerVersioning) */

@implementation NGCustomFileManager(NGFileManagerLocking)

- (BOOL)lockFileAtPath:(NSString *)_path handler:(id)_handler {
  return [self _boolDo:_cmd onPath:_path handler:_handler];
}
- (BOOL)unlockFileAtPath:(NSString *)_path handler:(id)_handler {
  return [self _boolDo:_cmd onPath:_path handler:_handler];
}
- (BOOL)isFileLockedAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}

/* access rights */

- (BOOL)isLockableFileAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}
- (BOOL)isUnlockableFileAtPath:(NSString *)_path {
  return [self _boolDo:_cmd onPath:_path];
}

@end /* NGCustomFileManager(NGFileManagerLocking) */

@implementation NGCustomFileManager(NGFileManagerDataSources)

/* datasources (work on folders) */

- (EODataSource *)dataSourceAtPath:(NSString *)_path {
  return [self _do:_cmd onPath:_path];
}

- (EODataSource *)dataSource {
  return [self dataSourceAtPath:[self currentDirectoryPath]];
}

@end /* NGCustomFileManager(NGFileManagerDataSources) */

@implementation NGCustomFileManagerInfo

- (id)initWithCustomFileManager:(NGCustomFileManager *)_master
  fileManager:(id<NGFileManager,NSObject>)_fm
{
  self->master      = _master;
  self->fileManager = [_fm retain];
  return self;
}
- (id)init {
  return [self initWithCustomFileManager:nil fileManager:nil];
}

- (void)dealloc {
  [self->fileManager release];
  [super dealloc];
}

- (void)resetMaster {
  self->master = nil;
}

/* accessors */

- (NGCustomFileManager *)master {
  return self->master;
}
- (id<NGFileManager,NSObject>)fileManager {
  return self->fileManager;
}

/* operations */

- (NSString *)rewriteAbsolutePath:(NSString *)_path {
  return _path;
}

/* capabilities */

- (BOOL)supportsGlobalIDs {
  return [self->fileManager respondsToSelector:@selector(globalIDForPath:)];
}

@end /* NGCustomFileManagerInfo */
