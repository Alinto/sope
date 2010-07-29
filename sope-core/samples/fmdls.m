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
#include <NGExtensions/NGExtensions.h>

static void printDirRecord(NSString *path, NSDictionary *record) {
  /* id uid gid date name */
  NSString *fileId;
  NSString *owner;
  int      gid;
  unsigned size;
  NSString *modDate;
  NSString *fname;
  NSString *ftype;
        
  fileId  = [[record objectForKey:@"NSFileIdentifier"] description];
  owner   = [record  objectForKey:NSFileOwnerAccountName];
  gid     = [[record objectForKey:@"NSFileGroupOwnerAccountNumber"] intValue];
  size    = [[record  objectForKey:NSFileSize] intValue];
  modDate = [[record objectForKey:NSFileModificationDate] description];
  fname   = [record  objectForKey:@"NSFileName"];
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

static void runOnDirPath(NSString *path) {
  NSFileManager *fm;
  EODataSource *ds;
  NSEnumerator *records;
  NSDictionary *record;
  NSArray      *sortOrderings;
  EOQualifier  *qualifier;
  id tmp;
  
  fm = [NSFileManager defaultManager];

  if ((ds = [fm dataSourceAtPath:path]) == nil) {
    NSLog(@"could not get datasource for path: '%@'", path);
    return;
  }

  /* build fetch specification */
      
  tmp = [[NSUserDefaults standardUserDefaults] stringForKey:@"qualifier"];
  if ([tmp length] > 0) {
    qualifier = [EOQualifier qualifierWithQualifierFormat:tmp];
    if (qualifier == nil)
      NSLog(@"could not parse qualifier: %@", tmp);
  }
  else
    qualifier = nil;

  tmp = [EOSortOrdering sortOrderingWithKey:@"NSFileName"
                        selector:EOCompareAscending];
  sortOrderings = [NSArray arrayWithObject:tmp];
      
  if ((qualifier != nil) || (sortOrderings != nil)) {
    EOFetchSpecification *fs;
        
    fs = [[EOFetchSpecification alloc] init];
    [fs setQualifier:qualifier];
    [fs setSortOrderings:sortOrderings];

    [(id)ds setFetchSpecification:fs];
    [fs release]; fs = nil;
  }
      
  /* perform fetch */
      
  records = [[ds fetchObjects] objectEnumerator];
      
  /* print out */

  while ((record = [records nextObject]))
    printDirRecord(path, record);
}

static void runOnPath(NSString *path) {
  NSFileManager *fm;
  BOOL     isDir;

  fm = [NSFileManager defaultManager];
  
  if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
    NSLog(@"file/directory does not exist: %@", path);
    return;
  }
  
  if (isDir)
    runOnDirPath(path);
  else
    /* a file */;
}

static void runit(NSArray *args) {
  int i;
  
  for (i = 1; i < [args count]; i++) {
    NSString *path;
    
    path = [args objectAtIndex:i];
    
    if ([path hasPrefix:@"-"]) { // TODO: there is a NSProcessInfo ext for that
      i++;
      continue;
    }
    
    runOnPath(path);
  }
}

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSArray       *args;
  
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  pool = [[NSAutoreleasePool alloc] init];
  
  args = [[NSProcessInfo processInfo] arguments];
  if ([args count] < 1) {
    NSLog(@"usage: %@ <files>", [args objectAtIndex:0]);
    exit(1);
  }
  else if ([args count] == 1)
    args = [args arrayByAddingObject:@"."];

  runit(args);
  [pool release];
  
  exit(0);
  return 0;
}
