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

#include <NGObjWeb/WOCoreApplication.h>
#include "common.h"

@implementation WOCoreApplication(Bundle)

+ (BOOL)didLoadDaemonBundle:(NSBundle *)_bundle {
  return YES;
}

+ (int)loadApplicationBundle:(NSString *)_bundleName
  domainPath:(NSString *)_domain
{
  // TODO: is this actually used somewhere?
  NSFileManager  *fm;
  NSString       *bp;
  NSBundle       *bundle;
  NSMutableArray *chkPathes;
  NSEnumerator   *e;

  fm = [NSFileManager defaultManager];
  
  if ([[_bundleName pathExtension] length] == 0)
    _bundleName = [_bundleName stringByAppendingPathExtension:@"sxa"];
  
  chkPathes = [NSMutableArray arrayWithCapacity:16];
  
  if ([_bundleName isAbsolutePath]) {
    [chkPathes addObject:_bundleName];
  }
  else {
    NSDictionary *env;
    
    env = [[NSProcessInfo processInfo] environment];
    
    [chkPathes addObject:@"."];
#if COCOA_FRAMEWORK
    bp = [env objectForKey:@"HOME"];
    bp = [bp stringByAppendingPathComponent:@"Library"];
    bp = [bp stringByAppendingPathComponent:_domain];
    [chkPathes addObject:bp];
    bp = @"/Library";
    bp = [bp stringByAppendingPathComponent:_domain];
    [chkPathes addObject:bp];
    bp = @"/System/Library";
    bp = [bp stringByAppendingPathComponent:_domain];
    [chkPathes addObject:bp];
#elif GNUSTEP_BASE_LIBRARY
    NSEnumerator *libraryPaths;
    NSString *directory;

    libraryPaths = [NSStandardLibraryPaths() objectEnumerator];
    while ((directory = [libraryPaths nextObject])) {
      directory = [directory stringByAppendingPathComponent:_domain];
      if ([chkPathes containsObject:directory]) continue;
      [chkPathes addObject:directory];

    }
#else
    NSEnumerator *e;
    id tmp;
    if ((tmp = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"]) == nil)
      tmp = [env objectForKey:@"GNUSTEP_PATHLIST"];
    tmp = [tmp componentsSeparatedByString:@":"];
    e = [tmp objectEnumerator];
    while ((tmp = [e nextObject])) {
      bp = [tmp stringByAppendingPathComponent:@"Library"];
      bp = [bp stringByAppendingPathComponent:_domain];
      if ([chkPathes containsObject:bp]) continue;
      
      [chkPathes addObject:bp];
    }
#endif
  }
  
  e = [chkPathes objectEnumerator];
  while ((bp = [e nextObject])) {
    BOOL isDir;
    
    bp = [bp stringByAppendingPathComponent:_bundleName];
    if (![fm fileExistsAtPath:bp isDirectory:&isDir]) continue;
    if (!isDir) continue;
    break; /* found */
  }
  
  if ([bp length] == 0) {
    [self debugWithFormat:
            @"%s: did not find the bundle '%@' in search list %@",
            __PRETTY_FUNCTION__, _bundleName, chkPathes];
    return 1;
  }
  
  if ((bundle = [NGBundle bundleWithPath:bp]) == nil) {
    [self debugWithFormat:@"%s: did not find %@ at %@ ...",
            __PRETTY_FUNCTION__, _bundleName, bp];
    //return 1;
  }
  
  if (![bundle load]) {
    [self errorWithFormat:@"%s: could not load %@ %@ (path=%@)...",
                             __PRETTY_FUNCTION__, _bundleName, bundle, bp];
    //return 2;
  }

  if (![self didLoadDaemonBundle:bundle]) {
    //return 3;
  }
  
  [self debugWithFormat:@"hosting bundle: %@", [bundle bundleName]];
  
  return 0;
}

+ (int)runApplicationBundle:(NSString *)_bundleName
  domainPath:(NSString *)_p
  arguments:(void *)_argv count:(int)_argc
{
  NSAutoreleasePool *pool = nil;
  int               rc;
  NSString          *appClassName, *bundleName;
  
  pool = [[NSAutoreleasePool alloc] init];
  
#if LIB_FOUNDATION_LIBRARY
  {
    extern char **environ;
    [NSProcessInfo initializeWithArguments:_argv
                   count:_argc
                   environment:environ];
  }
#endif
  
  if ((rc = [self loadApplicationBundle:_bundleName
                  domainPath:_p]) != 0)
    exit(rc);
  
  bundleName = [_bundleName lastPathComponent];
  bundleName = [bundleName stringByDeletingPathExtension];
  
  appClassName = [bundleName stringByAppendingString:@"Application"];
  
  rc = WOWatchDogApplicationMain(appClassName, _argc, _argv);
  
  RELEASE(pool); pool = nil;

  return rc;
}

+ (int)runApplicationBundle:(NSString *)_bundleName
  arguments:(void *)_args count:(int)_argc
{
  return [self runApplicationBundle:_bundleName
               domainPath:@"SxApps"
               arguments:_args count:_argc];
}

@end /* WOApplication */
