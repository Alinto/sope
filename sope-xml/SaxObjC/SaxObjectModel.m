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

#include "SaxObjectModel.h"
#include "common.h"

#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY || \
    APPLE_FOUNDATION_LIBRARY
bool _CFArrayIsMutable(CFArrayRef dict);
#endif

static NSDictionary *mapDictsToObjects(NSDictionary *_dict, Class clazz) {
  NSMutableDictionary *md;
  NSEnumerator *e;
  NSString     *key;
  
  md = [NSMutableDictionary dictionaryWithCapacity:16];
  
  e = [_dict keyEnumerator];
  while ((key = [e nextObject])) {
    id obj;

    obj = [[clazz alloc] initWithDictionary:[_dict objectForKey:key]];
    [md setObject:obj forKey:key];
    [obj release];
  }
  return md;
}

@implementation SaxObjectModel

static BOOL    doDebug = NO;
static NSArray *searchPathes = nil;

#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY || \
    APPLE_FOUNDATION_LIBRARY
static Class NSCFArrayClass = Nil;

+ (void)initialize {
  static BOOL isInitialized = NO;
  
  if (isInitialized) return;
  isInitialized = YES;
    NSCFArrayClass = NSClassFromString(@"NSCFArray");
}
#endif

+ (NSArray *)saxMappingSearchPathes {
  if (searchPathes == nil) {
    NSMutableArray *ma;
    NSDictionary   *env;
    
    env = [[NSProcessInfo processInfo] environment];
    ma  = [NSMutableArray arrayWithCapacity:6];

#if COCOA_Foundation_LIBRARY
    id tmp;
    tmp = NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory,
                                              NSAllDomainsMask,
                                              YES);
    if ([tmp count] > 0) {
      NSEnumerator *e;
      
      e = [tmp objectEnumerator];
      while ((tmp = [e nextObject])) {
        tmp = [tmp stringByAppendingPathComponent:@"SaxMappings"];
        if (![ma containsObject:tmp])
          [ma addObject:tmp];
      }
    }
#elif GNUSTEP_BASE_LIBRARY
    NSEnumerator *libraryPaths;
    NSString *directory, *suffix;

    suffix = [self libraryDriversSubDir];
    libraryPaths = [NSStandardLibraryPaths() objectEnumerator];
    while ((directory = [libraryPaths nextObject]))
      [ma addObject: [directory stringByAppendingPathComponent: suffix]];
#else
    id tmp;
    if ((tmp = [env objectForKey:@"GNUSTEP_PATHPREFIX_LIST"]) == nil)
      tmp = [env objectForKey:@"GNUSTEP_PATHLIST"];
    tmp = [tmp componentsSeparatedByString:@":"];
    if ([tmp count] > 0) {
      NSEnumerator *e;
      
      e = [tmp objectEnumerator];
      while ((tmp = [e nextObject])) {
        tmp = [tmp stringByAppendingPathComponent:@"Library/SaxMappings"];
        if (![ma containsObject:tmp])
          [ma addObject:tmp];
      }
    }
#endif
    
    /* FHS fallback */
    {
      NSString *p;
      
      p = [NSString stringWithFormat:@"share/sope-%i.%i/saxmappings/",
		      SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION];
#ifdef FHS_INSTALL_ROOT
      [ma addObject:[FHS_INSTALL_ROOT stringByAppendingPathComponent:p]];
#endif
      [ma addObject:[@"/usr/local/" stringByAppendingString:p]];
      [ma addObject:[@"/usr/"       stringByAppendingString:p]];
    }
    searchPathes = [ma copy];
    
    if ([searchPathes count] == 0)
      NSLog(@"%s: no search pathes were found!", __PRETTY_FUNCTION__);
  }
  return searchPathes;
}

+ (NSString *)libraryDriversSubDir {
  return [NSString stringWithFormat:@"SaxMappings"];
}

+ (id)modelWithName:(NSString *)_name {
  NSFileManager *fileManager;
  NSEnumerator  *pathes;
  NSString      *path;

  /* first look in main bundle */
  
  if ((path = [[NSBundle mainBundle] pathForResource:_name ofType:@"xmap"]))
    return [self modelWithContentsOfFile:path];

  /* then in Library */
  
  fileManager = [NSFileManager defaultManager];
  pathes      = [[[self class] saxMappingSearchPathes] objectEnumerator];
  _name       = [_name stringByAppendingPathExtension:@"xmap"];
  
  while ((path = [pathes nextObject])) {
    BOOL isDir;
    
    path = [path stringByAppendingPathComponent:_name];
    
    if (![fileManager fileExistsAtPath:path isDirectory:&isDir])
      continue;
    if (isDir)
      continue;
    
    break;
  }
  
  return [self modelWithContentsOfFile:path];
}

+ (id)modelWithContentsOfFile:(NSString *)_path {
  NSDictionary *dict;
  
  if ((dict = [NSDictionary dictionaryWithContentsOfFile:_path]) == nil)
    return nil;
  
  return [[[self alloc] initWithDictionary:dict] autorelease];
}

- (id)initWithDictionary:(NSDictionary *)_dict {
  self->nsToModel =
    [mapDictsToObjects(_dict, [SaxNamespaceModel class]) retain];
  return self;
}

- (void)dealloc {
  [self->nsToModel release];
  [super dealloc];
}

/* queries */

- (SaxTagModel *)modelForTag:(NSString *)_localName namespace:(NSString *)_ns {
  SaxNamespaceModel *nsmap;
  
  if ((nsmap = [self->nsToModel objectForKey:_ns]) == nil) {
    if ((nsmap = [self->nsToModel objectForKey:@"*"]) == nil)
      return nil;
  }
  return [nsmap modelForTag:_localName];
}

/* faking dictionary */

- (id)objectForKey:(id)_key {
  return [self->nsToModel objectForKey:_key];
}

@end /* SaxMappingModel */

@implementation SaxNamespaceModel

- (id)initWithDictionary:(NSDictionary *)_dict {
  self->tagToModel = [mapDictsToObjects(_dict, [SaxTagModel class]) retain];
  return self;
}

- (void)dealloc {
  [self->tagToModel release];
  [super dealloc];
}

/* queries */

- (SaxTagModel *)modelForTag:(NSString *)_localName {
  SaxTagModel *map;
  
  if ((map = [self->tagToModel objectForKey:_localName]))
    return map;
  if ((map = [self->tagToModel objectForKey:@"*"]))
    return map;
  return nil;
}

/* faking dictionary */

- (id)objectForKey:(id)_key {
  return [self->tagToModel objectForKey:_key];
}

@end /* SaxNamespaceModel */

@implementation SaxTagModel

- (NSDictionary *)_extractAttributeMapping:(NSDictionary *)as {
  NSMutableDictionary *md;
  NSEnumerator *keys;
  NSString     *k;
  NSDictionary *result;
      
  md = [[NSMutableDictionary alloc] initWithCapacity:16];
      
  keys = [as keyEnumerator];
  while ((k = [keys nextObject])) {
    id val;
	
    val = [as objectForKey:k];
	
    if ([val isKindOfClass:[NSString class]])
      [md setObject:val forKey:k];
    else if ([val count] == 0)
      [md setObject:k forKey:k];
    else 
      [md setObject:[(NSDictionary *)val objectForKey:@"key"] forKey:k];
  }
  
  result = [md copy];
  [md release];
  return result;
}

- (id)initWithDictionary:(NSDictionary *)_dict {
  if ((self = [super init])) {
    NSDictionary *rels;
    NSDictionary *as;
    
    self->className     = [[_dict objectForKey:@"class"]  copy];
    self->key           = [[_dict objectForKey:@"key"]    copy];
    self->tagKey        = [[_dict objectForKey:@"tagKey"] copy];
    self->namespaceKey  = [[_dict objectForKey:@"namespaceKey"] copy];
    self->parentKey     = [[_dict objectForKey:@"parentKey"] copy];
    self->contentKey    = [[_dict objectForKey:@"contentKey"] copy];
    self->defaultValues = [[_dict objectForKey:@"defaultValues"] copy];
    
    if ((as = [_dict objectForKey:@"attributes"]))
      self->attrToKey = [self _extractAttributeMapping:as];
    
    if ((rels = [_dict objectForKey:@"ToManyRelationships"])) {
      NSMutableDictionary *md;
      NSEnumerator *keys;
      NSString *k;
      
      self->toManyRelationshipKeys = [[rels allKeys] copy];
    
      md = [[NSMutableDictionary alloc] initWithCapacity:16];
      
      keys = [self->toManyRelationshipKeys objectEnumerator];
      while ((k = [keys nextObject])) {
	id       tags;
	NSString *tag;
	
	tags = [rels objectForKey:k];
	if ([tags isKindOfClass:[NSString class]])
	  tags = [NSArray arrayWithObject:tags];
	tags = [tags objectEnumerator];
	
	while ((tag = [tags nextObject])) {
	  NSString *t;
	  
	  if ((t = [md objectForKey:tag])) {
	    NSLog(@"SaxObjectModel: cannot map tag '%@' to key '%@', "
		  @"it is already mapped to key '%@'.",
		  tag, k, t);
	  }
	  else {
	    [md setObject:k forKey:tag];
	  }
	}
      }
      self->tagToKey = [md copy];
      [md release];
    }
    
  }
  return self;
}

- (void)dealloc {
  [self->defaultValues          release];
  [self->toManyRelationshipKeys release];
  [self->tagToKey     release];
  [self->className    release];
  [self->tagKey       release];
  [self->namespaceKey release];
  [self->parentKey  release];
  [self->contentKey release];
  [self->key        release];
  [self->attrToKey  release];
  [super dealloc];
}

/* accessors */

- (NSString *)className {
  return self->className;
}
- (NSString *)key {
  return self->key;
}
- (NSString *)tagKey {
  return self->tagKey;
}
- (NSString *)namespaceKey {
  return self->namespaceKey;
}
- (NSString *)parentKey {
  return self->parentKey;
}
- (NSString *)contentKey {
  return self->contentKey;
}

- (NSDictionary *)defaultValues {
  return self->defaultValues;
}

- (BOOL)isToManyKey:(NSString *)_key {
  return [self->toManyRelationshipKeys containsObject:_key];
}
- (NSArray *)toManyRelationshipKeys {
  return self->toManyRelationshipKeys;
}

- (BOOL)isToManyTag:(NSString *)_tag {
  return ([self->tagToKey objectForKey:_tag] != nil) ? YES : NO;
}

- (NSString *)propertyKeyForChildTag:(NSString *)_tag {
  return [self->tagToKey objectForKey:_tag];
}

- (NSArray *)attributeKeys {
  return [self->attrToKey allKeys];
}
- (NSString *)propertyKeyForAttribute:(NSString *)_attr {
  return [self->attrToKey objectForKey:_attr];
}

/* object operations */

- (void)addValue:(id)_value toPropertyWithKey:(NSString *)_key 
  ofObject:(id)_object
{
  NSString *selname;
  SEL      sel;
  
  selname = [[NSString alloc] initWithFormat:@"addTo%@:", 
			      [_key capitalizedString]];
  if ((sel = NSSelectorFromString(selname)) == NULL) {
    if (doDebug) {
      NSLog(@"got no selector for key '%@', selname '%@' !",
	    _key, selname);
    }
  }
  [selname release]; selname = nil;
  
  if (doDebug) {
    NSLog(@"%s: adding value %@ to %@ of %@", __PRETTY_FUNCTION__,
	  _value, _key, _object);
    NSLog(@"  selector: %@", NSStringFromSelector(sel));
  }
  
  if ((sel != NULL) && [_object respondsToSelector:sel]) {
    [_object performSelector:sel withObject:_value];
  }
  else {
    id v;
    
    v = [_object valueForKey:_key];
    
    if ([self isToManyKey:_key]) {
      /* to-many relationship */

      if (v == nil) {
        [_object takeValue:[NSArray arrayWithObject:_value] forKey:_key];
      }
      else {
#if NeXT_Foundation_LIBRARY || COCOA_Foundation_LIBRARY || \
    APPLE_FOUNDATION_LIBRARY
        if ([v isKindOfClass:NSCFArrayClass] &&
            _CFArrayIsMutable((CFArrayRef)v))
#else
        if ([v respondsToSelector:@selector(addObject:)])
#endif
	  /* the value is mutable */
          [v addObject:_value];
        else {
	  /* the value is immutable */
          v = [v arrayByAddingObject:_value];
          [_object takeValue:v forKey:_key];
        }
      }
    }
    else {
      NSLog(@" APPLIED ON TO-ONE (%@) !", _key);
      /* to-one relationship */
      if (v != _value)
        [_object takeValue:v forKey:_key];
    }
  }
}

@end /* SaxTagModel */
