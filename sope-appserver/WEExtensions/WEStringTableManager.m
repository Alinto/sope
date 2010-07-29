/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "WEStringTableManager.h"
#include "WEStringTable.h"
#include "WEResourceManager.h"
#include "common.h"

@implementation WEStringTableManager

static NSNull *null = nil;
static BOOL   debugOn = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if (null == nil) null = [[NSNull null] retain];
  
  if ((debugOn = [ud boolForKey:@"WEStringTableManagerDebugEnabled"]))
    NSLog(@"Note: WEStringTableManager debugging is enabled.");
}

- (id)init {
  if ((self = [super init])) {
    if ([WOApplication isCachingEnabled]) {
      // TODO: find proper capacities
      self->nameToTable = 
	[[NSMutableDictionary alloc] initWithCapacity:16];
      self->compLabelCache = 
	[[NSMutableDictionary alloc] initWithCapacity:512];
    }
    else
      [self logWithFormat:@"Note: label caching is disabled (slow!)."];
  }
  return self;
}

- (void)dealloc {
  [self->compLabelCache release];
  [self->nameToTable    release];
  [super dealloc];
}

/* accessors */

- (NGBundleManager *)bundleManager {
  static NGBundleManager *bm = nil; // THREAD
  if (bm == nil) bm = [[NGBundleManager defaultBundleManager] retain];
  return bm;
}

/* resource pathes */

+ (NSString *)findResourceDirectoryNamed:(NSString *)_name
  fhsName:(NSString *)_fhs
{
  static NSDictionary *env = nil;
  NSFileManager *fm;
  NSString      *path;
  id tmp;
  
  if (env == nil) env = [[[NSProcessInfo processInfo] environment] retain];
  fm = [NSFileManager defaultManager];

  /* look in GNUstep pathes */
  
  tmp = [[WEResourceManager rootPathesInGNUstep] objectEnumerator];
  while ((path = [tmp nextObject]) != nil) {
    path = [path stringByAppendingPathComponent:_name];
    
    if ([fm fileExistsAtPath:path])
      return path;
  }
  
  /* look in FHS pathes */
  
  tmp = [[WEResourceManager rootPathesInFHS] objectEnumerator];
  while ((path = [tmp nextObject])) {
    path = [path stringByAppendingPathComponent:_fhs];
    if ([fm fileExistsAtPath:path])
      return path;
  }
  return nil;
}

/* labels */

- (NSString *)labelForKey:(NSString *)_key component:(WOComponent *)_component{
  WOApplication   *app;
  NSArray         *langs;
  NSBundle        *bundle;
  id              value = nil;
  NGBundleManager *bm;
  NSString        *cname;
  id cacheKey;
  
  if (![_key isNotEmpty])
    return _key;
  if (_component == nil)
    return _key;

  if (null == nil) null = [[NSNull null] retain];
  
  cname = [_component name];
  langs = [(WOSession *)[_component session] languages];
  
  /* cache ?? */
  
  {
    /* cache cachekeys here ;-) */
    cacheKey = [NSArray arrayWithObjects:_key, cname, langs, nil];
  }
  
  if ((value = [self->compLabelCache objectForKey:cacheKey]) != nil) {
    if (value == null) value = nil;
    return value;
  }
  
  /* lookup bundle */
  
  app = [WOApplication application];
  
  bm = [NGBundleManager defaultBundleManager];
  bundle = [bm bundleProvidingResource:cname ofType:@"WOComponents"];
  if (bundle == nil)
    bundle = [NGBundle bundleForClass:[_component class]];
  
  /* look in BundleName.strings */
  
  value = [self stringForKey:_key
                inTableNamed:[bundle bundleName]
                withDefaultValue:nil
                languages:langs];
  if (value)
    goto done;
  
  /* look in App.strings */
  value = [self stringForKey:_key
                inTableNamed:cname
                withDefaultValue:nil
                languages:langs];
  if (value)
    goto done;
  
  /* no string found, use key as string */
  value = _key;
  
 done:
#if DEBUG
  NSAssert(value, @"missing value ..");
#endif
  
  [self->compLabelCache setObject:value forKey:cacheKey];
#if 0
  NSLog(@"%s: label cache size now: %i", __PRETTY_FUNCTION__,
        [self->compLabelCache count]);
#endif
  return value;
}

- (NSString *)_cachedStringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_default
  languages:(NSArray *)_languages
{
  if (_tableName == nil) _tableName = @"default";

  /* look into string cache */
  
  if ([_languages count] > 0) {
    NSString *tname;
    NSRange  r;
    NSString *language;
    id       table;
    
    language = [_languages objectAtIndex:0];
    
    r = [language rangeOfString:@"_"];
    if (r.length > 0)
      language = [language substringToIndex:r.location];
    
    tname = [language stringByAppendingString:@"+++"];
    tname = [tname stringByAppendingString:_tableName];
    
    if ((table = [self->nameToTable objectForKey:tname])) {
      if (debugOn) {
	[self logWithFormat:
		@"resolved label %@ table %@ in lang %@ (languages=%@)",
                _key, _tableName, language,
                [_languages componentsJoinedByString:@","]];
      }
      return [table stringForKey:_key withDefaultValue:_default];
    }
  }
  else if ([_languages count] == 0) {
    id table;
    
    NSLog(@"WARNING: called %s without languages array %@ !",
          __PRETTY_FUNCTION__, _languages);
    
    if ((table = [self->nameToTable objectForKey:_tableName]))
      return [table stringForKey:_key withDefaultValue:_default];
  }
  
  return nil;
}

- (WEStringTable *)bundleTableWithName:(NSString *)_tableName
  languages:(NSArray *)_languages
{
  NSBundle     *bundle;
  NSString     *path;
  NSEnumerator *e;
  NSString     *language;
  
  if (_tableName == nil) _tableName = @"default";
  
  bundle = [[self bundleManager]
                  bundleProvidingResource:_tableName
                  ofType:@"strings"];
  if (bundle == nil)
    return nil;

  e = [_languages objectEnumerator];
  while ((language = [e nextObject])) {
    NSArray *ls;
    NSRange r;
      
    r = [language rangeOfString:@"_"];
    if (r.length > 0)
      language = [language substringToIndex:r.location];
      
    ls = [NSArray arrayWithObject:language];
      
    path = [bundle pathForResource:_tableName
                   ofType:@"strings"
                   languages:ls];
    if (path != nil) {
      NSString *tname;
      id table;
      
      tname = [language stringByAppendingString:@"+++"];
      tname = [tname stringByAppendingString:_tableName];
        
      table = [WEStringTable stringTableWithPath:path];
      [self->nameToTable setObject:table forKey:tname];
      return table;
    }
  }
    
  path = [bundle pathForResource:_tableName
                 ofType:@"strings"
                 languages:nil];
    
  if (path != nil) {
    WEStringTable *table;
    
    table = [WEStringTable stringTableWithPath:path];
    
    [self->nameToTable setObject:table forKey:_tableName];
    return table;
  }
  
  if (debugOn) {
    // TODO: use logging
    NSLog(@"WARNING: missing string table %@ in bundle %@",
          _tableName, [bundle bundlePath]);
  }
  return nil;
}

+ (NSString *)gsTranslationsSubpath {
  NSString *p;
  
  p = [[WOApplication application] gsTranslationsDirectoryName];
  if (![p isNotEmpty])
    return nil;
  
  p = [@"Resources/" stringByAppendingString:p];
  return p;
}
+ (NSString *)fhsTranslationsSubpath {
  NSString *p;
  
  p = [[WOApplication application] shareTranslationsDirectoryName];
  if (![p isNotEmpty])
    return nil;
  
  p = [@"share/" stringByAppendingString:p];
  return [p stringByAppendingString:@"/translations/"];
}

+ (NSArray *)availableTranslations {
  static NSArray *ltranslations = nil;
  NSMutableSet  *translations;
  NSEnumerator  *e;
  NSFileManager *fm;
  NSString      *path;
  NSArray       *translationPathes;

  if (ltranslations != nil)
    return ltranslations;
  
  // TODO: use lists ..., or maybe NGResourceLocator
  path = [self findResourceDirectoryNamed:[self gsTranslationsSubpath]
               fhsName:[self fhsTranslationsSubpath]];
  if (path == nil)
    return nil;

  translationPathes = [NSArray arrayWithObject:path];
  translations = [NSMutableSet setWithCapacity:16];
  fm           = [NSFileManager defaultManager];
  
  e = [translationPathes objectEnumerator];
  while ((path = [e nextObject]) != nil) {
    NSEnumerator *dl;
    NSString *l;
    
    dl = [[fm directoryContentsAtPath:path] objectEnumerator];
    while ((l = [dl nextObject]) != nil) {
      if (![l hasSuffix:@".lproj"])
	continue;
      if ([l hasPrefix:@"."])
	continue;
      
      l = [l stringByDeletingPathExtension];
      [translations addObject:l];
    }
  }
  
  ltranslations = [[translations allObjects] copy];
  if ([ltranslations count] > 0) {
    NSLog(@"Note: located translations: %@", 
	  [ltranslations componentsJoinedByString:@", "]);
  }
  else
    NSLog(@"Note: located no additional translations.");
  return ltranslations;
}

- (WEStringTable *)resourceTableWithName:(NSString *)_tableName
  languages:(NSArray *)_languages
{
  NSString      *rpath, *path;
  NSEnumerator  *e;
  NSString      *language;
  NSFileManager *fm;

  if (_tableName == nil) _tableName = @"default";
  
  fm = [NSFileManager defaultManager];
  // TODO: should be NGResourceLocator method?
  rpath = [[self class] findResourceDirectoryNamed:
                          [[self class] gsTranslationsSubpath]
			fhsName:
                          [[self class] fhsTranslationsSubpath]];
  if (rpath == nil) {
    [self logWithFormat:@"missing translations directory ..."];
    return nil;
  }
  
  /* look into language projects .. */
  
  e = [_languages objectEnumerator];
  while ((language = [e nextObject]) != nil) {
    WEStringTable *table;
    NSArray  *ls;
    NSRange  r;
    NSString *tname;
      
    r = [language rangeOfString:@"_"];
    if (r.length > 0)
      language = [language substringToIndex:r.location];
    
    ls = [NSArray arrayWithObject:language];
    
    // TODO: add support for .po
    path = [_tableName stringByAppendingPathExtension:@"strings"];
    path = [[language stringByAppendingPathExtension:@"lproj"]
                      stringByAppendingPathComponent:path];
    path = [rpath stringByAppendingPathComponent:path];
    
    if (![fm fileExistsAtPath:path])
      continue;
    
    tname = [language stringByAppendingString:@"+++"];
    tname = [tname stringByAppendingString:_tableName];
    
    table = [WEStringTable stringTableWithPath:path];
    [self->nameToTable setObject:table forKey:tname];
    
    return table;
  }
  
  /* look into resource dir */
  
  // TODO: add support for .po
  path = [_tableName stringByAppendingPathExtension:@"strings"];
  path = [rpath stringByAppendingPathComponent:path];

  if ([fm fileExistsAtPath:path]) {
    WEStringTable *table;
    
    table = [WEStringTable stringTableWithPath:path];
    if (self->nameToTable == nil)
      self->nameToTable = [[NSMutableDictionary alloc] initWithCapacity:16];
    
    [self->nameToTable setObject:table forKey:_tableName];
    return table;
  }
  
  // TODO: use SOPE 4.5 logging framework
  if (debugOn)
    NSLog(@"WARNING: missing string table %@ in %@", _tableName, path);
  return nil;
}

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_default
  languages:(NSArray *)_languages
{
  WEStringTable *table;
  NSString *s;
  
  if (_tableName == nil) // TODO: Localizable in NGObjWeb
    _tableName = @"default";
  
  /* look into string cache */
  
  s = [self _cachedStringForKey:_key
            inTableNamed:_tableName
            withDefaultValue:_default
            languages:_languages];
  if (s != nil) return s;
  
  if (self->nameToTable == nil)
    self->nameToTable = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  /* search for string */
  
  if ((table = [self resourceTableWithName:_tableName languages:_languages])){
    if ((s = [table stringForKey:_key withDefaultValue:nil]) != nil)
      return s;
  }

  if ((table = [self bundleTableWithName:_tableName languages:_languages])){
    if ((s = [table stringForKey:_key withDefaultValue:nil]) != nil)
      return s;
  }
  
  // TODO: shouldn't we return the default value?
  return nil;
}

- (id)stringTableWithName:(NSString *)_tableName
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages
{
  WEStringTable *table;
  
  if ((table = [self resourceTableWithName:_tableName languages:_languages]))
    return table;
  if ((table = [self bundleTableWithName:_tableName languages:_languages]))
    return table;
  
  return nil;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* WEStringTableManager */

@implementation WOApplication(WEStringTableManager)

- (NSString *)shareTranslationsDirectoryName {
  return [[self name] lowercaseString];
}
- (NSString *)gsTranslationsDirectoryName {
  return [self name];
}

@end /* WOApplication(WEStringTableManager) */
