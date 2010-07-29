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

#include "NGFileManager.h"
#include "NGFileManagerURL.h"
#include "NSObject+Logs.h"
#include "common.h"

@implementation NGFileManager

static BOOL logPathOps = NO;

+ (int)version {
  return 0;
}

- (id)init {
  if ((self = [super init])) {
    self->cwd = @"/";
  }
  return self;
}
- (void)dealloc {
  [self->cwd release];
  [super dealloc];
}

/* path modifications */

- (NSString *)standardizePath:(NSString *)_path {
  NSMutableArray *rpc;
  NSArray        *pc;
  unsigned       i, pcn;
  NSString       *result;

  if (logPathOps) [self logWithFormat:@"standardize: %@", _path];
  
  pc = [_path pathComponents];
  if ((pcn = [pc count]) == 0) return _path;

  if (logPathOps) {
    [self logWithFormat:@"  components: %@", 
            [pc componentsJoinedByString:@" => "]];
  }
  
  rpc = [NSMutableArray arrayWithCapacity:pcn];
  
  for (i = 0; i < pcn; i++) {
    NSString *p;
    
    p = [pc objectAtIndex:i];
    
    if ([p isEqualToString:@"/"]) {
      /* found root */
      [rpc removeAllObjects];
      [rpc addObject:@"/"];
    }
    else if ([p isEqualToString:@"."]) {
      /* found current directory */
      /* '.' can always be removed, right ??? ... */
    }
    else if ([p isEqualToString:@".."]) {
      /* found parent directory */
      if (i == 0)
        /* relative path starting with '..' */
        [rpc addObject:p];
      else {
        /* remove last path component .. */
        unsigned count;
        
        if ((count = [rpc count]) > 0)
          [rpc removeObjectAtIndex:(count - 1)];
      }
    }
    else if ([p isEqualToString:@""]) {
      /* ignore empty strings */
    }
    else {
      /* usual path */
      [rpc addObject:p];
    }
  }
  
  if (logPathOps) {
    [self logWithFormat:@"  new components: %@", 
            [rpc componentsJoinedByString:@" => "]];
  }
  result = [NSString pathWithComponents:rpc];
  if ([result length] == 0)
    return _path;
  
  if (logPathOps) [self logWithFormat:@"  standardized: %@", result];
  return result;
}

- (NSString *)resolveSymlinksInPath:(NSString *)_path {
  return _path;
}

- (NSString *)expandTildeInPath:(NSString *)_path {
  return _path;
}

/* directory operations */

- (BOOL)changeCurrentDirectoryPath:(NSString *)_path {
  BOOL isDir;

  if (![self fileExistsAtPath:_path isDirectory:&isDir])
    return NO;
  if (!isDir)
    return NO;
  ASSIGNCOPY(self->cwd, _path);
  return YES;
}
- (NSString *)currentDirectoryPath {
  return self->cwd;
}

- (BOOL)createDirectoryAtPath:(NSString *)_path
  attributes:(NSDictionary *)_ats
{
  return NO;
}

/* file operations */

- (BOOL)copyPath:(NSString *)_s toPath:(NSString *)_d handler:(id)_handler {
  return NO;
}
- (BOOL)movePath:(NSString *)_s toPath:(NSString *)_d handler:(id)_handler {
  return NO;
}
- (BOOL)linkPath:(NSString *)_s toPath:(NSString *)_d handler:(id)_handler {
  return NO;
}

- (BOOL)removeFileAtPath:(NSString *)_path handler:(id)_handler {
  return NO;
}

- (BOOL)createFileAtPath:(NSString *)_path contents:(NSData *)_contents
  attributes:(NSDictionary *)_attributes
{
  return NO;
}

/* getting and comparing file contents */

- (NSData *)contentsAtPath:(NSString *)_path {
  return nil;
}
- (BOOL)contentsEqualAtPath:(NSString *)_path1 andPath:(NSString *)_path2 {
  NSData *data1, *data2;
  
  data1 = [self contentsAtPath:_path1];
  data2 = [self contentsAtPath:_path2];
  
  if (data1 == data2) return YES;
  if (data1 == nil || data2 == nil) return NO;
  
  return [data1 isEqual:data2];
}

/* determining access to files */

- (BOOL)fileExistsAtPath:(NSString *)_path {
  BOOL dummy = NO;
  return [self fileExistsAtPath:_path isDirectory:&dummy];
}
- (BOOL)fileExistsAtPath:(NSString *)_path isDirectory:(BOOL*)_isDirectory {
  return NO;
}
- (BOOL)isReadableFileAtPath:(NSString *)_path {
  return NO;
}
- (BOOL)isWritableFileAtPath:(NSString *)_path {
  return NO;
}
- (BOOL)isExecutableFileAtPath:(NSString *)_path {
  return NO;
}
- (BOOL)isDeletableFileAtPath:(NSString *)_path {
  return NO;
}

/* Getting and setting attributes */

- (NSDictionary *)fileAttributesAtPath:(NSString *)_p traverseLink:(BOOL)_flag{
  return nil;
}
- (NSDictionary *)fileSystemAttributesAtPath:(NSString *)_p {
  return nil;
}
- (BOOL)changeFileAttributes:(NSDictionary *)_attributes atPath:(NSString *)_p{
  return NO;
}

/* discovering directory contents */

- (NSArray *)directoryContentsAtPath:(NSString *)_path {
  return nil;
}
- (NSDirectoryEnumerator *)enumeratorAtPath:(NSString *)_path {
  return nil;
}
- (NSArray *)subpathsAtPath:(NSString *)_path {
  return nil;
}

/* symbolic-link operations */

- (BOOL)createSymbolicLinkAtPath:(NSString *)_p pathContent:(NSString *)_dpath{
  return NO;
}
- (NSString *)pathContentOfSymbolicLinkAtPath:(NSString *)_path {
  return nil;
}

/* feature check */

- (BOOL)supportsVersioningAtPath:(NSString *)_path {
  return [self supportsFeature:NGFileManagerFeature_Versioning atPath:_path];
}
- (BOOL)supportsLockingAtPath:(NSString *)_path {
  return [self supportsFeature:NGFileManagerFeature_Locking atPath:_path];
}
- (BOOL)supportsFolderDataSourceAtPath:(NSString *)_path {
  return [self supportsFeature:NGFileManagerFeature_DataSources atPath:_path];
}
- (BOOL)supportsFeature:(NSString *)_featureURI atPath:(NSString *)_path {
  return NO;
}

/* writing */

- (BOOL)writeContents:(NSData *)_content atPath:(NSString *)_path {
  return NO;
}

/* global-IDs */

- (EOGlobalID *)globalIDForPath:(NSString *)_path; {
  return nil;
}
- (NSString *)pathForGlobalID:(EOGlobalID *)_gid {
  return nil;
}

/* trash */

- (BOOL)supportsTrashFolderAtPath:(NSString *)_path {
  return NO;
}
- (NSString *)trashFolderForPath:(NSString *)_path {
  return nil;
}

- (BOOL)trashFileAtPath:(NSString *)_path handler:(id)_handler {
  NSString *trash, *destPath;
  BOOL     isDir;
  unsigned i;
  NSString *tmp;
  
  if (![self supportsTrashFolderAtPath:_path])
    return NO;
  if ([(trash = [self trashFolderForPath:_path]) length] == 0)
    return NO;
  
  if ([_path hasPrefix:trash])
    /* path already is in trash ... */
    return YES;
  
  /* ensure that the trash folder is existent */

  if ([self fileExistsAtPath:trash isDirectory:&isDir]) {
    if (!isDir) {
      NSLog(@"%s: '%@' exists, but isn't a folder !", __PRETTY_FUNCTION__,
            trash);
      return NO;
    }
  }
  else { /* trash doesn't exist yet */
    if (![self createDirectoryAtPath:trash attributes:nil]) {
      NSLog(@"%s: couldn't create trash folder '%@' !", __PRETTY_FUNCTION__,
            trash);
      return NO;
    }
  }

  /* construct trash path for target ... */

  destPath = [trash stringByAppendingPathComponent:
                      [_path lastPathComponent]];
  tmp = destPath;
  i = 0;
  while ([self fileExistsAtPath:tmp]) {
    i++;
    tmp = [destPath stringByAppendingFormat:@"%d", i];
    if (i > 40) {
      NSLog(@"%s: too many files named similiar to '%@' in trash folder '%@'",
            __PRETTY_FUNCTION__, destPath, trash);
      return NO;
    }
  }
  destPath = tmp;
  
  /* move to trash */
  if (![self movePath:_path toPath:destPath handler:_handler])
    return NO;
  
  return YES;
}

/* URLs */

- (NSURL *)urlForPath:(NSString *)_path {
  return [[[NGFileManagerURL alloc]
                             initWithPath:_path fileManager:self]
                             autorelease];
}

@end /* NGFileManager */
