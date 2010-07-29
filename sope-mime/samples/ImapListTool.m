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

#include "ImapListTool.h"
#include "common.h"
#include <NGImap4/NGImap4.h>
#include <EOControl/EOControl.h>
#include <NGImap4/NGImap4FileManager.h>
#include <NGImap4/NGImap4Message.h>

@implementation ImapListTool

/* output */

- (BOOL)outputResultsAsList:(NSArray *)dirContents
  fileManager:(NGImap4FileManager *)fm part:(NSString *)_part
{
  unsigned i, count;
  NSString *path = [fm currentDirectoryPath];
  
  for (i = 0, count = [dirContents count]; i < count; i++) {
    NSString     *cpath, *apath;
    NSDictionary *info;
    NSString     *mid;
    const unsigned char *datestr;
        
    if (!self->useDataSource) {
      cpath = [dirContents objectAtIndex:i];
      apath = [path stringByAppendingPathComponent:cpath];
        
      info = [fm fileAttributesAtPath:apath
		 traverseLink:NO];
    }
    else {
      info = [dirContents objectAtIndex:i];
      cpath = [NSString stringWithFormat:@"%u", [(id)info uid]];
      apath = [path stringByAppendingPathComponent:cpath];
      //cpath = [info valueForKey:@"NSFileName"];
      //apath = [info valueForKey:@"NSFilePath"];
    }
    
    mid = [[info valueForKey:@"NSFileIdentifier"] description];
    if ([mid length] > 39) {
      mid = [mid substringToIndex:37];
      mid = [mid stringByAppendingString:@"..."];
    }
    
    /* id uid date name */
    if (_part) {
      printf("%10d ",
             [[fm contentsAtPath:[info valueForKey:@"NSFilePath"]
                  part:_part] length]);
    }

    datestr = [[[info valueForKey:NSFileModificationDate]
		 description] cString];

    printf("%-40s  %8s  %8i  %-32s %s",
	   (mid ? [mid cString] : ""),
	   [[info valueForKey:NSFileOwnerAccountName]      cString],
	   [[info valueForKey:NSFileSize] intValue],
	   (datestr ? (char *)datestr : ""),
	   [apath cString]);

    if ([[info valueForKey:NSFileType]
	  isEqualToString:NSFileTypeDirectory])
      printf("/\n");
    else
      printf("\n");
  }
  return YES;
}

- (BOOL)outputResultsAsXML:(NSArray *)_dirContents
  fileManager:(NGFileManager *)_fm 
{
  NSLog(@"XML output not implemented ...");
  return NO;
}

- (BOOL)outputResults:(NSArray *)dirContents
  fileManager:(NGImap4FileManager *)fm part:(NSString *)_part
{
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSAutoreleasePool *pool;
  NSString *out;
  BOOL result;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  out = [ud stringForKey:@"out"];
  if ([out length] == 0)
    result = YES;
  else if ([out isEqualToString:@"xml"])
    result = [self outputResultsAsXML:dirContents fileManager:fm];
  else if ([out isEqualToString:@"ls"]) 
    result = [self outputResultsAsList:dirContents fileManager:fm part:_part];
  else {
    NSLog(@"unknown output module: %@", out);
    result = NO;
  }
  [pool release];
  return result;
}

/* ops */

- (void)processFile:(NSString *)path fileManager:(NGImap4FileManager *)fm
  part:(NSString *)_part
{
  /* a file */
  NSData   *contents;
  NSString *s;

  if (_part) {
    if ((contents = [fm contentsAtPath:path part:_part]) == nil) {
      NSLog(@"could not get content of message: '%@'", path);
    }
    else {
      s = [[NSString alloc] initWithData:contents
                            encoding:[NSString defaultCStringEncoding]];
      printf("%s\n", [s cString]);
      [s release];
    }
  }
  else {
    NGImap4Message *contents;
  
    if ((contents = [fm messageAtPath:path]) == nil) {
      NSLog(@"could not get message at path: '%@'", path);
    }
    else {
#if 0
      s = [[NSString alloc] initWithData:contents
                            encoding:[NSString defaultCStringEncoding]];
      printf("%s\n", [s cString]);
      [s release];
#else
      printf("%s\n", [[contents description] cString]);
      printf("%s\n", [[[contents bodyStructure] description] cString]);
    
#endif
    }
  }
}

- (void)processFolder:(NSString *)path fileManager:(NGImap4FileManager *)fm
  part:(NSString *)_part
{
  NSAutoreleasePool *pool;
  NSTimeInterval startTime, endTime;
  unsigned int   startSize, endSize;
  NSProcessInfo  *pi = [NSProcessInfo processInfo];
  NSArray        *dirContents;
  unsigned       i;
  EODataSource   *ds;
  
  if (![fm changeCurrentDirectoryPath:path]) {
    NSLog(@"%s: could not change to directory: '%@'", path);
  }
  
  ds = self->useDataSource
    ? [(id<NGFileManagerDataSources>)fm dataSourceAtPath:path]
    : nil;
  
  /* pre fetches */
  
  for (i = 0; i < self->preloops; i++ ) {
    NSAutoreleasePool *pool;
    
    startTime = [[NSDate date] timeIntervalSince1970];
    startSize = [pi virtualMemorySize];
    
    /* fetch */
    
    pool = [[NSAutoreleasePool alloc] init];
    {
      ds = self->useDataSource
	? [(id<NGFileManagerDataSources>)fm dataSourceAtPath:path]
	: nil;
  
      dirContents = (!self->useDataSource)
	? [fm directoryContentsAtPath:path]
	: [ds fetchObjects];
    }
    [pool release];
    
    /* statistics */
    
    endSize = [pi virtualMemorySize];
    endTime = [[NSDate date] timeIntervalSince1970];
    
    if (self->stats) {
      fprintf(stderr, 
	      "parsing time [%2i]: %.3fs, "
	      "vmem-diff: %8i (%4iK,%4iM), vmem: %8i (%4iK,%4iM))\n", 
	      i, (endTime-startTime), 
	      (endSize - startSize), 
	      (endSize - startSize) / 1024, 
	      (endSize - startSize) / 1024 / 1024, 
	      endSize, endSize/1024, endSize/1024/1024);
    }
  }
  
  /* actual fetch */

  startTime = [[NSDate date] timeIntervalSince1970];
  startSize = [pi virtualMemorySize];

  pool = [[NSAutoreleasePool alloc] init];
  
  ds = self->useDataSource
    ? [(id<NGFileManagerDataSources>)fm dataSourceAtPath:path]
    : nil;
  
  dirContents = (!self->useDataSource)
    ? [fm directoryContentsAtPath:path]
    : [ds fetchObjects];
  
  dirContents = [dirContents retain];
  [pool release];
  dirContents = [dirContents autorelease];
  
  /* statistics */
      
  endSize = [pi virtualMemorySize];
  endTime = [[NSDate date] timeIntervalSince1970];
  
  if (self->stats) {
    fprintf(stderr, 
	    "parsing time: %.3fs, "
	    "vmem-diff: %8i (%4iK,%4iM), vmem: %8i (%4iK,%4iM))\n", 
	    (endTime-startTime), 
	    (endSize - startSize), 
	    (endSize - startSize) / 1024, 
	    (endSize - startSize) / 1024 / 1024, 
	    endSize, endSize/1024, endSize/1024/1024);
  }
  
  /* output */
  [self outputResults:dirContents fileManager:fm part:_part];
}

/*
  path /INBOX/1233?part=1.2
*/


- (void)processPath:(NSString *)path fileManager:(NGImap4FileManager *)fm {
  BOOL    isDir;
  NSArray *array;
  NSString *part;

  array = [path componentsSeparatedByString:@"?"];

  if ([array count] > 1) {
    path = [array objectAtIndex:0];
    part = [[[array objectAtIndex:1] componentsSeparatedByString:@"="]
                     lastObject]; 
  }
  else
    part = nil;
  
  if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
    NSLog(@"file/directory does not exist: %@", path);
    return;
  }
    
  if (isDir)
    [self processFolder:path fileManager:fm part:part];
  else
    [self processFile:path fileManager:fm part:part];
}

/* tool operation */
 
- (int)usage {
  fprintf(stderr, "usage: imapls <pathes>?part=<part>\n");
  fprintf(stderr, "usage: imapls <pathes>\n");
  fprintf(stderr, "  -url        <url>\n");
  fprintf(stderr, "  -user       <login>\n");
  fprintf(stderr, "  -password   <pwd>\n");
  fprintf(stderr, "  -host       <host>\n");
  fprintf(stderr, "  -datasource YES|NO\n");
  fprintf(stderr, "  -out        ls|xml\n");
  fprintf(stderr, "  -statistics YES|NO\n");
  fprintf(stderr, "  -preloops   <n>\n");
  return 1;
}

- (int)runWithArguments:(NSArray *)_args {
  NGImap4FileManager *fm;
  NSUserDefaults *ud;
  int            i;
  
  _args = [_args subarrayWithRange:NSMakeRange(1, [_args count] - 1)];
  if ([_args count] == 0)
    return [self usage];
  
  ud = [NSUserDefaults standardUserDefaults];
  
  self->useDataSource = [ud boolForKey:@"datasource"];
  self->stats         = [ud boolForKey:@"statistics"];
  self->preloops      = [ud integerForKey:@"preloops"];
  
  if ((fm = [self fileManager]) == nil) {
    NSLog(@"could not open IMAP connection (got no filemanager)");
    return 2;
  }
  
#if 1
  NSLog(@"IMAP: %@", fm);
#endif
  
  for (i = 0; i < [_args count]; i++) {
    [self processPath:[_args objectAtIndex:i] fileManager:fm];
  }
  
  return 0;
}

@end /* ImapListTool */
