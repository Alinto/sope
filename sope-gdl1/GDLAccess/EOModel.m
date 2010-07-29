/* 
   EOModel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: August 1996

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

#import "common.h"
#import "EOModel.h"
#import "EOEntity.h"

/* Include the code from EOKeyValueCoding.m and EOCustomValues.m here because
   they contain categories to various classes from Foundation that don't get
   linked into the client application since no one refers them. The NeXT linker
   knows how to deal with this but all the other linkers don't... */
#if 0
#  import "EOCustomValues.m"
#endif

void EOModel_linkCategories(void) {
  void EOAccess_EOCustomValues_link(void);

  EOAccess_EOCustomValues_link();
}

@implementation EOModel

- (id)copyWithZone:(NSZone *)_zone {
  return RETAIN(self);
}

+ (NSString*)findPathForModelNamed:(NSString*)modelName {
    int i;
    NSBundle* bundle = [NSBundle mainBundle];
    NSString* modelPath = [bundle pathForResource:modelName ofType:@"eomodel"];
    NSString* paths[] = { @"~/Library/Models",
                          @"/LocalLibrary/Models",
                          @"/NextLibrary/Models",
                          nil };

    if(modelPath)
        return modelPath;

    for(i = 0; paths[i]; i++) {
        bundle = [NSBundle bundleWithPath:paths[i]];
        modelPath = [bundle pathForResource:modelName ofType:@"eomodel"];
        if(modelPath)
            return modelPath;
    }
    return nil;
}

- (id)init {
  if ((self = [super init])) {
    NSNotificationCenter *nc;

    nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(_requireClassDescriptionForClass:)
        name:@"EOClassDescriptionNeededForClass" object:nil];
    [nc addObserver:self 
	selector:@selector(_requireClassDescriptionForEntityName:)
        name:@"EOClassDescriptionNeededForEntityName" object:nil];
    
    self->entities       = [[NSArray alloc] init];
    self->entitiesByName = [[NSMutableDictionary alloc] initWithCapacity:4];
    self->entitiesByClassName = 
      [[NSMutableDictionary alloc] initWithCapacity:4];
  }

  return self;
}

- (void)resetEntities {
  [self->entities makeObjectsPerformSelector:@selector(resetModel)];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self resetEntities];
    RELEASE(self->entities);
    RELEASE(self->entitiesByName);
    RELEASE(self->entitiesByClassName);
    RELEASE(self->name);
    RELEASE(self->path);
    RELEASE(self->adaptorName);
    RELEASE(self->adaptorClassName);
    RELEASE(self->connectionDictionary);
    RELEASE(self->pkeyGeneratorDictionary);
    RELEASE(self->userDictionary);
    [super dealloc];
}

- (id)initWithContentsOfFile:(NSString*)filename
{
  NSDictionary *propList;

  propList = [[[NSDictionary alloc]
                initWithContentsOfFile:filename] autorelease];
  if (propList == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:@"EOModel: Couldn't load model file: %@", filename];
  }
 
  if ((self = [self initWithPropertyList:propList])) {
    self->path = [filename copy];
    self->name = [[[filename lastPathComponent] stringByDeletingPathExtension]
                             copy];
  }
  return self;
}

- (id)initWithPropertyList:(id)propertyList {
  if ((self = [self init]) != nil) {
    NSDictionary *dict;
    int     i, count;
    NSArray *propListEntities;
    
    if (propertyList == nil) {
      [NSException raise:NSInvalidArgumentException
		   format:
		     @"EOModel: Argument of initWithPropertyList: must "
		     @"not be the nil object"];
    }
    if (![(dict = propertyList) isKindOfClass:[NSDictionary class]]) {
      [NSException raise:NSInvalidArgumentException
		   format:@"EOModel: Argument of initWithPropertyList: must "
                           @"be kind of NSDictionary class"];
    }
    
    self->adaptorName      = [[dict objectForKey:@"adaptorName"] copy];
    self->adaptorClassName = [[dict objectForKey:@"adaptorClassName"] copy];
    self->connectionDictionary =
      [[dict objectForKey:@"connectionDictionary"] copy];
    self->pkeyGeneratorDictionary =
      [[dict objectForKey:@"pkeyGeneratorDictionary"] copy];
    self->userDictionary   = [[dict objectForKey:@"userDictionary"] copy];
    
    propListEntities = [dict objectForKey:@"entities"];

    flags.errors = NO;
    [self setCreateMutableObjects:YES];
    count = [propListEntities count];
    for (i = 0; i < count; i++) {
      EOEntity *entity;

      entity = [EOEntity entityFromPropertyList:
			   [propListEntities objectAtIndex:i]
			 model:self];
      [self addEntity:entity];
    }

    count = [self->entities count];
    for (i = 0; i < count; i++)
      [[self->entities objectAtIndex:i] replaceStringsWithObjects];

    /* Init relationships */
    for (i = 0; i < count; i++) {
      EOEntity *entity;
      NSArray  *rels;

      entity = [self->entities objectAtIndex:i];
      rels   = [entity relationships];
      /* Replace all the strings in relationships. */
      [rels makeObjectsPerformSelector:@selector(replaceStringsWithObjects)];
    }

    /* Another pass to allow properly initialization of flattened
        relationships. */
    for (i = 0; i < count; i++) {
        EOEntity* entity =
          [self->entities objectAtIndex:i];
        NSArray* rels = [entity relationships];

        [rels makeObjectsPerformSelector:@selector(initFlattenedRelationship)];
    }

    /* Init attributes */
    for (i = 0; i < count; i++) {
      EOEntity *entity = [self->entities objectAtIndex:i];
      NSArray  *attrs  = [entity attributes];
      
      [attrs makeObjectsPerformSelector:@selector(replaceStringsWithObjects)];
    }

    [self setCreateMutableObjects:NO];
  }
  return flags.errors ? (void)AUTORELEASE(self), (id)nil : (id)self;
}

- (id)initWithName:(NSString*)_name {
  if ((self = [self init])) {
    ASSIGN(self->name, _name);
  }
  return self;
}

/* class-description notifications */

- (void)_requireClassDescriptionForEntityName:(NSNotification *)_notification {
  NSString *entityName;

  if ((entityName = [_notification object])) {
    EOEntity *entity;

    if ((entity = [self->entitiesByName objectForKey:entityName])) {
      EOClassDescription *d;

      d = [[EOEntityClassDescription alloc] initWithEntity:entity];
      [EOClassDescription registerClassDescription:d
                          forClass:NSClassFromString([entity className])];
      RELEASE(d); d = nil;
    }
  }
}
- (void)_requireClassDescriptionForClass:(NSNotification *)_notification {
  Class    clazz;
  NSString *className;
  EOEntity *entity;
  EOClassDescription *d;

  if ((clazz = [_notification object]) == nil)
    return;
  if ((className = NSStringFromClass(clazz)) == nil)
    return;
  if ((entity = [self->entitiesByClassName objectForKey:className]) == nil)
    return;

  d = [[EOEntityClassDescription alloc] initWithEntity:entity];
  [EOClassDescription registerClassDescription:d forClass:clazz];
  [d release]; d = nil;
}

/* property list */

- (id)modelAsPropertyList {
  NSMutableDictionary *model = [NSMutableDictionary dictionaryWithCapacity:64];
  int i, count;
    
  [model setObject:[[NSNumber numberWithInt:[isa version]] stringValue]
	 forKey:@"EOModelVersion"];
  if (name)
        [model setObject:name forKey:@"name"];
  if (adaptorName)
        [model setObject:adaptorName forKey:@"adaptorName"];
  if (adaptorClassName)
        [model setObject:adaptorClassName forKey:@"adaptorClassName"];
  if (connectionDictionary)
        [model setObject:connectionDictionary forKey:@"connectionDictionary"];
  if (pkeyGeneratorDictionary) {
        [model setObject:pkeyGeneratorDictionary
               forKey:@"pkeyGeneratorDictionary"];
  }
  if (userDictionary)
        [model setObject:userDictionary forKey:@"userDictionary"];
  if (self->entities && (count = [self->entities count])) {
    id entitiesArray = [NSMutableArray arrayWithCapacity:count];

    [model setObject:entitiesArray forKey:@"entities"];
    for (i = 0; i < count; i++) {
      [entitiesArray addObject:
		       [[entities objectAtIndex:i] propertyList]];
    }
  }

  return model;
}

- (BOOL)addEntity:(EOEntity *)entity {
  NSString * entityName = [entity name];

  if ([self->entitiesByName objectForKey:entityName])
        return NO;

  if ([self createsMutableObjects])
        [(NSMutableArray*)self->entities addObject:entity];
  else {
    self->entities =
      [[[self->entities autorelease] mutableCopy] autorelease];
    [(NSMutableArray *)self->entities addObject:entity];
    self->entities = [self->entities copy];
  }

  [self->entitiesByName setObject:entity forKey:entityName];
  [self->entitiesByClassName setObject:entity forKey:[entity className]];
  [entity setModel:self];
  return YES;
}

- (void)removeEntityNamed:(NSString*)entityName {
  id entity;
  
  if (entityName == nil)
    return;
  
  entity = [self->entitiesByName objectForKey:entityName];

  if ([self createsMutableObjects])
    [(NSMutableArray*)self->entities removeObject:entity];
  else {
    self->entities = [AUTORELEASE(self->entities) mutableCopy];
    [(NSMutableArray*)self->entities removeObject:entity];
    self->entities = [AUTORELEASE(self->entities) copy];
  }
  [self->entitiesByName removeObjectForKey:entityName];
  [entity resetModel];
}

- (EOEntity *)entityNamed:(NSString *)entityName {
  return [self->entitiesByName objectForKey:entityName];
}

- (NSArray *)referencesToProperty:property {
  [self notImplemented:_cmd];
  return 0;
}

- (EOEntity *)entityForObject:object {
  NSString *className;

  className = NSStringFromClass([object class]);
  return [self->entitiesByClassName objectForKey:className];
}

- (BOOL)incorporateModel:(EOModel*)model {
  [self notImplemented:_cmd];
  return 0;
}

- (void)setAdaptorName:(NSString*)_adaptorName {
  id tmp = self->adaptorName;
  self->adaptorName = [_adaptorName copyWithZone:[self zone]];
  RELEASE(tmp); tmp = nil;
}
- (NSString *)adaptorName {
  return self->adaptorName;
}

- (void)setAdaptorClassName:(NSString*)_adaptorClassName {
  id tmp = self->adaptorClassName;
  self->adaptorClassName = [_adaptorClassName copyWithZone:[self zone]];
  RELEASE(tmp); tmp = nil;
}
- (NSString *)adaptorClassName {
  return self->adaptorClassName;
}

- (void)setConnectionDictionary:(NSDictionary*)_connectionDictionary {
  ASSIGN(self->connectionDictionary, _connectionDictionary);
}
- (NSDictionary *)connectionDictionary {
  return self->connectionDictionary;
}

- (void)setPkeyGeneratorDictionary:(NSDictionary *)_dict {
  ASSIGN(self->pkeyGeneratorDictionary, _dict);
}
- (NSDictionary *)pkeyGeneratorDictionary {
  return self->pkeyGeneratorDictionary;
}

- (void)setUserDictionary:(NSDictionary *)_userDictionary {
  ASSIGN(self->userDictionary, _userDictionary);
}
- (NSDictionary *)userDictionary {
  return self->userDictionary;
}

- (NSString *)path {
  return self->path;
}
- (NSString *)name {
  return self->name;
}
- (NSArray *)entities {
  NSMutableArray *ents;
  int cnt, i;

  cnt  = [self->entities count];
  ents = [NSMutableArray arrayWithCapacity:cnt];
  for (i = 0; i < cnt; i++)
    [ents addObject:[self->entities objectAtIndex:i]];
  
  return ents;
}

+ (int)version {
  return 1;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  NSString *s;

  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];

  if ((s = [self name]))             [ms appendFormat:@" name=%@", s];
  if ((s = [self path]))             [ms appendFormat:@" path=%@", s];
  if ((s = [self adaptorName]))      [ms appendFormat:@" adaptor=%@", s];
  if ((s = [self adaptorClassName])) [ms appendFormat:@" adaptor-class=%@", s];
  
  [ms appendFormat:@" #entities=%d", [self->entities count]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* EOModel */


@implementation EOModel (EOModelPrivate)

- (void)setCreateMutableObjects:(BOOL)flag {
    if(flags.createsMutableObjects == flag)
        return;

    flags.createsMutableObjects = flag;

    if(flags.createsMutableObjects)
        self->entities = [AUTORELEASE(self->entities) mutableCopy];
    else
        self->entities = [AUTORELEASE(self->entities) copy];
}

- (BOOL)createsMutableObjects {
  return flags.createsMutableObjects;
}
- (void)errorInReading {
  flags.errors = YES;
}

@end /* EOModel (EOModelPrivate) */

@implementation EOModel(NewInEOF2)

- (void)loadAllModelObjects {
}

@end
