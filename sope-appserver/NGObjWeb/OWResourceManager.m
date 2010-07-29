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

// ATTENTION: this class is for OGo legacy, so that WO compatibility changes 
//            to WOResourceManager do not break OGo.
//            So: do not use that class, its DEPRECATED!

#include <NGObjWeb/OWResourceManager.h>
#include <NGObjWeb/WOComponentDefinition.h>
#include "WOComponent+private.h"
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOApplication.h>
#include "common.h"
#import <Foundation/NSNull.h>
#include "_WOStringTable.h"

/*
  Component Discovery and Page Creation

    All WO code uses either directly or indirectly the OWResourceManager's
    -pageWithName:languages: method to instantiate WO components.

    This methods works in three steps:
      
      1. discovery of files associated with the component
         - (WOComponentDefinition *)definitionForComponent:(id)_name
           inFramework:(NSString *)_framework
           languages:(NSArray *)_languages
      
      2. creation of a proper WOComponentDefinition, which is some kind
         of 'blueprint' or 'class' for components
      
      3. component instantiation using the definition
    
    All the instantiation/setup work is done by a component definition, the
    resource manager is only responsible for managing those 'blueprint'
    resources.

    If you want to customize component creation, you can supply your
    own WOComponentDefinition in a subclass of OWResourceManager by
    overriding:
      - (WOComponentDefinition *)definitionForComponent:(id)_name
        inFramework:(NSString *)_frameworkName
        languages:(NSArray *)_languages

  Notably in WO 5.3 the WOResourceManager doesn't seem to handle components
  anymore.
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
*/
#if COCOA_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
#  define RSRCDIR_CONTENTS 1
#endif

@implementation OWResourceManager

+ (int)version {
  return 4;
}

static NSFileManager *fm                = nil;
static Class    UrlClass                = Nil;
static NSString *resourcePrefix         = @"";
static NSString *rapidTurnAroundPath    = nil;
static NSNull   *null                   = nil;
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

  fm   = [[NSFileManager defaultManager] retain];
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
  rapidTurnAroundPath     = [[ud stringForKey:@"WOProjectDirectory"] copy];
}

static inline BOOL
_pathExists(OWResourceManager *self, NSFileManager *fm, NSString *path)
{
  BOOL doesExist;
  
  if (self->existingPathes && (path != nil)) {
    int i;
    
    i = (int)(long)NSMapGet(self->existingPathes, path);
    if (i == 0) {
      doesExist = [fm fileExistsAtPath:path];
      NSMapInsert(self->existingPathes, path, (void*)(doesExist ? 1L : 0xFFL));
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
  if (_fw == nil) 
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

- (NSString *)_lookupResourceNamed:(NSString *)_name inPath:(NSString *)_path
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
{
  unsigned i, langCount;
  NSString *resource;

  if (_path == nil)
    return nil;
  
  // first check Language.lproj in WebServerResources
  for (i = 0, langCount = [_languages count]; i < langCount; i++) {
    NSString *langPath;
    
    langPath = [_languages objectAtIndex:i];
    langPath = [langPath stringByAppendingPathExtension:@"lproj"];
    langPath = [_path stringByAppendingPathComponent:langPath];
    
    if (!_pathExists(self, fm, langPath)) {
      if (debugResourceLookup) {
	[self logWithFormat:
		@"  no language lproj for '%@' in path: %@",
	        [_languages objectAtIndex:i], _path];
      }
      continue;
    }
    
    resource = [langPath stringByAppendingPathComponent:_name];
    
    if (_pathExists(self, fm, resource)) {
      if (debugResourceLookup) 
	[self logWithFormat:@"  found path: %@", resource];
      return resource;
    }
    else if (debugResourceLookup)
      [self logWithFormat:@"  not found in path: %@", resource];
  }
      
  /* next check in resources path (WebServerResources or Resources) itself */
  resource = [_path stringByAppendingPathComponent:_name];
  if (debugResourceLookup)
    [self logWithFormat:@"  check for flat path: %@", resource];
  if (_pathExists(self, fm, resource))
    return resource;
  
  return nil;
}

- (BOOL)shouldLookupResourceInWebServerResources:(NSString *)_name {
  if ([_name hasSuffix:@".wox"]) return NO;
  if ([_name hasSuffix:@".wo"])  return NO;
  return YES;
}

- (NSString *)pathForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
{
  /*
    Note: at least in the case of OGo component lookups the framework name is
          properly filled with the OGo bundle path on lookup, so no
          NGBundleManager query is necessary.
  */
  NSFileManager *fm;
  NSString      *resource = nil;
  unsigned      langCount;
  
  if (debugResourceLookup) {
    [self logWithFormat:@"lookup '%@' bundle=%@ languages=%@", 
          _name, _frameworkName, [_languages componentsJoinedByString:@","]];
  }
  
  fm        = [self fileManager];
  langCount = [_languages count];

  /* now check in webserver resources path */
  
  if ([self shouldLookupResourceInWebServerResources:_name]) {
    resource = [self _lookupResourceNamed:_name 
		     inPath:[self webServerResourcesPath]
		     inFramework:_frameworkName languages:_languages];
    if (resource != nil) return resource;
  }
  
  /* now check in regular resources path */

  resource = [self _lookupResourceNamed:_name 
		   inPath:[self resourcesPathForFramework:_frameworkName]
		   inFramework:_frameworkName languages:_languages];
  if (resource != nil) return resource;
  
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

- (NSString *)urlForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
  request:(WORequest *)_request
{
  WOApplication *app;
  NSString *resource = nil, *tmp;
  
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
  if (tmp) resource = tmp;
#endif
  
  if (resource) {
    NSString *path = nil, *sbase;
    unsigned len;
    
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
    
    if (path) {
      static NSString *suffix = nil;
      NSMutableString *url = nil;

      if (suffix == nil) {
	NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        suffix = [ud stringForKey:@"WOApplicationSuffix"];
      }
      
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
  }
  
  if (genMissingResourceLinks) {
    return [NSString stringWithFormat:
                       @"/missingresource?name=%@&application=%@",
                       _name, app ? [app name] : [_request applicationName]];
  }
  return nil;
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

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_defaultValue
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages;
{
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
  
  if (path != nil) {
    if ((table = NSMapGet(self->stringTables, path)) == NULL) {
      if ([fm fileExistsAtPath:path]) {
	table = [_WOStringTable allocWithZone:[self zone]]; /* for gcc */
        table = [table initWithPath:path];
        NSMapInsert(self->stringTables, path, table);
        [table release];
      }
    }
    if (table != nil)
      return [table stringForKey:_key withDefaultValue:_defaultValue];
  }
  /* didn't found table in cache */
  
  return _defaultValue;
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
  languages:(NSArray *)_langs
{
  /* search for component wrapper .. */
  // TODO: shouldn't we use that for WOx as well?
  NSEnumerator *e;
  NSString     *ext;
  
  if (_name == nil) {
#if DEBUG
    [self warnWithFormat:@"(%s): tried to get path to component with "
            @"<nil> name !",
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
                 languages:_langs];
    if (path != nil) return path;
  }
  return nil;
}

- (NSString *)pathToComponentNamed:(NSString *)_name
  inFramework:(NSString *)_fw
{
  // TODO: is this still used somewhere?
  return [self pathToComponentNamed:_name inFramework:_fw languages:nil];
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

- (BOOL)_isValidWrapperDirectory:(NSString *)_path 
  containingTemplate:(NSString *)_name 
{
  /* 
     Check whether this actually does contain a template! 
       
     This is new and hopefully doesn't break anything, but as far as I can
     see checking for Component.html inside should do the right thing (unless
     there are template wrappers which are not .wo wrappers ;-)
  */
  NSString *htmlPath;
  
  htmlPath = [_name stringByAppendingPathExtension:@"html"];
  htmlPath = [_path stringByAppendingPathComponent:htmlPath];
  return [[self fileManager] fileExistsAtPath:htmlPath];
}

- (WOComponentDefinition *)_processWrapperLanguageProjects:(NSString *)_name
  componentPath:(NSString *)componentPath
  languages:(NSArray *)_langs
{
  /* 
     this looks for language projects contained in template wrapper 
     directories, eg "Main.wo/English.lproj/"
  */
  WOComponentDefinition *cdef = nil;
  NSFileManager         *fm   = nil;
  NSEnumerator *languages;
  NSString     *language;
  NSString     *sname;
  BOOL         doesCache;

  if ([_langs count] == 0)
    return nil;
  
  doesCache = [[WOApplication application] isCachingEnabled];
  fm        = [self fileManager];
  sname     = [_name stringByAppendingString:@"\t"];
  
  languages = [_langs objectEnumerator];
  while ((language = [languages nextObject])) {
    NSString *compoundKey  = nil;
    NSString *languagePath = nil;
    BOOL     isDirectory   = NO;
    NSString *baseUrl = nil;
    
    // [self logWithFormat:@"check %@ / %@", _name, language];
    
    compoundKey = [sname stringByAppendingString:language];
    if (doesCache) {
      cdef = NSMapGet(self->componentDefinitions, compoundKey);
      
      if (cdef == (id)null)
	/* resource does not exist */
	continue;
          
      [cdef touch];
      if (cdef) return cdef; // found definition in cache
    }
        
    /* take a look into the file system */
    languagePath = [language stringByAppendingPathExtension:@"lproj"];
    languagePath = [componentPath stringByAppendingPathComponent:languagePath];
        
    if (![fm fileExistsAtPath:languagePath isDirectory:&isDirectory]) {
      if (doesCache) {
	// register null in cache, so that we know it's non-existent
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
    
    /* 
       Now check whether this actually does contain a template! 
       
       This is new and hopefully doesn't break anything, but as far as I can
       see checking for Component.html inside should do the right thing (unless
       there are template wrappers which are not .wo wrappers ;-)
    */
    if (![self _isValidWrapperDirectory:languagePath
	       containingTemplate:_name]){
      [self debugWithFormat:@"no HTML template for inside lproj '%@': '%@'",
	      _name, languagePath];
      if (doesCache && (compoundKey != nil)) {
	// register null in cache, so that we know it's non-existent
	NSMapInsert(self->componentDefinitions, compoundKey, null);
      }
      continue;
    }
    
    /* construct the base URL */
    
    baseUrl = [[[WOApplication application] baseURL] absoluteString];
    baseUrl = [NSString stringWithFormat:@"%@/%@.lproj/%@.wo",
			  baseUrl, language, _name];
    
    /* create WOComponentDefinition object */
    
    cdef = [self _definitionWithName:_name
		 path:languagePath
		 baseURL:[NSURL URLWithString:baseUrl]
		 frameworkName:nil];
    if (cdef == nil) {
      [self warnWithFormat:@"(%s): could not load component definition of "
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
  
  return nil; /* no lproj containing templates was found */
}

- (NSString *)defaultFrameworkForComponentNamed:(NSString *)_name {
  Class clazz;
  
  if (rapidTurnAroundPath != nil)
    return rapidTurnAroundPath;
  
  if ((clazz = NSClassFromString(_name)) == nil)
    return nil;
  
  return [[NSBundle bundleForClass:clazz] bundlePath];
}

- (WOComponentDefinition *)definitionForComponent:(id)_name
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages
{
  /* this is the primary method for finding a definition */
  // TODO: this method is too large
  WOApplication         *app;
  NSFileManager         *fm            = nil;
  WOComponentDefinition *cdef          = nil;
  NSURL                 *componentURL;
  BOOL                  doesCache, isDir;
  
  app       = [WOApplication application];
  doesCache = [app isCachingEnabled];
  
  /* lookup component path */
  
  if ([_name isKindOfClass:UrlClass]) {
    componentURL = _name;
    _name = [componentURL path];
    if (debugComponentLookup) {
      [self debugWithFormat:@"using URL %@ for component %@",
              componentURL, _name];
    }
  }
  else {
    NSString *path;
    
    /* 
       Note: this is a bit of a hack ..., actually this method should never
             be called without a framework and pages shouldn't be instantiated
             without specifying their framework.
             But for legacy reasons this needs to be done and seems to work
             without problems. It is required for loading components from
             bundles.
    */
    if (_framework == nil && _name != nil)
      _framework = [self defaultFrameworkForComponentNamed:_name];
    
    if (debugComponentLookup) {
      [self logWithFormat:@"lookup: component '%@' in framework '%@'", 
              _name, _framework];
    }
    
    /* look for .wox component */
    
    // TODO: why don't we use -pathForComponentNamed: here?
    path = [self pathForResourceNamed:
                   [self resourceNameForComponentNamed:_name]
                 inFramework:_framework
                 languages:_languages];
    
    if (debugComponentLookup)
      [self logWithFormat:@"lookup:  path-to-resource: '%@'", path];
    
    /* look for .wo component */
    
    if ([path length] == 0) {
      path = [self pathToComponentNamed:_name
                   inFramework:_framework
                   languages:_languages];
      if (debugComponentLookup)
        [self logWithFormat:@"lookup:  path-to-component: '%@'", path];
    }
    
    /* make URL from path */
    
    componentURL = ([path length] > 0)
      ? [[[UrlClass alloc] initFileURLWithPath:path] autorelease]
      : nil;
  }
  
  if (debugComponentLookup) {
    [self logWithFormat:@"  component='%@' in framework='%@'", 
            _name, _framework];
    [self logWithFormat:@"  => '%@'", [componentURL absoluteString]];
  }
  
  /* check whether it's a 'template-less' component ... */
  
  if (componentURL == nil) {
    /* did not find component wrapper ! */
    [app debugWithFormat:@"  component '%@' has no template !", _name];
    
    cdef = [self _definitionForPathlessComponent:_name languages:_languages];
    return cdef;
  }
  
  fm = [self fileManager];
  
  /* ensure that the component exists */
  
  isDir = NO;
  if ([componentURL isFileURL]) {
    NSString *componentPath;
    
    componentPath = [componentURL path];
    
    if (![fm fileExistsAtPath:componentPath isDirectory:&isDir]) {
      [[WOApplication application]
                      debugWithFormat:
                        @"%s: did not find component '%@' at path '%@' !",
                        __PRETTY_FUNCTION__,
                        _name, componentPath];
      return nil;
    }
    
    /* if the component spec is a directory (eg a .wo), scan lproj's inside */
    if (isDir && [_languages count] > 0) {
      if (debugComponentLookup) {
	[self logWithFormat:@"  check wrapper languages (%d)", 
	      [_languages count]];
      }
      cdef = [self _processWrapperLanguageProjects:_name
		   componentPath:componentPath
		   languages:_languages];
      if (cdef != nil) {
	if (debugComponentLookup)
	  [self logWithFormat:@"  => FOUND: %@", cdef];
	return cdef;
      }
      else if (debugComponentLookup)
	[self logWithFormat:@"  ... no language template found ..."];
    }
  }
  
  /* look flat */
  
  if (doesCache) {
    cdef = NSMapGet(self->componentDefinitions, componentURL);
    if (cdef == (id)null)
      /* resource does not exist */
      return nil;
    [cdef touch];
    
    if (cdef != nil) return cdef; // found definition in cache
  }

  /* 
     in case the "componentURL" is a directory, check whether it contains
     an HTML file
  */
  if (isDir) {
    if (![self _isValidWrapperDirectory:[componentURL path]
	       containingTemplate:_name]) {
      if (debugComponentLookup)
	[self logWithFormat:@"  not a valid wrapper '%@': '%@'",
	        _name, [componentURL absoluteString]];
      if (doesCache) {
        /* register null in cache, so that we know it's non-existent */
        NSMapInsert(self->componentDefinitions, componentURL, null);
      }
      return nil;
    }
  }
  
  /* take a look into the file system */
  {
    NSString *baseUrl = nil;
    
    baseUrl = [NSString stringWithFormat:@"%@/%@",
                          [[app baseURL] absoluteString], 
			  [_name lastPathComponent]];
    
    cdef = [self _definitionWithName:_name
                 url:componentURL
                 baseURL:[NSURL URLWithString:baseUrl]
                 frameworkName:nil];
    if (cdef == nil) {
      [self warnWithFormat:@"(%s): could not load component definition of "
              @"'%@' from component wrapper: '%@'", 
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
  /* Note: the framework will be determined base on the class '_name' */
  return [self definitionForComponent:_name inFramework:nil languages:_langs];
}

/* caching */

- (WOComponentDefinition *)__definitionForComponent:(id)_name
  languages:(NSArray *)_languages
{
  // TODO: this should add the framework parameter and maybe a context
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

/* primary call-in's */

- (WOElement *)templateWithName:(NSString *)_name
  languages:(NSArray *)_languages
{
  WOComponentDefinition *cdef;
  
  cdef = [self __definitionForComponent:_name languages:_languages];
  if (cdef == nil) return nil;
  
  return (WOElement *)[cdef template];
}

- (id)pageWithName:(NSString *)_name languages:(NSArray *)_languages {
  /* 
     TODO: this appears to be deprecated since the WOComponent initializer
           is now -initWithContext: and we have no context here ...
           Also misses the framework?
  */
  NSAutoreleasePool     *pool      = nil;
  WOComponentDefinition *cdef      = nil;
  WOComponent           *component = nil;
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    cdef = [self __definitionForComponent:_name languages:_languages];
    if (cdef != nil) {
      component = 
	[cdef instantiateWithResourceManager:(WOResourceManager *)self 
	      languages:_languages];
      component = [component retain];
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
  return [NSString stringWithFormat:@"<%@[0x%p]: path=%@>",
                     [self class], self, self->base];
                   
}

@end /* OWResourceManager */
