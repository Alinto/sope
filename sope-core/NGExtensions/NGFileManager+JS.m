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

#include "common.h"
#include "NGFileManager.h"
#include "NSFileManager+Extensions.h"
#include "EOCacheDataSource.h"

/*
  JavaScript
  
    Properties
    
      cwd - readonly - current working directory, string
    
    Methods
    
      bool   cd(path)
      Object ls([path|paths])
      bool   mkdir(path[,path..])
      bool   rmdir(path[,path..])
      bool   rm(path[,path..])
      bool   trash(path[,path..])
      bool   cp(frompath[,frompath..], topath)
      bool   mv(frompath[,frompath..], topath)
      bool   ln(frompath, topath)
      
      bool   exists(path[,path..])
      bool   isdir(path[,path..])
      bool   islink(path[,path..])
      
      Object getDataSource([String path, [bool cache]])
*/

@implementation NGFileManager(JSSupport)

static NSNumber *boolYes = nil;
static NSNumber *boolNo  = nil;

static void _ensureBools(void) {
  if (boolYes == nil) boolYes = [[NSNumber numberWithBool:YES] retain];
  if (boolNo  == nil) boolNo  = [[NSNumber numberWithBool:NO]  retain];
}

/* properties */

- (id)_jsprop_cwd {
  return [self currentDirectoryPath];
}

/* methods */

- (id)_jsfunc_cd:(NSArray *)_args {
  _ensureBools();
  return [self changeCurrentDirectoryPath:[_args objectAtIndex:0]]
    ? boolYes
    : boolNo;
}

- (id)_jsfunc_ls:(NSArray *)_args {
  unsigned count;
  
  if ((count = [_args count]) == 0) {
    return [self directoryContentsAtPath:@"."];
  }
  else if (count == 1) {
    return [self directoryContentsAtPath:
                   [[_args objectAtIndex:0] stringValue]];
  }
  else {
    NSMutableDictionary *md;
    unsigned i;
    
    md = [NSMutableDictionary dictionaryWithCapacity:count];
    for (i = 0; i < count; i++) {
      NSString *path;
      NSArray  *contents;

      path     = [_args objectAtIndex:i];
      contents = [self directoryContentsAtPath:path];

      if (contents)
        [md setObject:contents forKey:path];
    }
    
    return md;
  }
}

- (id)_jsfunc_mkdir:(NSArray *)_args {
  unsigned count;
  _ensureBools();

  if ((count = [_args count]) == 0) {
    return boolNo;
  }
  else {
    unsigned i;
    
    for (i = 0; i < count; i++) {
      NSString *path;
      
      path = [_args objectAtIndex:i];
      
      if (![self createDirectoryAtPath:path attributes:nil])
        return boolNo;
    }
    
    return boolYes;
  }
}

- (id)_jsfunc_rmdir:(NSArray *)_args {
  unsigned count;
  _ensureBools();

  if ((count = [_args count]) == 0) {
    return boolNo;
  }
  else {
    unsigned i;
    
    for (i = 0; i < count; i++) {
      NSString *path;
      BOOL isDir;
      
      path = [_args objectAtIndex:i];
      
      if (![self fileExistsAtPath:path isDirectory:&isDir])
        return boolNo;
      
      if (!isDir)
        /* not a directory ! */
        return boolNo;
      
      if ([[self directoryContentsAtPath:path] count] > 0)
        /* directory has contents */
        return boolNo;

      if (![self removeFileAtPath:path handler:nil])
        /* remove failed */
        return boolNo;
    }
    return boolYes;
  }
}

- (id)_jsfunc_rm:(NSArray *)_args {
  unsigned count;
  _ensureBools();
  
  if ((count = [_args count]) == 0) {
    return boolNo;
  }
  else {
    unsigned i;
    
    for (i = 0; i < count; i++) {
      NSString *path;
      BOOL isDir;
      
      path = [_args objectAtIndex:i];
      
      if (![self fileExistsAtPath:path isDirectory:&isDir])
        return boolNo;

      if (isDir) {
        if ([[self directoryContentsAtPath:path] count] > 0)
          /* directory has contents */
          return boolNo;
      }
      
      if (![self removeFileAtPath:path handler:nil])
        /* remove failed */
        return boolNo;
    }
    return boolYes;
  }
}

- (id)_jsfunc_trash:(NSArray *)_args {
  unsigned count;
  _ensureBools();

  if ((count = [_args count]) == 0) {
    return boolNo;
  }
  else {
    unsigned i;
    
    for (i = 0; i < count; i++) {
      NSString *path;
      BOOL isDir;
      
      path = [_args objectAtIndex:i];
      if (![self supportsTrashFolderAtPath:path])
        return boolNo;
      
      if (![self fileExistsAtPath:path isDirectory:&isDir])
        return boolNo;
      
      if (![self trashFileAtPath:path handler:nil])
        /* remove failed */
        return boolNo;
    }
    return boolYes;
  }
}

- (id)_jsfunc_mv:(NSArray *)_args {
  unsigned count;
  _ensureBools();
  
  if ((count = [_args count]) == 0)
    return boolNo;
  else if (count == 1)
    /* missing target path */
    return boolNo;
  else {
    NSString *destpath;
    unsigned i;
    BOOL isDir;
    
    destpath = [_args objectAtIndex:(count - 1)];

    if (![self fileExistsAtPath:destpath isDirectory:&isDir])
      isDir = NO;
    
    for (i = 0; i < (count - 1); i++) {
      NSString *path, *dpath = nil;
      
      path = [_args objectAtIndex:i];
      
      dpath = isDir
        ? [dpath stringByAppendingPathComponent:[path lastPathComponent]]
        : destpath;
      
      if (![self movePath:path toPath:dpath handler:nil])
        /* move failed */
        return boolNo;
    }
    
    return boolYes;
  }
}

- (id)_jsfunc_cp:(NSArray *)_args {
  unsigned count;
  _ensureBools();
   
  if ((count = [_args count]) == 0)
    return boolNo;
  else if (count == 1)
    /* missing target path */
    return boolNo;
  else {
    NSString *destpath;
    unsigned i;
    BOOL isDir;
    
    destpath = [_args objectAtIndex:(count - 1)];

    if (![self fileExistsAtPath:destpath isDirectory:&isDir])
      isDir = NO;
    
    for (i = 0; i < (count - 1); i++) {
      NSString *path, *dpath = nil;
      
      path = [_args objectAtIndex:i];

      dpath = isDir
        ? [dpath stringByAppendingPathComponent:[path lastPathComponent]]
        : destpath;
      
      if (![self copyPath:path toPath:dpath handler:nil])
        /* copy failed */
        return boolNo;
    }
    
    return boolYes;
  }
}

- (id)_jsfunc_ln:(NSArray *)_args {
  unsigned count;
  _ensureBools();
  
  if ((count = [_args count]) == 0)
    return boolNo;
  else if (count == 1)
    /* missing target path */
    return boolNo;
  else {
    NSString *srcpath;
    NSString *destpath;
    
    srcpath  = [_args objectAtIndex:0];
    destpath = [_args objectAtIndex:1];
    
    if (![self createSymbolicLinkAtPath:destpath pathContent:srcpath])
      return boolNo;
    
    return boolYes;
  }
}

- (id)_jsfunc_exists:(NSArray *)_args {
  unsigned count;
  _ensureBools();
  
  if ((count = [_args count]) == 0)
    return boolYes;
  else {
    unsigned i;
    
    for (i = 0; i < count; i++) {
      NSString *path;
      
      path = [_args objectAtIndex:i];
      
      if (![self fileExistsAtPath:path])
        return boolNo;
    }
    return boolYes;
  }
}

- (id)_jsfunc_isdir:(NSArray *)_args {
  unsigned count;
  _ensureBools();
  
  if ((count = [_args count]) == 0) {
    return boolYes;
  }
  else {
    unsigned i;
    
    for (i = 0; i < count; i++) {
      NSString *path;
      BOOL isDir;
      
      path = [_args objectAtIndex:i];

#if 0
      NSLog(@"CHECK PATH: %@", path);
#endif
      
      if (![self fileExistsAtPath:path isDirectory:&isDir]) {
#if 0
        NSLog(@"  does not exist ..");
#endif
        return boolNo;
      }

      if (!isDir) {
#if 0
        NSLog(@"  not a directory ..");
#endif
        return boolNo;
      }
    }

#if 0
    NSLog(@"%s: returning yes, %@ are directories",
          __PRETTY_FUNCTION__, _args);
#endif
    return boolYes;
  }
}

- (id)_jsfunc_islink:(NSArray *)_args {
  unsigned count;
  _ensureBools();
  
  if ((count = [_args count]) == 0)
    return boolYes;
  else {
    unsigned i;
    
    for (i = 0; i < count; i++) {
      NSString     *path;
      BOOL         isDir;
      NSDictionary *attrs;
      
      path = [_args objectAtIndex:i];
      
      if (![self fileExistsAtPath:path isDirectory:&isDir])
        return boolNo;
      
      if (isDir)
        return boolNo;

      if ((attrs = [self fileAttributesAtPath:path traverseLink:NO])==nil)
        return boolNo;

      if (![[attrs objectForKey:NSFileType]
                   isEqualToString:NSFileTypeSymbolicLink])
        return boolNo;
    }
    return boolYes;
  }
}

/* datasource */

- (id)_jsfunc_getDataSource:(NSArray *)_args {
  unsigned count;
  NSString *path = nil;
  BOOL     lcache;
  id       ds;
  _ensureBools();
  
  lcache = NO;
  
  if ((count = [_args count]) == 0) {
    path = @".";
  }
  else if (count == 1) {
    path = [[_args objectAtIndex:0] stringValue];
  }
  else if (count == 2) {
    path  = [[_args objectAtIndex:0] stringValue];
    lcache = [[_args objectAtIndex:1] boolValue];
  }
  
  if (![self supportsFolderDataSourceAtPath:path])
    return nil;
  
  if ((ds = [(id<NGFileManagerDataSources>)self dataSourceAtPath:path])==nil)
    return nil;
  
  if (lcache) 
    ds = [[[EOCacheDataSource alloc] initWithDataSource:ds] autorelease];
  
  return ds;
}

@end /* NGFileManager(JSSupport) */
