/*
  Copyright (C) 2006 Helge Hess

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

#include "SoProductLoader.h"
#include "SoProductRegistry.h"
#include "common.h"

@implementation SoProductLoader

- (id)initWithAppName:(NSString *)_appName fhsName:(NSString *)_fhsName
  majorVersion:(unsigned int)_mav minorVersion:(unsigned int)_miv
{
  if ((self = [super init]) != nil) {
    if (![_appName isNotEmpty] && ![_fhsName isNotEmpty]) {
      [self release];
      return nil;
    }
    
    if ([_appName isNotEmpty]) {
      self->productDirectoryName =
	[[NSString alloc] initWithFormat:@"%@-%i.%i", _appName, _mav, _miv];
    }
    if ([_fhsName isNotEmpty]) {
      self->fhsDirectoryName =
	[[NSString alloc] initWithFormat:@"%@-%i.%i", _fhsName, _mav, _miv];
    }
  }
  return self;
}

- (void)dealloc {
  [self->productDirectoryName release];
  [self->fhsDirectoryName     release];
  [self->searchPathes         release];
  [super dealloc];
}

/* loading */

- (void)_addCocoaSearchPathesToArray:(NSMutableArray *)ma {
  id tmp;

  tmp = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,
                                            NSAllDomainsMask,
                                            YES);
  if ([tmp count] > 0) {
    NSEnumerator *e;
      
    e = [tmp objectEnumerator];
    while ((tmp = [e nextObject]) != nil) {
      tmp = [tmp stringByAppendingPathComponent:self->productDirectoryName];
      if (![ma containsObject:tmp])
        [ma addObject:tmp];
    }
  }
}

- (void)_addGNUstepSearchPathesToArray:(NSMutableArray *)ma {
#if GNUSTEP_BASE_LIBRARY
  NSEnumerator *libraryPaths;
  NSString *directory;

  libraryPaths = [NSStandardLibraryPaths() objectEnumerator];
  while ((directory = [libraryPaths nextObject]))
    [ma addObject: [directory stringByAppendingPathComponent: self->productDirectoryName]];
#else
  NSDictionary *env;
  id tmp;
  
  env = [[NSProcessInfo processInfo] environment];
  if ((tmp = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"]) == nil)
    tmp = [env objectForKey:@"GNUSTEP_PATHLIST"];
  
  tmp = [tmp componentsSeparatedByString:@":"];
  if ([tmp count] > 0) {
    NSEnumerator *e;
      
    e = [tmp objectEnumerator];
    while ((tmp = [e nextObject]) != nil) {
      tmp = [tmp stringByAppendingPathComponent:@"Library"];
      tmp = [tmp stringByAppendingPathComponent:self->productDirectoryName];
      if (![ma containsObject:tmp])
        [ma addObject:tmp];
    }
  }
  else {
    [self logWithFormat:@"%s: empty library search path !", 
	  __PRETTY_FUNCTION__];
  }
#endif
}

- (void)_addFHSPathesToArray:(NSMutableArray *)ma {
  NSString *s;
  
  s = self->fhsDirectoryName;

#if CONFIGURE_64BIT
#ifdef FHS_INSTALL_ROOT
  [ma addObject:[[FHS_INSTALL_ROOT stringByAppendingString:@"/lib64/"] 
		                   stringByAppendingString:s]];
#endif
  [ma addObject:[@"/usr/local/lib64/" stringByAppendingString:s]];
  [ma addObject:[@"/usr/lib64/"       stringByAppendingString:s]];
#else
#ifdef FHS_INSTALL_ROOT
  [ma addObject:[[FHS_INSTALL_ROOT stringByAppendingString:@"/lib/"] 
		                   stringByAppendingString:s]];
#endif
  [ma addObject:[@"/usr/local/lib/" stringByAppendingString:s]];
  [ma addObject:[@"/usr/lib/"       stringByAppendingString:s]];
#endif
}

- (NSArray *)productSearchPathes {
  NSMutableArray *ma;
  
  if (self->searchPathes != nil)
    return self->searchPathes;

  ma  = [NSMutableArray arrayWithCapacity:6];
  
  if ([self->productDirectoryName isNotEmpty]) {
    BOOL hasGNUstepEnv;
    
    hasGNUstepEnv = [[[[NSProcessInfo processInfo] environment]
  		     objectForKey:@"GNUSTEP_USER_ROOT"] isNotEmpty];
    
    if (hasGNUstepEnv)
      [self _addGNUstepSearchPathesToArray:ma];
#if COCOA_Foundation_LIBRARY
    else
      [self _addCocoaSearchPathesToArray:ma];
#endif
  }
  
  if ([self->fhsDirectoryName isNotEmpty])
    [self _addFHSPathesToArray:ma];
  
  self->searchPathes = [ma copy];
  
  if (![self->searchPathes isNotEmpty]) {
    [self logWithFormat:@"no search pathes were found !", 
	  __PRETTY_FUNCTION__];
  }
  
  return self->searchPathes;
}

- (void)loadProducts {
  SoProductRegistry *registry = nil;
  NSFileManager *fm;
  NSEnumerator  *pathes;
  NSString      *lpath;
  
  registry = [SoProductRegistry sharedProductRegistry];
  fm       = [NSFileManager defaultManager];
  
  pathes = [[self productSearchPathes] objectEnumerator];
  while ((lpath = [pathes nextObject]) != nil) {
    NSEnumerator *productNames;
    NSString *productName;
    
    [self logWithFormat:@"scanning for products in: %@", lpath];

    productNames = [[fm directoryContentsAtPath:lpath] objectEnumerator];
    
    while ((productName = [productNames nextObject]) != nil) {
      NSString *bpath;

      if ([[productName pathExtension] length] == 0)
	/* filter out directories without extensions */
	continue;
      
      bpath = [lpath stringByAppendingPathComponent:productName];
      [self logWithFormat:@"  register product: %@", 
              [bpath lastPathComponent]];
      [registry registerProductAtPath:bpath];
    }
  }
  
  if (![registry loadAllProducts])
    [self warnWithFormat:@"could not load all products !"];
}

@end /* SoProductLoader */
