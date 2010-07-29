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

#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOComponentDefinition.h>
#include "WOComponent+private.h"
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOApplication.h>
#include "common.h"
#import <Foundation/NSNull.h>
#include "_WOStringTable.h"

/*
  Component Discovery and Page Creation

    All WO code uses either directly or indirectly the WOResourceManager's
    -pageWithName:languages: method to instantiate WO components.

    This methods works in three steps:
      
      1. discovery of files associated with the component
      
      2. creation of a proper WOComponentDefinition, which is some kind
         of 'blueprint' or 'class' for components
      
      3. component instantiation using the definition
    
    All the instantiation/setup work is done by a component definition, the
    resource manager is only responsible for managing those 'blueprint'
    resources.

    If you want to customize component creation, you can supply your
    own WOComponentDefinition in a subclass of WOResourceManager by
    overriding:
      - (WOComponentDefinition *)definitionForComponent:(id)_name
        inFramework:(NSString *)_frameworkName
        languages:(NSArray *)_languages
*/

/* 
   Note: this was #if !COMPILE_FOR_GSTEP_MAKE - but there is no difference
         between Xcode and gstep-make?!
	 The only possible difference might be that .wo wrappers are directly
	 in the bundle/framework root - but this doesn't relate to Resources.
	 
	 OK, this breaks gstep-make based template lookup which places .wo
	 wrappers in .woa/Resources/xxx.wo.
	 This is an issue because .wox are looked up in Contents/Resources
	 but .wo ones in just Resources.
	 
	 This issue should be fixed in recent woapp-gs.make ...
   
   Update: since for SOPE 4.3 we only work with gstep-make 1.10, this seems to
           be fixed?
*/
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
#  define RSRCDIR_CONTENTS 1
#endif

@implementation WOResourceManager

+ (int)version {
  return 4;
}

static Class    UrlClass             = Nil;
static NSString *resourcePrefix      = @"";
static NSString *rapidTurnAroundPath = nil;
static NSString *suffix              = nil;
static NSNull   *null                = nil;
static BOOL     debugOn                 = NO;
static BOOL     debugComponentLookup    = NO;
static BOOL     debugResourceLookup     = NO;
static BOOL     genMissingResourceLinks = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL isInitialized = NO;
  NSDictionary *defs;
  if (isInitialized) return;
  isInitialized = YES;
    
  null = [[NSNull null] retain];
  UrlClass = [NSURL class];
  
  defs = [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSArray arrayWithObject:@"wo"],
                         @"WOComponentExtensions",
                       nil];
  [ud registerDefaults:defs];
  debugOn                 = [WOApplication isDebuggingEnabled];
  debugComponentLookup    = [ud boolForKey:@"WODebugComponentLookup"];
  debugResourceLookup     = [ud boolForKey:@"WODebugResourceLookup"];
  genMissingResourceLinks = [ud boolForKey:@"WOGenerateMissingResourceLinks"];
  rapidTurnAroundPath     = [[ud stringForKey:@"WOProjectDirectory"]  copy];
  suffix                  = [[ud stringForKey:@"WOApplicationSuffix"] copy];
}

static inline BOOL
_pathExists(WOResourceManager *self, NSFileManager *fm, NSString *path)
{
  BOOL doesExist;
  
  if (self->existingPathes && (path != nil)) {
    int i;
    
    i = (int)(long)NSMapGet(self->existingPathes, path);
    if (i == 0) {
      doesExist = [fm fileExistsAtPath:path];
      NSMapInsert(self->existingPathes, path,
		  (void *)(doesExist ? 1L : 0xFFL));
    }
    else
      doesExist = i == 1 ? YES : NO;
  }
  else
    doesExist = [fm fileExistsAtPath:path];
  return doesExist;
}

+ (void)setResourcePrefix:(NSString *)_prefix {
  [resourcePrefix autorelease];
  resourcePrefix = [_prefix copy];
}
  
- (id)initWithPath:(NSString *)_path {
#if __APPLE__
  if ([_path length] == 0) {
    [self errorWithFormat:@"(%s): missing path!", __PRETTY_FUNCTION__];
    /* this doesn't work with subclasses which do not require a path ... */
#if 0
    [self release];
    return nil;
#endif
  }
#endif
  
  if ((self = [super init])) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSString *rprefix = nil;
    NSString *tmp;
    
    self->componentDefinitions =
      NSCreateMapTable(NSObjectMapKeyCallBacks,
                       NSObjectMapValueCallBacks,
                       128);
    self->stringTables = 
      NSCreateMapTable(NSObjectMapKeyCallBacks,
                       NSObjectMapValueCallBacks,
                       16);
    
    tmp = [_path stringByStandardizingPath];
    if (tmp) _path = tmp;
    
    self->base = [_path copy];
    
    if ([WOApplication isCachingEnabled]) {
      self->existingPathes = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                              NSIntMapValueCallBacks,
                                              256);
    }
    
    rprefix = [ud stringForKey:@"WOResourcePrefix"];
    if (rprefix) [[self class] setResourcePrefix:rprefix];
  }
  return self;
}
- (id)init {
  return [self initWithPath:[[NGBundle mainBundle] bundlePath]];
}

- (void)dealloc {
  if (self->existingPathes)       NSFreeMapTable(self->existingPathes);
  if (self->stringTables)         NSFreeMapTable(self->stringTables);
  if (self->componentDefinitions) NSFreeMapTable(self->componentDefinitions);
  if (self->keyedResources)       NSFreeMapTable(self->keyedResources);
  [self->w3resources release];
  [self->resources   release];
  [self->base        release];
  [super dealloc];
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}
- (NSString *)loggingPrefix {
  char buf[32];
  sprintf(buf, "[wo-rm-0x%p]", self);
  return [NSString stringWithCString:buf];
}

/* path methods */

- (NSFileManager *)fileManager {
  static NSFileManager *fm = nil;
  if (fm == nil)
    fm = [[NSFileManager defaultManager] retain];
  return fm;
}

- (NSString *)basePath {
  return self->base;
}

- (NSString *)resourcesPath {
  NSFileManager *fm;
  
  if (self->resources)
    return self->resources;
  
  fm = [self fileManager];
  if ([self->base length] > 0) {
    if (![fm fileExistsAtPath:self->base]) {
      [self warnWithFormat:@"(%s): Resources base path '%@' does not exist !",
              __PRETTY_FUNCTION__, self->base];
      return nil;
    }
  }
  
#if RSRCDIR_CONTENTS
  if ([rapidTurnAroundPath length] > 0) {
    /* 
      In rapid turnaround mode, first check for a Resources subdir in the
      project directory, then directly in the project dir.
      Note: you cannot have both! Either put stuff in a Resources subdir *or*
            in the project dir.
    */
    NSString *tmp;
    BOOL isDir;
    
    tmp = [rapidTurnAroundPath stringByAppendingPathComponent:@"Resources"];
    if (![fm fileExistsAtPath:tmp isDirectory:&isDir])
      isDir = NO;
    if (!isDir)
      tmp = rapidTurnAroundPath;
    
    self->resources = [tmp copy];
  }
  else {
    self->resources =
      [[[self->base stringByAppendingPathComponent:@"Contents"]
                    stringByAppendingPathComponent:@"Resources"] 
                    copy];
  }
#else
  self->resources =
    [[self->base stringByAppendingPathComponent:@"Resources"] copy];
#endif
  
  if ([self->resources length] > 0) {
    if (![fm fileExistsAtPath:self->resources]) {
      [self warnWithFormat:
              @"(%s): Resources path %@ does not exist !",
              __PRETTY_FUNCTION__, self->resources];
      [self->resources release]; self->resources = nil;
    }
    else if (self->existingPathes && (self->resources != nil))
      NSMapInsert(self->existingPathes, self->resources, (void*)1);
  }
  return self->resources;
}

- (NSString *)resourcesPathForFramework:(NSString *)_fw {
  if (_fw == nil || (_fw == rapidTurnAroundPath)) 
    return [self resourcesPath];
  
#if RSRCDIR_CONTENTS
  return [[_fw stringByAppendingPathComponent:@"Contents"]
               stringByAppendingPathComponent:@"Resources"];
#else
  return [_fw stringByAppendingPathComponent:@"Resources"];
#endif
}

- (NSString *)webServerResourcesPath {
  NSFileManager *fm;
  
  if (self->w3resources)
    return self->w3resources;

#if GNUSTEP_BASE_LIBRARY && 0
  self->w3resources =
    [[self->base stringByAppendingPathComponent:@"Resources/WebServer"] copy];
#else  
  self->w3resources =
    [[self->base stringByAppendingPathComponent:@"WebServerResources"] copy];
#endif
  
  fm = [self fileManager];
  if ([self->w3resources length] == 0)
    return nil;
  
  if (![fm fileExistsAtPath:self->w3resources]) {
    static BOOL didLog = NO;
    if (!didLog) {
      didLog = YES;
      [self warnWithFormat:
              @"(%s): WebServerResources path '%@' does not exist !",
              __PRETTY_FUNCTION__, self->w3resources];
    }
    [self->w3resources release]; self->w3resources = nil;
  }
  else if (self->existingPathes && (self->w3resources != nil))
    NSMapInsert(self->existingPathes, self->w3resources, (void*)1);
  
  if (debugResourceLookup)
    [self logWithFormat:@"WebServerResources: '%@'", self->w3resources];
  return self->w3resources;
}

- (NSString *)pathForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
{
  NSFileManager *fm;
  NSString      *resource = nil;
  unsigned      langCount;
  NSString      *w3rp, *rp;
  
  if (debugResourceLookup) {
    [self logWithFormat:@"lookup '%@' bundle=%@ languages=%@", 
          _name, _frameworkName, [_languages componentsJoinedByString:@","]];
  }
  
  fm        = [self fileManager];
  langCount = [_languages count];
  
  if ((w3rp = [self webServerResourcesPath]) != nil) {
    NSString *langPath = nil;
    unsigned i;
    
    if (debugResourceLookup)
      [self logWithFormat:@"  WebServerResources: %@", w3rp];
    
    // first check Language.lproj in WebServerResources
    for (i = 0; i < langCount; i++) {
      langPath = [_languages objectAtIndex:i];
      langPath = [langPath stringByAppendingPathExtension:@"lproj"];
      langPath = [w3rp stringByAppendingPathComponent:langPath];
      
      if (!_pathExists(self, fm, langPath)) {
        if (debugResourceLookup) {
          [self logWithFormat:
                  @"  no language project for '%@' in WebServerResources: %@",
                  [_languages objectAtIndex:i], langPath];
        }
        continue;
      }
      
      resource = [langPath stringByAppendingPathComponent:_name];
      
      if (debugResourceLookup) 
        [self logWithFormat:@"  check in WebServerResources: %@", resource];
      if (_pathExists(self, fm, resource))
        return resource;
    }
    
    /* next check in WebServerResources itself */
    resource = [w3rp stringByAppendingPathComponent:_name];
    if (debugResourceLookup) 
      [self logWithFormat:@"  check in WebServerResources-flat: %@", resource];
    if (_pathExists(self, fm, resource))
      return resource;
  }
  
  if ((rp = [self resourcesPathForFramework:_frameworkName])) {
    NSString *langPath = nil;
    unsigned i;
    
    if (debugResourceLookup) [self logWithFormat:@"  path %@", rp];
    
    // first check Language.lproj in Resources
    for (i = 0; i < langCount; i++) {
      langPath = [_languages objectAtIndex:i];
      langPath = [langPath stringByAppendingPathExtension:@"lproj"];
      langPath = [rp stringByAppendingPathComponent:langPath];
      
      if (_pathExists(self, fm, langPath)) {
        resource = [langPath stringByAppendingPathComponent:_name];

        if (debugResourceLookup) 
          [self logWithFormat:@"  check in Resources: %@", resource];
        if (_pathExists(self, fm, resource))
          return resource;
      }
    }
    
    // next check in Resources itself
    resource = [rp stringByAppendingPathComponent:_name];
    if (debugResourceLookup) 
      [self logWithFormat:@"  check in Resources-flat: %@", resource];
    if (_pathExists(self, fm, resource)) {
      if (debugResourceLookup) 
	[self logWithFormat:@"  found => %@", resource];
      return resource;
    }
  }
  
  /* and last check in the application directory */
  if (_pathExists(self, fm, self->base)) {
    resource = [self->base stringByAppendingPathComponent:_name];
    if (_pathExists(self, fm, resource))
      return resource;
  }
  return nil;
}

- (NSString *)pathForResourceNamed:(NSString *)_name {
  IS_DEPRECATED;
  return [self pathForResourceNamed:_name inFramework:nil languages:nil];
}

- (NSString *)pathForResourceNamed:(NSString *)_name ofType:(NSString *)_type {
  _name = [_name stringByAppendingPathExtension:_type];
  return [self pathForResourceNamed:_name];
}

/* URL methods */

- (NSString *)_urlForMissingResource:(NSString *)_name request:(WORequest *)_r{
  WOApplication *app;

  app = [WOApplication application];
  
  if (!genMissingResourceLinks)
    return nil;
  
  return [NSString stringWithFormat:
		     @"/missingresource?name=%@&application=%@",
                     _name, app ? [app name] : [_r applicationName]];
}

- (NSString *)urlForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
  request:(WORequest *)_request
{
  WOApplication   *app;
  NSMutableString *url;
  NSString *resource = nil, *tmp;
  NSString *path = nil, *sbase;
  unsigned len;
  
  app = [WOApplication application];
  
  if (_languages == nil)
    _languages = [_request browserLanguages];
  
  resource = [self pathForResourceNamed:_name
                   inFramework:_frameworkName
                   languages:_languages];
#if RSRCDIR_CONTENTS
  if ([resource rangeOfString:@"/Contents/"].length > 0) {
    resource = [resource stringByReplacingString:@"/Contents"
                         withString:@""];
  }
#endif
#if 0
  tmp = [resource stringByStandardizingPath];
  if (tmp != nil) resource = tmp;
#endif
  
  if (resource == nil) {
    if (debugResourceLookup)
      [self logWithFormat:@"did not find resource (cannot build URL)"];
    return [self _urlForMissingResource:_name request:_request];
  }
  
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
    return [self _urlForMissingResource:_name request:_request];
  
  url = [[NSMutableString alloc] initWithCapacity:256];
#if 0
  [url appendString:[_request adaptorPrefix]];
#endif
  if (resourcePrefix)
    [url appendString:resourcePrefix];
  if (![url hasSuffix:@"/"]) [url appendString:@"/"];
  [url appendString:app ? [app name] : [_request applicationName]];
  [url appendString:suffix];
  if (![path hasPrefix:@"/"]) [url appendString:@"/"];
  [url appendString:path];
      
  path = [url copy];
  [url release];
  return [path autorelease];
}

- (NSString *)urlForResourceNamed:(NSString *)_name {
  IS_DEPRECATED;
  return [self urlForResourceNamed:_name
               inFramework:nil
               languages:nil
               request:nil];
}
- (NSString *)urlForResourceNamed:(NSString *)_name ofType:(NSString *)_type {
  return [self urlForResourceNamed:
                 [_name stringByAppendingPathExtension:_type]];
}

/* string tables */

- (id)stringTableWithName:(NSString *)_tableName
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages
{
  /* side effect: tables are cached (currently not affected by default!) */
  NSFileManager  *fm;
  _WOStringTable *table     = nil;
  NSString       *path      = nil;
  
  fm = [self fileManager];
  
  if (_tableName == nil)
    _tableName = @"Localizable";

  /* take a look whether a matching table is already loaded */
  
  path = [_tableName stringByAppendingPathExtension:@"strings"];
  path = [self pathForResourceNamed:path inFramework:_framework 
               languages:_languages];
  
  if (path == nil)
    return nil;
  
  if ((table = NSMapGet(self->stringTables, path)) == NULL) {
    if ([fm fileExistsAtPath:path]) {
      table = [_WOStringTable allocWithZone:[self zone]]; /* for gcc */
      table = [table initWithPath:path];
      NSMapInsert(self->stringTables, path, table);
      [table release];
    }
  }
  return table;
}

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_defaultValue
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages
{
  _WOStringTable *table     = nil;
  
  table = [self stringTableWithName:_tableName inFramework:_framework 
		languages:_languages];
  
  return (table != nil)
    ? [table stringForKey:_key withDefaultValue:_defaultValue]
    : _defaultValue;
}

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_default
  languages:(NSArray *)_languages
{
  return [self stringForKey:_key inTableNamed:_tableName
               withDefaultValue:_default
               inFramework:nil
               languages:_languages];
}


/* NSLocking */

- (void)lock {
}
- (void)unlock {
}

/* component definitions */

- (NSString *)pathToComponentNamed:(NSString *)_name
  inFramework:(NSString *)_framework
{
  /* search for component wrapper .. */
  // TODO: shouldn't we used that for WOx as well?
  NSEnumerator *e;
  NSString     *ext;
  
  if (_name == nil) {
#if DEBUG
    [self warnWithFormat:
            @"(%s): tried to get path to component with <nil> name !",
            __PRETTY_FUNCTION__];
#endif
    return nil;
  }
  
  /* scan for name.$ext resource ... */
  e = [[[NSUserDefaults standardUserDefaults]
                        arrayForKey:@"WOComponentExtensions"]
                        objectEnumerator];
    
  while ((ext = [e nextObject])) {
    NSString *specName;
    NSString *path;
      
    specName = [_name stringByAppendingPathExtension:ext];
      
    path = [self pathForResourceNamed:specName
                 inFramework:_framework
                 languages:nil];
    if (path) return path;
  }
  return nil;
}

- (NSString *)pathToComponentNamed:(NSString *)_name
  inFramework:(NSString *)_framework
  languages:(NSArray *)_langs
{
  return [self pathToComponentNamed:_name inFramework:_framework];
}

- (WOComponentDefinition *)_definitionForPathlessComponent:(NSString *)_name
  languages:(NSArray *)_languages
{
  /* definition factory */
  WOComponentDefinition *cdef;
  
  cdef = [[WOComponentDefinition allocWithZone:[self zone]]
                                 initWithName:_name
                                 path:nil
                                 baseURL:nil
                                 frameworkName:nil];
  
  return [cdef autorelease];
}

- (WOComponentDefinition *)_definitionWithName:(NSString *)_name
  url:(NSURL *)_url
  baseURL:(NSURL *)_baseURL
  frameworkName:(NSString *)_fwname
{
  /* definition factory */
  static Class DefClass;
  id cdef;
  
  if (DefClass == Nil)
    DefClass = [WOComponentDefinition class];

  // TODO: is retained response intended?
  cdef = [[DefClass alloc] initWithName:_name
                           path:[_url path]
                           baseURL:_baseURL frameworkName:_fwname];
  return cdef;
}
- (WOComponentDefinition *)_definitionWithName:(NSString *)_name
  path:(NSString *)_path
  baseURL:(NSURL *)_baseURL
  frameworkName:(NSString *)_fwname
{
  NSURL *url;
  
  url = ([_path length] > 0)
    ? [[[NSURL alloc] initFileURLWithPath:_path] autorelease]
    : nil;
  
  return [self _definitionWithName:_name url:url
               baseURL:_baseURL frameworkName:_fwname];
}

- (WOComponentDefinition *)_cachedDefinitionForComponent:(id)_name
  languages:(NSArray *)_languages
{
  NSArray *cacheKey;
  id      cdef;

  if (self->componentDefinitions == NULL)
    return nil;
  if (![[WOApplication application] isCachingEnabled])
    return nil;
  
  cacheKey = [NSArray arrayWithObjects:_name, _languages, nil];
  cdef     = NSMapGet(self->componentDefinitions, cacheKey);
  
  return cdef;
}
- (WOComponentDefinition *)_cacheDefinition:(id)_cdef
  forComponent:(id)_name
  languages:(NSArray *)_languages
{
  NSArray *cacheKey;

  if (self->componentDefinitions == NULL)
    return _cdef;
  if (![[WOApplication application] isCachingEnabled])
    return _cdef;
  
  cacheKey = [NSArray arrayWithObjects:_name, _languages, nil];
  NSMapInsert(self->componentDefinitions, cacheKey, _cdef ? _cdef : (id)null);

  return _cdef;
}

- (NSString *)resourceNameForComponentNamed:(NSString *)_name {
  return [_name stringByAppendingPathExtension:@"wox"];
}

/* create component definition */

- (void)_getComponentURL:(NSURL **)url_ andName:(NSString **)name_
  forNameOrURL:(id)_nameOrURL inFramework:(NSString *)_framework
  languages:(NSArray *)_languages
{
  NSString *path;
  
  if ([_nameOrURL isKindOfClass:UrlClass]) {
    // TODO: where is this used currently? It probably was required for forms,
    //       but might not be anymore?
    *url_  = _nameOrURL;
    *name_ = [*url_ path];
    if (debugComponentLookup)
      [self debugWithFormat:@"using URL %@ for component %@", *url_, *name_];
    return;
  }
  
  /* the _nameOrURL is a string containing the component name */
  
  *name_ = _nameOrURL;

  if (_framework == nil && _nameOrURL != nil) {
    Class clazz;
      
    /* 
       Note: this is a bit of a hack ..., actually this method should never
       be called without a framework and pages shouldn't be instantiated
       without specifying their framework.
       But for legacy reasons this needs to be done and seems to work without
       problems. It is required for loading components from bundles.
    */
    if ((_framework = rapidTurnAroundPath) == nil) {
      if ((clazz = NSClassFromString(_nameOrURL)))
	_framework = [[NSBundle bundleForClass:clazz] bundlePath];
    }
  }
  
  if (debugComponentLookup) {
    [self logWithFormat:@"component '%@' in framework '%@'", 
	    _nameOrURL, _framework];
  }

  /* look for .wox component */
    
  path = [self pathForResourceNamed:
		 [self resourceNameForComponentNamed:*name_]
	       inFramework:_framework
	       languages:_languages];
    
  if (debugComponentLookup)
    [self logWithFormat:@"  .wox path: '%@'", path];
    
  /* look for .wo component */
    
  if ([path length] == 0) {
    path = [self pathToComponentNamed:*name_
		 inFramework:_framework
		 languages:_languages];
    if (debugComponentLookup)
      [self logWithFormat:@"  .wo  path: '%@'", path];
  }
    
  /* make URL from path */
    
  *url_ = ([path length] > 0)
    ? [[[UrlClass alloc] initFileURLWithPath:path] autorelease]
    : nil;
}

- (WOComponentDefinition *)definitionForFileURL:(NSURL *)componentURL
  componentName:(NSString *)_name inFramework:(NSString *)_framework
  languages:(NSArray *)_languages
{
  NSFileManager *fm;
  NSString      *componentPath;
  BOOL          doesCache, isDir;
  NSEnumerator  *languages;
  NSString      *language;
  NSString      *sname = nil;
  NSURL         *appUrl;
    
  fm            = [self fileManager];
  componentPath = [componentURL path];
  doesCache     = [[WOApplication application] isCachingEnabled];
    
  if (![fm fileExistsAtPath:componentPath isDirectory:&isDir]) {
    [[WOApplication application]
                      debugWithFormat:
                        @"%s: did not find component '%@' at path '%@' !",
                        __PRETTY_FUNCTION__,
                        _name, componentPath];
    return nil;
  }
  
  /* if the component spec is a directory (eg a .wo), scan inside for stuff*/
  
  if (!isDir)
    return nil;

  appUrl    = [[WOApplication application] baseURL];
  languages = [_languages objectEnumerator];
  while ((language = [languages nextObject])) {
    WOComponentDefinition *cdef;
    NSString *compoundKey  = nil;
    NSString *languagePath = nil;
    NSString *baseUrl = nil;
    BOOL     isDirectory   = NO;
        
    if (sname == nil) sname = [_name stringByAppendingString:@"\t"];
    compoundKey = [sname stringByAppendingString:language];
        
    if (doesCache) {
      cdef = NSMapGet(self->componentDefinitions, compoundKey);
      
      if (cdef == (id)null)
	/* resource does not exist */
	continue;
          
      [cdef touch];
      if (cdef != nil) return cdef; // found definition in cache
    }
    
    /* take a look into the file system */
    languagePath = [language stringByAppendingPathExtension:@"lproj"];
    languagePath = 
	  [componentPath stringByAppendingPathComponent:languagePath];
        
    if (![fm fileExistsAtPath:languagePath isDirectory:&isDirectory]) {
      if (doesCache) {
	/* register null in cache, so that we know it's non-existent */
	NSMapInsert(self->componentDefinitions, compoundKey, null);
      }
      continue;
    }
    
    if (!isDirectory) {
      [self warnWithFormat:@"(%s): language entry %@ is not a directory !",
              __PRETTY_FUNCTION__, languagePath];
            if (doesCache && (compoundKey != nil)) {
              // register null in cache, so that we know it's non-existent
              NSMapInsert(self->componentDefinitions, compoundKey, null);
            }
            continue;
    }
          
    baseUrl = [NSString stringWithFormat:@"%@/%@.lproj/%@.wo",
                                [appUrl absoluteString], language, _name];
          
    /* found appropriate language project */
    cdef = [self _definitionWithName:_name
                       path:languagePath
                       baseURL:[NSURL URLWithString:baseUrl]
                       frameworkName:nil];
    if (cdef == nil) {
            [self warnWithFormat:
                    @"(%s): could not load component definition of "
                    @"'%@' from language project: %@", 
                    __PRETTY_FUNCTION__, _name, languagePath];
            if (doesCache && (compoundKey != nil)) {
              // register null in cache, so that we know it's non-existent
              NSMapInsert(self->componentDefinitions, compoundKey, null);
            }
            continue;
    }
    
    if (doesCache && (compoundKey != nil)) {
            // register in cache
            NSMapInsert(self->componentDefinitions, compoundKey, cdef);
            [cdef release];
    }
    else {
            // don't register in cache
            cdef = [cdef autorelease];
    }
	  
    return cdef;
  }
  return nil;
}

- (WOComponentDefinition *)definitionForComponent:(id)_name
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages
{
  // TODO: this method is definitely too big! => refacture
  WOApplication         *app;
  NSFileManager         *fm            = nil;
  WOComponentDefinition *cdef          = nil;
  NSURL                 *componentURL;
  NSURL                 *appUrl;
  BOOL                  doesCache;
  
  app       = [WOApplication application];
  doesCache = [app isCachingEnabled];
  
  /* lookup component path */
  
  // TODO: Explain why _framework and _languages are NOT passed!
  [self _getComponentURL:&componentURL andName:&_name 
	forNameOrURL:_name inFramework:nil languages:nil];
  
  if (debugComponentLookup) {
    [self logWithFormat:@"  component='%@' in framework='%@': url='%@'", 
            _name, _framework, componentURL];
  }
  
  appUrl = [app baseURL];
  
  /* check whether it's a 'template-less' component ... */
  
  if (componentURL == nil) {
    /* did not find component wrapper ! */
    [app debugWithFormat:@"  component '%@' has no template !", _name];
    
    cdef = [self _definitionForPathlessComponent:_name languages:_languages];
    return cdef;
  }
  
  fm = [self fileManager];
  
  /* ensure that the component exists */

  if ([componentURL isFileURL]) {
    WOComponentDefinition *cdef;

    cdef = [self definitionForFileURL:componentURL componentName:_name
		 inFramework:_framework languages:_languages];
    if (cdef != nil && ![cdef isNotNull])
      return nil;
    else if (cdef != nil) 
      return cdef;
  }
  
  /* look flat */
    
  if (doesCache) {
    cdef = NSMapGet(self->componentDefinitions, componentURL);
      
    if (cdef == (id)null)
      /* resource does not exist */
      return nil;
    [cdef touch];
      
    if (cdef) return cdef; // found definition in cache
  }
  
  /* take a look into the file system */
  {
    NSString *baseUrl = nil;
    
    baseUrl = [NSString stringWithFormat:@"%@/%@",
                          [appUrl absoluteString], [_name lastPathComponent]];
    
    cdef = [self _definitionWithName:_name
                 url:componentURL
                 baseURL:[NSURL URLWithString:baseUrl]
                 frameworkName:nil];
    if (cdef == nil) {
      [self warnWithFormat:
              @"(%s): could not load component definition of '%@' from "
              @"component wrapper: '%@'", 
              __PRETTY_FUNCTION__, _name, componentURL];
      if (doesCache) {
        /* register null in cache, so that we know it's non-existent */
        NSMapInsert(self->componentDefinitions, componentURL, null);
      }
      return nil;
    }
    
    if (doesCache) {
      /* register in cache */
      NSMapInsert(self->componentDefinitions, componentURL, cdef);
      [cdef release];
    }
    else
      /* don't register in cache, does not cache */
      cdef = [cdef autorelease];

    return cdef;
  }
  
  /* did not find component */
  return nil;
}
- (WOComponentDefinition *)definitionForComponent:(id)_name
  languages:(NSArray *)_langs
{
  // TODO: who uses that? Probably should be deprecated?
  return [self definitionForComponent:_name inFramework:nil languages:_langs];
}

- (WOComponentDefinition *)__definitionForComponent:(id)_name
  languages:(NSArray *)_languages
{
  /* 
     First check whether the cdef is cached, otherwise create a new one.

     This method is used by the higher level methods and just implements the
     cache control.
     The definition itself is created by definitionForComponent:languages:.
  */
  WOComponentDefinition *cdef;
  
  /* look into cache */
  
  cdef = [self _cachedDefinitionForComponent:_name languages:_languages];
  if (cdef != nil) {
    if (cdef == (id)null)
      /* component does not exist */
      return nil;
    
    if ([cdef respondsToSelector:@selector(touch)])
      [cdef touch];
    return cdef;
  }
  
  /* not cached, create a definition */
  
  cdef = [self definitionForComponent:_name languages:_languages];

  /* cache created definition */
  
  return [self _cacheDefinition:cdef forComponent:_name languages:_languages];
}

- (WOElement *)templateWithName:(NSString *)_name
  languages:(NSArray *)_languages
{
  WOComponentDefinition *cdef;
  
  cdef = [self __definitionForComponent:_name languages:_languages];
  if (cdef == nil)
    return nil;
  
  return (WOElement *)[cdef template];
}

- (id)pageWithName:(NSString *)_name languages:(NSArray *)_langs {
  /* 
     TODO: this appears to be deprecated since the WOComponent initializer
           is now -initWithContext: and we have no context over here ...
  */
  NSAutoreleasePool     *pool;
  WOComponentDefinition *cdef;
  WOComponent           *component = nil;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    cdef = [self __definitionForComponent:_name languages:_langs];
    if (cdef != nil) {
      // TODO: document what the resource manager is used for in the cdef
      component =
        [[cdef instantiateWithResourceManager:self languages:_langs] retain];
    }
  }
  [pool release];
  
  return [component autorelease];
}

/* KeyedData */

- (void)setData:(NSData *)_data
  forKey:(NSString *)_key
  mimeType:(NSString *)_type
  session:(WOSession *)_session
{
  if ((_key == nil) || (_data == nil))
    return;
  if (_type == nil)
    _type = @"application/octet-stream";
  
  [self lock];
  
  if (self->keyedResources == NULL) {
    self->keyedResources = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                            NSObjectMapValueCallBacks,
                                            128);
  }

  NSMapInsert(self->keyedResources,
              _key,
              [NSDictionary dictionaryWithObjectsAndKeys:
                              _type, @"mimeType",
                              _key,  @"key",
                              _data, @"data",
                            nil]);
  
  [self unlock];
}

- (id)_dataForKey:(NSString *)_key sessionID:(NSString *)_sid {
  id tmp;

  [self lock];
  
  if (self->keyedResources)
    tmp = NSMapGet(self->keyedResources, _key);
  else
    tmp = nil;
  
  tmp = [[tmp retain] autorelease];
  
  [self unlock];

  return tmp;
}

- (void)removeDataForKey:(NSString *)_key session:(WOSession *)_session {
  [self lock];
  
  if (self->keyedResources)
    NSMapRemove(self->keyedResources, _key);
  
  [self unlock];
}

- (void)flushDataCache {
  [self lock];

  if (self->keyedResources) {
    NSFreeMapTable(self->keyedResources);
    self->keyedResources = NULL;
  }
  
  [self unlock];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:32];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  if ([self->base length] > 0)
    [ms appendFormat:@" path='%@'", self->base];
  [ms appendString:@">"];
  return ms;
}

@end /* WOResourceManager */
