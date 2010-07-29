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

#import <Foundation/Foundation.h>
#import <EOControl/EOControl.h>
#include <NGExtensions/NSFileManager+Extensions.h>
#include <NGExtensions/NGFileFolderInfoDataSource.h>
#include <NGExtensions/NGDirectoryEnumerator.h>

@interface TestDirEnumTool : NSObject
@end

@implementation TestDirEnumTool

- (void)runWithArguments:(NSArray *)args {
  NSFileManager *fm;
  NGDirectoryEnumerator *e;
  NSString      *cpath;

  fm = [NSFileManager defaultManager];
  
  e = [[NGDirectoryEnumerator alloc] initWithFileManager:fm
                                     directoryPath:[args objectAtIndex:1]];

  NSLog(@"enum: %@", e);
  
  while ((cpath = [e nextObject])) {
#if 1
    printf("%s\n", [cpath cString]);
#else
    NSDictionary *record;

    record = [e fileAttributes];
    {
      /* id uid gid date name */
      NSString *fileId;
      NSString *owner;
      int      gid;
      unsigned size;
      NSString *modDate;
      NSString *fname;
      NSString *ftype;
        
      fileId  = [[record objectForKey:NSFileIdentifier] description];
      owner   = [record  objectForKey:NSFileOwnerAccountName];
      gid     = [[record objectForKey:NSFileGroupOwnerAccountNumber] intValue];
      size    = [[record  objectForKey:NSFileSize] intValue];
      modDate = [[record objectForKey:NSFileModificationDate] description];
      fname   = [record  objectForKey:NSFileName];
      ftype   = [record  objectForKey:NSFileType];
      
      if ([ftype isEqualToString:NSFileTypeDirectory])
        fname = [fname stringByAppendingString:@"/"];
      else if ([ftype isEqualToString:NSFileTypeSocket])
        fname = [fname stringByAppendingString:@"="];
      else if ([ftype isEqualToString:NSFileTypeSymbolicLink])
        fname = [fname stringByAppendingString:@"@"];
        
      //NSLog(@"record: %@", record);
        
      printf("%8s  %8s  %8i  %8i  %8s  %s\n",
             [fileId cString],
             [owner  cString],
             gid,
             size,
             [modDate cString],
             [fname cString]);
    }
#endif
  }
}

@end /* TestDirEnumTool */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSArray *args;
  id tool;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  args = [[NSProcessInfo processInfo] arguments];
  if ([args count] < 1) {
    NSLog(@"usage: %@ dir", [args objectAtIndex:0]);
    exit(1);
  }
  else if ([args count] == 1)
    args = [args arrayByAddingObject:@"."];
  
  tool = [[TestDirEnumTool alloc] init];
  [tool runWithArguments:args];
  
  exit(0);
  return 0;
}
