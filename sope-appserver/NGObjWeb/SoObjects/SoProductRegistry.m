/*
  Copyright (C) 2002-2006 SKYRIX Software AG
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

#include "SoProductRegistry.h"
#include "SoProduct.h"
#include "SoObject.h"
#include "SoClassSecurityInfo.h"
#include "common.h"
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOContext.h>

@implementation SoProductRegistry

static int debugOn = 0;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  debugOn = [ud boolForKey:@"SoProductRegistryDebugEnabled"] ? 1 : 0;
}

+ (id)sharedProductRegistry {
  static SoProductRegistry *reg = nil; // THREAD
  if (reg == nil)
    reg = [[SoProductRegistry alloc] init];
  return reg;
}

- (id)init {
  if ((self = [super init])) {
    [self scanForAvailableProducts];

    [[NSNotificationCenter defaultCenter]
      addObserver:self selector:@selector(_bundleDidLoad:)
      name:@"NSBundleDidLoadNotification" object:nil];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self->bundlePathToFirstName release];
  [self->products              release];
  [super dealloc];
}

/* notifications */

- (void)_bundleDidLoad:(NSNotification *)_notification {
  /* 
     If bundles are loaded by some other code, check whether they contain
     SOPE products ...
  */
  [self registerProductBundle:[_notification object]];
}

/* operations */

- (NSFileManager *)fileManager {
  return [NSFileManager defaultManager];
}

- (void)registerProductBundle:(NSBundle *)_bundle {
  NSString  *productName, *firstProductName, *bundlePath;
  SoProduct *product;
  NSString  *manifest;
  
  if (![_bundle isNotNull])
    return;

  bundlePath = [_bundle bundlePath];
  
  if (_bundle != [NSBundle mainBundle]) {
    productName = 
      [[bundlePath lastPathComponent] stringByDeletingPathExtension];
  }
  else
    productName = @"MAIN";

#if COMPILE_AS_FRAMEWORK
  /* Framework's name is SoObjects, but needs to be SoCore in order to
     maintain dependency tracking */
  if ([productName isEqualToString:@"SoObjects"])
    productName = @"SoCore";
#endif

  if ((product = [self->products objectForKey:productName]) != nil) {
    [self debugWithFormat:@"product '%@' already registered.", productName];
    [product reloadIfPossible];
    return;
  }
  
  firstProductName = 
    [self->bundlePathToFirstName objectForKey:bundlePath];
  if (firstProductName != nil) {
    [self debugWithFormat:
	    @"Note: register bundle with a different name '%@': '%@'",
	    productName, bundlePath];
    if ((product = [self->products objectForKey:firstProductName]) != nil) {
      [self debugWithFormat:
	      @"add additional name '%@' (first %@) for product '%@'",
	      productName, firstProductName, product];
      [self->products setObject:product forKey:productName];
      return;
    }
    else {
      [self warnWithFormat:
              @"no product object for first name '%@' (name=%@,bundle=%@)",
              firstProductName, productName, bundlePath];
    }
  }
  
  manifest = [_bundle pathForResource:@"product" ofType:@"plist"];
  if ([manifest length] == 0) {
    if ([productName isEqualToString:@"MAIN"])
      [self debugWithFormat:@"  main bundle has no manifest."];
    return;
  }
  
  /* setup caches */
  
  if (self->products == nil)
    self->products = [[NSMutableDictionary alloc] initWithCapacity:32];
  if (self->bundlePathToFirstName == nil) {
    self->bundlePathToFirstName = 
      [[NSMutableDictionary alloc] initWithCapacity:32];
  }
  
  /* register */
  
  [self debugWithFormat:@"register product bundle: '%@' (0x%p[%@])", 
	  bundlePath, _bundle, NSStringFromClass([_bundle class])];
  
  [self debugWithFormat:@"  register as product: %@", productName];
  
  if ((product = [[SoProduct alloc] initWithBundle:_bundle]) == nil) {
    [self debugWithFormat:@"  could not init product from bundle: %@", 
	    _bundle];
    return;
  }
  
  [self->bundlePathToFirstName setObject:productName forKey:bundlePath];
  [self->products              setObject:product     forKey:productName];
  [product release];
}

- (void)registerProductAtPath:(NSString *)_path {
  static NGBundleManager *bm = nil;
  NSBundle *bundle;
  
  if (![_path isNotNull])
    return;
  
  if (bm == nil) bm = [[NGBundleManager defaultBundleManager] retain];
  bundle = [bm bundleWithPath:_path];
  
  if (bundle == nil) {
    [self logWithFormat:@"could not init bundle object for path: %@", _path];
    return;
  }
  [self registerProductBundle:bundle];
}

- (void)scanForProductsInDirectory:(NSString *)_path {
  NSFileManager *fm;
  NSEnumerator  *pathes;
  NSString      *lPath;
  
  fm = [self fileManager];
  pathes = [[fm directoryContentsAtPath:_path] objectEnumerator];
  while ((lPath = [pathes nextObject])) {
    BOOL isDir;
    
    lPath = [_path stringByAppendingPathComponent:lPath];
    
    if (![fm fileExistsAtPath:lPath isDirectory:&isDir])
      continue;
    if (!isDir)
      continue;
    
    [self registerProductAtPath:lPath];
  }
}

- (void)scanForAvailableProducts {
  NSFileManager *fm;
  NSProcessInfo *pi;
  NSArray  *pathes;
  NSBundle *bundle;
  NSString *relPath;
  unsigned i;

  /* scan mail bundle & frameworks */
  
  if ((bundle = [NSBundle mainBundle]))
    [self registerProductBundle:bundle];
  else
    NSLog(@"%s: missing main bundle ...", __PRETTY_FUNCTION__);
  
  pathes = [NSBundle allFrameworks];
  for (i = 0; i < [pathes count]; i++)
    [self registerProductBundle:[pathes objectAtIndex:i]];

  pathes = [NSBundle allBundles];
  for (i = 0; i < [pathes count]; i++)
    [self registerProductBundle:[pathes objectAtIndex:i]];
  
  /* scan library pathes */
  
  fm = [NSFileManager defaultManager];
  pi = [NSProcessInfo processInfo];
#if ! GNUSTEP_BASE_LIBRARY  
#if COCOA_Foundation_LIBRARY && !COMPILE_FOR_GNUSTEP
  /* 
     TODO: (like COMPILE_FOR_GNUSTEP)
     This should actually check whether we are compiling in the
     GNUstep environment since this modifies the location of bundles.
  */
  pathes = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
					       NSAllDomainsMask,
					       YES);
  relPath = @"";
#else
  pathes = [[pi environment] objectForKey:@"GNUSTEP_PATHPREFIX_LIST"];
  if (pathes == nil)
    pathes = [[pi environment] objectForKey:@"GNUSTEP_PATHLIST"];
  
  pathes = [[pathes stringValue] componentsSeparatedByString:@":"];
  relPath = @"Library/";
#endif
  relPath = [relPath stringByAppendingFormat:@"SoProducts-%i.%i/",
                        SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION];
  [self debugWithFormat:@"scanning for products ..."];
  for (i = 0; i < [pathes count]; i++) {
    NSString *lPath;
    BOOL     isDir;
    
    lPath = [[pathes objectAtIndex:i] stringByAppendingPathComponent:relPath];
    [self debugWithFormat:@"  scan: %@", lPath];
    
    if (![fm fileExistsAtPath:lPath isDirectory:&isDir])
      continue;
    if (!isDir)
      continue;
    
    [self debugWithFormat:@"  directory %@", lPath];
    [self scanForProductsInDirectory:lPath];
  }
#else
  NSEnumerator *libraryPaths;
  NSString *directory;
  NSMutableArray *tmppath;

  libraryPaths = [NSStandardLibraryPaths() objectEnumerator];
  tmppath = [[NSMutableArray alloc] init];
  while ((directory = [libraryPaths nextObject]))
    [tmppath addObject: [directory stringByAppendingPathComponent: 
		[NSString stringWithFormat:@"SoProducts-%i.%i/",
		SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION]]];
  pathes = [tmppath mutableCopy];
  [self debugWithFormat:@"scanning for products ..."];
  for (i = 0; i < [pathes count]; i++) {
    NSString *lPath;
    BOOL     isDir;
    
    lPath = [pathes objectAtIndex:i];
    [self debugWithFormat:@"  scan: %@", lPath];
    
    if (![fm fileExistsAtPath:lPath isDirectory:&isDir])
      continue;
    if (!isDir)
      continue;
    
    [self debugWithFormat:@"  directory %@", lPath];
    [self scanForProductsInDirectory:lPath];
  }
  [tmppath release];
#endif


#if COCOA_Foundation_LIBRARY
  /* look in wrapper places */
  bundle = [NSBundle bundleForClass:[self class]];
  relPath = [[bundle resourcePath]
                     stringByAppendingPathComponent:@"SoProducts"];
  [self scanForProductsInDirectory:relPath];
#endif
  /* look into FHS pathes */
  
  relPath = [NSString stringWithFormat:
#ifdef CGS_LIBDIR_NAME
			[CGS_LIBDIR_NAME stringByAppendingString:@"/sope-%i.%i/products/"],
#else
			@"lib/sope-%i.%i/products/",
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
    [self scanForProductsInDirectory:lPath];
  }
  
  /* report result */
  
  [self debugWithFormat:
	  @"finished scan for products (%i products registered).",
	  [self->products count]];
}

/* registering products */

- (BOOL)loadProductNamed:(NSString *)_name {
  SoProduct    *product;
  NSEnumerator *requiredProducts;
  NSString     *rqname;
  
  if ((product = [self->products objectForKey:_name]) == nil) {
    [self debugWithFormat:@"did not find product: %@", _name];
    return NO;
  }
  
  /* load dependencies (TODO: should detect cycles) */
  requiredProducts = [[product requiredProducts] objectEnumerator];
  while ((rqname = [requiredProducts nextObject])) {
    if (![self loadProductNamed:rqname]) {
      if ([rqname isEqualToString:@"MAIN"]) continue;
      [self errorWithFormat:@"failed to load product %@ required by %@.",
              rqname, _name];
      return NO;
    }
  }
  
  return [product load];
}

- (BOOL)loadAllProducts {
  NSEnumerator *e;
  NSString *p;
  
  e = [self->products keyEnumerator];
  while ((p = [e nextObject])) {
    if (![self loadProductNamed:p])
      [self logWithFormat:@"could not load product: %@", p];
  }
  return YES;
}

/* lookup products */

- (NSArray *)registeredProductNames {
  return [self->products allKeys];
}
- (SoProduct *)productWithName:(NSString *)_name {
  return [self->products objectForKey:_name];
}

/* bundle */

- (SoProduct *)productForBundle:(NSBundle *)_bundle {
  /* TODO: add a registry based on path ... */
  NSString  *pname, *bpath;
  SoProduct *product;
  
  bpath = [_bundle bundlePath];
  
  /* check whether a name is cached for the bundle .. */
  
  pname = [self->bundlePathToFirstName objectForKey:bpath];
  if ((product = [self productWithName:pname]) != nil)
    return product;
  
  /* 'calculate' name of bundle */
  
  pname = [[bpath lastPathComponent] stringByDeletingPathExtension];
  if ((product = [self productWithName:pname]) != nil)
    return product;
  
  /* load missing product */
  
  [self logWithFormat:
          @"product '%@' not yet registered, attempting to load ...", pname];
  if (![self loadProductNamed:pname])
    return nil;
  return [self productWithName:pname];
}

/* product registry as a SoObject */

- (NSArray *)allKeys {
  return [self registeredProductNames];
}

- (BOOL)hasName:(NSString *)_key inContext:(id)_ctx {
  if ([self->products objectForKey:_key])
    return YES;
  return [super hasName:_key inContext:_ctx];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  SoProduct *product;
  
  if ((product = [self productWithName:_key]))
    return product;
  
  return [super lookupName:_key inContext:_ctx acquire:_flag];
}

- (NSArray *)toOneRelationshipKeys {
  NSMutableSet *ma;
  id root;

  if ((root = [super toOneRelationshipKeys]) == nil)
    return [self->products allKeys];
  
  ma = [[NSMutableSet alloc] initWithArray:root];
  [ma addObjectsFromArray:[self->products allKeys]];
  root = [ma allObjects];
  [ma release];
  return root;
}

/* debugging */

- (NSString *)loggingPrefix {
  return @"[so-product-registry]";
}
- (BOOL)isDebuggingEnabled {
  return debugOn ? YES : NO;
}

/* web representation */

- (void)appendToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  NSEnumerator *e;
  NSString *name;
  
  [_r appendContentString:@"<h3>SOPE Product Registry</h3>"];
  
  e = [[self toOneRelationshipKeys] objectEnumerator];
  while ((name = [e nextObject])) {
    [_r appendContentString:@"<li><a href=\""];
    [_r appendContentHTMLAttributeValue:name];
    [_r appendContentString:@"\">"];
    [_r appendContentHTMLString:name];
    [_r appendContentString:@"</a></li>"];
  }    
}

@end /* SoProductRegistry */
