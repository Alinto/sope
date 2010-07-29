/* 
   NSBundle.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Mircea Oancea <mircea@jupiter.elcom.pub.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#include <Foundation/common.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSPathUtilities.h>
#include <extensions/objc-runtime.h>

/*
 * Static class variables
 */

typedef struct {
    Class    class;
    Category *category;
} LoadingClassCategory;

static NSMapTable           *bundleClasses     = NULL; // class -> bundle mapping
static NSMapTable           *bundleNames       = NULL; // path  -> bundle mapping
static NSBundle             *mainBundle        = nil;  // application bundle
static LoadingClassCategory*load_Classes      = NULL; // used while loading
static int                  load_classes_size = 0;    // used while loading
static int                  load_classes_used = 0;    // used while loading

/*
 * Private API
 */

@interface NSBundle (PrivateAPI)
- (NSString*)pathForResource:(NSString*)name ofType:(NSString*)ext
  inDirectory:(NSString*)directory
  forLocalizations:(NSArray*)localizationNames;
@end

/*
 * NSBundle methods
 */

@implementation NSBundle

#if WITH_GNUSTEP
static BOOL useGNUstepEnv = YES;
#else
static BOOL useGNUstepEnv = NO;
#endif

/* Library resource directory */

+ (NSArray *)_resourcesSearchPathes {
    static NSArray *cachedPathes = nil;
    NSDictionary   *env;
    NSArray        *searchPaths;
    NSString       *resourcesPathsString = nil;
    id             resourcesPaths        = nil;
    static BOOL isRunning = NO;

    if (isRunning) {
        fprintf(stderr, "WARNING(%s): nested call to function! (probably "
                "some libFoundation setup issue)\n",
                __PRETTY_FUNCTION__);
        return nil;
    }
    
    if (cachedPathes != nil)
	return cachedPathes;
    
    isRunning = YES;
    env = [[NSProcessInfo processInfo] environment];
    
#if WITH_GNUSTEP
    {
	NSMutableArray *ma;
	id tmp;
	
	ma = [NSMutableArray arrayWithCapacity:16];
	if ((tmp = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"]) == nil)
	    tmp = [env objectForKey:@"GNUSTEP_PATHLIST"];
	tmp = [tmp componentsSeparatedByString:@":"];
	if ([tmp count] > 0) {
	    NSFileManager *fm;
	    int i;
	    
	    fm = [NSFileManager defaultManager];
	    for (i = 0; i < [tmp count]; i++) {
		NSString *p;
		
		p = [tmp objectAtIndex:i];
		p = [p stringByAppendingPathComponent:@"Libraries"];
		p = [p stringByAppendingPathComponent:@"Resources"];
		p = [p stringByAppendingPathComponent:@"libFoundation"];
		if ([ma containsObject:p]) continue;
		
		[ma addObject:p];
	    }
	}
	[ma addObject:@"/usr/local/share/libFoundation"];
	[ma addObject:@"/usr/share/libFoundation"];
	
	searchPaths = ma;
    }
#else
    searchPaths = [NSArray arrayWithObject:@RESOURCES_PATH];
#endif
    
    resourcesPathsString
        = [env objectForKey:@"LIB_FOUNDATION_RESOURCES_PATH"];
    if (resourcesPathsString) {
#if defined(__WIN32__)
        resourcesPaths=[resourcesPathsString componentsSeparatedByString:@";"];
#else
        resourcesPaths=[resourcesPathsString componentsSeparatedByString:@":"];
#endif
        resourcesPaths = AUTORELEASE([resourcesPaths mutableCopy]);
        [resourcesPaths addObjectsFromArray:searchPaths];
        searchPaths = resourcesPaths;
    }
    
    cachedPathes = [searchPaths copy];
    isRunning = NO;
    return cachedPathes;
}

+ (NSString*)_fileResourceNamed:(NSString*)fileName
  extension:(NSString*)extension
  inDirectory:(NSString*)directoryName
{
    NSFileManager  *fm;
    int            i, count;
    NSArray        *searchPaths;
    
    searchPaths = [self _resourcesSearchPathes];
    
    fm = [NSFileManager defaultManager];
    for (i = 0, count = [searchPaths count]; i < count; i++) {
	NSString *fullFilenamePath;
	NSString *p;
	
	p = [searchPaths objectAtIndex:i];
	p = [p stringByAppendingPathComponent:directoryName];
	p = [p stringByAppendingPathComponent:fileName];
	p = [p stringByAppendingPathExtension:extension];
	
        fullFilenamePath = [p stringByResolvingSymlinksInPath];
	if (fullFilenamePath == nil)
	    continue;
	if ([fullFilenamePath length] == 0)
	    continue;
	
	/* found it */
	if ([fm fileExistsAtPath:fullFilenamePath])
	    return fullFilenamePath;
    }
    return nil;
}

// Bundle initialization

+ (void)initialize
{
    if (bundleClasses == NULL) {
        bundleClasses =
            NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                             NSNonRetainedObjectMapValueCallBacks, 23);
    }
    if (bundleNames == NULL) {
        bundleNames = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                       NSNonRetainedObjectMapValueCallBacks, 23);
    }
}

// Load info for bundle

- (void)loadInfo
{
    NSString *file;

    if (self->infoDictionary)
        return;
    
    if (useGNUstepEnv)
	file = [self pathForResource:@"Info-gnustep" ofType:@"plist"];
    else
	file = [self pathForResource:@"Info" ofType:@"plist"];
    
    if (file)
        infoDictionary = RETAIN([[NSString stringWithContentsOfFile:file] 
                                    propertyList]);
    
    if (infoDictionary == nil)
        infoDictionary = [[NSDictionary alloc] init];
}

// Internal code loading

static int debugBundles = -1;

static void load_callback(Class class, Category* category)
{
    if (load_classes_used >= load_classes_size) {
        load_classes_size += 128;
        load_Classes = Realloc(load_Classes,
            load_classes_size*sizeof(LoadingClassCategory));
    }
    load_Classes[load_classes_used].class    = class;
    load_Classes[load_classes_used].category = category;

    if (debugBundles == -1) {
        debugBundles =
            [[NSUserDefaults standardUserDefaults] boolForKey:@"DebugBundles"]
            ? 1 : 0;
    }
    if (debugBundles) {
        if (category) {
            NSLog(@"dynamically loaded category %s(%s)",
                  class
                  ? (class->name ? class->name : "Nil")
                  : (category->class_name ? category->class_name : "<Nil>"),
                  category->category_name ? category->category_name : "<Nil>");
            if (class == NULL) {
                NSLog(@"WARNING: class %s of category %s wasn't resolved !",
                      category->class_name ? category->class_name : "<Nil>",
                      category->category_name?category->category_name:"<Nil>");
            }
        }
        else if (class) {
            NSLog(@"dynamically loaded class %s", class->name);
        }
    }
    load_classes_used++;
}

+ (BOOL)isFlattenedDirLayout 
{
    static BOOL  didCheck = NO;
    static BOOL  isFlattened = NO;
    NSDictionary *env;
    id           tmp;
    
    if (didCheck) return isFlattened;
    
    if (!useGNUstepEnv) {
	didCheck = YES;
	isFlattened = YES;
	return isFlattened;
    }
    
    env = [[NSProcessInfo processInfo] environment];
    tmp = [env objectForKey:@"GNUSTEP_FLATTENED"];
    tmp = [tmp lowercaseString];
    isFlattened = [tmp isEqual:@"yes"] || [tmp isEqual:@"1"];
    if (!isFlattened) {
	/* if no GNUstep env is set, assume flattened */
	if ([[env objectForKey:@"GNUSTEP_SYSTEM_ROOT"] length] == 0)
	    isFlattened = YES;
    }
    didCheck = YES;
    return isFlattened;
}

- (BOOL)loadCode
{
    extern int objc_load_module(const char*, void (*)(Class, Category*));
    void           *lookupCallback = NULL;
    int            i;
    NSFileManager  *fm;
    NSString       *file;
    NSString       *rfile;
    BOOL           status;
    NSDictionary   *environment;
    NSString       *tmp;
    BOOL           isFlattened;
    NSMutableArray *loadedClasses    = nil;
    NSMutableArray *loadedCategories = nil;
    
    if (self->codeLoaded)
        return YES;
    
    self->codeLoaded = YES;
    isFlattened = [NSBundle isFlattenedDirLayout];
    environment = useGNUstepEnv
	? [[NSProcessInfo processInfo] environment]
	: (NSDictionary *)nil;
    
    fm = [NSFileManager defaultManager];
    
    // Find file to load
    if ((file = [[self infoDictionary] objectForKey:@"NSExecutable"]) != nil) {
	if (!useGNUstepEnv || isFlattened) {
	    file = [fullPath stringByAppendingPathComponent:file];
	    if (useGNUstepEnv && ![fm fileExistsAtPath:file]) {
		/* this happens for combo-bundles in flattened environments */
		NSString *p;
		
		file = nil;
		if ((p = [self pathForResource:@"Info" ofType:@"plist"])) {
		    NSDictionary *info;
		    
		    info = [[NSDictionary alloc] initWithContentsOfFile:p];
		    p = [[info objectForKey:@"NSExecutable"] copy];
		    [info release];
		    file = [fullPath stringByAppendingPathComponent:p];
		    [p release];
		}
	    }
	}
	else {
	    NSString *tvar;
	    
	    tvar = [environment objectForKey:@"GNUSTEP_HOST_CPU"];
	    tmp  = [fullPath stringByAppendingPathComponent:tvar];
	    tvar = [environment objectForKey:@"GNUSTEP_HOST_OS"];
	    tmp  = [tmp stringByAppendingPathComponent:tvar];
	    tvar = [environment objectForKey:@"LIBRARY_COMBO"];
	    tmp  = [tmp stringByAppendingPathComponent:tvar];
	    
	    file = [tmp stringByAppendingPathComponent:file];
	}
    }
    else {
	fprintf(stderr, "has no exe\n");
	if (!useGNUstepEnv || isFlattened) {
	    tmp = [fullPath lastPathComponent];
	    tmp = [tmp stringByDeletingPathExtension];
	    file = [fullPath stringByAppendingPathComponent:tmp];
	}
	else {
	    tmp = [environment objectForKey:@"GNUSTEP_HOST_CPU"];
	    tmp = [fullPath stringByAppendingPathComponent:tmp];
	    tmp = [tmp stringByAppendingPathComponent:
			   [environment objectForKey:@"GNUSTEP_HOST_OS"]];
	    tmp = [tmp stringByAppendingPathComponent:
			   [environment objectForKey:@"LIBRARY_COMBO"]];
	    file = [tmp stringByAppendingPathComponent:
			    [[fullPath lastPathComponent] 
				       stringByDeletingPathExtension]];
	}
    }
    
    rfile = [file stringByResolvingSymlinksInPath];
    if (rfile != nil) {
	if (![fm fileExistsAtPath:rfile]) rfile = nil;
    }
    if (rfile == nil) {
        NSLog(@"%@: NSBundle: cannot find executable file %@%s",
	      [[NSProcessInfo processInfo] processName], 
	      file,
	      isFlattened ? " (flattened layout)" : " (combo layout)");
        return NO;
    }
    
    loadedClasses    = [NSMutableArray arrayWithCapacity:32];
    loadedCategories = [NSMutableArray arrayWithCapacity:32];
    
    // Prepare to keep classes/categories loaded
    load_classes_size = 128;
    load_classes_used = 0;
    load_Classes = Malloc(load_classes_size
                                * sizeof(LoadingClassCategory));
    
    lookupCallback = _objc_lookup_class;
    _objc_lookup_class = NULL;
#ifdef __CYGWIN32__
    file = [@"C:/cygwin" stringByAppendingString:file];
#if 0
    file = [[file componentsSeparatedByString:@"/"]
	          componentsJoinedByString:@"\\"];
#endif
#endif
    status = objc_load_module([file fileSystemRepresentation], load_callback);
    _objc_lookup_class = lookupCallback;
    
    if (status) {
        firstLoadedClass = Nil;
        
        for (i = 0; i < load_classes_used; i++) {
            // get first class from bundle
            if (firstLoadedClass == NULL) {
                if (load_Classes[i].category == NULL)
                    firstLoadedClass = load_Classes[i].class;
            }
            
            // TODO - call class/category load method
            
            // insert in bundle hash
            if (load_Classes[i].category == NULL)
                NSMapInsert(bundleClasses, load_Classes[i].class, self);
            
            // register for notification
            if (load_Classes[i].category == NULL) {
                NSString *className = nil;
                
                className = [NSString stringWithCStringNoCopy:
                                        (char *)(load_Classes[i].class->name)
                                      freeWhenDone:NO];
                [loadedClasses addObject:className];
            }
            else {
                NSString *className    = nil;
                NSString *categoryName = nil;

                if (load_Classes[i].class) {
                    className = [NSString stringWithCString:(char *)
                                            (load_Classes[i].class->name)];
                }
#if 0 // class of category
                else {
                    className = [NSString stringWithCString:
                                           load_Classes[i].category->class_name];
                }
#endif
                
                categoryName = [NSString stringWithCString:(char *)
                                  load_Classes[i].category->category_name];

                if (className) [loadedClasses addObject:className];
                [loadedCategories addObject:categoryName];
            }
        }
    }
    
    lfFree(load_Classes); load_Classes = NULL;

    if (status) {
      [[NSNotificationCenter defaultCenter] 
          postNotificationName:@"NSBundleDidLoadNotification"
          object:self
          userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                   loadedClasses,    @"NSLoadedClasses",
                                   loadedCategories, @"NSLoadedCategories",
                                   nil]];
    }
    return status;
}

- (BOOL)load
{
    /* load, as specified in MacOSX-S docs */
    return [self loadCode];
}

// Initializing an NSBundle 

static BOOL canReadDirectory(NSString* path)
{
    NSFileManager* fileManager = [NSFileManager defaultManager];
    BOOL isDirectory;

    if (![fileManager fileExistsAtPath:path isDirectory:&isDirectory]
        || !isDirectory)
        return NO;

    return [fileManager isReadableFileAtPath:path];
}

static BOOL canReadFile(NSString *path)
{
    NSFileManager* fileManager = [NSFileManager defaultManager];

    return [fileManager isReadableFileAtPath:path];
}

- (id)initWithPath:(NSString *)path
{
    NSBundle *old;

    path = [path stringByResolvingSymlinksInPath];
    if ((path == nil) || !canReadDirectory(path)) {
        RELEASE(self);
        return nil;
    }
    
    old = (NSBundle *)NSMapGet(bundleNames, path);
    if (old) {
        (void)AUTORELEASE(self);
        return RETAIN(old);
    }
    
    NSMapInsert(bundleNames, path, self);
    self->fullPath = RETAIN(path);
    return self;
}

#if 0 /* the thing below can result in a memory leak if -initWithPath:
         is used in client code ... */
// TODO - now bundle is not capable of dealloc & code unloading

- (id)retain
{
    return self;
}
- (id)autorelease
{
    return self;
}
- (void)release
{
}
- (unsigned int)retainCount
{
    return 1;
}
#endif

- (void)dealloc
{
    NSMapRemove(bundleNames, self->fullPath);
    RELEASE(self->fullPath);
    RELEASE(self->infoDictionary);
    RELEASE(self->stringTables);
    [super dealloc];
}

// Getting an NSBundle 

+ (NSArray *)allBundles
{
    NSMutableArray *bundles = [NSMutableArray arrayWithCapacity:64];
    NSMapEnumerator e;
    NSString *key;
    NSBundle *value;

    e = NSEnumerateMapTable(bundleNames);
    while (NSNextMapEnumeratorPair(&e, (void**)&key, (void**)&value))
        [bundles addObject:value];

    return AUTORELEASE([bundles copy]);
}
+ (NSArray *)allFrameworks
{
    return nil;
}

+ (NSBundle *)bundleForClass:(Class)aClass
{
    NSBundle *bundle;
    
    if ((bundle = (NSBundle *)NSMapGet(bundleClasses, aClass)))
        return bundle;
    
    return [self mainBundle];
}

+ (NSBundle *)bundleWithPath:(NSString *)path
{
    if (path) {
        NSBundle *bundle;

        /* look in cache */
        if ((bundle = (NSBundle *)NSMapGet(bundleNames, path)))
            return bundle;
    }
    return AUTORELEASE([[self alloc] initWithPath:path]);
}

+ (NSBundle *)mainBundle
{
    if (mainBundle == nil) {
        NSString *path = [[[[NSProcessInfo processInfo] arguments]
                              objectAtIndex:0]
                              stringByDeletingLastPathComponent];
        if ([path isEqual:@""])
            path = @".";
#if WITH_GNUSTEP
        else if (![NSBundle isFlattenedDirLayout]) {
            /* The path is the complete path to the executable, including the
               processor, the OS and the library combo. Strip these directories
               from the main bundle's path. */
            path = [[[path stringByDeletingLastPathComponent]
                           stringByDeletingLastPathComponent]
                           stringByDeletingLastPathComponent];
        }
#endif
        mainBundle = [[NSBundle alloc] initWithPath:path];
    }
    return mainBundle;
}

// Getting a Bundled Class 

- (Class)classNamed:(NSString *)className
{
    Class class;

    [self loadCode];
    
    class = NSClassFromString(className);
    if (class != Nil && (NSBundle*)NSMapGet(bundleClasses, class) == self)
        return class;

    return nil;
}

- (Class)principalClass
{
    NSString *className;
    Class    class;
    
    [self loadCode];
    
    className = [[self infoDictionary] objectForKey:@"NSPrincipalClass"];
    
    if ((class = NSClassFromString(className)) == Nil)
        class = firstLoadedClass;
    
    if (class) {
#if DEBUG
        if (NSMapGet(bundleClasses, class) != self) {
            NSLog(@"WARNING(%s): principal class %@ of bundle %@ "
                  @"is not a class of the bundle !",
                  __PRETTY_FUNCTION__, class, self);
        }
#endif
    }
    
    return class;
}

// Finding a Resource 

+ (NSString*)pathForResource:(NSString*)name ofType:(NSString*)ext
  inDirectories:(NSArray*)directories
{
    int i, n;
    NSString* file;
    CREATE_AUTORELEASE_POOL(pool);

    if (ext)
        name = [name stringByAppendingPathExtension:ext];
    
    n = [directories count];
    
    for (i = 0; i < n; i++) {
        file = [[directories objectAtIndex:i]
            stringByAppendingPathComponent:name];
        if (canReadFile(file))
            goto found;
    }
    
    file = nil;
    
    found:
    
    (void)RETAIN(file);
    RELEASE(pool);
    
    return AUTORELEASE(file);
}

- (NSString*)pathForResource:(NSString*)name ofType:(NSString*)ext
  inDirectory:(NSString*)directory
{
  NSArray *languages = [[NSUserDefaults standardUserDefaults] 
                                        stringArrayForKey:@"Languages"]; 
  return [self pathForResource:name ofType:ext inDirectory:directory
               forLocalizations:languages];
}

- (NSString*)pathForResource:(NSString*)name ofType:(NSString*)ext
  inDirectory:(NSString*)directory
  forLocalization:(NSString*)localizationName
{
  NSArray *languages = nil;

  if(localizationName) {
    languages = [NSArray arrayWithObject:localizationName];
  }
  return [self pathForResource:name ofType:ext inDirectory:directory
              forLocalizations:languages];
  
}

- (NSString*)pathForResource:(NSString*)name ofType:(NSString*)ext
  inDirectory:(NSString*)directory
  forLocalizations:(NSArray*)localizationNames
{
    int i, n;
    NSString* path;
    NSString* file;
    NSMutableArray* languages;
    CREATE_AUTORELEASE_POOL(pool);
    
    // Translate list by adding "lproj" extension
    // {English, German, ...} to {English.lproj, German.lproj, ...}
    languages = AUTORELEASE([localizationNames mutableCopy]);
    if(languages)
      n = [languages count];
    else
      n = 0;
    for (i = 0; i < n; i++) {
        file = [[languages objectAtIndex:i] 
            stringByAppendingPathExtension:@"lproj"];
        [languages replaceObjectAtIndex:i withObject:file];
    }
    
    // make file name name.ext if extension is present
    if (ext)
        name = [name stringByAppendingPathExtension:ext];
    
    // look for fullPath/Resources/directory/...
    path = [fullPath stringByAppendingPathComponent:@"Resources"];
    if (directory && ![directory isEqualToString:@""])
        path = [path stringByAppendingPathComponent:directory];
    if (canReadDirectory(path)) {
        // check languages
        for (i = 0; i < n; i++) {
            file = [[path stringByAppendingPathComponent:
                [languages objectAtIndex:i]]
                    stringByAppendingPathComponent:name];
            if (canReadFile(file))
                goto found;
        }
        // check base
        file = [path stringByAppendingPathComponent:name];
        if (canReadFile(file))
            goto found;
    }
    
    // look for fullPath/directory/...
    if (directory && ![directory isEqualToString:@""])
        path = [fullPath stringByAppendingPathComponent:directory];
    else
        path = fullPath;
    if (canReadDirectory(path)) {
        // check languages
        for (i = 0; i < n; i++) {
            file = [[path stringByAppendingPathComponent:
                [languages objectAtIndex:i]]
                    stringByAppendingPathComponent:name];
            if (canReadFile(file))
                goto found;
        }
        // check base
        file = [path stringByAppendingPathComponent:name];
        if (canReadFile(file))
            goto found;
    }

    file = nil;
    
found:
    
    (void)RETAIN(file);
    RELEASE(pool);
    
    return AUTORELEASE(file);
}

- (NSArray *)pathsForResourcesOfType:(NSString *)extension
  inDirectory:(NSString *)bundlePath
{
  return [self pathsForResourcesOfType:extension inDirectory:bundlePath
               forLocalization:nil];
}

- (NSArray *)pathsForResourcesOfType:(NSString *)extension
  inDirectory:(NSString *)bundlePath
  forLocalization:(NSString *)localizationName
{
    NSFileManager  *fm;
    NSMutableArray *result = nil;
    NSString       *path, *mainPath;
    NSEnumerator   *contents;

    fm     = [NSFileManager defaultManager];
    result = [[NSMutableArray alloc] initWithCapacity:32];

    /* look in bundle/Resources/$bundlePath/name.$extension */
    mainPath = [self resourcePath];
    if (bundlePath)
        mainPath = [mainPath stringByAppendingPathComponent:bundlePath];
    contents = [[fm directoryContentsAtPath:mainPath] objectEnumerator];
    while ((path = [contents nextObject])) {
        if ([[path pathExtension] isEqualToString:extension])
            [result addObject:path];
    }

#if 0 // to be completed
    /* look in bundle/Resources/$bundlePath/$Language.lproj/name.$extension */
    mainPath = [self resourcePath];
    if (bundlePath)
        mainPath = [mainPath stringByAppendingPathComponent:bundlePath];
    contents = [[fm directoryContentsAtPath:mainPath] objectEnumerator];
    while ((path = [contents nextObject])) {
        if ([[path pathExtension] isEqualToString:extension])
            [result addObject:path];
    }
#endif

    /* look in bundle/$bundlePath/name.$extension */
    mainPath = self->fullPath;
    if (bundlePath)
        mainPath = [mainPath stringByAppendingPathComponent:bundlePath];
    contents = [[fm directoryContentsAtPath:mainPath] objectEnumerator];
    while ((path = [contents nextObject])) {
        if ([[path pathExtension] isEqualToString:extension])
            [result addObject:path];
    }

#if 0 // to be completed
    /* look in bundle/$bundlePath/$Language.lproj/name.$extension */
    mainPath = self->fullPath;
    if (bundlePath)
        mainPath = [mainPath stringByAppendingPathComponent:bundlePath];
    contents = [[fm directoryContentsAtPath:mainPath] objectEnumerator];
    while ((path = [contents nextObject])) {
        if ([[path pathExtension] isEqualToString:extension])
            [result addObject:path];
    }
#endif
    {
        NSArray *tmp;
        tmp = [result copy];
        RELEASE(result); result = nil;
        return AUTORELEASE(tmp);
    }
}

- (NSString*)pathForResource:(NSString*)name ofType:(NSString*)ext
{
    return [self pathForResource:name ofType:ext inDirectory:nil];
}

- (NSString*)resourcePath
{
    return [fullPath stringByAppendingPathComponent:@"Resources"];
}

// Getting bundle information

- (NSDictionary*)infoDictionary
{
    [self loadInfo];
    return infoDictionary;
}

// Getting the Bundle Directory 

- (NSString*)bundlePath
{
    return fullPath;
}

// Managing Localized Resources

- (NSString*)localizedStringForKey:(NSString*)key value:(NSString*)value
  table:(NSString*)tableName
{
    NSDictionary* table;
    NSString* string;

    if (!stringTables)
        stringTables = [NSMutableDictionary new];
    
    table = [stringTables objectForKey:tableName];
    if (!table) {
        string = [NSString stringWithContentsOfFile:
                [self pathForResource:tableName ofType:@"strings"]];
        if (!string)
                return value;
        table = [string propertyListFromStringsFileFormat];
        if (table)
            [stringTables setObject:table forKey:tableName];
    }

    string = [table objectForKey:key];
    if (!string)
        string = value;

    return string;
}

- (void)releaseStringtableCache
{
    RELEASE(stringTables);
    stringTables = nil;
}

- (NSString *)description
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[1024];
    
    sprintf (buffer,
             "<%s %p fullPath: %s infoDictionary: %p loaded=%s>",
             (char*)object_get_class_name(self),
             self,
             fullPath ? [fullPath cString] : "nil",
             infoDictionary, self->codeLoaded ? "yes" : "no");

    return [NSString stringWithCString:buffer];
}

@end /* NSBundle */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
