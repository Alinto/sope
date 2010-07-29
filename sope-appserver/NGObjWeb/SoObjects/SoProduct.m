/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "SoProduct.h"
#include "SoProductClassInfo.h"
#include "SoProductResourceManager.h"
#include "SoClassRegistry.h"
#include "SoClassSecurityInfo.h"
#include "SoObject.h"
#include "SoSecurityManager.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@interface SoProduct(Privates)
- (void)registerClassesFromDictionary:(NSDictionary *)_classToInfo;
- (void)registerCategoriesFromDictionary:(NSDictionary *)_classToInfo;
@end

@implementation SoProduct

static int debugOn     = 1;
static int regDebugOn  = 0;
static int loadDebugOn = 0;

+ (void)initialize {
  static BOOL didInit = NO;
  if (!didInit) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    didInit = YES;
    regDebugOn  = [ud boolForKey:@"SoDebugProductRegistry"] ? 1 : 0;
    loadDebugOn = [ud boolForKey:@"SoDebugProductLoading"] ? 1 : 0;
  }
}

- (id)initWithDictionary:(NSDictionary *)_dict {
  if ((self = [super init])) {
    self->requiredProducts = [[_dict objectForKey:@"requires"] copy];
    self->publicResources  = [[_dict objectForKey:@"publicResources"] copy];
    
    [self registerClassesFromDictionary:[_dict objectForKey:@"classes"]];
    [self registerCategoriesFromDictionary:[_dict objectForKey:@"categories"]];
  }
  return self;
}

- (id)initWithBundle:(NSBundle *)_bundle {
  NSString     *manifestPath;
  NSDictionary *manifest;
  
  if (_bundle == nil) {
    [self release];
    return nil;
  }
  self->bundle = [_bundle retain];
  manifestPath = [self->bundle pathForResource:@"product" ofType:@"plist"];
  if ([manifestPath length] == 0) {
    [self release];
    return nil;
  }
  
  manifest = [NSDictionary dictionaryWithContentsOfFile:manifestPath];
  if (manifest == nil) {
    [self logWithFormat:@"could not parse manifest: %@", manifestPath];
    [self release];
    return nil;
  }
  
  self->resourceManager =
    [[SoProductResourceManager alloc] initWithProduct:self];
  if (self->resourceManager == nil)
    [self logWithFormat:@"failed to instantiate resourcemanager for bundle"];
  
  return [self initWithDictionary:manifest];
}

- (void)dealloc {
  [self->resourceManager detachFromContainer];
  
  [self->resourceManager  release];
  [self->publicResources  release];
  [self->requiredProducts release];
  [self->categories       release];
  [self->classes          release];
  [self->bundle           release];
  [super dealloc];
}

/* accessors */

- (NSArray *)requiredProducts {
  return self->requiredProducts;
}

- (NSBundle *)bundle {
  return self->bundle;
}

- (BOOL)isMainProduct {
  if (self->bundle == nil) return YES;
  if (self->bundle == [NSBundle mainBundle]) return YES;
  return NO;
}

- (NSString *)productName {
  if ([self isMainProduct])
    return @"MAIN";
  
  return [[[self->bundle bundlePath]
	    lastPathComponent] stringByDeletingPathExtension];
}

- (BOOL)isPublicResource:(NSString *)_key {
  return [self->publicResources containsObject:_key] ? YES : NO;
}

/* parsing manifest */

- (void)registerCategoryNamed:(NSString *)_name info:(NSDictionary *)_info {
  SoProductCategoryInfo *catInfo;
  
  if (regDebugOn)
    [self logWithFormat:@"  register category on '%@'", _name];
  
  catInfo = [[SoProductCategoryInfo alloc] 
		initWithName:_name manifest:_info product:self];
  if (catInfo == nil) {
    [self logWithFormat:@"   could not init category info for '%@'", _name];
    return;
  }
  if ([self->categories objectForKey:_name]) {
    [self errorWithFormat:
            @"duplicate declaration of category on '%@' in product.",
            _name];
    [catInfo release];
    return;
  }
  
  if (self->categories == nil)
    self->categories = [[NSMutableDictionary alloc] init];
  
  [self->categories setObject:catInfo forKey:_name];
  [catInfo autorelease];
}

- (void)registerClassNamed:(NSString *)_name info:(NSDictionary *)_info {
  SoProductClassInfo *classInfo;
  
  if (regDebugOn)
    [self logWithFormat:@"  register class: %@", _name];
  
  classInfo = [[SoProductClassInfo alloc] 
		initWithName:_name manifest:_info product:self];
  if (classInfo == nil) {
    [self debugWithFormat:@"   could not init class info for '%@'", _name];
    return;
  }
  if ([self->classes objectForKey:_name]) {
    [self errorWithFormat:@"duplicate declaration of class %@ in product "
            @"(registering as category)",
            _name];
    [classInfo release];
    [self registerCategoryNamed:_name info:_info];
    return;
  }
  
  if (self->classes == nil)
    self->classes = [[NSMutableDictionary alloc] init];
  
  [self->classes setObject:classInfo forKey:_name];
  [classInfo autorelease];
}

- (void)registerClassesFromDictionary:(NSDictionary *)_classToInfo {
  NSEnumerator *names;
  NSMutableSet *regClasses;
  NSString *className;
  
  regClasses = [NSMutableSet setWithCapacity:16];
  names = [_classToInfo keyEnumerator];
  while ((className = [names nextObject])) {
    NSDictionary *info;
    
    if ([regClasses containsObject:className])
      continue;
    
    info = [_classToInfo objectForKey:className];
    [self registerClassNamed:className info:info];
    [regClasses addObject:className];
  }
}
- (void)registerCategoriesFromDictionary:(NSDictionary *)_classToInfo {
  NSEnumerator *names;
  NSMutableSet *regCats;
  NSString *className;
  
  regCats = [NSMutableSet setWithCapacity:16];
  names = [_classToInfo keyEnumerator];
  while ((className = [names nextObject])) {
    NSDictionary *info;
    
    if ([regCats containsObject:className])
      continue;
    
    info = [_classToInfo objectForKey:className];
    [self registerCategoryNamed:className info:info];
    [regCats addObject:className];
  }
}

/* loading */

- (BOOL)load {
  SoClassRegistry *registry;
  
  if (self->flags.isLoaded) {
    if (loadDebugOn)
      [self logWithFormat:@"product already loaded: %@", self];
    return YES;
  }
  
  if (loadDebugOn)
    [self logWithFormat:@"loading product: %@", self];
  self->flags.isLoaded = 1;
  
  /* check whether bundle is binary ! */
  
  if ((self->bundle != nil) && (self->bundle != [NSBundle mainBundle])) {
    if (loadDebugOn) {
      [self logWithFormat:@"  loading bundle of product: %@", 
	      [self->bundle bundlePath]];
    }
    
    if (![self->bundle load]) {
      if (loadDebugOn) [self logWithFormat:@"  failed to load bundle."];
      return NO;
    }
    self->flags.isCodeLoaded = 1;
  }
  
  registry = [SoClassRegistry sharedClassRegistry];
  
  if (loadDebugOn) {
    [self logWithFormat:@"  registering %i classes ...", 
	    [self->classes count]];
  }
  
  [[self->classes allValues] 
    makeObjectsPerformSelector:@selector(applyOnRegistry:)
    withObject:registry];
  
  if (loadDebugOn) {
    [self logWithFormat:@"  registering %i categories ...", 
	    [self->categories count]];
  }
  
  [[self->categories allValues] 
    makeObjectsPerformSelector:@selector(applyOnRegistry:)
    withObject:registry];
  
  if (loadDebugOn)
    [self logWithFormat:@"done loading product."];
  return YES;
}

- (BOOL)reloadIfPossible {
  /* only possible if no product ObjC code is loaded */
  if (self->flags.isCodeLoaded) return NO;
  
  return NO;
}

/* product as a SoObject */

- (NSString *)baseURLInContext:(id)_ctx {
  /* Note: cannot use -stringByAppendingPathComponent: on OSX ! */
  NSString *baseURL, *cname;
  
  baseURL = [self rootURLInContext:_ctx];
  if (![baseURL hasSuffix:@"/"]) 
    baseURL = [baseURL stringByAppendingString:@"/"];
  
  baseURL = [baseURL stringByAppendingString:@"ControlPanel/Products/"];
  cname   = [[self productName] stringByEscapingURL];
  baseURL = [baseURL stringByAppendingString:cname];
  return baseURL;
}

- (NSArray *)allKeys {
  return [NSArray arrayWithObject:@"Resources"];
}

- (BOOL)hasName:(NSString *)_key inContext:(id)_ctx {
  if ([_key isEqualToString:@"Resources"])
    return YES;
  return [super hasName:_key inContext:_ctx];
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  if ([_key isEqualToString:@"Resources"])
    return [self resourceManager];
  
  return [super lookupName:_key inContext:_ctx acquire:_flag];
}

/* resource manager */

- (WOResourceManager *)resourceManager {
  if ([self isMainProduct])
    return [[WOApplication application] resourceManager];
  
  if (self->resourceManager == nil) {
    [self warnWithFormat:@"resource-manager was nil ..."];
    self->resourceManager =
      [[SoProductResourceManager alloc] initWithProduct:self];
  }
  return self->resourceManager;
}

/* HTML representation */

- (void)appendToResponse:(WOResponse *)_response inContext:(id)_ctx {
  [_response appendContentString:@"<h3>SOPE Product: "];
  [_response appendContentHTMLString:[self productName]];
  [_response appendContentString:@"</h3>"];
  
  [_response appendContentString:
	       @"<li><a href=\"Resources/\">Resources</a></li>"];
}

/* debugging */

- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"[so-product:%@]",
                     [[[self bundle] bundlePath] lastPathComponent]];
}
- (BOOL)isDebuggingEnabled {
  return debugOn ? YES : NO;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  unsigned cnt;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if (self->flags.isLoaded)
    [ms appendFormat:@" loaded"];
  if (self->flags.isCodeLoaded)
    [ms appendFormat:@" code-loaded"];

  if (self->bundle)
    [ms appendFormat:@" bundle=%@", [self->bundle bundlePath]];
  
  if ((cnt = [self->classes count]) > 0)
    [ms appendFormat:@" #classes=%d", cnt];
  if ((cnt = [self->categories count]) > 0)
    [ms appendFormat:@" #categories=%d", cnt];
  if ((cnt = [self->publicResources count]) > 0)
    [ms appendFormat:@" #pubrsrc=%d", cnt];
  
  if (self->resourceManager)
    [ms appendFormat:@" rm=0x%p", self->resourceManager];
  
  [ms appendString:@">"];
  return ms;
}

@end /* SoProduct */
