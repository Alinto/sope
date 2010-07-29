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

#include "SoObject.h"
#include "SoClassRegistry.h"
#include "SoClass.h"
#include "SoSecurityManager.h"
#include "WOContext+SoObjects.h"
#import <EOControl/EOClassDescription.h> // for -shallowCopy
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include "common.h"

@implementation NSObject(SoObject)

static int debugLookup  = -1;
static int debugBaseURL = -1;
static int useRelativeURLs = -1;
static int redirectInitted = -1;
static NSURL *redirectURL = nil;

static void _initialize(void) {
  NSString *url;
  NSUserDefaults *ud;

  ud = [NSUserDefaults standardUserDefaults];

  if (debugLookup == -1) {
    debugLookup = [ud boolForKey:@"SoDebugKeyLookup"] ? 1 : 0;
    NSLog(@"Note(SoObject): SoDebugKeyLookup is enabled!");
  }
  if (debugBaseURL == -1) {
    debugBaseURL = [ud boolForKey:@"SoDebugBaseURL"] ? 1 : 0;
    NSLog(@"Note(SoObject): SoDebugBaseURL is enabled!");
  }
  if (useRelativeURLs == -1) {
    useRelativeURLs = [ud boolForKey:@"WOUseRelativeURLs"] ?1:0;
    NSLog(@"Note(SoObject): relative base URLs are enabled.");
  }
  if (redirectInitted == -1) {
    url = [ud stringForKey:@"WOApplicationRedirectURL"];
    if ([url length]) {
      redirectURL = [[NSURL alloc] initWithString: url];
    }
    redirectInitted = 1;
  }
}

/* classes */

+ (SoClass *)soClass {
  static SoClassRegistry *registry = nil; // THREAD
  if (registry == nil)
    registry = [[SoClassRegistry sharedClassRegistry] retain];
  return [registry soClassForClass:self];
}
- (SoClass *)soClass {
  return [[self class] soClass];
}
- (NSString *)soClassName {
  return [[self soClass] className];
}

+ (SoClassSecurityInfo *)soClassSecurityInfo {
  return [[self soClass] soClassSecurityInfo];
}

- (NSClassDescription *)soClassDescription {
  return [[self soClass] soClassDescription];
}

/* invocation */

- (BOOL)isCallable {
  return NO;
}
- (id)clientObject {
  return self;
}

- (id)callOnObject:(id)_client inContext:(id)_ctx {
  return nil;
}

- (NSString *)defaultMethodNameInContext:(id)_ctx {
  return @"index";
}
- (id)lookupDefaultMethod {
  id ctx = nil;
  
  // TODO: lookupDefaultMethod should be rewritten to take a context!
  ctx = [[WOApplication application] context];

  // TODO: we might want to return a redirect?!
  
  return [self lookupName:[self defaultMethodNameInContext:ctx]
	       inContext:ctx
	       acquire:YES];
}

/* keys */

- (BOOL)hasName:(NSString *)_key inContext:(id)_ctx {
  /* this corresponds to Zope's/Pythons __hasattr__() */
  if ([[self soClass] hasKey:_key inContext:_ctx])
    return YES;
  if ([[self toOneRelationshipKeys] containsObject:_key])
    return YES;
  return NO;
}

- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag {
  /* this corresponds to Zope's/Pythons __getattr__() */
  id value;
  _initialize();
  
  if (debugLookup)
    [self debugWithFormat:@"lookup key '%@'", _key];
  
  /* we might want to cache class methods ? */
  if ((value = [[self soClass] lookupKey:_key inContext:_ctx]) == nil) {
    if (debugLookup) {
      [self logWithFormat:@"  did not find key '%@' in SoClass: %@", 
              _key, [self soClass]];
    }
    
    if ([[self toOneRelationshipKeys] containsObject:_key]) {
      if (debugLookup) {
	[self logWithFormat:
                @"  %@ is a toOneRelationshipKey (use -valueForKey:)", _key];
      }
      value = [self valueForKey:_key];
    }
  }
  
  if (value) {
    if ((value = [value bindToObject:self inContext:_ctx]) == nil) {
      if (debugLookup)
        [self logWithFormat:@"  value from class did not bind: %@", 
	      [self soClass]];
      return nil;
    }
  }
  else if (_flag) { /* try to acquire from container */
    if (debugLookup)
      [self logWithFormat:@"  try to acquire %@ from container ...", _key];
    value = [[self container] lookupName:_key inContext:_ctx acquire:YES];
  }
  
  if (debugLookup) [self logWithFormat:@"  looked up value: %@", value];
  return value;
}

- (NSException *)validateName:(NSString *)_key inContext:(id)_ctx {
  static SoSecurityManager *sm = nil;
  if (sm == nil) sm = [[SoSecurityManager sharedSecurityManager] retain];
  return [sm validateName:_key ofObject:self inContext:_ctx];
}

/* binding */

- (id)bindToObject:(id)_object inContext:(id)_ctx {
  return self;
}

/* security */

- (NSString *)ownerInContext:(id)_ctx {
  /* objects are not owned by default, suggest to inherit owner */
  return [[self container] ownerInContext:_ctx];
}
- (id)authenticatorInContext:(id)_ctx {
  return [[_ctx application] authenticatorInContext:_ctx];
}

/* containment */

- (id)container {
  return nil;
}
- (void)detachFromContainer {
}
- (NSString *)nameInContainer {
  return nil;
}

- (NSArray *)objectContainmentStack {
  NSMutableArray *ma;
  id object;
  
  if ((object = [self container]) == nil)
    /* this is root */
    return [NSArray arrayWithObject:self];
  
  ma = [[NSMutableArray alloc] initWithCapacity:16];
  for (object = self; object; object = [object container])
    [ma insertObject:(object ? object : (id)[NSNull null]) atIndex:0];

  object = [ma shallowCopy];
  [ma release];
  return [object autorelease];
}

- (NSArray *)reversedPathArrayToSoObject {
  NSMutableArray *ma;
  id object, nextObject;
  
  if ((object = [self container]) == nil)
    /* this is root */
    return [NSArray array];
  
  ma = [NSMutableArray arrayWithCapacity:16];
  for (object = self; (nextObject = [object container]); object = nextObject) {
    NSString *oname;
    
    oname = [object nameInContainer];
    [ma addObject:(oname != nil ? oname : (NSString *)[NSNull null])];
  }
  return ma;
}
- (NSArray *)pathArrayToSoObject {
  NSArray      *pathArray;
  NSEnumerator *e;
  
  if ((pathArray = [self reversedPathArrayToSoObject]) == nil)
    return nil;
  
  e = [pathArray reverseObjectEnumerator];
  pathArray = [[[NSArray alloc] initWithObjectsFromEnumerator:e] autorelease];
  return pathArray;
}

- (BOOL) isFolderish
{
  return NO;
}

- (NSString *)baseURLInContext:(id)_ctx {
  NSString *baseURL;
  id parent;
  _initialize();
  
  // TODO: should we check the traversal path?
  
  if ((parent = [self container]) != nil) {
    /* Note: cannot use -stringByAppendingPathComponent: on OSX! */
    NSString *name;
    
    if (parent == self) {
      [self warnWithFormat:
              @"container==object in baseURL calculation (loop?): %@",
              self];
    }
    
    baseURL = [parent baseURLInContext:_ctx];
    if (![baseURL hasSuffix:@"/"])
      baseURL = [baseURL stringByAppendingString:@"/"];
    
    name    = [[self nameInContainer] stringByEscapingURL];
    baseURL = [baseURL stringByAppendingString:name];
    
    if (debugBaseURL) {
      [self logWithFormat:
	      @"baseURL: name=%@ (container=%@)\n  container: %@\n  own: %@", 
	      [self nameInContainer],
	      NSStringFromClass([[self container] class]),
	      [[self container] baseURL], baseURL];
    }
  }
  else {
    baseURL = [self rootURLInContext:_ctx];
    if (debugBaseURL) {
      [self logWithFormat:@"ROOT baseURL(no container, name=%@):\n  own: %@", 
              [self nameInContainer], baseURL];
    }
  }
  
  /* add a trailing slash for folders */
  
  if (![baseURL hasSuffix:@"/"]) {
    if ([self isFolderish])
      baseURL = [baseURL stringByAppendingString:@"/"];
  }
  
  return baseURL;
}

NSString *SoObjectRootURLInContext
  (WOContext *_ctx, id self /* logger */, BOOL withAppPart)
{
  // TODO: it would be best if we would return relative URLs here, but
  //       _some_ places (like the ZideStore subscription page) actually
  //       need absolute URLs.
  /*
    Note: Evolution doesn't correctly transfer the "Host:" header, it
    misses the port argument :-(
    
    Note: this is called by SoObjectWebDAVDispatcher.m.
  */
  // TODO: this should be a WOContext method?
  NSMutableString *ms;
  BOOL      isHTTPS = NO; // TODO: what about https??
  NSString  *rootURL;
  WORequest *rq;
  NSString  *rh, *tmp;
  int       port;
  _initialize();
  
  // TODO: this is somewhat weird, why don't we use WOContext for URL gen.?
  
  rq = [_ctx request];
  ms = [[NSMutableString alloc] initWithCapacity:128];

  if (redirectURL) {
    [ms appendString: [redirectURL absoluteString]];
  }
  else {  
    if (!useRelativeURLs) {
      port = [[rq headerForKey:@"x-webobjects-server-port"] intValue];
  
      /* this is actually a bug in Apache */
      if (port == 0) {
	static BOOL didWarn = NO;
	if (!didWarn) {
	  [self warnWithFormat:@"(%s:%i): got an empty port from Apache!",
		__PRETTY_FUNCTION__, __LINE__];
	  didWarn = YES;
	}
	port = 80;
      }
  
      if ((tmp = [rq headerForKey:@"host"]) != nil) { 
	/* check whether we have a host header with port */
	if ([tmp rangeOfString:@":"].length == 0)
	  tmp = nil;
      }
      if (tmp != nil) { /* we have a host header with port */
	isHTTPS = 
	  [[rq headerForKey:@"x-webobjects-server-url"] hasPrefix:@"https"];
	[ms appendString:isHTTPS ? @"https://" : @"http://"]; 
	[ms appendString:tmp];
      }
      else if ((tmp = [rq headerForKey:@"x-webobjects-server-url"]) != nil) {
	/* sometimes the URL is just wrong! (suggests port 80) */
	if ([tmp hasSuffix:@":0"] && [tmp length] > 2) { // TODO: bad bad bad
	  [self warnWithFormat:@"%s: got incorrect URL from Apache: '%@'",
		__PRETTY_FUNCTION__, tmp];
	  tmp = [tmp substringToIndex:([tmp length] - 2)];
	}
	else if ([tmp hasSuffix:@":443"] && [tmp hasPrefix:@"http://"]) {
	  /* see OGo bug #1435, Debian Apache hack */
	  [self warnWithFormat:@"%s: got 'http' protocol but 443 port, "
		@"assuming Debian/Apache bug (OGo #1435): '%@'",
		__PRETTY_FUNCTION__, tmp];
	  tmp = [tmp substringWithRange:NSMakeRange(4, [tmp length] - 4 - 4)];
	  tmp = [@"https" stringByAppendingString:tmp];
	}
	[ms appendString:tmp];
      }
      else {
	// TODO: isHTTPS always no in this case?
	[ms appendString:isHTTPS ? @"https://" : @"http://"]; 
  
	[ms appendString:[rq headerForKey:@"x-webobjects-server-name"]];
	if ((isHTTPS ? (port != 443) : (port != 80)) && port != 0)
	  [ms appendFormat:@":%i", port];
      }
    }
  }
  
  if (withAppPart) {
    if (![ms hasSuffix:@"/"]) [ms appendString:@"/"];
    
    /* appname, two cases: */
    /*   a) direct access,  eg /MyFolder */
    /*   b) access via app, eg /MyApp/so/MyFolder */
    [ms appendString:[rq applicationName]];
    if (![ms hasSuffix:@"/"]) [ms appendString:@"/"];
  }
  
  /* done */
  rootURL = [[ms copy] autorelease];
  [ms release];
  if (debugBaseURL)
    [self logWithFormat:@"  constructed root-url: %@", rootURL];
  
  /* some hack for the request handler? */
  if (withAppPart) {
    rh = [rq requestHandlerKey];
    if ([[[_ctx application] registeredRequestHandlerKeys] containsObject:rh])
      rootURL = [rootURL stringByAppendingFormat:@"%@/", rh];
  }
  
  return rootURL;
}

- (NSString *)rootURLInContext:(id)_ctx {
  NSString *rootURL;

  /* check cache */
  if ((rootURL = [_ctx rootURL]) != nil) {
    if (debugBaseURL) {
      [self logWithFormat:@"  using root-url from context: %@",
              rootURL];
    }
    return rootURL;
  }
  
  rootURL = SoObjectRootURLInContext
    (_ctx, self /* logger */, YES /* withAppPart */);
  
  /* remember in cache */
  if (debugBaseURL) {
    [self logWithFormat:@"  setting root-url in context: %@",
	    rootURL];
  }
  [(WOContext *)_ctx setRootURL:rootURL];
  return rootURL;
}

- (NSString *)baseURL {
  /* you should use the context method ! */
  return [self baseURLInContext:[[WOApplication application] context]];
}

@end /* NSObject(SoObject) */

@implementation WOApplication(Authenticator)

- (NSString *)ownerInContext:(id)_ctx {
  /* objects are not owned by default */
  return nil;
}
- (id)authenticatorInContext:(id)_ctx {
  return nil;
}

@end /* WOApplication(Authenticator) */
