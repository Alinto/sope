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

#include "NGDirectoryEnumerator.h"
#import <Foundation/NSFileManager.h>
#include "common.h"

@interface NGDirectoryEnumerator(PrivateMethods)
- (void)recurseIntoDirectory:(NSString *)_path relativeName:(NSString *)_name;
- (void)backtrack;
- (void)findNextFile;
@end

@interface NGDirEntry : NSObject
{
@public
  id           fileManager;
  NSString     *path;
  NSEnumerator *e;
}

- (id)initWithFileManager:(id<NSObject,NGFileManager>)_fm
  path:(NSString *)_path;

- (NSString *)readdir;

@end

@implementation NGDirectoryEnumerator

- (id)initWithFileManager:(id<NSObject,NGFileManager>)_fm
  directoryPath:(NSString *)_path 
  recurseIntoSubdirectories:(BOOL)_recurse
  followSymlinks:(BOOL)_follow
  prefixFiles:(BOOL)_prefix
{
  self->fileManager = _fm
    ? [_fm retain]
    : [[NSFileManager defaultManager] retain];

  self->pathStack = [[NSMutableArray alloc] init];
  self->enumStack = [[NSMutableArray alloc] init];
  self->flags.isRecursive = _recurse;
  self->flags.isFollowing = _follow;
  
  self->topPath = [_path copy];
  
  [self recurseIntoDirectory:_path relativeName:@""];
  
  return self;
}

- (id)initWithDirectoryPath:(NSString *)_path 
  recurseIntoSubdirectories:(BOOL)_recurse
  followSymlinks:(BOOL)_follow
  prefixFiles:(BOOL)_prefix
{
  return [self initWithFileManager:nil
               directoryPath:_path
               recurseIntoSubdirectories:_recurse
               followSymlinks:_follow
               prefixFiles:_prefix];
}

- (id)initWithFileManager:(id<NSObject,NGFileManager>)_fm {
  return [self initWithFileManager:_fm
               directoryPath:@"/"
               recurseIntoSubdirectories:YES
               followSymlinks:NO
               prefixFiles:YES];
}
- (id)initWithFileManager:(id<NSObject,NGFileManager>)_fm
  directoryPath:(NSString *)_path
{
  return [self initWithFileManager:_fm
               directoryPath:_path
               recurseIntoSubdirectories:YES
               followSymlinks:NO
               prefixFiles:YES];
}

- (void)dealloc {
  while ([self->pathStack count])
    [self backtrack];
  
  [self->pathStack release];
  [self->enumStack release];
  [self->currentFileName release];
  [self->currentFilePath release];
  [self->topPath release];

  [super dealloc];
}

/* accessors */

- (id<NSObject,NGFileManager>)fileManager {
  return self->fileManager;
}

/* operations */

- (NSDictionary *)directoryAttributes {
  return [self->fileManager
              fileAttributesAtPath:self->topPath
              traverseLink:self->flags.isFollowing];
}

- (NSDictionary *)fileAttributes {
  return [self->fileManager
              fileAttributesAtPath:self->currentFilePath
              traverseLink:self->flags.isFollowing];
}

- (void)skipDescendents {
  if ([self->pathStack count])
    [self backtrack];
}

/* enumerator */

- (id)nextObject {
  [self findNextFile];
  return self->currentFileName;
}

/* internals */

- (void)recurseIntoDirectory:(NSString *)_path relativeName:(NSString *)name {
  /* 
     recurses into directory `path' 
     - pushes relative path (relative to root of search) on pathStack
     - pushes system dir enumerator on enumPath 
  */
  NGDirEntry *dir;

  //NSLog(@"RECURSE INTO: %@", _path);
  
  dir = [[NGDirEntry alloc] initWithFileManager:self->fileManager path:_path];
  
  if (dir) {
    [pathStack addObject:name];
    [enumStack addObject:dir];
  }
}

- (void)backtrack {
  /*
    backtracks enumeration to the previous dir
    - pops current dir relative path from pathStack
    - pops system dir enumerator from enumStack
    - sets currentFile* to nil
  */
  //NSLog(@"BACKTRACK: %@", [self->pathStack lastObject]);
  [self->enumStack removeLastObject];
  [self->pathStack removeLastObject];
  [self->currentFileName release]; self->currentFileName = nil;
  [self->currentFilePath release]; self->currentFilePath = nil;
}

- (void)findNextFile {
  /*
    finds the next file according to the top enumerator
    - if there is a next file it is put in currentFile
    - if the current file is a directory and if isRecursive calls 
    recurseIntoDirectory:currentFile
    - if the current file is a symlink to a directory and if isRecursive 
    and isFollowing calls recurseIntoDirectory:currentFile
    - if at end of current directory pops stack and attempts to
    find the next entry in the parent
    - sets currentFile to nil if there are no more files to enumerate
  */
  NGDirEntry *dir;
  
  [self->currentFileName release]; self->currentFileName = nil;
  [self->currentFilePath release]; self->currentFilePath = nil;
    
  while ([self->pathStack count]) {
    NSString     *dname;
    NSString     *dtype;
    
    dir = [enumStack lastObject];
    
    if ((dname = [dir readdir]) == nil) {
      /* If we reached the end of this directory, go back to the upper one */
      [self backtrack];
      continue;
    }
    
    /* Skip "." and ".." directory entries */
    
    if ([dname isEqualToString:@"."]) continue;
    if ([dname isEqualToString:@".."]) continue;
    
    /* Name of current file */
    
    self->currentFileName =
      [[[pathStack lastObject]
                   stringByAppendingPathComponent:dname]
                   copy];
    
    /* Full path of current file */
    
    self->currentFilePath =
      [[self->topPath stringByAppendingPathComponent:self->currentFileName]
                      copy];
    
    dtype = [[self->fileManager
                  fileAttributesAtPath:self->currentFilePath
                  traverseLink:self->flags.isFollowing]
                  objectForKey:NSFileType];
    
    // do not follow links
    
    if (!flags.isFollowing) {
      if ([dtype isEqualToString:NSFileTypeSymbolicLink])
        /* if link then return it as link */
        break;
    }
    
    /* Follow links - check for directory */

    if ([dtype isEqualToString:NSFileTypeDirectory] &&
        self->flags.isRecursive) {
      [self recurseIntoDirectory:self->currentFilePath 
            relativeName:self->currentFileName];
    }
    
    break;
  }
}

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];

  [ms appendFormat:@"<%@[0x%p]: ", NSStringFromClass([self class]), self];

  [ms appendFormat:@" dir='%@'", self->topPath];
  [ms appendFormat:@" cname='%@'", self->currentFileName];
  [ms appendFormat:@" cpath='%@'", self->currentFilePath];
  [ms appendString:@">"];
  
  return ms;
}

@end /* NGDirectoryEnumerator */

@implementation NGDirEntry

- (id)initWithFileManager:(id<NSObject, NGFileManager>)_fm path:(NSString *)_p{
  self->fileManager = [_fm retain];
  self->path        = [_p copy];
  return self;
}

- (void)dealloc {
  [self->e    release];
  [self->path release];
  [self->fileManager release];
  [super dealloc];
}

/* operations */

- (NSString *)readdir {
  NSString *s;
  
  if (self->e == nil) {
    self->e = [[[self->fileManager directoryContentsAtPath:self->path]
                                   sortedArrayUsingSelector:
                                     @selector(compare:)]
                                   objectEnumerator];
    self->e = [self->e retain];
  }
  
  s = [self->e nextObject];
  // [self logWithFormat:@"readdir: %@", s];
  
  return s;
}

@end /* NGDirEntry */
