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

#include "SaxObjectDecoder.h"
#include "SaxObjectModel.h"
#include "common.h"

static BOOL debugOn = NO;

@interface _SaxObjTagInfo : NSObject
{
@public
  SaxObjectDecoder *decoder;    /* non-retained */
  _SaxObjTagInfo   *parentInfo; /* non-retained */
  SaxTagModel *mapping;
  NSString    *tagName;
  NSString    *namespace;
  NSException *error;
  id          object;
  struct {
    int isRoot:1;
    int isMutableDict:1;
    int isString:1;
    int isMutableString:1;
    int hasContentKey:1;
  } flags;
  NSMutableString *collectedCharData;
}

/* accessors */

- (SaxTagModel *)mapping;
- (id)object;

/* tag handling */

- (void)start;
- (void)stop;

- (void)characters:(unichar *)_chars length:(int)_len;

@end

@implementation SaxObjectDecoder

static NSNull *null = nil;

+ (void)initialize {
  static BOOL    didInit = NO;
  NSUserDefaults *ud;

  if (didInit) return;
  didInit = YES;

  null    = [[NSNull null] retain];
  ud      = [NSUserDefaults standardUserDefaults];
  debugOn = [ud boolForKey:@"SaxObjectDecoderDebugEnabled"];
}

- (id)initWithMappingModel:(SaxObjectModel *)_model {
  if ((self = [super init])) {
    self->mapping = [_model retain];
  }
  return self;
}

- (id)initWithMappingAtPath:(NSString *)_path {
  SaxObjectModel *model;

  model = [SaxObjectModel modelWithContentsOfFile:_path];
  return [self initWithMappingModel:model];
}
- (id)initWithMappingNamed:(NSString *)_name {
  SaxObjectModel *model;
  
  model = [SaxObjectModel modelWithName:_name];
  return [self initWithMappingModel:model];
}

- (id)init {
  return [self initWithMappingModel:nil];
}

- (void)dealloc {
  [self->locator      release];
  [self->rootObject   release];
  [self->mapping      release];

  [self->infoStack    release];
  [self->mappingStack release];
  [self->objectStack  release];
  [super dealloc];
}

/* parse results */

- (id)rootObject {
  return self->rootObject;
}

/* cleanup */

- (void)parseReset {
  NSAutoreleasePool *pool;
  
  pool = [[NSAutoreleasePool alloc] init];
  [self->infoStack    removeAllObjects];
  [self->mappingStack removeAllObjects];
  [self->objectStack  removeAllObjects];
  [pool release];
}
- (void)reset {
  [self parseReset];
  
  [self->rootObject release]; 
  self->rootObject = nil;
}

/* parsing */

- (void)startDocument {
  [self reset];
  
  if (self->infoStack == nil)
    self->infoStack = [[NSMutableArray alloc] initWithCapacity:16];
}

- (void)endDocument {
  [self parseReset];
}

/* positioning info */

- (void)setDocumentLocator:(id<NSObject,SaxLocator>)_locator {
  ASSIGN(self->locator, _locator);
}

/* stacks */

- (void)pushInfo:(_SaxObjTagInfo *)_info {
  [self->infoStack addObject:_info];
}
- (void)popInfo {
  [self->infoStack removeObjectAtIndex:([self->infoStack count] - 1)];
}
- (id)currentInfo {
  return [self->infoStack lastObject];
}

/* elements */

- (NSException *)missingNamespaceMapping:(NSString *)_ns {
  return [NSException exceptionWithName:@"MissingNamespaceMapping"
		      reason:_ns
		      userInfo:nil];
}
- (NSException *)missingElementMapping:(NSString *)_ns:(NSString *)_tag {
  return [NSException exceptionWithName:@"MissingElementMapping"
		      reason:_tag
		      userInfo:nil];
}
- (NSException *)missingMappedClass:(NSString *)_className {
  return [NSException exceptionWithName:@"MissingMappedClass"
		      reason:_className
		      userInfo:nil];
}

- (SaxTagModel *)mappingForTag:(NSString *)_tag namespace:(NSString *)_ns {
  return [self->mapping modelForTag:_tag namespace:_ns];
}

- (void)couldNotApplyAttribute:(NSString *)_attr asKey:(NSString *)_key
  onObject:(id)_object
{
  NSLog(@"SaxObjectDecoder: could not apply attribute '%@' (key=%@) "
	@"on object %@",
	_attr, _key, _object);
}

- (void)startElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
  attributes:(id<SaxAttributes>)_attributes
{
  _SaxObjTagInfo *info;
  
  info = [_SaxObjTagInfo alloc];
  info->decoder      = self;
  info->flags.isRoot = [self->infoStack count] == 0 ? 1 : 0;
  info->parentInfo   = info->flags.isRoot ? nil : [self->infoStack lastObject];
  info->tagName      = [_localName copy];
  info->namespace    = [_ns        copy];
  
  [self->infoStack addObject:info];
  [info release];

  /* determine mapping dictionary */
  
  if ((info->mapping = [self mappingForTag:_localName namespace:_ns]) == nil) {
    if (debugOn) {
      NSLog(@"found no mapping for element '%@' (namespace %@)", 
	    _localName, _ns);
    }
    info->error = [[self missingElementMapping:_ns:_localName] retain];
    return;
  }
  
  /* start object */
  [info start];
  
  /* add attribute values */
  {
    NSEnumerator *e;
    NSString     *a;
    
    e = [[info->mapping attributeKeys] objectEnumerator];
    while ((a = [e nextObject])) {
      NSString *v, *key;
      
      if ((v = [_attributes valueForName:a uri:_ns])) {
	key = [info->mapping propertyKeyForAttribute:a];
	
	NS_DURING
	  [info->object takeValue:v forKey:key];
	NS_HANDLER
	  [self couldNotApplyAttribute:a asKey:key onObject:info->object];
	NS_ENDHANDLER;
      }
    }
  }
}
- (void)endElement:(NSString *)_localName
  namespace:(NSString *)_ns
  rawName:(NSString *)_rawName
{
  _SaxObjTagInfo *info;
  unsigned idx;

  idx = [self->infoStack count] - 1;
  info = [self->infoStack objectAtIndex:idx];
  [info stop];
  
  if (idx == 0)
    ASSIGN(self->rootObject, [info object]);
  
  [self->infoStack removeObjectAtIndex:idx];
}

/* CDATA */

- (void)characters:(unichar *)_chars length:(int)_len {
  _SaxObjTagInfo *info;
  
  if (_len == 0) return;
  info = [self->infoStack objectAtIndex:([self->infoStack count] - 1)];
  [info characters:_chars length:_len];
}

- (BOOL)processIgnorableWhitespace {
  return NO;
}

- (void)ignorableWhitespace:(unichar *)_chars length:(int)_len {
  if ([self processIgnorableWhitespace])
    [self characters:_chars length:_len];
}

@end /* SaxObjectDecoder */

@implementation NSObject(SaxObjectCoding)

- (id)initWithSaxDecoder:(SaxObjectDecoder *)_decoder {
  return [self init];
}

- (id)awakeAfterUsingSaxDecoder:(SaxObjectDecoder *)_decoder {
  return self;
}

@end /* SaxCoding */

@implementation _SaxObjTagInfo

static Class  MutableDictClass   = Nil;
static Class  MutableStringClass = Nil;
static Class  StringClass        = Nil;

+ (void)initialize {
  MutableDictClass   = [NSMutableDictionary class];
  MutableStringClass = [NSMutableString     class];
  StringClass        = [NSString            class];
}

- (void)dealloc {
  [self->tagName   release];
  [self->namespace release];
  [self->error     release];
  [self->object    release];
  [self->collectedCharData release];
  [super dealloc];
}

/* errors */

- (NSException *)missingMappedClass:(NSString *)_className {
  return [NSException exceptionWithName:@"MissingMappedClass"
		      reason:_className
		      userInfo:nil];
}

/* accessors */

- (SaxTagModel *)mapping {
  return self->mapping;
}
- (id)object {
  return (self->object == null) ? nil : self->object;
}

- (SaxTagModel *)parentMapping {
  return [self->parentInfo mapping];
}
- (id)parentObject {
  return [self->parentInfo object];
}

/* run */

- (Class)defaultElementClass {
  return [NSMutableDictionary class];
}

- (void)unableToSetValue:(id)_object forKey:(NSString *)_key
  withTag:(NSString *)_tag toParent:(id)_parent
  exception:(NSException *)_exc
{
  NSLog(@"couldn't apply value %@ for key %@ with parent %@<%@>: %@",
	_object, _key, _parent, NSStringFromClass([_parent class]), _exc);
}

- (void)addObject:(id)_object fromTag:(NSString *)_tag
  withMapping:(SaxTagModel *)_elementMap
  toParent:(id)_parent withMapping:(SaxTagModel *)_parentMap
{
  NSString *key;

  if (_object     == nil || _object     == null) return;
  if (_parent     == nil || _parent     == null) return;
  if (_elementMap == nil || _elementMap == (id)null) return;
  if (_parentMap  == nil || _parentMap  == (id)null) return;
  
  if ((key = [_parentMap propertyKeyForChildTag:_tag]) == nil) {
    if ((key = [_elementMap key]) == nil)
      key = _tag;
  }
  
  NS_DURING {
    if ([_parentMap isToManyKey:key]) {
      [_parentMap addValue:_object toPropertyWithKey:key ofObject:_parent];
    }
    else {
      [_parent takeValue:_object forKey:key];
    }
  }
  NS_HANDLER {
    [self unableToSetValue:_object forKey:key withTag:_tag toParent:_parent
          exception:localException];
  }
  NS_ENDHANDLER;
}

- (void)start {
  NSString *s;
  Class    mappedClazz;
  
  /* determine class */
  
  if ((s = [self->mapping className])) {
    mappedClazz = NSClassFromString(s);
    if (mappedClazz == Nil) {
      self->error = [[self missingMappedClass:s] retain];
      return;
    }
  }
  else
    mappedClazz = [self defaultElementClass];
  
  /* do we need to check for subclasses? I guess not. */
  self->flags.isMutableDict   = (mappedClazz == MutableDictClass)   ? 1 : 0;
  self->flags.isMutableString = (mappedClazz == MutableStringClass) ? 1 : 0;
  self->flags.isString        = (mappedClazz == StringClass)        ? 1 : 0;
  self->flags.hasContentKey   = [[self->mapping contentKey] length] > 0 ?1:0;
  
  /* create an object for the element .. */
  
  if ((self->object = [[mappedClazz alloc] initWithSaxDecoder:self->decoder])) {
    NSDictionary *defaultValues;
    id tmp;
    
    if ((defaultValues = [self->mapping defaultValues]))
      [self->object takeValuesFromDictionary:defaultValues];
    
    if ((tmp = [self->mapping tagKey]))
      [self->object takeValue:self->tagName forKey:tmp];
    if ((tmp = [self->mapping namespaceKey]))
      [self->object takeValue:self->namespace forKey:tmp];
  }
}

- (void)stop {
  id tmp;

  /* awake from decoding (the decoded object can replace itself :-) */
  
  if (self->flags.isString) {
  }
  else {
    if (self->flags.hasContentKey) {
      NSString *s;

      s = [self->collectedCharData copy];
      ASSIGN(self->collectedCharData, (id)nil);
      
      [self->object takeValue:s forKey:[self->mapping contentKey]];
      [s release];
    }
    
    tmp = self->object;
    self->object =
      [[self->object awakeAfterUsingSaxDecoder:self->decoder] retain];
    [tmp release];
  }
  if (!self->flags.isRoot) {
    NSString *t;
    id parent;

    parent = [self parentObject];
    
    /* add to parent */

    if ((t = [self->mapping parentKey]))
      [self->object takeValue:parent forKey:t];
    
    [self addObject:self->object 
	  fromTag:self->tagName
	  withMapping:self->mapping
	  toParent:parent
	  withMapping:[self parentMapping]];
  }
}

- (void)characters:(unichar *)_chars length:(int)_len {
  if (self->flags.isMutableString) {
    NSString *tmp;
    
    tmp = [[NSString alloc] initWithCharacters:_chars length:_len];
    [self->object appendString:tmp];
    [tmp release];
  }
  else if (self->flags.isString) {
    NSString *tmp, *old;

    old = self->object;
    
    tmp = [[NSString alloc] initWithCharacters:_chars length:_len];
    self->object = [[self->object stringByAppendingString:tmp] retain];
    [tmp release];
    [old release];
  }
  else if (self->flags.hasContentKey) {
    if (self->collectedCharData == nil) {
      self->collectedCharData = 
	[[NSMutableString alloc] initWithCharacters:_chars length:_len];
    }
    else {
      NSString *tmp;
      
      tmp = [[NSString alloc] initWithCharacters:_chars length:_len];
      [self->collectedCharData appendString:tmp];
      [tmp release];
    }
  }
}

@end /* _SaxObjTagInfo */
