/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include <NGObjWeb/WOApplication.h>
#include "WOxTemplateBuilder.h"
#include <NGObjWeb/WOxElemBuilder.h>
#include "common.h"

@implementation WOApplication(BuilderStack)

- (void)scanForBuilderBundlesInDirectory:(NSString *)_path {
  NGBundleManager *bm;
  NSFileManager *fm;
  NSEnumerator  *pathes;
  NSString      *lPath;

  bm = [NGBundleManager defaultBundleManager];
  
  fm = [NSFileManager defaultManager];
  pathes = [[fm directoryContentsAtPath:_path] objectEnumerator];
  while ((lPath = [pathes nextObject])) {
    NSBundle *bundle;
    BOOL isDir;
    
    lPath = [_path stringByAppendingPathComponent:lPath];
    
    if (![fm fileExistsAtPath:lPath isDirectory:&isDir])
      continue;
    if (!isDir)
      continue;
    
    if ((bundle = [bm bundleWithPath:lPath]) == nil) {
      [self warnWithFormat:@"could not get bundle for path: '%@'",
              lPath];
      continue;
    }
    
    if (![bundle load]) {
      [self warnWithFormat:@"could not load bundle: '%@'", lPath];
      continue;
    }
    
    [self debugWithFormat:@"loaded elem builder bundle: %@",
	    [lPath lastPathComponent]];
  }
}

- (void)loadBuilderBundles {
  // TODO: DUP to SoProductRegistry.m
  NSFileManager *fm;
  NSProcessInfo *pi;
  NSArray       *pathes;
  NSString      *relPath;
  unsigned      i;
  
  /* scan library pathes */
  
  fm = [NSFileManager defaultManager];
  pi = [NSProcessInfo processInfo];
#if ! GNUSTEP_BASE_LIBRARY  
#if COCOA_Foundation_LIBRARY
  /* 
     TODO: (like COMPILE_FOR_GNUSTEP)
     This should actually check whether we are compiling in the
     GNUstep environment since this modifies the location of bundles.
  */
  pathes = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
					       NSAllDomainsMask,
					       YES);
#else
  pathes = [[pi environment] objectForKey:@"GNUSTEP_PATHPREFIX_LIST"];
  if (pathes == nil)
    pathes = [[pi environment] objectForKey:@"GNUSTEP_PATHLIST"];
  
  pathes = [[pathes stringValue] componentsSeparatedByString:@":"];
#endif
  
  if ([pathes count] == 0) {
    [self debugWithFormat:@"found no builder bundle pathes."];
    return;
  }
  
  [self debugWithFormat:@"scanning for builder bundles ..."];
  
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
  relPath = @"";
#else
  relPath = @"Library/";
#endif
  relPath = [NSString stringWithFormat:@"%@WOxElemBuilders-%i.%i/", relPath,
                        SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION];
  for (i = 0; i < [pathes count]; i++) {
    NSString *lPath;
    BOOL     isDir;
    
    lPath = [[pathes objectAtIndex:i] stringByAppendingPathComponent:relPath];
    if (![fm fileExistsAtPath:lPath isDirectory:&isDir])
      continue;
    if (!isDir)
      continue;
    
    [self debugWithFormat:@"  directory %@", lPath];
    [self scanForBuilderBundlesInDirectory:lPath];
  }
#else
 NSEnumerator *libraryPaths;
  NSString *directory;
 NSMutableArray *tmppathes;

  libraryPaths = [NSStandardLibraryPaths() objectEnumerator];
  tmppathes = [[NSMutableArray alloc] init];
  while ((directory = [libraryPaths nextObject]))
    [tmppathes addObject: [directory stringByAppendingPathComponent: 
		[NSString stringWithFormat:@"WOxElemBuilders-%i.%i/", 
			SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION]]];
  pathes = [tmppathes mutableCopy];
  for (i = 0; i < [pathes count]; i++) {
    NSString *lPath;
    BOOL     isDir;
    
    lPath = [pathes objectAtIndex:i];
    if (![fm fileExistsAtPath:lPath isDirectory:&isDir])
      continue;
    if (!isDir)
      continue;
    
    [self debugWithFormat:@"  directory %@", lPath];
    [self scanForBuilderBundlesInDirectory:lPath];
  }
  [tmppathes release];
#endif
  
  /* look into FHS pathes */
  
  relPath = [NSString stringWithFormat:
#ifdef CGS_LIBDIR_NAME
	[CGS_LIBDIR_NAME stringByAppendingString:@"/sope-%i.%i/wox-builders/"],
#else
	@"lib/sope-%i.%i/wox-builders/",
#endif
        SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION];
  pathes = [NSArray arrayWithObjects:
#ifdef FHS_INSTALL_ROOT
		      [FHS_INSTALL_ROOT stringByAppendingString:relPath],
#endif
		      [@"/usr/local/" stringByAppendingString:relPath],
		      [@"/usr/"       stringByAppendingString:relPath],
		    nil];
  for (i = 0; i < [pathes count]; i++) {
    NSString *lPath;
    BOOL     isDir;
    
    lPath = [pathes objectAtIndex:i];
    if (![fm fileExistsAtPath:lPath isDirectory:&isDir])
      continue;
    if (!isDir)
      continue;
    
    [self debugWithFormat:@"  directory %@", lPath];
    [self scanForBuilderBundlesInDirectory:lPath];
  }
  
  /* report result */
  
  [self debugWithFormat:@"finished scan for builders."];
}

- (WOxElemBuilder *)builderForDocument:(id<DOMDocument>)_document {
  static WOxElemBuilder *builder    = nil;
  static NSArray        *defClasses = nil;
  NSUserDefaults *ud;
  NSArray *classes = nil;
  NSArray *infos;
  
  if (builder != nil)
    return builder;
    
  ud = [NSUserDefaults standardUserDefaults];
  if (defClasses == nil)
    defClasses = [[ud arrayForKey:@"WOxBuilderClasses"] copy];
  
  /* ensure that bundles are loaded */
  [self loadBuilderBundles];
  
  infos = [[NGBundleManager defaultBundleManager]
                            providedResourcesOfType:@"WOxElemBuilder"];
  if ([infos count] > 0) {
    classes = [NSMutableArray arrayWithCapacity:24];
    [(id)classes addObjectsFromArray:[infos valueForKey:@"name"]];
    [(id)classes addObjectsFromArray:defClasses];
  }
  else
    classes = defClasses;
  
  if ([ud boolForKey:@"WOxLogBuilderQueue"]) {
    NSEnumerator *e;
    NSString *b;
      
    if ([classes count] > 0) {
      [self debugWithFormat:@"builder stack:"];
      e = [classes objectEnumerator];
      while ((b = [e nextObject]))
	[self logWithFormat:@"  %@", b];
    }
    else {
      [self debugWithFormat:@"empty wox-element builder stack !"];
    }
  }
  
  builder = [[WOxElemBuilder createBuilderQueue:classes] retain];
  return builder;
}

@end /* WOApplication(BuilderStack) */
