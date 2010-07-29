/* 
   EOAdaptorChannel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

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
// $Id: EOModelGroup.m 1 2004-08-20 10:38:46Z znek $

#include "EOModelGroup.h"
#include "EOModel.h"
#include "EOEntity.h"
#import <EOControl/EOClassDescription.h>
#include "common.h"

@implementation EOModelGroup

static EOModelGroup *defaultGroup = nil;
static id<EOModelGroupClassDelegation> classDelegate = nil;

+ (void)setDefaultGroup:(EOModelGroup *)_group {
  ASSIGN(defaultGroup, _group);
}

+ (EOModelGroup *)defaultGroup {
  EOModelGroup *group;

  group = defaultGroup;
  
  if (group == nil)
    group = [[self classDelegate] defaultModelGroup];
  
  if (group == nil)
    group = [self globalModelGroup];
  
  return group;
}

+ (EOModelGroup *)globalModelGroup {
  static EOModelGroup *globalModelGroup = nil;
  NSEnumerator *bundles;
  NSBundle *bundle;

  if (globalModelGroup)
    return globalModelGroup;

  globalModelGroup = [[EOModelGroup alloc] init];

  bundles = [[NSBundle allBundles] objectEnumerator];
  while ((bundle = [bundles nextObject])) {
    NSEnumerator *paths;
    NSString *path;

    paths = [[bundle pathsForResourcesOfType:@"eomodel" inDirectory:nil]
                     objectEnumerator];

    while ((path = [paths nextObject])) {
      EOModel *model;
      
      model = [[EOModel alloc] initWithContentsOfFile:path];
      if (model == nil) {
        NSLog(@"WARNING: couldn't load model %@", path);
      }
      else {
        [globalModelGroup addModel:model];
        RELEASE(model);
      }
    }
  }
  return globalModelGroup;
}

+ (void)setClassDelegate:(id<EOModelGroupClassDelegation>)_delegate {
  ASSIGN(classDelegate, _delegate);
}
+ (id<EOModelGroupClassDelegation>)classDelegate {
  return classDelegate;
}

- (id)init {
  self->nameToModel = [[NSMutableDictionary allocWithZone:[self zone]] init];
  return self;
}

- (void)dealloc {
  RELEASE(self->nameToModel);
  [super dealloc];
}

/* instance delegate */

- (void)setDelegate:(id<EOModelGroupDelegation>)_delegate {
  self->delegate = _delegate;
}
- (id<EOModelGroupDelegation>)delegate {
  return self->delegate;
}

/* accessors */

- (void)addModel:(EOModel *)_model {
  NSString *name;

  name = [_model name];
  if (name == nil) name = [[_model path] lastPathComponent];
  
  if ([self->nameToModel objectForKey:name]) {
    [NSException raise:@"NSInvalidArgumentException"
                 format:@"model group %@ already contains model named %@",
                   self, name];
  }
  
  [self->nameToModel setObject:_model forKey:name];

  [[NSNotificationCenter defaultCenter]
                         postNotificationName:@"EOModelAddedNotification"
                         object:_model];
}

- (void)removeModel:(EOModel *)_model {
  NSArray *allNames;

  allNames = [self->nameToModel allKeysForObject:_model];
  [self->nameToModel removeObjectsForKeys:allNames];

  [[NSNotificationCenter defaultCenter]
                         postNotificationName:@"EOModelInvalidatedNotification"
                         object:_model];
}

- (EOModel *)addModelWithFile:(NSString *)_path {
  EOModel *model;

  model = [[EOModel alloc] initWithContentsOfFile:_path];
  if (model == nil)
    return nil;
  AUTORELEASE(model);

  [self addModel:model];

  return model;
}

- (EOModel *)modelNamed:(NSString *)_name {
  return [self->nameToModel objectForKey:_name];
}
- (EOModel *)modelWithPath:(NSString *)_path {
  NSEnumerator *e;
  EOModel  *m;
  NSString *p;

  p = [_path stringByStandardizingPath];
  if (p == nil) p = _path;

  e = [self->nameToModel objectEnumerator];
  while ((m = [e nextObject])) {
    NSString *mp;

    mp = [[m path] stringByStandardizingPath];
    if (mp == nil) mp = [m path];

    if ([p isEqual:mp])
      return m;
  }
  return m;
}

- (NSArray *)modelNames {
  return [self->nameToModel allKeys];
}
- (NSArray *)models {
  return [self->nameToModel allValues];
}

- (void)loadAllModelObjects {
  [[self->nameToModel allValues] makeObjectsPerformSelector:_cmd];
}

/* entities */

- (EOEntity *)entityForObject:(id)_object {
  NSEnumerator *e;
  EOModel  *m;

  e = [self->nameToModel objectEnumerator];
  while ((m = [e nextObject])) {
    EOEntity *entity;

    if ((entity = [m entityForObject:_object]))
      return entity;
  }
  return nil;
}

- (EOEntity *)entityNamed:(NSString *)_name {
  NSEnumerator *e;
  EOModel  *m;

  e = [self->nameToModel objectEnumerator];
  while ((m = [e nextObject])) {
    EOEntity *entity;

    if ((entity = [m entityNamed:_name]))
      return entity;
  }
  return nil;
}

- (EOFetchSpecification *)fetchSpecificationNamed:(NSString *)_name
  entityNamed:(NSString *)_entityName
{
  return [[self entityNamed:_entityName] fetchSpecificationNamed:_name];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: models=%@>",
                     NSStringFromClass([self class]),
                     self,
                     [[self modelNames] componentsJoinedByString:@","]];
}

@end /* EOModelGroup */
