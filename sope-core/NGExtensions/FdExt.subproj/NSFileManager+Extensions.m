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

#include "NSFileManager+Extensions.h"
#include "NGFileFolderInfoDataSource.h"
#import <EOControl/EOGlobalID.h>
#include "common.h"

@interface NSFileManagerGlobalID : EOGlobalID < NSCopying >
{
@public
  NSString *path;
}
@end

// TODO: support -lastException
// TODO: add stuff like -dictionaryAtPath:, -arrayAtPath:, -propertyListAtPath:

@implementation NSFileManager(ExtendedFileManagerImp)

/* directories */

- (BOOL)createDirectoriesAtPath:(NSString *)_p attributes:(NSDictionary *)_a {
  unsigned i, count;
  NSArray *pc;
  BOOL    isDir;
  
  if ([_p length] == 0)
    return NO;
  if ([self fileExistsAtPath:_p isDirectory:&isDir])
    return isDir;
  
  pc = [_p pathComponents];
  if ((count = [pc count]) == 0)
    return YES;
  
  for (i = 0; i < count; i++) {
    NSString *fp;
    NSRange  r;
    
    r.location = 0;
    r.length   = i + 1;
    
    fp = [NSString pathWithComponents:[pc subarrayWithRange:r]];
    if ([self fileExistsAtPath:fp isDirectory:&isDir]) {
      if (!isDir) /* exists, but is a file */
        return NO;
      continue;
    }
    
    if (![self createDirectoryAtPath:fp attributes:_a])
      /* failed to create */
      return NO;
  }
  return YES;
}

/* path modifications */

- (NSString *)standardizePath:(NSString *)_path {
  if (![_path isAbsolutePath])
    _path = [[self currentDirectoryPath] stringByAppendingPathComponent:_path];
  
  return [_path stringByStandardizingPath];
}
- (NSString *)resolveSymlinksInPath:(NSString *)_path {
  return [_path stringByResolvingSymlinksInPath];
}
- (NSString *)expandTildeInPath:(NSString *)_path {
  return [_path stringByExpandingTildeInPath];
}

/* feature check */

- (BOOL)supportsVersioningAtPath:(NSString *)_path {
  return NO;
}
- (BOOL)supportsLockingAtPath:(NSString *)_path {
  return NO;
}
- (BOOL)supportsFolderDataSourceAtPath:(NSString *)_path {
  return YES;
}

- (BOOL)supportsFeature:(NSString *)_featureURI atPath:(NSString *)_path {
  if ([_featureURI isEqualToString:NGFileManagerFeature_DataSources])
    return YES;
  
  return NO;
}

/* writing */

- (BOOL)writeContents:(NSData *)_content atPath:(NSString *)_path {
  return [_content writeToFile:_path atomically:YES];
}

/* global-IDs */

- (EOGlobalID *)globalIDForPath:(NSString *)_path {
  NSFileManagerGlobalID *gid;
  
  _path = [self standardizePath:_path];
  
  gid = [[NSFileManagerGlobalID alloc] init];
  gid->path = [_path copy];
  return [gid autorelease];
}
- (NSString *)pathForGlobalID:(EOGlobalID *)_gid {
  NSFileManagerGlobalID *gid;
  
  if (![_gid isKindOfClass:[NSFileManagerGlobalID class]])
    /* not a gid we can handle ... */
    return nil;
  
  gid = (NSFileManagerGlobalID *)_gid;
  return gid->path;
}

/* datasources (work on folders) */

- (EODataSource *)dataSourceAtPath:(NSString *)_path {
  return [[[NGFileFolderInfoDataSource alloc] initWithFolderPath:_path] 
           autorelease];
}

- (EODataSource *)dataSource {
  return [self dataSourceAtPath:[self currentDirectoryPath]];
}

/* trash */

- (BOOL)supportsTrashFolderAtPath:(NSString *)_path {
  return NO;
}
- (NSString *)trashFolderForPath:(NSString *)_path {
  return nil;
}

- (BOOL)trashFileAtPath:(NSString *)_path handler:(id)_handler {
  // TODO: support trashfolder on MacOSX ?
  return NO;
}

@end /* NSFileManager(ExtendedFileManagerImp) */

@implementation NSFileManagerGlobalID

- (void)dealloc {
  [self->path release];
  [super dealloc];
}

/* NSCopying */

- (id)copyWithZone:(NSZone *)_zone {
  /* global IDs are immutable, so we can return an retained object ... */
  return [self retain];
}

/* description */

- (NSString *)description {
  NSMutableString *ms = [NSMutableString stringWithCapacity:32];
  
  [ms appendFormat:@"<0x%p[%@]", self, NSStringFromClass([self class])];
  [ms appendFormat:@" path=%@", self->path];
  [ms appendString:@">"];
  return ms;
}

@end /* NSFileManagerGlobalID */
