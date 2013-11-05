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

#include "EOKeyMapDataSource.h"
#include "NSArray+enumerator.h"
#include "EODataSource+NGExtensions.h"
#include "NSNull+misc.h"
#import <EOControl/EOControl.h>
#include "common.h"
#include <sys/time.h>

@interface EOKeyMapDataSource(Private)
- (void)_registerForSource:(id)_source;
- (void)_removeObserverForSource:(id)_source;
- (void)_sourceChanged;
@end

@implementation EOKeyMapDataSource

- (id)initWithDataSource:(EODataSource *)_ds map:(id)_map {
  if ((self = [super init])) {
    self->source  = [_ds  retain];
    self->map     = [_map retain];
    [self _registerForSource:self->source];
  }
  return self;
}
- (id)initWithDataSource:(EODataSource *)_ds {
  return [self initWithDataSource:_ds map:nil];
}
- (id)init {
  return [self initWithDataSource:nil map:nil];
}

- (void)dealloc {
  [self _removeObserverForSource:self->source];
  [self->classDescription release];
  [self->entityKeys release];
  [self->mappedKeys release];
  [self->map    release];
  [self->fspec  release];
  [self->source release];
  [super dealloc];
}

/* mapping */

- (EOFetchSpecification *)mapFetchSpecification:(EOFetchSpecification *)_fs {
  return [_fs fetchSpecificationByApplyingKeyMap:self->map];
}

- (id)mapFromSourceObject:(id)_object {
  id values;
  if (_object == nil) return nil;
  
  if (self->mappedKeys == nil) {
    /* no need to rewrite keys, only taking a subset */
    values = [_object valuesForKeys:self->entityKeys];
  }
  else {
    unsigned i, count;
    
    count  = [self->entityKeys count];
    values = [NSMutableDictionary dictionaryWithCapacity:count];
    
    for (i = 0; i < count; i++) {
      NSString *key, *newKey;
      id value;
      
      key    = [self->mappedKeys objectAtIndex:i];
      newKey = [self->entityKeys objectAtIndex:i];
      
      value = [_object valueForKey:key];
      if (value) [(NSMutableDictionary *)values setObject:value forKey:newKey];
    }
  }
  
  return [[[EOMappedObject alloc] 
	    initWithObject:_object values:values] autorelease];
}

- (id)mapToSourceObject:(id)_object {
  // TODO
  if (_object == nil) return nil;

  if ([_object isKindOfClass:[EOMappedObject class]]) {
    id obj;
    
    if ((obj = [_object mappedObject]) == nil) {
      NSLog(@"don't know how to back-map objects: %@", _object);
      return nil;
    }
    
    if ([obj isModified]) {
      if (self->map) {
	NSLog(@"%s: don't know how to back-map modified object: %@", 
	      _object);
#if NeXT_Foundation_LIBRARY
    [self doesNotRecognizeSelector:_cmd];
    return nil; // keep compiler happy
#else
    return [self notImplemented:_cmd];
#endif
      }
      
      [obj applyChangesOnObject];
    }    
    return obj;
  }
  else {
    NSLog(@"don't know how to back-map objects of class %@", [_object class]);
#if NeXT_Foundation_LIBRARY
    [self doesNotRecognizeSelector:_cmd];
#else
    return [self notImplemented:_cmd];
#endif
  }
  return nil; // keep compiler happy
}

- (id)mapCreatedObject:(id)_object {
  return [self mapFromSourceObject:_object];
}

- (id)mapObjectForUpdate:(id)_object {
  return [self mapToSourceObject:_object];
}
- (id)mapObjectForInsert:(id)_object {
  return [self mapToSourceObject:_object];
}
- (id)mapObjectForDelete:(id)_object {
  return [self mapToSourceObject:_object];
}

- (id)mapFetchedObject:(id)_object {
  return [self mapFromSourceObject:_object];
}

- (void)setClassDescriptionForObjects:(NSClassDescription *)_cd {
  ASSIGN(self->classDescription, _cd);
  
  /* setup array of keys to map */
  
  [self->entityKeys release]; self->entityKeys = nil;
  [self->mappedKeys release]; self->mappedKeys = nil;
  
  if (_cd != nil) {
    NSMutableArray *ma;
    NSArray  *tmp;
    unsigned i, count;
    
    ma = [[NSMutableArray alloc] initWithCapacity:16];
    
    /* first, collect keys we need */
    
    if ((tmp = [_cd attributeKeys]) != nil)
      [ma addObjectsFromArray:tmp];
    if ((tmp = [_cd toOneRelationshipKeys]) != nil)
      [ma addObjectsFromArray:tmp];
    if ((tmp = [_cd toManyRelationshipKeys]) != nil)
      [ma addObjectsFromArray:tmp];
    
    self->entityKeys = [ma copy];

    /* next, map those keys to the source-schema */
    
    if (self->map != nil) {
      [ma removeAllObjects];
      for (i = 0, count = [entityKeys count]; i < count; i++) {
	NSString *mappedKey, *key;
	
	key       = [entityKeys objectAtIndex:i];
	mappedKey = [self->map valueForKey:key];
	[ma addObject:mappedKey ? mappedKey : key];
      }
      
      self->mappedKeys = [ma copy];
    }
    
    [ma release];
  }
}
- (NSClassDescription *)classDescriptionForObjects {
  return self->classDescription;
}

/* accessors */

- (void)setSource:(EODataSource *)_source {
  NSAssert(self->fspec == nil, @"only allowed as long as no spec is set !");
  
  [self _removeObserverForSource:self->source];
  ASSIGN(self->source, _source);
  [self _registerForSource:self->source];
  
  [self postDataSourceChangedNotification];
}
- (EODataSource *)source {
  return self->source;
}

- (void)setFetchSpecification:(EOFetchSpecification *)_fetchSpec {
  EOFetchSpecification *mappedSpec;
  
  if ([_fetchSpec isEqual:self->fspec])
    return;

  /*
      This saves the spec in the datasource and saves a mapped spec
      in the source datasource.
  */
    
  ASSIGN(self->fspec, _fetchSpec);
  mappedSpec = [self mapFetchSpecification:self->fspec];
  [self->source setFetchSpecification:mappedSpec];
    
  [self postDataSourceChangedNotification];
}
- (EOFetchSpecification *)fetchSpecification {
  return self->fspec;
}

- (NSException *)lastException {
  if ([self->source respondsToSelector:@selector(lastException)])
    return [(id)self->source lastException];
  return nil;
}

/* fetch operations */

- (Class)fetchEnumeratorClass {
  return [EOKeyMapDataSourceEnumerator class];
}

- (NSEnumerator *)fetchEnumerator {
  NSEnumerator *e;
  
  if ((e = [self->source fetchEnumerator]) == nil)
    return nil;
  
  e = [[[self fetchEnumeratorClass] alloc] initWithKeyMapDataSource:self
					   fetchEnumerator:e];
  return [e autorelease];
}

- (NSArray *)fetchObjects {
  NSAutoreleasePool *pool;
  NSArray *a;
  
  pool = [[NSArray alloc] init];
  a = [[NSArray alloc] initWithObjectsFromEnumerator:[self fetchEnumerator]];
  [pool release];
  return [a autorelease];
}

/* modifications */

- (void)insertObject:(id)_obj {
  [self->source insertObject:[self mapObjectForInsert:_obj]];
}

- (void)deleteObject:(id)_obj {
  [self->source deleteObject:[self mapObjectForDelete:_obj]];
}

- (id)createObject {
  return [self mapCreatedObject:[self->source createObject]];
}
- (void)updateObject:(id)_obj {
  [self->source updateObject:[self mapObjectForUpdate:_obj]];
}

- (void)clear {
  if ([self->source respondsToSelector:@selector(clear)])
    [(id)self->source clear];
}

/* description */

- (NSString *)description {
  NSString *fmt;

  fmt = [NSString stringWithFormat:@"<%@[0x%p]: source=%@ map=%@>",
                    NSStringFromClass([self class]), self,
                    self->source, self->map];
  return fmt;
}

/* private */

- (void)_registerForSource:(id)_source {
  static NSNotificationCenter *nc = nil;

  if (_source != nil) {
    if (nc == nil)
      nc = [[NSNotificationCenter defaultCenter] retain];
    
    [nc addObserver:self selector:@selector(_sourceChanged)
        name:EODataSourceDidChangeNotification object:_source];
  }
}

- (void)_removeObserverForSource:(id)_source {
  static NSNotificationCenter *nc = nil;

  if (_source != nil) {
    if (nc == nil)
      nc = [NSNotificationCenter defaultCenter];
    [nc removeObserver:self name:EODataSourceDidChangeNotification
        object:_source];
  }
}

 - (void)_sourceChanged {
  [self postDataSourceChangedNotification];
}

@end /* EOKeyMapDataSource */


@implementation EOKeyMapDataSourceEnumerator

- (id)initWithKeyMapDataSource:(EOKeyMapDataSource *)_ds
  fetchEnumerator:(NSEnumerator *)_enum
{
  if ((self = [super init])) {
    self->ds     = [_ds retain];
    self->source = [_enum retain];
  }
  return self;
}
- (void)dealloc {
  [self->ds     release];
  [self->source release];
  [super dealloc];
}

/* fetching */

- (void)fetchDone {
}

- (id)nextObject {
  id object;
  
  if ((object = [self->source nextObject]) == nil) {
    [self fetchDone];
    return nil;
  }
  
  return [self->ds mapFetchedObject:object];
}

@end /* EOKeyMapDataSourceEnumerator */


@implementation EOMappedObject

- (id)initWithObject:(id)_object values:(NSDictionary *)_values {
  if ((self = [super init])) {
    self->original = [_object retain];
    self->values   = [_values mutableCopy];
  }
  return self;
}

- (void)dealloc {
  [self->original release];
  [self->globalID release];
  [self->values   release];
  [super dealloc];
}

/* accessors */

- (id)mappedObject {
  return self->original;
}
- (EOGlobalID *)globalID {
  if (self->globalID == nil) {
    if ([self->original respondsToSelector:@selector(globalID)])
      self->globalID = [[self->original globalID] retain];
  }
  return self->globalID;
}

- (BOOL)isModified {
  return self->flags.didChange ? YES : NO;
}
- (void)willChange {
  self->flags.didChange = 1;
}

- (void)applyChangesOnObject {
  if (!self->flags.didChange)
    [self->original takeValuesFromDictionary:self->values];
}

/* mimic dictionary */

- (void)setObject:(id)_obj forKey:(id)_key {
  [self willChange];
  [self->values setObject:_obj forKey:_key];
}
- (id)objectForKey:(id)_key {
  return [self->values objectForKey:_key];
}

- (void)removeObjectForKey:(id)_key {
  [self willChange];
  [self->values removeObjectForKey:_key];
}

- (NSEnumerator *)keyEnumerator {
  return [self->values keyEnumerator];
}
- (NSEnumerator *)objectEnumerator {
  return [self->values objectEnumerator];
}

- (NSDictionary *)asDictionary {
  return self->values;
}

/* KVC */

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  [self willChange];
  if ([_value isNotNull])
    [self->values setObject:_value forKey:_key];
  else
    [self->values removeObjectForKey:_key];
}

- (id)valueForKey:(NSString *)_key {
  return [self->values objectForKey:_key];
}

@end /* EOMappedObject */
