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

#include "SaxXMLReaderFactory.h"
#include "common.h"

#if GNUSTEP_BASE_LIBRARY
@implementation NSBundle(Copying)
- (id)copyWithZone:(NSZone *)_zone {
  return [self retain];
}
@end
#endif

@implementation SaxXMLReaderFactory

static BOOL    coreOnMissingParser = NO;
static BOOL    debugOn       = NO;
static NSArray *searchPathes = nil;
static NSNull  *null         = nil;
static id      factory       = nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  coreOnMissingParser = [ud boolForKey:@"SaxCoreOnMissingParser"];
  debugOn             = [ud boolForKey:@"SaxDebugReaderFactory"];
}

+ (id)standardXMLReaderFactory {
  if (factory == nil)
    factory = [[self alloc] init];
  return factory;
}

- (void)dealloc {
  [self->nameToBundle   release];
  [self->mimeTypeToName release];
  [super dealloc];
}

/* operations */

- (void)flush {
  [self->nameToBundle   release]; self->nameToBundle   = nil;
  [self->mimeTypeToName release]; self->mimeTypeToName = nil;
}

/* search path construction */

- (BOOL)searchFrameworkBundle {
#if COMPILE_AS_FRAMEWORK
  return YES;
#else
  return NO;
#endif
}

- (NSString *)libraryDriversSubDir {
  return [NSString stringWithFormat:@"SaxDrivers-%i.%i", 
		     SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION];
}

- (void)addSearchPathesForCocoa:(NSMutableArray *)ma {
  /* for Cocoa */
  id tmp;
  
  tmp = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,
					    NSAllDomainsMask,
					    YES);
  if ([tmp count] > 0) {
    NSEnumerator *e;
    NSString *subdir;
    
    subdir = [self libraryDriversSubDir];
    e = [tmp objectEnumerator];
    while ((tmp = [e nextObject]) != nil) {
      tmp = [tmp stringByAppendingPathComponent:subdir];
      if (![ma containsObject:tmp])
	[ma addObject:tmp];
    }
  }
  if ([self searchFrameworkBundle]) {
    NSBundle *fwBundle;
      
    /* no need to add 4.5 here, right? */
    fwBundle = [NSBundle bundleForClass:[self class]];
    tmp = [[fwBundle resourcePath] stringByAppendingPathComponent:
				     @"SaxDrivers"];
    [ma addObject:tmp];
  }
}

- (void)addSearchPathesForStdLibPathes:(NSMutableArray *)ma {
  /* for gstep-base */
  NSEnumerator *e;
  NSString *subdir;
  id tmp;
  
#if !COCOA_Foundation_LIBRARY && !NeXT_Foundation_LIBRARY
  tmp = NSStandardLibraryPaths();
#else
  tmp = nil; /* not available on Cocoa? */
#endif
  if ([tmp count] == 0)
    return;
  
  subdir = [self libraryDriversSubDir];
  e = [tmp objectEnumerator];
  while ((tmp = [e nextObject]) != nil) {
    tmp = [tmp stringByAppendingPathComponent:subdir];
    if ([ma containsObject:tmp])
      continue;

    [ma addObject:tmp];
  }
}

- (void)addSearchPathesForGNUstepEnv:(NSMutableArray *)ma {
  /* for libFoundation */
#if GNUSTEP_BASE_LIBRARY
NSEnumerator *libraryPaths;
  NSString *directory, *suffix;

  suffix = [self libraryDriversSubDir];
  libraryPaths = [NSStandardLibraryPaths() objectEnumerator];
  while ((directory = [libraryPaths nextObject]))
    [ma addObject: [directory stringByAppendingPathComponent: suffix]];
#else  
  NSString *subdir;
  NSEnumerator *e;
  NSDictionary *env;
  id tmp;
  env = [[NSProcessInfo processInfo] environment];
  
  if ((tmp = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"]) == nil)
    tmp = [env objectForKey:@"GNUSTEP_PATHLIST"];
  tmp = [tmp componentsSeparatedByString:@":"];
  if ([tmp count] == 0)
    return;
  
  subdir = [@"Library/" stringByAppendingString:[self libraryDriversSubDir]];
  e = [tmp objectEnumerator];
  while ((tmp = [e nextObject]) != nil) {
    tmp = [tmp stringByAppendingPathComponent:subdir];
    if ([ma containsObject:tmp])
      continue;

    [ma addObject:tmp];
  }
#endif
}

- (NSArray *)saxReaderSearchPathes {
  NSMutableArray *ma;
  id tmp;
  
  if (searchPathes != nil)
    return searchPathes;
  
  ma = [NSMutableArray arrayWithCapacity:8];
  
#if COCOA_Foundation_LIBRARY
  /* Note: do not use NeXT_Foundation_LIBRARY, this is only for Xcode! */
  [self addSearchPathesForCocoa:ma];
#elif GNUSTEP_BASE_LIBRARY
  [self addSearchPathesForStdLibPathes:ma];
#else
  [self addSearchPathesForGNUstepEnv:ma];
#endif
  
  /* FHS fallback */
  
  tmp = [[NSString alloc] initWithFormat:
#ifdef CGS_LIBDIR_NAME
			    [CGS_LIBDIR_NAME stringByAppendingString:@"/sope-%i.%i/saxdrivers/"],
#else
			    @"lib/sope-%i.%i/saxdrivers/",
#endif
			    SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION];
  
#ifdef FHS_INSTALL_ROOT
  [ma addObject:[FHS_INSTALL_ROOT stringByAppendingPathComponent:tmp]];
#endif

  // TODO: should we always add those? or maybe derive from PATH or
  //       LD_LIBRARY_PATH?
  [ma addObject:[@"/usr/local/" stringByAppendingString:tmp]];
  [ma addObject:[@"/usr/"       stringByAppendingString:tmp]];
  [tmp release]; tmp = nil;
  searchPathes = [ma copy];
  
  if ([searchPathes count] == 0)
    NSLog(@"%s: no search pathes were found!", __PRETTY_FUNCTION__);
  
  return searchPathes;
}

/* loading */

- (void)_loadBundlePath:(NSString *)_bundlePath
  infoDictionary:(NSDictionary *)_info
  nameMap:(NSMutableDictionary *)_nameMap
  typeMap:(NSMutableDictionary *)_typeMap
{
  NSArray      *drivers;
  NSEnumerator *e;
  NSDictionary *driverInfo;
  NSBundle     *bundle;

  _info = [_info objectForKey:@"provides"];
  if ((drivers = [_info objectForKey:@"SAXDrivers"]) == nil) {
    NSLog(@"%s: .sax bundle '%@' does not provide any SAX drivers ...",
          __PRETTY_FUNCTION__, _bundlePath);
    return;
  }
  
  if ((bundle = [NSBundle bundleWithPath:_bundlePath]) == nil) {
    NSLog(@"%s: could not create bundle from path '%@'",
          __PRETTY_FUNCTION__, _bundlePath);
    return;
  }
  
  /* found a driver with valid info dict, process it ... */
  
  e = [drivers objectEnumerator];
  while ((driverInfo = [e nextObject]) != nil) {
    NSString     *name, *tname;
    NSEnumerator *te;
    
    name = [driverInfo objectForKey:@"name"];
    if ([name length] == 0) {
      NSLog(@"%s: missing name in sax driver section of bundle %@ ...",
            __PRETTY_FUNCTION__, _bundlePath);
      continue;
    }

    /* check if name is already registered */
    if ([_nameMap objectForKey:name]) {
      if (debugOn)
        NSLog(@"%s: already have sax driver named '%@' ...",
              __PRETTY_FUNCTION__, name);
      continue;
    }

    /* register bundle for name */
    [_nameMap setObject:bundle forKey:name];

    /* register MIME-types */
    te = [[driverInfo objectForKey:@"sourceTypes"] objectEnumerator];
    while ((tname = [te nextObject])) {
      NSString *tmp;
      
      if ((tmp = [_typeMap objectForKey:tname])) {
        NSLog(@"WARNING(%s): multiple parsers available for MIME type '%@', "
              @"using '%@' as default for type %@.", 
              __PRETTY_FUNCTION__, tname, tmp, tname);
        continue;
      }
      
      [_typeMap setObject:name forKey:tname];
    }
  }
}

- (void)_loadLibraryPath:(NSString *)_libraryPath
  nameMap:(NSMutableDictionary *)_nameMap
  typeMap:(NSMutableDictionary *)_typeMap
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator  *e;
  NSString      *p;
  
  e = [[fm directoryContentsAtPath:_libraryPath] objectEnumerator];
  while ((p = [e nextObject]) != nil) {
    NSDictionary *info;
    NSString     *infoPath;
    BOOL         isDir;
    
    if (![p hasSuffix:@".sax"]) continue;
    
    p = [_libraryPath stringByAppendingPathComponent:p];
    if (![fm fileExistsAtPath:p isDirectory:&isDir])
      continue;
    if (!isDir) { /* info file is a directory ??? */
      NSLog(@"%s: .sax is not a dir: '%@' ???", __PRETTY_FUNCTION__, p);
      continue;
    }

    infoPath = [p stringByAppendingPathComponent:@"bundle-info.plist"];
    if (![fm fileExistsAtPath:infoPath]) {
      NSBundle *b;
      
      b = [NSBundle bundleWithPath:p];
      infoPath = [b pathForResource:@"bundle-info" ofType:@"plist"];
      if (![fm fileExistsAtPath:infoPath]) {
	NSLog(@"%s: did not find bundle-info dictionary in driver: '%@'",
	      __PRETTY_FUNCTION__, infoPath);
	continue;
      }
    }
    
    if ((info = [NSDictionary dictionaryWithContentsOfFile:infoPath]) == nil) {
      NSLog(@"%s: could not parse bundle-info dictionary: '%@'",
            __PRETTY_FUNCTION__, infoPath);
      continue;
    }
    
    [self _loadBundlePath:p infoDictionary:info
          nameMap:_nameMap typeMap:_typeMap];
  }
}

- (void)_loadAvailableBundles {
  NSAutoreleasePool *pool;
  
  /* setup globals */
  if (null == nil)
    null = [[NSNull null] retain];

#if DEBUG
  NSAssert(self->nameToBundle   == nil, @"already set up !");
  NSAssert(self->mimeTypeToName == nil, @"partially set up !");
#else
  if (self->nameToBundle != nil) return;
#endif
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    /* lookup bundle in Libary/SaxDrivers pathes */
    NSEnumerator        *pathes;
    NSString            *path;
    NSMutableDictionary *nameMap, *typeMap;

    nameMap = [NSMutableDictionary dictionaryWithCapacity:16];
    typeMap = [NSMutableDictionary dictionaryWithCapacity:16];
    
    pathes = [[self saxReaderSearchPathes] objectEnumerator];
    while ((path = [pathes nextObject]))
      [self _loadLibraryPath:path nameMap:nameMap typeMap:typeMap];
    
    self->nameToBundle   = [nameMap copy];
    self->mimeTypeToName = [typeMap copy];

#if DEBUG
    if ([self->nameToBundle count] == 0) {
      NSLog(@"%s: no XML parser could be found in pathes: %@", 
	    __PRETTY_FUNCTION__, [self saxReaderSearchPathes]);
    }
    else if ([self->mimeTypeToName count] == 0) {
      NSLog(@"%s: no XML parser declared a MIME type ...",__PRETTY_FUNCTION__);
    }
#endif
  }
  [pool release];
}

- (id<NSObject,SaxXMLReader>)createXMLReader {
  NSString *defReader;
  id       reader;

  if (debugOn) NSLog(@"%s: lookup default XML reader ...",__PRETTY_FUNCTION__);
  
  defReader = 
    [[NSUserDefaults standardUserDefaults] stringForKey:@"XMLReader"];

  if (debugOn) NSLog(@"%s:   default name ...",__PRETTY_FUNCTION__, defReader);
  
  if (defReader) {
    if ((reader = [self createXMLReaderWithName:defReader]))
      return reader;

    NSLog(@"%s: could not create default XMLReader '%@' !",
          __PRETTY_FUNCTION__, defReader);
  }
  
  return [self createXMLReaderForMimeType:@"text/xml"];
}

- (id<NSObject,SaxXMLReader>)createXMLReaderWithName:(NSString *)_name {
  NSBundle *bundle;
  Class    readerClass;
  
  if (debugOn)
    NSLog(@"%s: lookup XML reader with name: '%@'",__PRETTY_FUNCTION__,_name);
  
  if ([_name length] == 0)
    return [self createXMLReader];
  
  if (self->nameToBundle == nil)
    [self _loadAvailableBundles];
  
  if ((bundle = [self->nameToBundle objectForKey:_name]) == nil)
    return nil;
  
  /* load bundle executable code */
  if (![bundle load]) {
    NSLog(@"%s: could not load SaxDriver bundle %@ !", __PRETTY_FUNCTION__,
          bundle);
    return nil;
  }
  
  NSAssert(bundle, @"should have a loaded bundle at this stage ...");
  
  /* lookup class */
  if ((readerClass = NSClassFromString(_name)) == Nil) {
    NSLog(@"WARNING(%s): could not find SAX reader class %@ (SAX bundle=%@)",
          __PRETTY_FUNCTION__, _name, bundle);
    return nil;
  }
  
  /* create instance */
  return [[[readerClass alloc] init] autorelease];
}

- (id<NSObject,SaxXMLReader>)createXMLReaderForMimeType:(NSString *)_mtype {
  id<NSObject,SaxXMLReader> reader;
  NSString *name;

  if (self->mimeTypeToName == nil)
    [self _loadAvailableBundles];
  
  if (debugOn)
    NSLog(@"%s: lookup XML reader for type: '%@'",__PRETTY_FUNCTION__, _mtype);
  
  if ([_mtype respondsToSelector:@selector(stringValue)])
    _mtype = [(id)_mtype stringValue];
  if ([_mtype length] == 0)
    _mtype = @"text/xml";
  
  if ((name = [self->mimeTypeToName objectForKey:_mtype]) == nil) {
    if (debugOn) {
      NSLog(@"%s: did not find SAX parser for MIME type %@ map: \n%@",
	    __PRETTY_FUNCTION__, _mtype, self->mimeTypeToName);
      NSLog(@"%s: parsers: %@", __PRETTY_FUNCTION__, 
	    [self->nameToBundle allKeys]);
    }
    if (coreOnMissingParser) {
      NSLog(@"%s: aborting, because 'SaxCoreOnMissingParser' "
	    @"default is enabled!", __PRETTY_FUNCTION__);
      abort();
    }
    return nil;
  }
  if (debugOn) 
    NSLog(@"%s:  found XML reader named: '%@'", __PRETTY_FUNCTION__, name);
  
  reader = [self createXMLReaderWithName:name];

  if (debugOn)
    NSLog(@"%s:  created XML reader: %@", __PRETTY_FUNCTION__, reader);
  return reader;
}

- (NSArray *)availableXMLReaders {
  return [self->nameToBundle allKeys];
}

@end /* SaxXMLReaderFactory */
