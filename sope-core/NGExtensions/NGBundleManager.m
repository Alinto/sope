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

#include "NGBundleManager.h"
#include "common.h"
#include <NGExtensions/NSObject+Logs.h>
#include <NGExtensions/NSNull+misc.h>
#import <Foundation/NSFileManager.h>
#import <EOControl/EOQualifier.h>
#include <ctype.h>

#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
#  include <NGExtensions/NGPropertyListParser.h>
#endif

#if LIB_FOUNDATION_LIBRARY
@interface NSBundle(UsedPrivates)
+ (BOOL)isFlattenedDirLayout;
@end
#endif

#if NeXT_RUNTIME || APPLE_RUNTIME

#include <objc/objc-runtime.h>

//OBJC_EXPORT void objc_setClassHandler(int (*)(const char *));

static BOOL debugClassHook = NO;
static BOOL hookDoLookup   = YES;

static int _getClassHook(const char *className) {
  // Cocoa variant
  if (className == NULL) return 0;
  
  if (debugClassHook)
    printf("lookup class '%s'.\n", className);
  
  if (objc_lookUpClass(className))
    return 1;
  
  if (hookDoLookup) {
    static NGBundleManager *manager = nil;
    NSBundle *bundle;
    NSString *cns;
    
    if (debugClassHook)
      printf("%s: look for class %s\n", __PRETTY_FUNCTION__, className);
    if (manager == nil)
      manager = [NGBundleManager defaultBundleManager];
    
    cns = [[NSString alloc] initWithCString:className];
    bundle = [manager bundleForClassNamed:cns];
    [cns release]; cns = nil;
    
    if (bundle != nil) {
      if (debugClassHook) {
	NSLog(@"%s: found bundle %@", __PRETTY_FUNCTION__, 
	      [bundle bundlePath]);
      }
      
      if (![manager loadBundle:bundle]) {
	fprintf(stderr,
		"bundleManager couldn't load bundle for class '%s'.\n", 
                className);
      }
#if 0
      else {
        Class c = objc_lookUpClass(className);
        NSLog(@"%s: loaded bundle %@ for className %s class %@", 
	      __PRETTY_FUNCTION__,
              bundle, className, c);
      }
#endif
    }
  }
  
  return 1;
}

#endif

NSString *NGBundleWasLoadedNotificationName = @"NGBundleWasLoadedNotification";

@interface NSBundle(NGBundleManagerPrivate)
- (BOOL)_loadForBundleManager:(NGBundleManager *)_manager;
@end

@interface NGBundleManager(PrivateMethods)

- (void)registerBundle:(NSBundle *)_bundle
  classes:(NSArray *)_classes
  categories:(NSArray *)_categories;

- (NSString *)pathForBundleProvidingResource:(NSString *)_resourceName
  ofType:(NSString *)_type
  resourceSelector:(NGBundleResourceSelector)_selector
  context:(void *)_ctx;
  
- (NSString *)makeBundleInfoPath:(NSString *)_path;

@end

static BOOL _selectClassByVersion(NSString        *_resourceName,
                                  NSString        *_resourceType,
                                  NSString        *_path,
                                  NSDictionary    *_resourceConfig,
                                  NGBundleManager *_bundleManager,
                                  void            *_version)
{
  id  tmp;
  int classVersion;
  
  if (![_resourceType isEqualToString:@"classes"])
    return NO;

  if (_version == NULL)
    return YES;
  if ([(id)_version intValue] == -1)
    return YES;

  if ((tmp = [_resourceConfig objectForKey:@"version"])) {
    classVersion = [tmp intValue];

    if (classVersion < [(id)_version intValue]) {
      NSLog(@"WARNING: class version mismatch for class %@: "
            @"requested at least version %i, got version %i",
            _resourceName, [(id)_version intValue], classVersion);
    }
  }
  if ((tmp = [_resourceConfig objectForKey:@"exact-version"])) {
    classVersion = [tmp intValue];

    if (classVersion != [(id)_version intValue]) {
      NSLog(@"WARNING: class version mismatch for class %@: "
            @"requested exact version %i, got version %i",
            _resourceName, [(id)_version intValue], classVersion);
    }
  }
  return YES;
}

@implementation NGBundleManager

// THREAD
static NGBundleManager *defaultManager = nil;
static BOOL debugOn = NO;

#if defined(__MINGW32__)
static NSString *NGEnvVarPathSeparator = @";";
#else
static NSString *NGEnvVarPathSeparator = @":";
#endif

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn = [ud boolForKey:@"NGBundleManagerDebugEnabled"];
}

+ (id)defaultBundleManager {
  if (defaultManager == nil) {
    defaultManager = [[NGBundleManager alloc] init];
  }

  return defaultManager;
}

/* setup bundle search path */

- (void)_addMainBundlePathToPathArray:(NSMutableArray *)_paths {
  NSProcessInfo *pi;
  NSString *path;
  
  pi   = [NSProcessInfo processInfo];
  path = [[pi arguments] objectAtIndex:0];
  path = [path stringByDeletingLastPathComponent];

  if ([path length] > 0) {
    // TODO: to be correct this would need to read the bundle-info
    //       NSExecutable?!
    /*
       The path is the complete path to the executable, including the
       processor, the OS and the library combo. Strip these directories
       from the main bundle's path.
    */
    path = [[[path stringByDeletingLastPathComponent]
                   stringByDeletingLastPathComponent]
                   stringByDeletingLastPathComponent];
    [_paths addObject:path];
  }
}

- (void)_addBundlePathDefaultToPathArray:(NSMutableArray *)_paths {
  NSUserDefaults *ud;
  id paths;
  
  if ((ud = [NSUserDefaults standardUserDefaults]) == nil) {
	// got this with gstep-base during the port, apparently it happens
	// if the bundle manager is created inside the setup process of
	// gstep-base (for whatever reason)
	NSLog(@"ERROR(NGBundleManager): got no system userdefaults object!");
#if DEBUG
	abort();
#endif
  }
  
  if ((paths = [ud arrayForKey:@"NGBundlePath"]) == nil) {
    if ((paths = [ud stringForKey:@"NGBundlePath"]) != nil)
      paths = [paths componentsSeparatedByString:NGEnvVarPathSeparator];
  }
  if (paths != nil) 
    [_paths addObjectsFromArray:paths];
  else if (debugOn)
    NSLog(@"Note: NGBundlePath default is not configured.");
}

- (void)_addEnvironmentPathToPathArray:(NSMutableArray *)_paths {
  NSProcessInfo *pi;
  id paths;
  
  pi = [NSProcessInfo processInfo];
  paths = [[pi environment] objectForKey:@"NGBundlePath"];
  if (paths)
    paths = [paths componentsSeparatedByString:NGEnvVarPathSeparator];
  if (paths) [_paths addObjectsFromArray:paths];
}

- (void)_addGNUstepPathsToPathArray:(NSMutableArray *)_paths {
  /* Old code for old gstep-make and gstep-base.  */
  NSDictionary *env;
  NSString     *p;
  unsigned     i, count;
  id tmp;
    
  env = [[NSProcessInfo processInfo] environment];

  if ((tmp = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"]) == nil)
    tmp = [env objectForKey:@"GNUSTEP_PATHLIST"];
  tmp = [tmp componentsSeparatedByString:@":"];
    
  for (i = 0, count = [tmp count]; i < count; i++) {
    p = [tmp objectAtIndex:i];
    p = [p stringByAppendingPathComponent:@"Library"];
    p = [p stringByAppendingPathComponent:@"Bundles"];
    if ([self->bundleSearchPaths containsObject:p]) continue;
      
    if (p) [self->bundleSearchPaths addObject:p];
  }
   
  /* New code for new gstep-make and gstep-base.  */
  tmp = NSStandardLibraryPaths();
  {
    NSEnumerator *e = [tmp objectEnumerator];
    while ((tmp = [e nextObject]) != nil) {
      tmp = [tmp stringByAppendingPathComponent:@"Bundles"];
      if ([self->bundleSearchPaths containsObject:tmp])
	continue;

      [self->bundleSearchPaths addObject:tmp];
    }
  }
}

- (void)_setupBundleSearchPathes {
  NSProcessInfo *pi;
  
  pi = [NSProcessInfo processInfo];
  
  /* setup bundle search path */

  self->bundleSearchPaths = [[NSMutableArray alloc] initWithCapacity:16];
  
  [self _addMainBundlePathToPathArray:self->bundleSearchPaths];
  [self _addBundlePathDefaultToPathArray:self->bundleSearchPaths];
  [self _addEnvironmentPathToPathArray:self->bundleSearchPaths];
  [self _addGNUstepPathsToPathArray:self->bundleSearchPaths];
  
#if DEBUG && NeXT_Foundation_LIBRARY && 0
  NSLog(@"%s: bundle search pathes:\n%@", __PRETTY_FUNCTION__, 
	self->bundleSearchPaths);
#endif
}

- (void)_registerLoadedBundles {
  NSEnumerator *currentBundles;
  NSBundle     *loadedBundle;

  currentBundles = [[NSBundle allBundles] objectEnumerator];
  while ((loadedBundle = [currentBundles nextObject]) != nil)
    [self registerBundle:loadedBundle classes:nil categories:nil];
}

- (void)_registerForBundleLoadNotification {
  [[NSNotificationCenter defaultCenter]
                         addObserver:self
                         selector:@selector(_bundleDidLoadNotifcation:)
                         name:@"NSBundleDidLoadNotification"
                         object:nil];
}

- (id)init {
#if GNUSTEP_BASE_LIBRARY
  if ([NSUserDefaults standardUserDefaults] == nil) {
    /* called inside setup process, deny creation (HACK) */
    [self release];
    return nil;
  }
#endif
  
  if ((self = [super init])) {
    self->classToBundle =
      NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                       NSNonRetainedObjectMapValueCallBacks,
                       32);
    self->classNameToBundle =
      NSCreateMapTable(NSObjectMapKeyCallBacks,
                       NSNonRetainedObjectMapValueCallBacks,
                       32);
    self->categoryNameToBundle =
      NSCreateMapTable(NSObjectMapKeyCallBacks,
                       NSNonRetainedObjectMapValueCallBacks,
                       32);
    self->pathToBundle =
      NSCreateMapTable(NSObjectMapKeyCallBacks,
                       NSNonRetainedObjectMapValueCallBacks,
                       32);
    self->pathToBundleInfo =
      NSCreateMapTable(NSObjectMapKeyCallBacks,
                       NSObjectMapValueCallBacks,
                       32);
    self->nameToBundle =
      NSCreateMapTable(NSObjectMapKeyCallBacks,
                       NSNonRetainedObjectMapValueCallBacks,
                       32);
    self->loadedBundles = 
      NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
                       NSObjectMapValueCallBacks,
                       32);
    
    [self _setupBundleSearchPathes];
    [self _registerLoadedBundles];
    [self _registerForBundleLoadNotification];
  }
  return self;
}

- (void)dealloc {
  [self->loadingBundles release];
  if (self->loadedBundles)        NSFreeMapTable(self->loadedBundles);
  if (self->classToBundle)        NSFreeMapTable(self->classToBundle);
  if (self->classNameToBundle)    NSFreeMapTable(self->classNameToBundle);
  if (self->categoryNameToBundle) NSFreeMapTable(self->categoryNameToBundle);
  if (self->pathToBundle)         NSFreeMapTable(self->pathToBundle);
  if (self->pathToBundleInfo)     NSFreeMapTable(self->pathToBundleInfo);
  if (self->nameToBundle)         NSFreeMapTable(self->nameToBundle);
  [self->bundleSearchPaths release];
  [super dealloc];
}

/* accessors */

- (void)setBundleSearchPaths:(NSArray *)_paths {
  ASSIGNCOPY(self->bundleSearchPaths, _paths);
}
- (NSArray *)bundleSearchPaths {
  return self->bundleSearchPaths;
}

/* registering bundles */

- (void)registerBundle:(NSBundle *)_bundle
  classes:(NSArray *)_classes
  categories:(NSArray *)_categories
{
  NSEnumerator *e;
  id v;

#if NeXT_RUNTIME || APPLE_RUNTIME
  v = [_bundle bundlePath];
  if ([v hasSuffix:@"Libraries"] || [v hasSuffix:@"Tools"]) {
    if (debugOn)
      fprintf(stderr, "INVALID BUNDLE: %s\n", [[_bundle bundlePath] cString]);
    return;
  }
#endif
  
#if 0
  NSLog(@"NGBundleManager: register loaded bundle %@", [_bundle bundlePath]);
#endif
  
  e = [_classes objectEnumerator];
  while ((v = [e nextObject]) != nil) {
#if NeXT_RUNTIME || APPLE_RUNTIME
    hookDoLookup = NO;
#endif

    NSMapInsert(self->classToBundle, NSClassFromString(v), _bundle);
    NSMapInsert(self->classNameToBundle, v, _bundle);
    
#if NeXT_RUNTIME || APPLE_RUNTIME
    hookDoLookup = YES;
#endif
  }
  
  e = [_categories objectEnumerator];
  while ((v = [e nextObject]) != nil)
    NSMapInsert(self->categoryNameToBundle, v, _bundle);
}

/* bundle locator */

- (NSString *)pathForBundleWithName:(NSString *)_name type:(NSString *)_type {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator  *e;
  NSString      *path;
  NSString      *bundlePath;
  NSBundle      *bundle;
  
  /* first check in table */
    

  bundlePath = [_name stringByAppendingPathExtension:_type];
  
  if ((bundle = NSMapGet(self->nameToBundle, bundlePath)))
    return [bundle bundlePath];
  
  e = [self->bundleSearchPaths objectEnumerator];
  while ((path = [e nextObject])) {
    BOOL isDir = NO;
    
    if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
      if (!isDir) continue;

      if ([[path lastPathComponent] isEqualToString:bundlePath]) {
        // direct match (a bundle was specified in the path)
        return path;
      }
      else {
        NSString *tmp;
        
        tmp = [path stringByAppendingPathComponent:bundlePath];
        if ([fm fileExistsAtPath:tmp isDirectory:&isDir]) {
          if (isDir)
            // found bundle
            return tmp;
        }
      }
    }
  }
  return nil;
}
 
/* getting bundles */

- (NSBundle *)bundleForClass:(Class)aClass {
  /* this method never loads a dynamic bundle (since the class is set up) */
  NSBundle *bundle;
  
  if (aClass == Nil)
    return nil;
  
  bundle = NSMapGet(self->classToBundle, aClass);

#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
  if (bundle == nil) {
    NSString *p;
    
    bundle = [NSBundle bundleForClass:aClass];
    if (bundle == [NSBundle mainBundle])
      bundle = nil;
    else {
      p = [bundle bundlePath];
      if ([p hasSuffix:@"Libraries"]) {
	if (debugOn) {
	  fprintf(stderr, "%s: Dylib bundle: 0x%p: %s\n",
		  __PRETTY_FUNCTION__,
		  bundle, [[bundle bundlePath] cString]);
	}
	bundle = nil;
      }
      else if ([p hasSuffix:@"Tools"]) {
	if (debugOn) {
	  fprintf(stderr, "%s: Tool bundle: 0x%p: %s\n",
		  __PRETTY_FUNCTION__,
		  bundle, [[bundle bundlePath] cString]);
	}
	bundle = nil;
      }
    }
  }
#endif
  if (bundle == nil) {
    /*
      if the class wasn't loaded from a bundle, it's *either* the main bundle
      or a bundle loaded before NGExtension was loaded !!!
    */

#if !LIB_FOUNDATION_LIBRARY && !GNUSTEP_BASE_LIBRARY
    // Note: incorrect behaviour if NGExtensions is dynamically loaded !
    // TODO: can we do anything about this? Can we detect the situation and
    //       print a log instead of the compile warning?
    // Note: the above refers to the situation when a framework is implicitly
    //       loaded by loading a bundle (the framework is not linked against
    //       the main tool)
#endif
    bundle = [NSBundle mainBundle];
    NSMapInsert(self->classToBundle,     aClass, bundle);
    NSMapInsert(self->classNameToBundle, NSStringFromClass(aClass), bundle);
  }
  return bundle;
}
- (NSBundle *)bundleWithPath:(NSString *)path {
  NSBundle *bundle = nil;
  NSString *bn;
  
  path = [path stringByResolvingSymlinksInPath];
  if (path == nil)
    return nil;
  
  if (debugOn) NSLog(@"find bundle for path: '%@'", path);
  bundle = NSMapGet(self->pathToBundle, path);
  
  if (bundle) {
    if (debugOn) NSLog(@"  found: %@", bundle);
    return bundle;
  }
  
  if ((bundle = [(NGBundle *)[NGBundle alloc] initWithPath:path]) == nil) {
    NSLog(@"ERROR(%s): could not create bundle for path: '%@'", 
	  __PRETTY_FUNCTION__, path);
    return nil;
  }
  
  bn = [[bundle bundleName]
                stringByAppendingPathExtension:[bundle bundleType]],
    
  NSMapInsert(self->pathToBundle, path, bundle);
  NSMapInsert(self->nameToBundle, bn,   bundle);
  return bundle;
}

- (NSBundle *)bundleWithName:(NSString *)_name type:(NSString *)_type {
  NSBundle *bundle;
  NSString *bn;

  bn     = [_name stringByAppendingPathExtension:_type];
  bundle = NSMapGet(self->nameToBundle, bn);
  
  if (![bundle isNotNull]) {
    bundle = [self bundleWithPath:
		     [self pathForBundleWithName:_name type:_type]];
  }
  
  if (![bundle isNotNull]) /* NSNull is used to signal missing bundles */
    return nil;
  
  if (![[bundle bundleType] isEqualToString:_type])
    return nil;
  
  /* bundle matches */
  return bundle;
}
- (NSBundle *)bundleWithName:(NSString *)_name {
  return [self bundleWithName:_name type:@"bundle"];
}

- (NSBundle *)bundleForClassNamed:(NSString *)_className {
  NSString *path   = nil;
  NSBundle *bundle = nil;

  if (_className == nil)
    return nil;

  /* first check in table */
  
  if ((bundle = NSMapGet(self->classNameToBundle, _className)) != nil)
    return bundle;
  
  path = [self pathForBundleProvidingResource:_className
               ofType:@"classes"
               resourceSelector:_selectClassByVersion
               context:NULL /* version */];
  if (path != nil) {
    path = [path stringByResolvingSymlinksInPath];
    NSAssert(path, @"couldn't resolve symlinks in path ..");
  }

  if (path == nil)
    return nil;
  
  if ((bundle = [self bundleWithPath:path]) != nil)
    NSMapInsert(self->classNameToBundle, _className, bundle);

  return bundle;
}

// dependencies

+ (NSInteger)version {
  return 2;
}

- (NSArray *)bundlesRequiredByBundle:(NSBundle *)_bundle {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (NSArray *)classesProvidedByBundle:(NSBundle *)_bundle {
  return [[_bundle providedResourcesOfType:@"classes"] valueForKey:@"name"];
}
- (NSArray *)classesRequiredByBundle:(NSBundle *)_bundle {
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

/* initialization */

- (NSString *)makeBundleInfoPath:(NSString *)_path {
#if (NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY) && !defined(GSWARN)
  return [[[_path stringByAppendingPathComponent:@"Contents"]
                  stringByAppendingPathComponent:@"Resources"]
                  stringByAppendingPathComponent:@"bundle-info.plist"];
#else
  return [_path stringByAppendingPathComponent:@"bundle-info.plist"];
#endif
}

- (id)_initializeLoadedBundle:(NSBundle *)_bundle
  info:(NSDictionary *)_bundleInfo
{
  id handler;
  
  /* check whether a handler was specified */
  
  if ((handler = [_bundleInfo objectForKey:@"bundleHandler"]) != nil) {
    [self debugWithFormat:@"lookup bundle handler %@ of bundle: %@",
	    handler, _bundle];
    
    if ((handler = NSClassFromString(handler)) == nil) {
      NSLog(@"ERROR: did not find handler class %@ of bundle %@.",
            [_bundleInfo objectForKey:@"bundleHandler"], [_bundle bundlePath]);
      handler = [_bundle principalClass];
    }
    
    handler = [handler alloc];
    
    if ([handler respondsToSelector:@selector(initForBundle:bundleManager:)])
      handler = [handler initForBundle:_bundle bundleManager:self];
    else
      handler = [handler init];
    handler = [handler autorelease];
    
    if (handler == nil) {
      NSLog(@"ERROR: could not instantiate handler class %@ of bundle %@.",
            [_bundleInfo objectForKey:@"bundleHandler"], [_bundle bundlePath]);
      handler = [_bundle principalClass];
    }
  }
  else {
    [self debugWithFormat:
	    @"no bundle handler, lookup principal class of bundle: %@",
	    _bundle];
    if ((handler = [_bundle principalClass]) == nil) {
      /* use NGBundle class as default bundle handler */
#if !(NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY)
      [self warnWithFormat:@"bundle has no principal class: %@", _bundle];
#endif
      handler = [NGBundle class];
    }
    else
      [self debugWithFormat:@"  => %@", handler];
  }
  
  return handler;
}

/* loading */

- (NSDictionary *)_loadBundleInfoAtExistingPath:(NSString *)_path {
  NSDictionary *bundleInfo;
  id info;

#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
  bundleInfo = NGParsePropertyListFromFile(_path);
#else
  bundleInfo = [NSDictionary dictionaryWithContentsOfFile:_path];
#endif
  if (bundleInfo == nil) {
    NSLog(@"could not load bundle-info at path '%@' !", _path);
    return nil;
  }
  
  /* check required bundle manager version */
  info = [bundleInfo objectForKey:@"requires"];
  if ((info = [(NSDictionary *)info objectForKey:@"bundleManagerVersion"])) {
    if ([info intValue] > [[self class] version]) {
      /* bundle manager version does not match ... */
      return nil;
    }
  }
  NSMapInsert(self->pathToBundleInfo, _path, bundleInfo);
  return bundleInfo;
}

- (NSBundle *)_locateBundleForClassInfo:(NSDictionary *)_classInfo {
  NSString *className;
  NSBundle *bundle;
  
  if (_classInfo == nil)
    return nil;
  if ((className = [_classInfo objectForKey:@"name"]) == nil) {
    NSLog(@"ERROR: missing classname in bundle-info.plist class section !");
    return nil;
  }
  
  // TODO: do we need to check the runtime for already loaded classes?
  //       Yes, I think so. But avoid recursions
#if 0
#if APPLE_Foundation_LIBRARY || COCOA_Foundation_LIBRARY
  // TODO: HACK, see above. w/o this, we get issues.
  if ([className hasPrefix:@"NS"])
    return nil;
#endif
#endif
  
  if ((bundle = [self bundleForClassNamed:className]) == nil) {
#if 0 // class might be already loaded
    NSLog(@"ERROR: did not find class %@ required by bundle %@.",
          className, [_bundle bundlePath]);
#endif
  }
  
  if (debugOn)
    NSLog(@"CLASS %@ => BUNDLE %@", className, bundle);
  
  return bundle;
}
- (NSArray *)_locateBundlesForClassInfos:(NSEnumerator *)_classInfos {
  NSMutableArray *requiredBundles;
  NSDictionary   *i;
  
  requiredBundles = [NSMutableArray arrayWithCapacity:16];
  while ((i = [_classInfos nextObject]) != nil) {
    NSBundle *bundle;
    
    if ((bundle = [self _locateBundleForClassInfo:i]) == nil)
      continue;
    
    [requiredBundles addObject:bundle];
  }
  return requiredBundles;
}

- (BOOL)_preLoadBundle:(NSBundle *)_bundle info:(NSDictionary *)_bundleInfo {
  /* TODO: split up this huge method */
  NSDictionary   *requires;
  NSMutableArray *requiredBundles = nil;
  NSBundle       *requiredBundle  = nil;
  
  if (debugOn) NSLog(@"NGBundleManager: preload bundle: %@", _bundle);

  requires = [_bundleInfo objectForKey:@"requires"];
  
  if (requires == nil)
    /* invalid bundle info specified */
    return YES;

  /* load required bundles */
  {
    NSEnumerator *e;
    NSDictionary *i;

    /* locate required bundles */
    
    e = [[requires objectForKey:@"bundles"] objectEnumerator];
    while ((i = [e nextObject]) != nil) {
      NSString *bundleName;
      
      if (![i respondsToSelector:@selector(objectForKey:)]) {
        NSLog(@"ERROR(%s): invalid bundle-info of bundle %@ !!!\n"
              @"  requires-entry is not a dictionary: %@",
              __PRETTY_FUNCTION__, _bundle, i);
        continue;
      }
      
      if ((bundleName = [i objectForKey:@"name"])) {
        NSString *type;
        
        type = [i objectForKey:@"type"];
        if (type == nil) type = @"bundle";

        if ((requiredBundle = [self bundleWithName:bundleName type:type])) {
          if (requiredBundles == nil)
            requiredBundles = [NSMutableArray arrayWithCapacity:16];
          
          [requiredBundles addObject:requiredBundle];
        }
        else {
          NSLog(@"ERROR(NGBundleManager): did not find bundle '%@' (type=%@) "
		@"required by bundle %@.",
                bundleName, type, [_bundle bundlePath]);
	  continue;
        }
      }
      else
        NSLog(@"ERROR: error in bundle-info.plist of bundle %@", _bundle);
    }
  }
  
  /* load located bundles */
  {
    NSEnumerator *e;
    
    if (debugOn) {
      NSLog(@"NGBundleManager:   preload required bundles: %@",
	    requiredBundles);
    }
    
    e = [requiredBundles objectEnumerator];
    while ((requiredBundle = [e nextObject]) != nil) {
      Class bundleMaster;
      
      if ((bundleMaster = [self loadBundle:requiredBundle]) == Nil) {
        NSLog(@"ERROR: could not load bundle %@ (%@) required by bundle %@.",
              [requiredBundle bundlePath], requiredBundle,
	      [_bundle bundlePath]);
	continue;
      }
    }
  }

  /* load required classes */
  {
    NSArray *bundles;
    NSArray *reqClasses;
    
    reqClasses = [requires objectForKey:@"classes"];
    
    bundles = [self _locateBundlesForClassInfos:[reqClasses objectEnumerator]];
    if (requiredBundles == nil)
      requiredBundles = [NSMutableArray arrayWithCapacity:16];
    [requiredBundles addObjectsFromArray:bundles];
  }

  /* load located bundles */
  {
    NSEnumerator *e;
    
    e = [requiredBundles objectEnumerator];
    while ((requiredBundle = [e nextObject]) != nil) {
      Class bundleMaster;
      
      if ((bundleMaster = [self loadBundle:requiredBundle]) == Nil) {
        NSLog(@"ERROR: could not load bundle %@ (%@) required by bundle %@.",
              [requiredBundle bundlePath], requiredBundle,
	      [_bundle bundlePath]);
	continue;
      }
    }
  }

  /* check whether versions of classes match */
  {
    NSEnumerator *e;
    NSDictionary *i;

    e = [[requires objectForKey:@"classes"] objectEnumerator];
    while ((i = [e nextObject]) != nil) {
      NSString *className;
      Class clazz;

      if ((className = [i objectForKey:@"name"]) == nil)
        continue;

      if ((clazz = NSClassFromString(className)) == Nil)
        continue;
      
      if ([i objectForKey:@"exact-version"]) {
        int v;

        v = [[i objectForKey:@"exact-version"] intValue];
	
        if (v != [clazz version]) {
          NSLog(@"ERROR: required exact class match failed:\n"
                @"  class:            %@\n"
                @"  required version: %i\n"
                @"  loaded version:   %i\n"
                @"  bundle:           %@",
                className,
                v, [clazz version],
                [_bundle bundlePath]);
        }
      }
      else if ([i objectForKey:@"version"]) {
        int v;
        
        v = [[i objectForKey:@"version"] intValue];
        
        if (v > [clazz version]) {
          NSLog(@"ERROR: provided class does not match required version:\n"
                @"  class:                  %@\n"
                @"  least required version: %i\n"
                @"  loaded version:         %i\n"
                @"  bundle:                 %@",
                className,
                v, [clazz version],
                [_bundle bundlePath]);
        }
      }
    }
  }
  
  return YES;
}
- (BOOL)_postLoadBundle:(NSBundle *)_bundle info:(NSDictionary *)_bundleInfo {
  return YES;
}

- (id)loadBundle:(NSBundle *)_bundle {
  NSString     *path       = nil;
  NSDictionary *bundleInfo = nil;
  id bundleManager = nil;

#if DEBUG
  NSAssert(self->loadedBundles, @"missing loadedBundles hashmap ..");
#endif
  
  if ((bundleManager = NSMapGet(self->loadedBundles, _bundle)))
    return bundleManager;
  
  if (_bundle == [NSBundle mainBundle])
    return [NSBundle mainBundle];
  
  if ([self->loadingBundles containsObject:_bundle])
    // recursive call
    return nil;
  
  if (self->loadingBundles == nil)
    self->loadingBundles = [[NSMutableSet allocWithZone:[self zone]] init];
  [self->loadingBundles addObject:_bundle];

  path = [_bundle bundlePath];
  path = [self makeBundleInfoPath:path];

  if ((bundleInfo = NSMapGet(self->pathToBundleInfo, path)) == nil) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path])
      bundleInfo = [self _loadBundleInfoAtExistingPath:path];
  }
  
  if (![self _preLoadBundle:_bundle info:bundleInfo])
    goto done;

  if (debugOn) NSLog(@"NGBundleManager: will load bundle: %@", _bundle);
  if (![_bundle _loadForBundleManager:self])
    goto done;
  if (debugOn) NSLog(@"NGBundleManager: did load bundle: %@", _bundle);
  
  if (![self _postLoadBundle:_bundle info:bundleInfo])
    goto done;
  
  if ((bundleManager = 
       [self _initializeLoadedBundle:_bundle info:bundleInfo])) {
    NSMapInsert(self->loadedBundles, _bundle, bundleManager);
    
    if ([bundleManager respondsToSelector:
                         @selector(bundleManager:didLoadBundle:)])
      [bundleManager bundleManager:self didLoadBundle:_bundle];
  }
#if 0
  else {
    NSLog(@"ERROR(%s): couldn't initialize loaded bundle '%@'",
          __PRETTY_FUNCTION__, [_bundle bundlePath]);
  }
#endif
 done:
  [self->loadingBundles removeObject:_bundle];

  if (bundleManager) {
    if (bundleInfo == nil)
      bundleInfo = [NSDictionary dictionary];
    
    [[NSNotificationCenter defaultCenter]
                           postNotificationName:
                             NGBundleWasLoadedNotificationName
                           object:_bundle
                           userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                             self,          @"NGBundleManager",
                             bundleManager, @"NGBundleHandler",
                             bundleInfo,    @"NGBundleInfo",
                             nil]];
  }
  return bundleManager;
}

// manager

- (id)principalObjectOfBundle:(NSBundle *)_bundle {
  return (id)NSMapGet(self->loadedBundles, _bundle);
}

// resources

static BOOL _doesInfoMatch(NSArray *keys, NSDictionary *dict, NSDictionary *info)
{
  int i, count;

  for (i = 0, count = [keys count]; i < count; i++) {
    NSString *key;
    id kv, vv;

    key = [keys objectAtIndex:i];
    vv  = [info objectForKey:key];

    if (vv == nil) {
      /* info has no matching key */
      return NO;
    }

    kv = [dict objectForKey:key];
    if (![kv isEqual:vv])
      return NO;
  }
  return YES;
}

- (NSDictionary *)configForResource:(id)_resource ofType:(NSString *)_type
  providedByBundle:(NSBundle *)_bundle
{
  NSDictionary *bundleInfo = nil;
  NSString     *infoPath;
  NSEnumerator *providedResources;
  NSArray      *rnKeys = nil;
  int          rnKeyCount = 0;
  id           info;

  if ([_resource respondsToSelector:@selector(objectForKey:)]) {
    rnKeys     = [_resource allKeys];
    rnKeyCount = [rnKeys count];
  }
  
  infoPath = [self makeBundleInfoPath:[_bundle bundlePath]];

  /* check whether info is in cache */
  if ((bundleInfo = NSMapGet(self->pathToBundleInfo, infoPath)) == nil) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:infoPath])
      /* no bundle-info.plist available .. */
      return nil;

    /* load info */
    bundleInfo = [self _loadBundleInfoAtExistingPath:infoPath];
  }

  /* get provided resources config */
  
  providedResources =
    [[(NSDictionary *)[bundleInfo objectForKey:@"provides"] objectForKey:_type]
                  objectEnumerator];
  if (providedResources == nil) return nil;

  /* scan provided resources */
  
  while ((info = [providedResources nextObject])) {
    if (rnKeys) {
      if (!_doesInfoMatch(rnKeys, _resource, info))
        continue;
    }
    else {
      NSString *name;
      
      name = [[(NSDictionary *)info objectForKey:@"name"] stringValue];
      if (name == nil) continue;
      if (![name isEqualToString:_resource]) continue;
    }
    return info;
  }
  return nil;
}

- (void)_processInfoForProvidedResources:(NSDictionary *)info 
  ofType:(NSString *)_type path:(NSString *)path
  resourceName:(NSString *)_resourceName
  resourceSelector:(NGBundleResourceSelector)_selector
  context:(void *)_context
  andAddToResultArray:(NSMutableArray *)result
{
  NSEnumerator *providedResources = nil;
  if (info == nil) return;
  
  /* direct match (a bundle was specified in the path) */

  providedResources = [[(NSDictionary *)[info objectForKey:@"provides"]
                              objectForKey:_type]
                              objectEnumerator];
  info = nil;
  if (providedResources == nil) return;

  /* scan provide array */
  while ((info = [providedResources nextObject])) {
    NSString *name;
          
    if ((name = [[info objectForKey:@"name"] stringValue]) == nil)
      continue;

    if (_resourceName) {
      if (![name isEqualToString:_resourceName])
	continue;
    }
    if (_selector) {
      if (!_selector(_resourceName, _type, path, info, self, _context))
	continue;
    }
    
    [result addObject:path];
  }
}

- (NSArray *)pathsForBundlesProvidingResource:(NSString *)_resourceName
  ofType:(NSString *)_type
  resourceSelector:(NGBundleResourceSelector)_selector
  context:(void *)_context
{
  /* TODO: split up method */
  NSMutableArray *result = nil;
  NSFileManager  *fm;
  NSEnumerator   *e;
  NSString       *path;

  if (debugOn) {
    NSLog(@"BM LOOKUP pathes (%d bundles loaded): %@ / %@", 
          NSCountMapTable(self->loadedBundles), _resourceName, _type);
  }
  
  fm     = [NSFileManager defaultManager];
  result = [NSMutableArray arrayWithCapacity:64];
  
  // TODO: look in loaded bundles
  
  /* check physical pathes */
  
  e = [self->bundleSearchPaths objectEnumerator];
  while ((path = [e nextObject]) != nil) {
    NSEnumerator *dir;
    BOOL     isDir = NO;
    NSString *tmp, *bundleDirPath;
    id       info = nil;
    
    if (![fm fileExistsAtPath:path isDirectory:&isDir])
      continue;
      
    if (!isDir) continue;
      
    /* check whether an appropriate bundle is contained in 'path' */
	
    dir = [[fm directoryContentsAtPath:path] objectEnumerator];
    while ((bundleDirPath = [dir nextObject]) != nil) {
      NSDictionary *bundleInfo      = nil;
      NSEnumerator *providedResources = nil;
      NSString     *infoPath;
      id           info;
          
      bundleDirPath = [path stringByAppendingPathComponent:bundleDirPath];
      infoPath = [self makeBundleInfoPath:bundleDirPath];
	  
      // TODO: can we use _doesBundleInfo:path:providedResource:... ?
      if ((bundleInfo = NSMapGet(self->pathToBundleInfo, infoPath))==nil) {
	if (![fm fileExistsAtPath:infoPath])
	  continue;

	bundleInfo = [self _loadBundleInfoAtExistingPath:infoPath];
      }
      
      providedResources = 
	[[(NSDictionary *)[bundleInfo objectForKey:@"provides"]
			              objectForKey:_type]
	                              objectEnumerator];
      if (providedResources == nil) continue;
      
      /* scan 'provides' array */
      while ((info = [providedResources nextObject])) {
	NSString *name;
            
	name = [[(NSDictionary *)info objectForKey:@"name"] stringValue];
	if (name == nil) continue;
	
	if (_resourceName != nil) {
	  if (![name isEqualToString:_resourceName])
	    continue;
	}
	if (_selector != NULL) {
	  if (!_selector(name, _type, bundleDirPath, info, self, _context))
	    continue;
	}

	[result addObject:bundleDirPath];
	break;
      }
    }
    
    /* check for direct match (NGBundlePath element is a bundle) */
    
    tmp = [self makeBundleInfoPath:path];

    if ((info = NSMapGet(self->pathToBundleInfo, tmp)) == nil) {
      if ([fm fileExistsAtPath:tmp])
	info = [self _loadBundleInfoAtExistingPath:tmp];
    }
    
    [self _processInfoForProvidedResources:info ofType:_type path:path
	  resourceName:_resourceName resourceSelector:_selector
	  context:_context
	  andAddToResultArray:result];
  }
  
  if ([result count] == 0) {
    [self logWithFormat:
	    @"Note(%s): method does not search in loaded bundles for "
	    @"resources of type '%@'",
	    __PRETTY_FUNCTION__, _type];
  }
  
  return [[result copy] autorelease];
}

- (BOOL)_doesBundleInfo:(NSDictionary *)_bundleInfo path:(NSString *)_path
  provideResource:(id)_resourceName ofType:(NSString *)_type
  rnKeys:(NSArray *)_rnKeys
  resourceSelector:(NGBundleResourceSelector)_selector context:(void *)_context
{
  NSEnumerator *providedResources;
  NSDictionary *info;
  
  providedResources = 
    [[(NSDictionary *)[_bundleInfo objectForKey:@"provides"] 
                      objectForKey:_type] objectEnumerator];
  if (providedResources == nil) return NO;
  
  /* scan provide array */
  while ((info = [providedResources nextObject])) {
    if (_rnKeys != nil) {
      if (!_doesInfoMatch(_rnKeys, _resourceName, info))
        continue;
    }
    else {
      NSString *name;

      name = [[(NSDictionary *)info objectForKey:@"name"] stringValue];
      if (name == nil) continue;
      if (![name isEqualToString:_resourceName]) continue;
    }
    
    if (_selector != NULL) {
      if (!_selector(_resourceName, _type, _path, info, self, _context))
        continue;
    }
    
    /* all conditions applied (found) */
    return YES;
  }
  return NO;
}

- (NSString *)pathOfLoadedBundleProvidingResource:(id)_resourceName
  ofType:(NSString *)_type
  resourceSelector:(NGBundleResourceSelector)_selector context:(void *)_context
{
  NSMapEnumerator menum;
  NSString     *path;
  NSDictionary *bundleInfo;
  NSArray      *rnKeys;
  
  rnKeys = ([_resourceName respondsToSelector:@selector(objectForKey:)])
    ? [_resourceName allKeys]
    : (NSArray *)nil;
  
  menum = NSEnumerateMapTable(self->pathToBundleInfo);
  while (NSNextMapEnumeratorPair(&menum, (void *)&path, (void *)&bundleInfo)) {
    if (debugOn) {
      NSLog(@"check loaded bundle for resource %@: %@", _resourceName,
            path);
    }
    
    if ([self _doesBundleInfo:bundleInfo path:path
              provideResource:_resourceName ofType:_type rnKeys:rnKeys
              resourceSelector:_selector context:_context])
      /* strip bundle-info.plist name */
      return [path stringByDeletingLastPathComponent];
  }
  
  return nil;
}

- (NSString *)pathForBundleProvidingResource:(id)_resourceName
  ofType:(NSString *)_type
  resourceSelector:(NGBundleResourceSelector)_selector
  context:(void *)_context
{
  /* main path lookup method */
  // TODO: this method seriously needs some refactoring
  NSFileManager *fm;
  NSEnumerator  *e;
  NSString      *path;
  NSArray       *rnKeys = nil;
  int           rnKeyCount = 0;
  
  if (debugOn) {
    NSLog(@"BM LOOKUP path (%d bundles loaded): %@ / %@", 
          NSCountMapTable(self->loadedBundles), _resourceName, _type);
  }
  
  /* look in loaded bundles */
  
  path = [self pathOfLoadedBundleProvidingResource:_resourceName ofType:_type
               resourceSelector:_selector context:_context];
  if (path != nil) return path;
  
  /* look in filesystem */
  
  if ([_resourceName respondsToSelector:@selector(objectForKey:)]) {
    rnKeys     = [_resourceName allKeys];
    rnKeyCount = [rnKeys count];
  }
  
  fm = [NSFileManager defaultManager];
  e = [self->bundleSearchPaths objectEnumerator];
  while ((path = [e nextObject]) != nil) {
    NSEnumerator *dir;
    BOOL     isDir = NO;
    NSString *tmp;
    id       info = nil;
    
    if (![fm fileExistsAtPath:path isDirectory:&isDir])
      continue;
    
    if (!isDir) continue;
    
    /* check whether an appropriate bundle is contained in 'path' */
	
    dir = [[fm directoryContentsAtPath:path] objectEnumerator];
    while ((tmp = [dir nextObject]) != nil) {
      NSDictionary *bundleInfo      = nil;
      NSString     *infoPath;
      
      tmp      = [path stringByAppendingPathComponent:tmp];
      infoPath = [self makeBundleInfoPath:tmp];
      
      if (debugOn)
        NSLog(@"check path path=%@ info=%@", tmp, infoPath);
	  
      if ((bundleInfo = NSMapGet(self->pathToBundleInfo, infoPath)) == nil) {
        if (![fm fileExistsAtPath:infoPath])
          continue;

        bundleInfo = [self _loadBundleInfoAtExistingPath:infoPath];
      }
      if (debugOn)
        NSLog(@"found info for path=%@ info=%@: %@", tmp,infoPath,bundleInfo);
      
      if ([self _doesBundleInfo:bundleInfo path:tmp
                provideResource:_resourceName ofType:_type rnKeys:rnKeys
                resourceSelector:_selector context:_context])
        return tmp;
    }
    
    /* check for direct match */
      
    tmp = [self makeBundleInfoPath:path];

    if ((info = NSMapGet(self->pathToBundleInfo, tmp)) == nil) {
        if ([fm fileExistsAtPath:tmp])
          info = [self _loadBundleInfoAtExistingPath:tmp];
        else if (debugOn) {
          NSLog(@"WARNING(%s): did not find direct path '%@'",
                __PRETTY_FUNCTION__, tmp);
        }
    }
      
    if (info != nil) {
        // direct match (a bundle was specified in the path)
        NSEnumerator *providedResources;
        NSDictionary *provides;
        
        provides          = [(NSDictionary *)info objectForKey:@"provides"];
        providedResources = [[provides objectForKey:_type] objectEnumerator];
        info              = nil;
        if (providedResources == nil) continue;
        
        // scan provide array
        while ((info = [providedResources nextObject])) {
          if (rnKeys) {
            if (!_doesInfoMatch(rnKeys, _resourceName, info))
              continue;
          }
          else {
            NSString *name;

            name = [[(NSDictionary *)info objectForKey:@"name"] stringValue];
            if (name == nil) continue;
            if (![name isEqualToString:_resourceName]) continue;
          }

          if (_selector) {
            if (!_selector(_resourceName, _type, tmp, info, self, _context))
              continue;
          }
          /* all conditions applied */
          return tmp;
        }
    }
  }
  return nil;
}

- (NSBundle *)bundleProvidingResource:(id)_name ofType:(NSString *)_type {
  NSString *bp;
  
  if (debugOn) NSLog(@"BM LOOKUP: %@ / %@", _name, _type);
  
  bp = [self pathForBundleProvidingResource:_name
             ofType:_type
             resourceSelector:NULL context:nil];
  if ([bp length] == 0) {
#if (NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY) && HEAVY_DEBUG
    NSLog(@"%s: found no resource '%@' of type '%@' ...",
          __PRETTY_FUNCTION__, _resourceName, _resourceType);
#endif
    if (debugOn) NSLog(@"  did not find: %@ / %@", _name, _type);
    return nil;
  }
  
  if (debugOn) NSLog(@"  FOUND: %@", bp);
  return [self bundleWithPath:bp];
}

- (NSArray *)bundlesProvidingResource:(id)_resourceName
  ofType:(NSString *)_type
{
  NSArray        *paths;
  NSMutableArray *bundles;
  int i, count;

  paths = [self pathsForBundlesProvidingResource:_resourceName
                ofType:_type
                resourceSelector:NULL context:nil];
  
  count = [paths count];
  if (paths == nil) return nil;
  if (count == 0)   return paths;

  bundles = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++) {
    NSBundle *bundle;

    if ((bundle = [self bundleWithPath:[paths objectAtIndex:i]]))
      [bundles addObject:bundle];
  }
  return [[bundles copy] autorelease];
}

- (NSArray *)providedResourcesOfType:(NSString *)_resourceType
  inBundle:(NSBundle *)_bundle
{
  NSString     *path;
  NSDictionary *bundleInfo;
  
  path = [self makeBundleInfoPath:[_bundle bundlePath]];
  if (path == nil) return nil;
  
  /* retrieve bundle info dictionary */
  if ((bundleInfo = NSMapGet(self->pathToBundleInfo, path)) == nil)
    bundleInfo = [self _loadBundleInfoAtExistingPath:path];
  
  return [(NSDictionary *)[bundleInfo objectForKey:@"provides"] 
                                      objectForKey:_resourceType];
}

- (void)_addRegisteredProvidedResourcesOfType:(NSString *)_type
  toSet:(NSMutableSet *)_result
{
  NSMapEnumerator menum;
  NSString     *path;
  NSDictionary *bundleInfo;
  
  menum = NSEnumerateMapTable(self->pathToBundleInfo);
  while (NSNextMapEnumeratorPair(&menum, (void *)&path, (void *)&bundleInfo)) {
    NSArray *providedResources;
    
    if (debugOn)
      NSLog(@"check loaded bundle for resource types %@: %@", _type, path);
    
    providedResources = 
      [(NSDictionary *)[bundleInfo objectForKey:@"provides"]
                       objectForKey:_type];
    if (providedResources == nil) continue;

    [_result addObjectsFromArray:providedResources];
  }
}

- (NSArray *)providedResourcesOfType:(NSString *)_resourceType {
  NSMutableSet  *result = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator  *e;
  NSString      *path;
  
  result = [NSMutableSet setWithCapacity:128];
  
  /* scan loaded bundles */
  
  [self _addRegisteredProvidedResourcesOfType:_resourceType toSet:result];
  
  /* scan all bundle search paths */
  
  e = [self->bundleSearchPaths objectEnumerator];
  while ((path = [e nextObject]) != nil) {
    NSEnumerator *dir;
    BOOL     isDir = NO;
    NSString *tmp;
    id       info = nil;

    if (![fm fileExistsAtPath:path isDirectory:&isDir])
      continue;
    if (!isDir) continue;

    /* check whether an appropriate bundle is contained in 'path' */
    
    // TODO: move to own method
    dir = [[fm directoryContentsAtPath:path] objectEnumerator];
    while ((tmp = [dir nextObject]) != nil) {
      NSDictionary *bundleInfo      = nil;
      NSArray      *providedResources = nil;
      NSString     *infoPath;
          
      tmp = [path stringByAppendingPathComponent:tmp];
      infoPath = [self makeBundleInfoPath:tmp];
      
#if 0
      NSLog(@"  info path: %@", tmp);
#endif

      if ((bundleInfo = NSMapGet(self->pathToBundleInfo, infoPath)) == nil) {
        if (![fm fileExistsAtPath:infoPath])
          continue;

        bundleInfo = [self _loadBundleInfoAtExistingPath:infoPath];
      }

      providedResources = 
        [(NSDictionary *)[bundleInfo objectForKey:@"provides"]
                         objectForKey:_resourceType];
      if (providedResources == nil) continue;

      [result addObjectsFromArray:providedResources];
    }
    
    /* check for direct match */
      
    tmp = [self makeBundleInfoPath:path];

    if ((info = NSMapGet(self->pathToBundleInfo, tmp)) == nil) {
      if ([fm fileExistsAtPath:tmp])
        info = [self _loadBundleInfoAtExistingPath:tmp];
    }
      
    if (info != nil) {
      // direct match (a bundle was specified in the path)
      NSArray      *providedResources;
      NSDictionary *provides;

      provides          = [(NSDictionary *)info objectForKey:@"provides"];
      providedResources = [provides objectForKey:_resourceType];
      info = nil;
      if (providedResources == nil) continue;

      [result addObjectsFromArray:providedResources];
    }
  }
  return [result allObjects];
}

- (NSBundle *)bundleProvidingResourceOfType:(NSString *)_resourceType
  matchingQualifier:(EOQualifier *)_qual
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSEnumerator   *e;
  NSString       *path;

  /* foreach search path entry */
  
  e = [self->bundleSearchPaths objectEnumerator];
  while ((path = [e nextObject])) {
    BOOL isDir = NO;
    
    if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
      NSString *tmp;
      id info = nil;
      if (!isDir) continue;

      /* check whether an appropriate bundle is contained in 'path' */
      {
        NSEnumerator *dir;

        dir = [[fm directoryContentsAtPath:path] objectEnumerator];
        while ((tmp = [dir nextObject])) {
          NSDictionary *bundleInfo;
          NSArray      *providedResources;
          NSString     *infoPath;
          
          tmp      = [path stringByAppendingPathComponent:tmp];
          infoPath = [self makeBundleInfoPath:tmp];
          
          if ((bundleInfo=NSMapGet(self->pathToBundleInfo, infoPath)) == nil) {
            if (![fm fileExistsAtPath:infoPath])
              continue;

            bundleInfo = [self _loadBundleInfoAtExistingPath:infoPath];
          }
          
          bundleInfo        = [bundleInfo objectForKey:@"provides"];
          providedResources = [bundleInfo objectForKey:_resourceType];
          bundleInfo        = nil;
          if (providedResources == nil) continue;

          providedResources =
            [providedResources filteredArrayUsingQualifier:_qual];

          if ([providedResources count] > 0)
            return [self bundleWithPath:tmp];
        }
      }

      /* check for direct match */
      
      tmp = [self makeBundleInfoPath:path];

      if ((info = NSMapGet(self->pathToBundleInfo, tmp)) == nil) {
        if ([fm fileExistsAtPath:tmp])
          info = [self _loadBundleInfoAtExistingPath:tmp];
      }
      
      if (info) {
        // direct match (a bundle was specified in the path)
        NSArray      *providedResources;
        NSDictionary *provides;
        
        provides          = [(NSDictionary *)info objectForKey:@"provides"];
        providedResources = [provides objectForKey:_resourceType];
        info = nil;
        if (providedResources == nil) continue;

        providedResources =
          [providedResources filteredArrayUsingQualifier:_qual];

        if ([providedResources count] > 0)
          return [self bundleWithPath:path];
      }
    }
  }
  return nil;
}

- (NSBundle *)bundlesProvidingResourcesOfType:(NSString *)_resourceType
  matchingQualifier:(EOQualifier *)_qual
{
  NSMutableArray *bundles = nil;
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSEnumerator   *e;
  NSString       *path;

  bundles = [NSMutableArray arrayWithCapacity:128];

  /* foreach search path entry */
  
  e = [self->bundleSearchPaths objectEnumerator];
  while ((path = [e nextObject])) {
    BOOL isDir = NO;
    
    if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
      NSString *tmp;
      id info = nil;
      if (!isDir) continue;

      /* check whether an appropriate bundle is contained in 'path' */
      {
        NSEnumerator *dir;

        dir = [[fm directoryContentsAtPath:path] objectEnumerator];
        while ((tmp = [dir nextObject])) {
          NSDictionary *bundleInfo      = nil;
          NSArray      *providedResources = nil;
          NSString     *infoPath;
          
          tmp = [path stringByAppendingPathComponent:tmp];
          infoPath = [self makeBundleInfoPath:tmp];
          
          if ((bundleInfo=NSMapGet(self->pathToBundleInfo, infoPath)) == nil) {
            if (![fm fileExistsAtPath:infoPath])
              continue;

            bundleInfo = [self _loadBundleInfoAtExistingPath:infoPath];
          }
          
          bundleInfo        = [bundleInfo objectForKey:@"provides"];
          providedResources = [bundleInfo objectForKey:_resourceType];
          bundleInfo        = nil;
          if (providedResources == nil) continue;

          providedResources =
            [providedResources filteredArrayUsingQualifier:_qual];

          if ([providedResources count] > 0)
            [bundles addObject:[self bundleWithPath:tmp]];
        }
      }

      /* check for direct match */
      
      tmp = [self makeBundleInfoPath:path];

      if ((info = NSMapGet(self->pathToBundleInfo, tmp)) == nil) {
        if ([fm fileExistsAtPath:tmp])
          info = [self _loadBundleInfoAtExistingPath:tmp];
      }
      
      if (info) {
        // direct match (a bundle was specified in the path)
        NSArray      *providedResources;
        NSDictionary *provides;
        
        provides          = [(NSDictionary *)info objectForKey:@"provides"];
        providedResources = [provides objectForKey:_resourceType];
        info = nil;
        if (providedResources == nil) continue;

        providedResources =
          [providedResources filteredArrayUsingQualifier:_qual];

        if ([providedResources count] > 0)
          [bundles addObject:[self bundleWithPath:path]];
      }
    }
  }
  return [[bundles copy] autorelease];
}

/* notifications */

- (void)_bundleDidLoadNotifcation:(NSNotification *)_notification {
  NSDictionary *ui = [_notification userInfo];

#if 0
  NSLog(@"bundle %@ did load with classes %@",
        [[_notification object] bundlePath],
        [ui objectForKey:@"NSLoadedClasses"]);
#endif
  
  [self registerBundle:[_notification object]
        classes:[ui objectForKey:@"NSLoadedClasses"]
        categories:[ui objectForKey:@"NSLoadedCategories"]];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* NGBundleManager */

@implementation NSBundle(BundleManagerSupport)

+ (id)alloc {
  return [NGBundle alloc];
}
+ (id)allocWithZone:(NSZone *)zone {
  return [NGBundle allocWithZone:zone];
}

#if !(NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY)
//#warning remember, bundleForClass is not overridden !
#if 0
+ (NSBundle *)bundleForClass:(Class)aClass {
  return [[NGBundleManager defaultBundleManager] bundleForClass:aClass];
}
#endif
+ (NSBundle *)bundleWithPath:(NSString*)path {
  return [[NGBundleManager defaultBundleManager] bundleWithPath:path];
}
#endif

@end /* NSBundle(BundleManagerSupport) */

@implementation NSBundle(NGBundleManagerExtensions)

- (id)principalObject {
  return [[NGBundleManager defaultBundleManager]
                           principalObjectOfBundle:self];
}

- (NSArray *)providedResourcesOfType:(NSString *)_resourceType {
  return [[NGBundleManager defaultBundleManager]
                           providedResourcesOfType:_resourceType
                           inBundle:self];
}

- (NSString *)bundleName {
  return [[[self bundlePath] lastPathComponent] stringByDeletingPathExtension];
}

- (NSString *)bundleType {
  return [[self bundlePath] pathExtension];
}

- (NSArray *)providedClasses {
  return [[NGBundleManager defaultBundleManager] classesProvidedByBundle:self];
}

- (NSArray *)requiredClasses {
  return [[NGBundleManager defaultBundleManager] classesRequiredByBundle:self];
}

- (NSArray *)requiredBundles {
  return [[NGBundleManager defaultBundleManager] bundlesRequiredByBundle:self];
}

- (NSDictionary *)configForResource:(id)_resource ofType:(NSString *)_type {
  return [[NGBundleManager defaultBundleManager]
                           configForResource:_resource ofType:_type
                           providedByBundle:self];
}

/* loading */

- (BOOL)_loadForBundleManager:(NGBundleManager *)_manager {
  return [self load];
}

@end /* NSBundle(NGBundleManagerExtensions) */

@implementation NSBundle(NGLanguageResourceExtensions)

static BOOL debugLanguageLookup = NO;

// locating resources

- (NSString *)pathForResource:(NSString *)_name ofType:(NSString *)_ext
  inDirectory:(NSString *)_directory
  languages:(NSArray *)_languages
{
  NSFileManager *fm;
  NSString      *path = nil;
  int i, langCount;
  id (*objAtIdx)(id,SEL,int);
  
  if (debugLanguageLookup) {
    NSLog(@"LOOKUP(%s): %@ | %@ | %@ | %@", __PRETTY_FUNCTION__,
	  _name, _ext, _directory, [_languages componentsJoinedByString:@","]);
  }
  
  path = [self bundlePath];
  if ([_directory isNotNull]) {
    // TODO: should we change that?
    path = [path stringByAppendingPathComponent:_directory];
  }
  else {
#if (NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY)
    path = [path stringByAppendingPathComponent:@"Contents"];
#endif
    path = [path stringByAppendingPathComponent:@"Resources"];
  }
  
  if (debugLanguageLookup) NSLog(@"  BASE: %@", path);
  
  fm   = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:path])
    return nil;
  
  if (_ext != nil) _name = [_name stringByAppendingPathExtension:_ext];
  
  langCount = [_languages count];
  objAtIdx = (langCount > 0)
    ? (void*)[_languages methodForSelector:@selector(objectAtIndex:)]
    : NULL;

  for (i = 0; i < langCount; i++) {
    NSString *language;
    NSString *lpath;

    language = objAtIdx
      ? objAtIdx(_languages, @selector(objectAtIndex:), i)
      : [_languages objectAtIndex:i];

    language = [language stringByAppendingPathExtension:@"lproj"];
    lpath = [path stringByAppendingPathComponent:language];
    lpath = [lpath stringByAppendingPathComponent:_name];

    if ([fm fileExistsAtPath:lpath])
      return lpath;
  }
  
  if (debugLanguageLookup) 
    NSLog(@"  no language matched, check base: %@", path);

  /* now look into x.bundle/Resources/name.type */
  if ([fm fileExistsAtPath:[path stringByAppendingPathComponent:_name]])
    return [path stringByAppendingPathComponent:_name];

  return nil;
}

- (NSString *)pathForResource:(NSString *)_name ofType:(NSString *)_ext
  languages:(NSArray *)_languages
{
  NSString *path;

  path = [self pathForResource:_name ofType:_ext
               inDirectory:@"Resources"
               languages:_languages];
  if (path) return path;

  path = [self pathForResource:_name ofType:_ext
               inDirectory:nil
               languages:_languages];
  return path;
}

@end /* NSBundle(NGLanguageResourceExtensions) */

@implementation NGBundle

+ (id)alloc {
  return [self allocWithZone:NULL];
}
+ (id)allocWithZone:(NSZone*)zone {
  return NSAllocateObject(self, 0, zone);
}

- (id)initWithPath:(NSString *)__path {
  return [super initWithPath:__path];
}

/* loading */

- (BOOL)_loadForBundleManager:(NGBundleManager *)_manager {
  return [super load];
}

- (BOOL)load {
  NGBundleManager *bm;

  bm = [NGBundleManager defaultBundleManager];
  
  return [bm loadBundle:self] ? YES : NO;
}

+ (NSBundle *)bundleForClass:(Class)aClass {
  return [[NGBundleManager defaultBundleManager] bundleForClass:aClass];
}
+ (NSBundle *)bundleWithPath:(NSString*)path {
  return [[NGBundleManager defaultBundleManager] bundleWithPath:path];
}

#if GNUSTEP_BASE_LIBRARY

- (Class)principalClass {
  Class c;
  NSString *cname;
  
  if ((c = [super principalClass]) != Nil)
    return c;
  
  if ((cname = [[self infoDictionary] objectForKey:@"NSPrincipalClass"]) ==nil)
    return Nil;
  
  if ((c = NSClassFromString(cname)) != Nil)
    return c;
  
  NSLog(@"%s: did not find principal class named '%@' of bundle %@, dict: %@",
	__PRETTY_FUNCTION__, cname, self, [self infoDictionary]);
  return Nil;
}

/* description */

- (NSString *)description {
  char buffer[1024];
  
  sprintf (buffer,
	   "<%s %p fullPath: %s infoDictionary: %p loaded=%s>",
#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__) 
	   (char*)class_getName([self class]),
#else
	   (char*)object_get_class_name(self),
#endif
	   self,
	   [[self bundlePath] cString],
	   [self infoDictionary], 
	   self->_codeLoaded ? "yes" : "no");
  
  return [NSString stringWithCString:buffer];
}
#endif

@end /* NGBundle */
