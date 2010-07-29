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

#include <SoObjects/SoApplication.h>

/*
  An executable which can run a SoOFS based SOPE application. When started,
  it takes the current-directory path for constructing the SoOFS root folder
  of the SOPE application.
  It also reads a file ".sope.plist" in the root-path to load site-local
  configuration settings.
  
  TODO:
  - load defaults from root-folder
    DONE [".sope.plist" is loaded and registered]
  - load products from root-folder
  - load authenticator from root-folder
*/

@class NSString, NSFileManager;

@interface SOPE : SoApplication
{
  NSFileManager *fm;
  NSString *rootPath;
}

@end

#include <SoObjects/SoClassSecurityInfo.h>
#include "OFSFolder.h"
#include "OFSFactoryContext.h"
#include "common.h"

NSString *SoRootFolder = @"SoRootFolder";

@implementation SOPE

static BOOL debugRootObject = NO;

+ (void)initialize {
  /* 
     Since we are a tool, we have no bundle and need to declare security info
     manually ...
  */
  SoClassSecurityInfo *si = [self soClassSecurityInfo];
  [si declareObjectPublic];
  [si setDefaultAccess:@"allow"];
}

- (void)loadLocalDefaults:(NSString *)_path {
  NSDictionary *plist;

  if ((plist = [[NSDictionary alloc] initWithContentsOfFile:_path]) == nil) {
    [self logWithFormat:@"could not read SOPE config: %@", _path];
    return;
  }
  /* 
     TODO: we need a separate domain for this, this stuff doesn't make sense
           at all ...
  */
  [[NSUserDefaults standardUserDefaults] registerDefaults:plist];
  [self logWithFormat:@"registered site defaults: %@", _path];
  [plist release];
}

- (BOOL)_bootstrap {
  // TODO: create some bootstrap code to create initial user database,
  //       defaults, control-panel, etc
  return YES;
}

- (BOOL)_setupRoot {
  BOOL isDir;

  /* setup root path */
  
  if (self->fm == nil) {
    [self logWithFormat:@"missing SOPE storage filemanager."];
    return NO;
  }
  if ([self->rootPath length] == 0) {
    [self logWithFormat:@"missing SOPE storage root-path."];
    return NO;
  }

  if (![self->fm fileExistsAtPath:self->rootPath isDirectory:&isDir]) {
    [self logWithFormat:@"SOPE storage root-path does not exist: %@", 
                        self->rootPath];
    return NO;
  }
  if (!isDir) {
    [self logWithFormat:@"SOPE storage root-path is not a directory: %@", 
            self->rootPath];
    return NO;
  }
  
  /* bootstrap root if necessary */
  
  if (![self _bootstrap])
    return NO;
  
  /* configure */
  
  [self logWithFormat:@"starting SOPE on OFS root: %@", self->rootPath];

  return YES;
}

- (void)registerUserDefaults {
  NSString *p;

  [super registerUserDefaults];
  p = [self->rootPath stringByAppendingPathComponent:@".sope.plist"];
  if ([self->fm isReadableFileAtPath:p])
    [self loadLocalDefaults:p];
}

- (id)init {
  // TODO: make root-path/fm configurable ?
  self->fm       = [[NSFileManager defaultManager] retain];
  self->rootPath = [[self->fm currentDirectoryPath] copy];

  if (![self _setupRoot]) {
    [self release];
    return nil;
  }
  /* Q: Why is [super init] done so goddamn late?
     A: In the process of setting up or root directory, we're also registering
        defaults. These defaults are important for the inits done by super,
        so we need to do this in advance.
  */
  [super init];
  return self;
}

- (void)dealloc {
  [self->fm       release];
  [self->rootPath release];
  [super dealloc];
}

/* accessors */

- (id)fileManager {
  return self->fm;
}
- (NSString *)rootPath {
  return self->rootPath;
}

/* define the root SoObject */

- (id)rootObjectInContext:(id)_ctx {
  OFSFactoryContext *ctx;
  OFSFolder *root;

  if (debugRootObject) [self logWithFormat:@"queried root object ..."];
  
  if ((root = [_ctx valueForKey:SoRootFolder]) != nil) {
    if (debugRootObject) 
      [self logWithFormat:@"  using cached root object: %@", root];
    return root;
  }
  
  ctx = [OFSFactoryContext contextWithFileManager:[self fileManager]
			   storagePath:[self rootPath]];
  
  root = [[[OFSFolder alloc] init] autorelease];
  [root takeStorageInfoFromContext:ctx];
  [root awakeFromFetchInContext:ctx];
  [_ctx takeValue:root forKey:SoRootFolder];
  if (debugRootObject) 
    [self logWithFormat:@"  created new root object: %@", root];
  return root;
}

/* security */

- (id)authenticatorInContext:(id)_ctx {
  id root;
  id auth;
  
  root = [self rootObjectInContext:_ctx];
  if ((auth = [root authenticatorInContext:_ctx]))
    return auth;
  
  return [super authenticatorInContext:_ctx];
}

/* SMI */

- (NSArray *)manageMenuChildNames {
  NSMutableArray *ma;
  id root;
  
  ma = [NSMutableArray arrayWithCapacity:16];
  [ma addObject:@"ControlPanel"];
  
  root = [self rootObjectInContext:[self context]];
  if (root != nil && (root != self)) 
    [ma addObjectsFromArray:[root toOneRelationshipKeys]];
  
  return ma;
}

/* MacOSX support */

- (id)handleQueryWithUnboundKey:(NSString *)key {
  /* KVC on MacOSX throws an exception when an unbound key is queried ... */
  return nil;
}

@end /* SOPE */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSEnumerator      *args;
  NSString          *arg;
  id                self;

  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  self = pool;
  args = [[[NSProcessInfo processInfo] arguments] objectEnumerator];
  [args nextObject];

  while ((arg = [args nextObject]) != nil) {
    if ([arg isEqualToString:@"--bundle"]) {
      NSString *path = [args nextObject];
      if (path != nil) {
        NSBundle *bundle;
        bundle = [NSBundle bundleWithPath:path];
        if (!bundle) {
          [self errorWithFormat:@"No loadable bundle at path: '%@'!", path];
          exit(1);
        }
        [bundle load];
      }
      else {
        [self errorWithFormat:@"Missing path for --bundle argument!"];
        exit(1);
      }
    }
#if 0
    else {
      [self errorWithFormat:@"Unknown argument: '%@', skipping.", arg];
    }
#endif
  }

  WOWatchDogApplicationMain(@"SOPE", argc, (void*)argv);
  
  [pool release];
  return 0;
}
