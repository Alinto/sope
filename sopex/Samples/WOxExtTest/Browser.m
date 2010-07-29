/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id: Browser.m 1 2004-08-20 11:17:52Z znek $

#import <NGObjWeb/WOComponent.h>

@class NSFileManager, NSArray, NSString;

@interface Browser : WOComponent < NSCoding >
{
  NSFileManager *fm;

  NSArray  *currentPath;
  NSString *currentPathString;
}
@end

#include "common.h"

@implementation Browser

- (id)init {
  if ((self = [super init])) {
    self->fm = [[NSFileManager defaultManager] retain];

    //    [self setCurrentPath:nil];
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->currentPathString);
  RELEASE(self->currentPath);
  RELEASE(self->fm);
  [super dealloc];
}

- (void)setCurrentPath:(NSArray *)_p {
  if (_p == nil)
    _p = [NSArray array];
  
  ASSIGN(self->currentPath, _p);
  
  RELEASE(self->currentPathString); self->currentPathString = nil;
  self->currentPathString = [[_p componentsJoinedByString:@"/"] copy];
}
- (NSArray *)currentPath {
  return self->currentPath;
}
- (NSString *)currentPathString {
  return self->currentPathString;
}

- (NSFileManager *)fileManager {
  return self->fm;
}

- (NSArray *)rootFolder {
  return [[self fileManager] directoryContentsAtPath:@"."];
}

- (NSString *)bgColor {
  NSString *cf;

  cf = [self valueForKey:@"currentFolder"];
  if ([cf isEqualToString:[self currentPathString]])
    return @"AAAAAA";
  if ([cf hasPrefix:[self currentPathString]])
    return @"#FAE8B8";

  return @"white"; // default bg
}

- (BOOL)currentIsDirectory {
  BOOL isDir;

  if (![self->fm fileExistsAtPath:[self currentPathString] isDirectory:&isDir])
    return NO;
  
  return isDir;
}

- (NSString *)currentImage {
  if ([self currentIsDirectory]) {
    /* directory */
    NSString *cf;
    
    cf = [self valueForKey:@"currentFolder"];

    if ([cf hasPrefix:[self currentPathString]])
      return @"folder_opened.gif";
    else
      return @"folder_closed.gif";
  }
  return nil;
}

- (NSArray *)dirContents {
  if (![self currentIsDirectory])
    return nil;
  
  return [[self fileManager] directoryContentsAtPath:[self currentPathString]];
}

- (id)clicked {
  NSLog(@"clicked: path is %@", [self currentPathString]);
  NSLog(@"clicked: item is %@", [self valueForKey:@"item"]);
  [self takeValue:[self currentPathString] forKey:@"currentFolder"];
  return self;
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];

  [_coder encodeObject:self->currentPath];
  [_coder encodeObject:self->currentPathString];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder])) {
    self->fm   = [[NSFileManager defaultManager] retain];

    self->currentPath       = [[_coder decodeObject] retain];
    self->currentPathString = [[_coder decodeObject] retain];
  }
  return self;
}

@end /* TableView */
