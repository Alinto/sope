/*
  Copyright (C) 2005 SKYRIX Software AG
  Copyright (C) 2005 by Scott Stevenson
  
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

#include "WOCoreDataApplication.h"

@interface CoreDataBlog : WOCoreDataApplication
{
}

@end

#include "common.h"

@implementation CoreDataBlog

- (id)init {
  if ((self = [super init]) != nil) {
    [self logWithFormat:@"Store coordinator: %@", 
	  [self defaultPersistentStoreType]];
  }
  return self;
}

- (NSString *)applicationSupportFolder {
  // TODO: simplify that
  unsigned char path[1024];
  NSString *p;
  FSRef foundRef;
  OSErr err;
  
  err = FSFindFolder(kUserDomain, kApplicationSupportFolderType, 
		     kDontCreateFolder, &foundRef);
  if (err != noErr) {
    [self errorWithFormat:@"Can't find application support folder."];
    return nil;
  }
  
  FSRefMakePath(&foundRef, path, sizeof(path));
  p = [NSString stringWithUTF8String:(char *)path]; // TODO: is UTF-8 ok?
  p = [p stringByAppendingPathComponent:@"BlogDemo"];
  return p;
}

- (NSURL *)defaultPersistentStoreURL {
  NSString *s;
  
  s = @"BlogDemo.xml";
  s = [[self applicationSupportFolder] stringByAppendingPathComponent:s];
  return [NSURL fileURLWithPath:s];
}

@end /* CoreDataBlog */


/* starting the app */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  WOApplicationMain(@"CoreDataBlog", argc, (void*)argv);

  [pool release];
  return 0;
}
