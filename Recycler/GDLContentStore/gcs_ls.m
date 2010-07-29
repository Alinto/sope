/*
  Copyright (C) 2004-2005 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

#import <Foundation/NSObject.h>

@class NSUserDefaults, NSArray;
@class GCSFolderManager;

@interface Tool : NSObject
{
  NSUserDefaults   *ud;
  GCSFolderManager *folderManager;
}

+ (int)runWithArgs:(NSArray *)_args;
- (int)run;

@end

#include <GDLContentStore/GCSFolder.h>
#include <GDLContentStore/GCSFolderManager.h>
#include "common.h"

@implementation Tool

- (id)init {
  if ((self = [super init])) {
    self->ud            = [[NSUserDefaults standardUserDefaults]   retain];
    self->folderManager = [[GCSFolderManager defaultFolderManager] retain];
  }
  return self;
}
- (void)dealloc {
  [self->ud            release];
  [self->folderManager release];
  [super dealloc];
}

/* operation */

- (int)runOnPath:(NSString *)_path {
  NSArray   *subfolders;
  unsigned  i, count;
  GCSFolder *folder;
  
  [self logWithFormat:@"ls path: '%@'", _path];
  
#if 0 // we do not necessarily need the whole hierarchy
  if (![self->folderManager folderExistsAtPath:_path])
    [self logWithFormat:@"folder does not exist: '%@'", _path];
#endif
  
  subfolders = [self->folderManager
		    listSubFoldersAtPath:_path
		    recursive:[ud boolForKey:@"r"]];
  if (subfolders == nil) {
    [self logWithFormat:@"cannot list folder: '%@'", _path];
    return 1;
  }
  
  for (i = 0, count = [subfolders count]; i < count; i++) {
    printf("%s\n", [[subfolders objectAtIndex:i] cString]);
  }

  folder = [self->folderManager folderAtPath:_path];
  
  if ([folder isNotNull]) {
    NSLog(@"folder: %@", folder);
    
    NSLog(@"  can%s connect store: %@", [folder canConnectStore] ? "" : "not",
	  [[folder location] absoluteString]);
    NSLog(@"  can%s connect quick: %@", [folder canConnectQuick] ? "" : "not",
	  [[folder quickLocation] absoluteString]);
  }
  else {
    NSLog(@"ERROR: could not create folder object for path: '%@'", _path);
  }
  
  return 0;
}

- (int)run {
  NSEnumerator *e;
  NSString *path;
  
  [self logWithFormat:@"manager: %@", self->folderManager];

  if (![self->folderManager canConnect]) {
    [self logWithFormat:@"cannot connect folder-info database!"];
    return 1;
  }
  
  e = [[[NSProcessInfo processInfo] argumentsWithoutDefaults] 
                       objectEnumerator];
  [e nextObject]; // skip tool name
  
  while ((path = [e nextObject]) != nil)
    [self runOnPath:path];
  
  return 0;
}
+ (int)runWithArgs:(NSArray *)_args {
  return [(Tool *)[[[self alloc] init] autorelease] run];
}

@end /* Tool */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  int rc;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY  
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  rc = [Tool runWithArgs:
               [[NSProcessInfo processInfo] argumentsWithoutDefaults]];
  
  [pool release];
  return rc;
}
