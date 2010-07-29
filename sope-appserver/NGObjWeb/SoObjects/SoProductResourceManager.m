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

#include "SoProductResourceManager.h"
#include "SoProduct.h"
#include "SoObject.h"
#include "SoClassSecurityInfo.h"
#include "SoProductRegistry.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WORequest.h>
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

/*
  How is resource lookup supposed to work?

  First, we need to determine whether the resource being asked for is a 
  resource contained in the product bundle. If thats the case, this resource
  manager will take of it.
  
  If not, there are two options:
  a) the resource is from a different product, so we direct lookup to that
  b) the resource is a "global" resource, so we ask the WOApplication manager
*/

@interface WOResourceManager(UsedPrivates)
- (NSString *)webServerResourcesPath;
- (NSString *)resourcesPath;
@end

@implementation SoProductResourceManager

static NGBundleManager *bm = nil;
static BOOL debugOn = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  bm = [[NGBundleManager defaultBundleManager] retain];
  debugOn = [ud boolForKey:@"SoProductResourceManagerDebugEnabled"];
}

- (id)initWithProduct:(SoProduct *)_product {
  if ((self = [super initWithPath:[[_product bundle] bundlePath]])) {
    self->product = _product;
  }
  return self;
}

/* containment */

- (void)detachFromContainer {
  self->product = nil;
}
- (id)container {
  return self->product;
}
- (NSString *)nameInContainer {
  return @"Resources";
}

- (WOResourceManager *)fallbackResourceManager {
  WOResourceManager *rm;
  
  rm = [[WOApplication application] resourceManager];
  return (rm == self) ? (WOResourceManager *)nil : rm; /* avoid recursion */
}

/* lookup resources */

- (NSBundle *)bundleForFrameworkName:(NSString *)_fwName {
  NSBundle *bundle;
  
  if ([_fwName length] == 0) {
    if ((bundle = [self->product bundle]) == nil)
      [self warnWithFormat:@"missing bundle for product: %@", self->product];
    return bundle;
  }
  
  if ([_fwName hasPrefix:@"/"]) {
    bundle = [bm bundleWithPath:_fwName];
  }
  else {
    bundle = [bm bundleWithName:[_fwName stringByDeletingPathExtension]
		 type:[_fwName pathExtension]];
  }
  if (bundle == nil)
      [self warnWithFormat:@"missing bundle for framework: '%@'", _fwName];
  
  return bundle;
}

- (WOResourceManager *)resourceManagerForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
{
  SoProduct *bproduct;
  NSBundle  *bundle;
  
  /* determine product bundle or explicitly requested framework/bundle */

  if ([_frameworkName length] == 0)
    return self;
  
  if ((bundle = [self bundleForFrameworkName:_frameworkName]) == nil)
    return nil;
  
  bproduct = [[SoProductRegistry sharedProductRegistry] 
	       productForBundle:bundle];
  
  if (debugOn) {
    [self debugWithFormat:
	    @"  fwname: '%@'\n  bundle: '%@'\n  product: '%@'", 
	    _frameworkName, bundle, bproduct];
  }
  return (bproduct == self->product)
    ? self : (SoProductResourceManager *)[bproduct resourceManager];
}

- (NSString *)primaryLookupPathForResourceNamed:(NSString *)_name
  languages:(NSArray *)_l
{
  NSString *path;
  
  path = [[self->product bundle]
	     pathForResource:[_name stringByDeletingPathExtension]
	     ofType:[_name pathExtension]
	     inDirectory:nil
	     languages:_l];
  if (debugOn && path == nil) {
    [self debugWithFormat:@"  resource %@/%@ not found in bundle: %@",
	  _name, [_l componentsJoinedByString:@","], [self->product bundle]];
  }
  return path;
}

- (NSString *)pathForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
{
  // TODO: should we do acquisition? (hm, don't think so!, done in lookup)
  //       but maybe we should not fall back to WOApplication resources
  WOResourceManager *rm;
  NSString *path;
  
  if (debugOn) [self debugWithFormat:@"lookup resource: '%@'", _name];
  
  /* determine resource manager to be actually used */
  
  rm = [self resourceManagerForResourceNamed:_name inFramework:_frameworkName];
  
  /* lookup resource */
  
  if (rm == self) {
    path = [self primaryLookupPathForResourceNamed:_name languages:_languages];
  }
  else if (rm != nil) {
    /* delegate lookup to resource manager of other products */
    path = [rm pathForResourceNamed:_name inFramework:_frameworkName
	       languages:_languages];
    if (debugOn && path == nil)
      [self debugWithFormat:@"  resource %@ not found in rm: %@", _name, rm];
  }
  else
    path = nil;
  
  if (path != nil) {
    if (debugOn) [self debugWithFormat:@"  => found: %@", path];
    return path;
  }
  
  /* fall back to global resource manager */
  
  return [[self fallbackResourceManager]
	   pathForResourceNamed:_name inFramework:_frameworkName
	   languages:_languages];
}

/* generate URL for resources (eg filename binding in WOImage) */

- (NSString *)webServerResourcesPath {
  /* to avoid warning that WebServerResources path does not exist ... */
  return [[self fallbackResourceManager] webServerResourcesPath];
}

- (NSString *)urlForProductRelativeResourcePath:(NSString *)resource {
  NSString *tmp;
  NSString *path = nil, *sbase;
  unsigned len;
  NSString *url;
  
  sbase = self->base;
  tmp  = [sbase commonPrefixWithString:resource options:0];
  
  len  = [tmp length];
  path = [sbase    substringFromIndex:len];
  tmp  = [resource substringFromIndex:len];
  if (([path length] > 0) && ![tmp hasPrefix:@"/"] && ![tmp hasPrefix:@"\\"])
    path = [path stringByAppendingString:@"/"];
  path = [path stringByAppendingString:tmp];
  
#ifdef __WIN32__
  {
    NSArray *cs;
    cs   = [path componentsSeparatedByString:@"\\"];
    path = [cs componentsJoinedByString:@"/"];
  }
#endif
  if (path == nil)
    return nil;
  
  if ([path hasPrefix:@"/Resources/"])
    path = [path substringFromIndex:11];
  else if ([path hasPrefix:@"Resources/"])
    path = [path substringFromIndex:10];
  
  /* Note: cannot use -stringByAppendingPathComponent: on OSX! */
  url = [self baseURLInContext:[[WOApplication application] context]];
  if (debugOn) [self debugWithFormat:@" base: '%@'", url];
  
  if (![url hasSuffix:@"/"]) url = [url stringByAppendingString:@"/"];
  url = [url stringByAppendingString:path];
  return url;
}

- (NSString *)fixupResourcePath:(NSString *)resource {
#if APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
  if ([resource rangeOfString:@"/Contents/"].length > 0) {
    resource = [resource stringByReplacingString:@"/Contents"
                         withString:@""];
  }
#endif
#if 0
  if ((tmp = [resource stringByStandardizingPath]) != nil)
    resource = tmp;
#endif
  return resource;
}

- (NSString *)urlForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
  request:(WORequest *)_request
{
  WOResourceManager *rm;
  NSString *url;
  
  if (debugOn) [self debugWithFormat:@"lookup url: '%@'", _name];
  
  if (_languages == nil) _languages = [_request browserLanguages];
  
  /* determine resource manager to be actually used */
  
  rm = [self resourceManagerForResourceNamed:_name inFramework:_frameworkName];

  /* lookup resource */
  
  url = nil;
  if (rm == self) { /* handle it directly */
    NSString *resource;
    
    resource = [self primaryLookupPathForResourceNamed:_name
		     languages:_languages];
    if (debugOn) [self debugWithFormat:@"  resource: %@", resource];
    resource = [self fixupResourcePath:resource];
    if (debugOn) [self debugWithFormat:@"  resource to URL: %@", resource];
    
    if (resource != nil) {
      url = [self urlForProductRelativeResourcePath:resource];
    }
    else if (debugOn) {
      [self debugWithFormat:@"  => not found '%@' (fw=%@,langs=%@)", 
	      _name, _frameworkName, 
	      [_languages componentsJoinedByString:@","]];
    }
  }
  else if (rm != nil) { /* delegate to other product */
    if (debugOn) [self debugWithFormat:@"  lookup with rm: %@", rm];
    url = [rm urlForResourceNamed:_name inFramework:_frameworkName
	      languages:_languages request:_request];
  }
  
  if (url == nil) { /* fallback */
    rm = [self fallbackResourceManager];
    if (debugOn) [self debugWithFormat:@"  fallback: %@", rm];
    url = [rm urlForResourceNamed:_name inFramework:_frameworkName
	      languages:_languages request:_request];
  }
  
  if (debugOn) [self debugWithFormat:@"  => '%@'", url];
  return url;
}

- (NSString *)pathToComponentNamed:(NSString *)_name
  inFramework:(NSString *)_fwname
  languages:(NSArray *)_langs
{
  NSString *p;
  
  p = [super pathToComponentNamed:_name inFramework:_fwname languages:_langs];
  if (![p isNotNull] || [p length] == 0 ) {
    [self logWithFormat:@"LOOKUP FAILED: %@", _name];
    p = [[self fallbackResourceManager] pathToComponentNamed:_name
					inFramework:_fwname
					languages:_langs];
    [self logWithFormat:@"  PARENT (%@) SAID: %@", 
            [self fallbackResourceManager], p];
  }
  return p;
}

- (WOElement *)templateWithName:(NSString *)_name
  languages:(NSArray *)_languages
{
  WOResourceManager *arm;
  WOElement *e;
  
  if (debugOn) {
    [self logWithFormat:@"lookup template with name '%@' (languages=%@)",
	  _name, [_languages componentsJoinedByString:@","]];
  }
  if ((e = [super templateWithName:_name languages:_languages]) != nil) {
    if (debugOn) [self logWithFormat:@"  found: %@", e];
    return e;
  }
  
  arm = [self fallbackResourceManager];
  if (arm == self) return nil;
  
  if (debugOn) [self logWithFormat:@"  lookup in parent RM: %@", arm];
  if ((e = [arm templateWithName:_name languages:_languages]) != nil) {
    if (debugOn) [self logWithFormat:@"  found: %@", e];
    return e;
  }
  
  if (debugOn) [self logWithFormat:@"did not find template %@", _name];
  return nil;
}

/* resource manager as a SoObject */

- (NSString *)mimeTypeForExtension:(NSString *)_ext {
  // TODO: HACK, move to some object
  NSString *ctype = nil;
  
  if ([_ext isEqualToString:@"css"])       ctype = @"text/css";
  else if ([_ext isEqualToString:@"gif"])  ctype = @"image/gif";
  else if ([_ext isEqualToString:@"jpg"])  ctype = @"image/jpeg";
  else if ([_ext isEqualToString:@"png"])  ctype = @"image/png";
  else if ([_ext isEqualToString:@"html"]) ctype = @"text/html";
  else if ([_ext isEqualToString:@"xml"])  ctype = @"text/xml";
  else if ([_ext isEqualToString:@"txt"])  ctype = @"text/plain";
  else if ([_ext isEqualToString:@"js"])   ctype = @"application/x-javascript";
  else if ([_ext isEqualToString:@"xhtml"]) ctype = @"application/xhtml+xml";
  return ctype;
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  WOResponse *r;
  NSBundle   *b;
  NSString   *p, *pe, *ctype;
  NSData     *data;
  NSArray    *languages = nil;
  
  /* TODO: add support for languages (eg English.lproj/ok.gif) ! */
  
  /* check whether the resource is made public */
  
  if (![self->product isPublicResource:_key]) {
    [self debugWithFormat:@"key '%@' is not declared a public resource.",_key];
    return nil;
  }
  
  if ((b = [self->product bundle]) == nil) {
    [self debugWithFormat:@"product has no bundle for lookup of %@", _key];
    return nil;
  }
  
  pe = [_key pathExtension];

  /* ask resource-manager (self) for path */
  
  languages = [_ctx resourceLookupLanguages];
  
  p = [self pathForResourceNamed:_key 
	    inFramework:[b bundlePath]
	    languages:languages];
  if (p == nil) {
    [self errorWithFormat:@"did not find product resource: %@", _key];
    return nil;
  }

  /* load data */

  if ((data = [NSData dataWithContentsOfMappedFile:p]) == nil) {
    [self errorWithFormat:@"failed to load product resource: %@", _key];
    return nil;
  }
  
  /* and deliver as a complete response */
  
  r = [(id<WOPageGenerationContext>)_ctx response];
  
  [r setStatus:200 /* OK */];
  [r setContent:data];
  
  if ((ctype = [self mimeTypeForExtension:pe]) == nil) {
    [self warnWithFormat:@"did not recognize extension '%@', "
            @"delivering as application/octet-stream.", pe];
    ctype = @"application/octet-stream";
  }

  {
    NSDate *expDate = nil;
    NSString *str = nil;
    
    expDate = [[NSDate alloc] initWithTimeInterval:(60 * 60 * 1) /* 1 hour */
			      sinceDate:[NSDate date]];
    str = [expDate descriptionWithCalendarFormat:
		     @"%a, %d %b %Y %H:%M:%S GMT"
		   timeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]
		   locale:nil];
    [r setHeader:str forKey:@"expires"];
    [expDate release];
  }
  
  [r setHeader:ctype forKey:@"content-type"];
  return r;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}
- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"[RM:%@]", [self->product productName]];
}

/* description */

- (NSString *)description {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:64];
  [str appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  [str appendFormat:@" product='%@'", [self->product productName]];
  [str appendString:@">"];
  return str;
}

@end /* SoProductResourceManager */
