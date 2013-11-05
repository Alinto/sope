/* 
   EOAttributeOrdering.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#include "EOAdaptor.h"
#include "EOAdaptorChannel.h"
#include "EOAdaptorContext.h"
#include "EOAttribute.h"
#include "EOFExceptions.h"
#include "EOModel.h"
#include "EOSQLExpression.h"
#include "common.h"

@implementation EOAdaptor

+ (id)adaptorWithModel:(EOModel*)_model {
    /* Check first to see if the adaptor class exists in the running program
       by testing the existence of [_model adaptorClassName]. */
    NSString *adaptorName = [_model adaptorName];
    Class    adaptorClass = NSClassFromString([_model adaptorClassName]);
    id       adaptor;

    adaptor = adaptorClass
        ? AUTORELEASE([[adaptorClass alloc] initWithName:adaptorName])
        : [self adaptorWithName:adaptorName];
    
    [adaptor setModel:_model];
    return adaptor;
}

+ (NSArray *)adaptorSearchPathes {
  // TODO: add support for Cocoa
  static NSArray *searchPathes = nil;
  NSMutableArray *ma;
  id             tmp;

  if (searchPathes != nil) return searchPathes;

  ma  = [NSMutableArray arrayWithCapacity:8];

#if GNUSTEP_BASE_LIBRARY
  NSEnumerator *libraryPaths;
  NSString *directory, *suffix;
  suffix = [self libraryDriversSubDir];
  libraryPaths = [NSStandardLibraryPaths() objectEnumerator];
  while ((directory = [libraryPaths nextObject]))
    [ma addObject: [directory stringByAppendingPathComponent: suffix]];
#else
  NSDictionary   *env;
  env = [[NSProcessInfo processInfo] environment];
  
  if ((tmp = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"]) == nil)
    tmp = [env objectForKey:@"GNUSTEP_PATHLIST"];
  tmp = [tmp componentsSeparatedByString:@":"];
  if ([tmp count] > 0) {
    NSEnumerator *e;
    
    e = [tmp objectEnumerator];
    while ((tmp = [e nextObject])) {
      if (![tmp hasSuffix:@"/"]) tmp = [tmp stringByAppendingString:@"/"];
      
      tmp = [tmp stringByAppendingFormat:@"Library/GDLAdaptors-%i.%i",
		   GDL_MAJOR_VERSION, GDL_MINOR_VERSION];
      
      if ([ma containsObject:tmp] || tmp == nil) continue;
      [ma addObject:tmp];
    }
  }
#endif
  
  tmp = [NSString stringWithFormat:
#ifdef CGS_LIBDIR_NAME
		    [CGS_LIBDIR_NAME stringByAppendingString:@"/sope-%i.%i/dbadaptors"],
#else
		    @"/lib/sope-%i.%i/dbadaptors",
#endif
		    SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION];

#ifdef FHS_INSTALL_ROOT
  [ma addObject:[FHS_INSTALL_ROOT stringByAppendingPathComponent:tmp]];
#endif

  [ma addObject:[@"/usr/local/" stringByAppendingString:tmp]];
  [ma addObject:[@"/usr/" stringByAppendingString:tmp]];
  searchPathes = [ma copy];
  if ([searchPathes count] == 0)
    NSLog(@"%s: empty library search path !", __PRETTY_FUNCTION__);
  return searchPathes;
}

+ (id)adaptorWithName:(NSString *)adaptorName {
  int      i, count;
  NSBundle *bundle;
  NSString *adaptorBundlePath = nil;
  Class    adaptorClass       = Nil;
  
  bundle = [NSBundle mainBundle];
    
  /* Check error */
  if ((adaptorName == nil) || [adaptorName isEqual:@""])
    return nil;
  
  /* Look in application bundle */
  bundle = [NSBundle mainBundle];
  adaptorBundlePath =
    [bundle pathForResource:adaptorName ofType:@"gdladaptor"];
  
  /* Look in standard paths */
  if (adaptorBundlePath == nil) {
    NSFileManager *fm;
    NSString *dirname;
    NSArray  *paths;
      
    fm      = [NSFileManager defaultManager];
    paths   = [self adaptorSearchPathes];
    dirname = [adaptorName stringByAppendingPathExtension:@"gdladaptor"];
      
    /* Loop through the paths and check each one */
    for (i = 0, count = [paths count]; i < count; i++) {
      NSString *p;
      BOOL isDir;
	
      p = [[paths objectAtIndex:i] stringByAppendingPathComponent:dirname];
      if (![fm fileExistsAtPath:p isDirectory:&isDir])
	continue;
      if (!isDir)
	continue;
	
      adaptorBundlePath = p;
      break;
    }
  }
    
  /* Make adaptor bundle */
  bundle = adaptorBundlePath
    ? [NSBundle bundleWithPath:adaptorBundlePath]
    : (NSBundle *)nil;
    
  /* Check bundle */
  if (bundle == nil) {
    NSLog(@"EOAdaptor: cannot find adaptor bundle: '%@'", adaptorName);
#if 0
    [[[[CannotFindAdaptorBundleException alloc]
	initWithFormat:@"Cannot find adaptor bundle '%@'",
	adaptorName] autorelease] raise];
#endif
    return nil;
  }

  /* load bundle */

  if (![bundle load]) {
    NSLog(@"Cannot load adaptor bundle '%@'", adaptorName);
#if 1
    [[[[InvalidAdaptorBundleException alloc]
	initWithFormat:@"Cannot load adaptor bundle '%@'",
	adaptorName] autorelease] raise];
#endif
    return nil;
  }
    
  /* Get the adaptor bundle "infoDictionary", and pricipal class, ie. the
     adaptor class. Other info about the adaptor should be put in the
     bundle's "Info.plist" file (property list format - see NSBundle class
     documentation for details about reserved keys in this dictionary
     property list containing one entry whose key is adaptorClassName. It
     identifies the actual adaptor class from the bundle. */
    
  adaptorClass = [bundle principalClass];
  if (adaptorClass == Nil) {
    NSLog(@"The adaptor bundle '%@' at '%@' doesn't contain "
	  @"a principal class (infoDict=%@)",
	  adaptorName, [bundle bundlePath], [bundle infoDictionary]);
      
    [[[InvalidAdaptorBundleException alloc]
       initWithFormat:@"The adaptor bundle '%@' doesn't contain "
       @"a principal class (infoDict=%@)",
       adaptorName, [bundle infoDictionary]]
      raise];
  }
  return AUTORELEASE([[adaptorClass alloc] initWithName:adaptorName]);
}

+ (NSString *)adaptorNameForURLScheme:(NSString *)_scheme {
  // TODO: map scheme to adaptors (eg 'postgresql://' to PostgreSQL
  
  // TODO: hack in some known names
  if ([_scheme isEqualToString:@"postgresql"]) return @"PostgreSQL";
  if ([_scheme isEqualToString:@"sybase"])     return @"Sybase10";
  if ([_scheme isEqualToString:@"sqlite"])     return @"SQLite3";
  if ([_scheme isEqualToString:@"oracle"])     return @"Oracle8";
  if ([_scheme isEqualToString:@"mysql"])      return @"MySQL";

  if ([_scheme isEqualToString:@"http"]) {
    NSLog(@"WARNING(%s): asked for 'http' URL, "
	  @"please fix the URLs to 'postgresql'!",
	  __PRETTY_FUNCTION__);
    return @"PostgreSQL";
  }
  
  return _scheme;
}

+ (NSString *)libraryDriversSubDir {
  return [NSString stringWithFormat:@"GDLAdaptors-%i.%i",
                     GDL_MAJOR_VERSION, GDL_MINOR_VERSION];
}

- (NSDictionary *)connectionDictionaryForNSURL:(NSURL *)_url {
  /*
    "Database URLs"
    
    We use the schema:
      postgresql://[user]:[password]@[host]:[port]/[dbname]/[tablename]
  */
  NSMutableDictionary *md;
  id tmp;
  
  md = [NSMutableDictionary dictionaryWithCapacity:8];
  
  if ((tmp = [_url host]) != nil) 
    [md setObject:tmp forKey:@"hostName"];
  if ((tmp = [_url port]) != nil) 
    [md setObject:tmp forKey:@"port"];
  if ((tmp = [_url user]) != nil) 
    [md setObject:tmp forKey:@"userName"];
  if ((tmp = [_url password]) != nil) 
    [md setObject:tmp forKey:@"password"];

  /* extract dbname */
  
  tmp = [_url path];
  if ([tmp hasPrefix:@"/"]) tmp = [tmp substringFromIndex:1];
  if ([tmp length] > 0) {
    NSRange r;
    
    r = [tmp rangeOfString:@"/"];
    if (r.length > 0) tmp = [tmp substringToIndex:r.location];
    
    if ([tmp length] > 0)
      [md setObject:tmp forKey:@"databaseName"];
  }
  
  return md;
}

+ (id)adaptorForNSURL:(NSURL *)_url {
  EOAdaptor    *adaptor;
  NSString     *adaptorName;
  NSDictionary *condict;
  
  if (_url == nil)
    return nil;
  
  adaptorName = [self adaptorNameForURLScheme:[_url scheme]];
  adaptor     = [self adaptorWithName:adaptorName];
  
  if ((condict = [adaptor connectionDictionaryForNSURL:_url]) != nil)
    [adaptor setConnectionDictionary:condict];
  
  return adaptor;
}

+ (id)adaptorForURL:(id)_url {
  NSURL *url;
  
  if (_url == nil)
    return nil;
  
  if ([_url isKindOfClass:[NSURL class]])
    url = _url;
  else if ((url = [NSURL URLWithString:[_url stringValue]]) == nil) {
    NSLog(@"ERROR(%s): could not parse URL: '%@'", __PRETTY_FUNCTION__, _url);
    return nil;
  }
  
  return [self adaptorForNSURL:url];
}

- (id)initWithName:(NSString*)_name {
    ASSIGN(self->name, _name);
    self->contexts = [[NSMutableArray allocWithZone:[self zone]] init];
    return self;
}

- (void)dealloc {
    RELEASE(self->model);
    RELEASE(self->name);
    RELEASE(self->connectionDictionary);
    RELEASE(self->pkeyGeneratorDictionary);
    RELEASE(self->contexts);
    [super dealloc];
}

/* accessors */

- (void)setConnectionDictionary:(NSDictionary*)_dictionary {
  if([self hasOpenChannels]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"Cannot set the connection dictionary "
		 @"while the adaptor is connected!"];
  }
  ASSIGN(self->connectionDictionary, _dictionary);
  [self->model setConnectionDictionary:_dictionary];
}
- (NSDictionary *)connectionDictionary {
  return self->connectionDictionary;
}
- (BOOL)hasValidConnectionDictionary {
  return NO;
}

- (EOAdaptorContext*)createAdaptorContext {
  return AUTORELEASE([[[self adaptorContextClass] alloc] 
                             initWithAdaptor:self]);
}
- (NSArray *)contexts {
  NSMutableArray *ma;
  unsigned i, count;
  
  if ((count = [self->contexts count]) == 0)
    return nil;

  ma = [NSMutableArray arrayWithCapacity:count];
  for (i = 0; i < count; i++)
    [ma addObject:[[self->contexts objectAtIndex:i] nonretainedObjectValue]];
  
  return ma;
}

/* Setting pkey generation info */

- (void)setPkeyGeneratorDictionary:(NSDictionary*)aDictionary {
  ASSIGN(self->pkeyGeneratorDictionary, aDictionary);
  [self->model setPkeyGeneratorDictionary:aDictionary];
}
- (NSDictionary*)pkeyGeneratorDictionary {
  return self->pkeyGeneratorDictionary;
}

// notifications

- (void)contextDidInit:aContext {
    [self->contexts addObject:[NSValue valueWithNonretainedObject:aContext]];
}

- (void)contextWillDealloc:aContext {
    int i;
    
    for (i = [contexts count]-1; i >= 0; i--) {
        if ([[contexts objectAtIndex:i] nonretainedObjectValue] == aContext) {
            [contexts removeObjectAtIndex:i];
            break;
        }
    }
}

- (BOOL)hasOpenChannels {
    int i;

    for (i = [contexts count] - 1; i >= 0; i--) {
        EOAdaptorContext* ctx = [[contexts objectAtIndex:i] 
            nonretainedObjectValue];
        if ([ctx hasOpenChannels])
            return YES;
    }
    return NO;
}

- (id)formatAttribute:(EOAttribute *)_attribute {
    return [_attribute expressionValueForContext:nil];
}

- (id)formatValue:(id)_value forAttribute:(EOAttribute *)attribute {
  if (_value == nil) _value = [NSNull null];
  return [_value expressionValueForContext:nil];
}

- (void)reportError:(NSString*)error {
    if(delegateWillReportError) {
        if([delegate adaptor:self willReportError:error] == NO)
            return;
    }
    NSLog(@"%@ adaptor error: %@", name, error);
}

- (void)setDelegate:(id)_delegate {
    self->delegate = _delegate;
    self->delegateWillReportError
        = [self->delegate respondsToSelector:
                            @selector(adaptor:willReportError:)];
}

- (void)setModel:(EOModel *)_model {
    ASSIGN(self->model, _model);
    [self setConnectionDictionary:[_model connectionDictionary]];
    [self setPkeyGeneratorDictionary:[_model pkeyGeneratorDictionary]];
}
- (EOModel *)model {
    return self->model;
}

- (NSString *)name {
    return self->name;
}

- (Class)expressionClass {
  return [EOSQLExpression class];
}
- (Class)adaptorContextClass {
  return [EOAdaptorContext class];
}
- (Class)adaptorChannelClass {
  return [EOAdaptorChannel class];
}

- (BOOL)attributeAllowedInDistinctSelects:(EOAttribute *)_attr {
  return YES;
}
- (BOOL)isValidQualifierType:(NSString*)typeName {
  return NO;
}
- (id)delegate {
  return self->delegate;
}

// description

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p]: name=%@ "
                     @"model=%s connection-dict=%s>",
                     NSStringFromClass([self class]), self,
                     [self name],
                     [self model] ? "yes" : "no",
                     [self connectionDictionary] ? "yes" : "no"];
}

@end /* EOAdaptor */

@implementation EOAdaptor(EOF2Additions)

- (BOOL)canServiceModel:(EOModel *)_model {
  return YES;
}

@end
