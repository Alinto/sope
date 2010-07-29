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

#ifndef __NGDirectoryEnumerator_H__
#define __NGDirectoryEnumerator_H__

#import <Foundation/NSEnumerator.h>
#include <NGExtensions/NGFileManager.h>

/*
  A class which is compatible to NSDirectoryEnumerator, but works with any
  object conforming to the filemanager interface.
*/

@class NSString, NSMutableArray, NSFileManager, NSDictionary;

@interface NGDirectoryEnumerator : NSEnumerator
{
  id<NSObject,NGFileManager> fileManager;

  NSMutableArray *enumStack;
  NSMutableArray *pathStack;
  NSString       *currentFileName;
  NSString       *currentFilePath;
  NSString       *topPath;
  struct {
    BOOL isRecursive:1;
    BOOL isFollowing:1;
  } flags;
}

- (id)initWithFileManager:(id<NSObject,NGFileManager>)_fm
  directoryPath:(NSString *)path 
  recurseIntoSubdirectories:(BOOL)recurse
  followSymlinks:(BOOL)follow
  prefixFiles:(BOOL)prefix;
- (id)initWithFileManager:(id<NSObject,NGFileManager>)_fm;
- (id)initWithFileManager:(id<NSObject,NGFileManager>)_fm
  directoryPath:(NSString *)_path;

- (id<NSObject,NGFileManager>)fileManager;

- (NSDictionary *)directoryAttributes;
- (NSDictionary *)fileAttributes;

- (void)skipDescendents;

@end

#endif /* __NGDirectoryEnumerator_H__ */
