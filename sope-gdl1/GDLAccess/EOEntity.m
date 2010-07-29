/* 
   EOEntity.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: August 1996

   Author: Helge Hess <helge.hess@mdlink.de>
   Date: November 1999
   
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
#import "EOEntity.h"
#import "EOAttribute.h"
#import "EOFExceptions.h"
#import "EOModel.h"
#import "EOPrimaryKeyDictionary.h"
#import "EOSQLQualifier.h"
#import "EORelationship.h"
#import <EOControl/EOKeyValueCoding.h>
#import <EOControl/EOKeyGlobalID.h>

static int _compareByName(id obj1, id obj2, void * context);

@interface NSObject(MappedArrayProtocol)
- (NSArray *)mappedArrayUsingSelector:(SEL)_selector;
@end

@interface NSString(EntityBeautify)
- (NSString *)_beautifyEntityName;
@end

@implementation EOEntity

- (id)init {
  if ((self = [super init])) {
    self->attributes          = [[NSArray alloc] init];
    self->attributesByName    = [[NSMutableDictionary alloc] init];
    self->relationships       = [[NSArray alloc] init];
    self->relationshipsByName = [[NSMutableDictionary alloc] init];
    self->classProperties     = [[NSArray alloc] init];
    self->model               = nil;
  }
  return self;
}

- (void)resetAttributes {
  [self->attributes makeObjectsPerformSelector:@selector(resetEntity)];
}
- (void)resetRelationships {
  [self->relationships makeObjectsPerformSelector:@selector(resetEntities)];
}

- (void)dealloc {
  self->model = nil;
  RELEASE(self->qualifier);
  [self resetAttributes];
  RELEASE(self->attributes);
  RELEASE(self->attributesByName);
  [self resetRelationships];
  RELEASE(self->relationships);
  RELEASE(self->relationshipsByName);
  RELEASE(self->primaryKeyAttributes);
  RELEASE(self->classProperties);
  RELEASE(self->attributesUsedForLocking);
  RELEASE(self->attributesUsedForInsert);
  RELEASE(self->attributesUsedForFetch);
  RELEASE(self->relationsUsedForFetch);
  RELEASE(self->name);                     self->name = nil;
  RELEASE(self->className);                self->className = nil;
  RELEASE(self->externalName);             self->externalName = nil;
  RELEASE(self->externalQuery);            self->externalQuery = nil;
  RELEASE(self->userDictionary);           self->userDictionary = nil;
  RELEASE(self->primaryKeyAttributeNames);
  self->primaryKeyAttributeNames = nil;
  RELEASE(self->attributesNamesUsedForInsert);
  self->attributesNamesUsedForInsert = nil;
  RELEASE(self->classPropertyNames); self->classPropertyNames = nil;
  [super dealloc];
}

// These methods should be here to let the library work with NeXT foundation
- (id)copy {
  return RETAIN(self);
}
- (id)copyWithZone:(NSZone *)_zone {
  return RETAIN(self);
}

// Is equal only if same name; used to make aliasing ordering stable
- (unsigned)hash {
  return [name hash];
}

- (id)initWithName:(NSString *)_name {
  [self init];
  ASSIGN(name, _name);
  return self;
}

- (BOOL)setName:(NSString *)_name {
  if([model entityNamed:name]) return NO;
  ASSIGN(name, _name);
  return YES;
}

+ (BOOL)isValidName:(NSString *)attributeName {
  unsigned   len = [attributeName cStringLength];
  char       buf[len + 1];
  const char *s;
  
  s = buf;
  [attributeName getCString:buf];
  
  if(!isalnum((int)*s) && *s != '@' && *s != '_' && *s != '#')
    return NO;

  for(++s; *s; s++)
    if(!isalnum((int)*s) && *s != '@' && *s != '_' && *s != '#' && *s != '$')
      return NO;

  return YES;
}

- (BOOL)addAttribute:(EOAttribute *)attribute {
  NSString* attributeName = [attribute name];

  if([self->attributesByName objectForKey:attributeName])
    return NO;

  if([self->relationshipsByName objectForKey:attributeName])
    return NO;

  if([self createsMutableObjects])
    [(NSMutableArray*)self->attributes addObject:attribute];
  else {
    id newAttributes = [self->attributes arrayByAddingObject:attribute];
    ASSIGN(self->attributes, newAttributes);
  }

  [self->attributesByName setObject:attribute forKey:attributeName];
  [attribute setEntity:self];
  [self invalidatePropertiesCache];
  return YES;
}

- (void)removeAttributeNamed:(NSString *)attributeName {
  id attribute = [self->attributesByName objectForKey:attributeName];

  if(attribute) {
    [attribute resetEntity];
    if([self createsMutableObjects])
      [(NSMutableArray*)attributes removeObject:attribute];
    else {
      self->attributes = [AUTORELEASE(self->attributes) mutableCopy];
      [(NSMutableArray*)self->attributes removeObject:attribute];
      self->attributes = [AUTORELEASE(self->attributes) copy];
    }
    [self->attributesByName removeObjectForKey:attributeName];
    [self invalidatePropertiesCache];
  }
}

- (EOAttribute *)attributeNamed:(NSString *)attributeName {
  return [self->attributesByName objectForKey:attributeName];
}

- (BOOL)addRelationship:(EORelationship *)relationship {
  NSString* relationshipName = [relationship name];

  if([self->attributesByName objectForKey:relationshipName])
    return NO;

  if([self->relationshipsByName objectForKey:relationshipName])
    return NO;

  if([self createsMutableObjects])
    [(NSMutableArray*)relationships addObject:relationship];
  else {
    id newRelationships = [self->relationships arrayByAddingObject:relationship];
    ASSIGN(self->relationships, newRelationships);
  }

  [self->relationshipsByName setObject:relationship forKey:relationshipName];
  [relationship setEntity:self];
  [self invalidatePropertiesCache];
  return YES;
}

- (void)removeRelationshipNamed:(NSString*)relationshipName {
  id relationship = [relationshipsByName objectForKey:relationshipName];

  if(relationship) {
    [relationship setEntity:nil];
    if([self createsMutableObjects])
      [(NSMutableArray*)self->relationships removeObject:relationship];
    else {
      self->relationships = [AUTORELEASE(self->relationships) mutableCopy];
      [(NSMutableArray*)self->relationships removeObject:relationship];
      self->relationships = [AUTORELEASE(relationships) copy];
    }
    [self->relationshipsByName removeObjectForKey:relationship];
    [self invalidatePropertiesCache];
  }
}

- (EORelationship*)relationshipNamed:(NSString *)relationshipName {
  if([relationshipName isNameOfARelationshipPath]) {
    NSArray        *defArray;
    int            i, count;
    EOEntity       *currentEntity = self;
    NSString       *relName       = nil;
    EORelationship *relationship  = nil;

    defArray = [relationshipName componentsSeparatedByString:@"."];
    relName  = [defArray objectAtIndex:0];

    for(i = 0, count = [defArray count]; i < count; i++) {
      if(![EOEntity isValidName:relName])
        return nil;
      relationship = [currentEntity->relationshipsByName objectForKey:relName];
      if(relationship == nil)
        return nil;
      currentEntity = [relationship destinationEntity];
    }
    return relationship;
  }
  else
    return [self->relationshipsByName objectForKey:relationshipName];
}

- (BOOL)setPrimaryKeyAttributes:(NSArray *)keys {
  int i, count = [keys count];

  for(i = 0; i < count; i++)
    if(![self isValidPrimaryKeyAttribute:[keys objectAtIndex:i]])
      return NO;

  RELEASE(self->primaryKeyAttributes);
  RELEASE(self->primaryKeyAttributeNames);

  if([keys isKindOfClass:[NSArray class]]
     || [keys isKindOfClass:[NSMutableArray class]])
    self->primaryKeyAttributes = [keys copy];
  else
    self->primaryKeyAttributes = [[NSArray alloc] initWithArray:keys];

  self->primaryKeyAttributeNames = [NSMutableArray arrayWithCapacity:count];
  for(i = 0; i < count; i++) {
    id key = [keys objectAtIndex:i];
    
    [(NSMutableArray*)self->primaryKeyAttributeNames
                      addObject:[(EOAttribute*)key name]];
  }
  self->primaryKeyAttributeNames
    = RETAIN([self->primaryKeyAttributeNames
                  sortedArrayUsingSelector:@selector(compare:)]);
    
  [self invalidatePropertiesCache];
    
  return YES;
}

- (BOOL)isValidPrimaryKeyAttribute:(EOAttribute*)anAttribute {
  if(![anAttribute isKindOfClass:[EOAttribute class]])
    return NO;

  if([self->attributesByName objectForKey:[anAttribute name]])
    return YES;

  return NO;
}

- (NSDictionary *)primaryKeyForRow:(NSDictionary *)_row {
  return [EOPrimaryKeyDictionary dictionaryWithKeys:
                                   self->primaryKeyAttributeNames
                                 fromDictionary:_row];
}

- (NSDictionary *)snapshotForRow:(NSDictionary *)aRow {
  NSArray             *array;
  int                 i, n;
  NSMutableDictionary *dict;

  array = [self attributesUsedForLocking];
  n     = [array count];
  dict  = [NSMutableDictionary dictionaryWithCapacity:n];
  
  for (i = 0; i < n; i++) {
    EOAttribute *attribute;
    NSString *columnName;
    NSString *attributeName;
    id value;

    attribute     = [array objectAtIndex:i];
    columnName    = [attribute columnName];
    attributeName = [attribute name];

    value = [aRow objectForKey:attributeName];

#if DEBUG
    NSAssert1(columnName, @"missing column name in attribute %@ !", attribute);
    NSAssert3(value, @"missing value for column '%@' (attr '%@') in row %@",
              columnName, attribute, aRow);
#endif
    
    [dict setObject:value forKey:attributeName];
  }
  return dict;
}

/* Getting attributes used for database oprations */

- (NSArray*)attributesUsedForInsert
{
  if (!flags.isPropertiesCacheValid)
    [self validatePropertiesCache];
  return self->attributesUsedForInsert;
}

- (NSArray *)attributesUsedForFetch {
  if (!flags.isPropertiesCacheValid)
    [self validatePropertiesCache];
  return self->attributesUsedForFetch;
}

- (NSArray *)relationsUsedForFetch {
  if (!flags.isPropertiesCacheValid)
    [self validatePropertiesCache];
  return self->relationsUsedForFetch;
}

- (NSArray *)attributesNamesUsedForInsert {
  if (!flags.isPropertiesCacheValid)
    [self validatePropertiesCache];
  return self->attributesNamesUsedForInsert;
}

- (BOOL)setClassProperties:(NSArray *)properties {
  int i, count = [properties count];

  for(i = 0; i < count; i++)
    if(![self isValidClassProperty:[properties objectAtIndex:i]])
      return NO;

  RELEASE(self->classProperties);    self->classProperties    = nil;
  RELEASE(self->classPropertyNames); self->classPropertyNames = nil;

  if([properties isKindOfClass:[NSArray class]]
     || [properties isKindOfClass:[NSMutableArray class]]) {
    self->classProperties = [properties copyWithZone:[self zone]];
  }
  else {
    self->classProperties = [[NSArray allocWithZone:[self zone]]
                                      initWithArray:properties];
  }

  self->classPropertyNames = [NSMutableArray arrayWithCapacity:count];
  for(i = 0; i < count; i++) {
    id property = [properties objectAtIndex:i];
    [(NSMutableArray*)classPropertyNames addObject:[(EOAttribute*)property name]];
  }
  self->classPropertyNames = [self->classPropertyNames copyWithZone:[self zone]];
  [self invalidatePropertiesCache];
    
  return YES;
}

- (BOOL)isValidClassProperty:(id)aProperty {
  id thePropertyName = nil;

  if(!([aProperty isKindOfClass:[EOAttribute class]]
       || [aProperty isKindOfClass:[EORelationship class]]))
    return NO;

  thePropertyName = [(EOAttribute*)aProperty name];
  if([self->attributesByName objectForKey:thePropertyName]
     || [self->relationshipsByName objectForKey:thePropertyName])
    return YES;

  return NO;
}

- (NSArray *)relationshipsNamed:(NSString *)_relationshipPath {    
  if([_relationshipPath isNameOfARelationshipPath]) {
    NSMutableArray *myRelationships = [[NSMutableArray alloc] init];
    NSArray  *defArray = [_relationshipPath componentsSeparatedByString:@"."];
    int            i, count  = [defArray count] - 1;
    EOEntity       *currentEntity = self;
    NSString       *relName       = nil;
    id             relation       = nil;

    for(i = 0; i < count; i++) {
      relName = [defArray objectAtIndex:i];

      if([EOEntity isValidName:relName]) {
        relation = [currentEntity relationshipNamed:relName];
        if(relation) {
          [myRelationships addObject:relation];
          currentEntity = [relation destinationEntity];
        }
      }
    }
    return AUTORELEASE(myRelationships);
  }
  return nil;
}

- (id)propertyNamed:(NSString *)_name {
  if([_name isNameOfARelationshipPath]) {
    NSArray  *defArray      = [_name componentsSeparatedByString:@"."];
    EOEntity *currentEntity = self;
    NSString *propertyName;
    int      i = 0, count = [defArray count];
    id       property;

    for(; i < count - 1; i++) {
      propertyName = [defArray objectAtIndex:i];
      if(![EOEntity isValidName:propertyName])
        return nil;
      property = [currentEntity propertyNamed:propertyName];
      if(!property)
        return nil;
            
      currentEntity = [property destinationEntity];
    }
    propertyName = [defArray lastObject];
    property = [currentEntity attributeNamed:propertyName];
    return property;
  }
  else {
    id attribute    = nil;
    id relationship = nil;

    attribute = [self->attributesByName objectForKey:_name];
    if(attribute)
      return attribute;

    relationship = [self->relationshipsByName objectForKey:_name];
    if(relationship)
      return relationship;
  }

  return nil;
}

- (BOOL)setAttributesUsedForLocking:(NSArray *)_attributes {
  int i, count = [_attributes count];

  for(i = 0; i < count; i++)
    if(![self isValidAttributeUsedForLocking:
              [_attributes objectAtIndex:i]])
      return NO;

  RELEASE(self->attributesUsedForLocking);

  if([_attributes isKindOfClass:[NSArray class]]
     || [_attributes isKindOfClass:[NSMutableArray class]])
    self->attributesUsedForLocking = [_attributes copy];
  else
    self->attributesUsedForLocking = [[NSArray alloc] initWithArray:_attributes];
  [self invalidatePropertiesCache];
    
  return YES;
}

- (BOOL)isValidAttributeUsedForLocking:(EOAttribute*)anAttribute {
  if(!([anAttribute isKindOfClass:[EOAttribute class]]
       && [self->attributesByName objectForKey:[anAttribute name]]))
    return NO;
  
  return YES;
}

- (void)setModel:(EOModel *)aModel {
  self->model = aModel;  /* non-retained */
}
- (void)resetModel {
  self->model = nil;
}
- (BOOL)hasModel {
  return (self->model != nil) ? YES : NO;
}

- (void)setClassName:(NSString *)_name {
  if(!_name) _name = @"EOGenericRecord";
  ASSIGN(self->className, _name);
}

- (void)setReadOnly:(BOOL)flag
{
  flags.isReadOnly = flag;
}

- (BOOL)referencesProperty:(id)property {
  id propertyName = [(EOAttribute*)property name];

  if([self->attributesByName objectForKey:propertyName]
     || [self->relationshipsByName objectForKey:propertyName])
    return YES;
  return NO;
}

- (EOSQLQualifier*)qualifier {
  if (self->qualifier == nil) {
    self->qualifier = [[EOSQLQualifier allocWithZone:[self zone]]
                                       initWithEntity:self
                                       qualifierFormat:nil];
  }
  return self->qualifier;
}

// accessors

- (void)setExternalName:(NSString*)_name {
  ASSIGN(externalName, _name);
}
- (NSString *)externalName {
  return self->externalName;
}

- (void)setExternalQuery:(NSString*)query {
  ASSIGN(externalQuery, query);
}
- (NSString *)externalQuery {
  return self->externalQuery;
}

- (void)setUserDictionary:(NSDictionary*)dict {
  ASSIGN(userDictionary, dict);
}
- (NSDictionary *)userDictionary {
  return self->userDictionary;
}

- (NSString *)name {
  return self->name;
}
- (BOOL)isReadOnly {
  return self->flags.isReadOnly;
}
- (NSString *)className {
  return self->className;
}
- (NSArray *)attributesUsedForLocking {
  return self->attributesUsedForLocking;
}
- (NSArray *)classPropertyNames {
  return self->classPropertyNames;
}
- (NSArray *)classProperties {
  return self->classProperties;
}
- (NSArray *)primaryKeyAttributes {
  return self->primaryKeyAttributes;
}
- (NSArray *)primaryKeyAttributeNames {
  return self->primaryKeyAttributeNames;
}
- (NSArray *)relationships {
  return self->relationships;
}
- (EOModel *)model {
  return self->model;
}
- (NSArray *)attributes {
  return self->attributes;
}

/* EOEntityCreation */

+ (EOEntity *)entityFromPropertyList:(id)propertyList model:(EOModel *)_model {
  NSDictionary *plist = propertyList;
  EOEntity     *entity;
  NSArray      *array;
  NSEnumerator *enumerator;
  id attributePList;
  id relationshipPList;

  entity = [[[EOEntity alloc] init] autorelease];
  [entity setCreateMutableObjects:YES];

  entity->name           = RETAIN([plist objectForKey:@"name"]);
  entity->className      = RETAIN([plist objectForKey:@"className"]);
  entity->externalName   = RETAIN([plist objectForKey:@"externalName"]);
  entity->externalQuery  = RETAIN([plist objectForKey:@"externalQuery"]);
  entity->userDictionary = RETAIN([plist objectForKey:@"userDictionary"]);

  array      = [plist objectForKey:@"attributes"];
  enumerator = [array objectEnumerator];
  
  while ((attributePList = [enumerator nextObject])) {
    EOAttribute *attribute;
    
    attribute = [EOAttribute attributeFromPropertyList:attributePList];
    
    if (![entity addAttribute:attribute]) {
      NSLog(@"duplicate name for attribute '%@' in entity '%@'",
            [attribute name], [entity name]);
      [_model errorInReading];
    }
  }

  entity->attributesUsedForLocking
    = RETAIN([plist objectForKey:@"attributesUsedForLocking"]);
  entity->classPropertyNames
    = RETAIN([plist objectForKey:@"classProperties"]);

  if ((attributePList = [plist objectForKey:@"primaryKeyAttributes"])) {
    entity->primaryKeyAttributeNames
      = RETAIN([attributePList sortedArrayUsingSelector:@selector(compare:)]);
  }

  else
    if ((attributePList = [plist objectForKey:@"primaryKeyAttribute"]))
      entity->primaryKeyAttributeNames
        = RETAIN([NSArray arrayWithObject:attributePList]);

  array = [plist objectForKey:@"relationships"];
  enumerator = [array objectEnumerator];
  while((relationshipPList = [enumerator nextObject])) {
    EORelationship *relationship
      = [EORelationship relationshipFromPropertyList:relationshipPList
                        model:_model];
    
    if(![entity addRelationship:relationship]) {
      NSLog(@"duplicate name for relationship '%@' in entity '%@'",
            [relationship name], [entity name]);
      [_model errorInReading];
    }
  }

  [entity setCreateMutableObjects:NO];

  return entity;
}

- (void)replaceStringsWithObjects {
  NSEnumerator   *enumerator    = nil;
  EOAttribute    *attribute     = nil;
  NSString       *attributeName = nil;
  NSString       *propertyName  = nil;
  NSMutableArray *array         = nil;
  int            i, count;

  enumerator           = [self->primaryKeyAttributeNames objectEnumerator];
  RELEASE(self->primaryKeyAttributes);
  self->primaryKeyAttributes = AUTORELEASE([NSMutableArray new]);
  
  while ((attributeName = [enumerator nextObject])) {
    attribute = [self attributeNamed:attributeName];
    
    if((attribute == nil) || ![self isValidPrimaryKeyAttribute:attribute]) {
      NSLog(@"invalid attribute name specified as primary key attribute "
            @"'%s' in entity '%s'", 
            [attributeName cString], [name cString]);
      [self->model errorInReading];
    }
    else
      [(NSMutableArray*)self->primaryKeyAttributes addObject:attribute];
  }
  self->primaryKeyAttributes = [self->primaryKeyAttributes copy];

  enumerator = [self->classPropertyNames objectEnumerator];
  RELEASE(self->classProperties);
  self->classProperties = AUTORELEASE([NSMutableArray new]);
  while((propertyName = [enumerator nextObject])) {
    id property;

    property = [self propertyNamed:propertyName];
    if(!property || ![self isValidClassProperty:property]) {
      NSLog(@"invalid property '%s' specified as class property in "
            @"entity '%s'", 
            [propertyName cString], [name cString]);
      [self->model errorInReading];
    }
    else
      [(NSMutableArray*)self->classProperties addObject:property];
  }
  self->classProperties = [self->classProperties copy];

  array = AUTORELEASE([NSMutableArray new]);
  [array setArray:self->attributesUsedForLocking];
  RELEASE(self->attributesUsedForLocking);
  count = [array count];
  for(i = 0; i < count; i++) {
    attributeName = [array objectAtIndex:i];
    attribute = [self attributeNamed:attributeName];
    if(!attribute || ![self isValidAttributeUsedForLocking:attribute]) {
      NSLog(@"invalid attribute specified as attribute used for "
            @"locking '%@' in entity '%@'", attributeName, name);
      [self->model errorInReading];
    }
    else
      [array replaceObjectAtIndex:i withObject:attribute];
  }
  self->attributesUsedForLocking = [array copy];
}

- (id)propertyList
{
  id propertyList;
  
  propertyList = [NSMutableDictionary dictionary];
  [self encodeIntoPropertyList:propertyList];
  return propertyList;
}

- (void)setCreateMutableObjects:(BOOL)flag {
  if(self->flags.createsMutableObjects == flag)
    return;

  self->flags.createsMutableObjects = flag;

  if(self->flags.createsMutableObjects) {
    self->attributes    = [AUTORELEASE(self->attributes) mutableCopy];
    self->relationships = [AUTORELEASE(self->relationships) mutableCopy];
  }
  else {
    self->attributes    = [AUTORELEASE(self->attributes)    copy];
    self->relationships = [AUTORELEASE(self->relationships) copy];
  }
}

- (BOOL)createsMutableObjects {
  return self->flags.createsMutableObjects;
}

#if 0
static inline void _printIds(NSArray *a, const char *pfx, const char *indent) {
  int i;
  if (pfx    == NULL) pfx    = "";
  if (indent == NULL) indent = "  ";
  printf("%s", pfx);
  for (i = 0; i < [a count]; i++)
    printf("%s0x%p\n", indent, (unsigned)[a objectAtIndex:i]);
}
#endif

static inline BOOL _containsObject(NSArray *a, id obj) {
  id (*objAtIdx)(NSArray*, SEL, int idx);
  register int i;
  
  objAtIdx = (void *)[a methodForSelector:@selector(objectAtIndex:)];
  for (i = [a count] - 1; i >= 0; i--) {
    register id o;

    o = objAtIdx(a, @selector(objectAtIndex:), i);
    if (o == obj) return YES;
  }
  return NO;
}

- (void)validatePropertiesCache
{
  NSMutableArray *updAttr = [NSMutableArray new];
  NSMutableArray *updName = [NSMutableArray new];
  NSMutableArray *fetAttr = [NSMutableArray new];
  NSMutableArray *fetRels = [NSMutableArray new];
    
  int i;
    
  [self invalidatePropertiesCache];

#ifdef DEBUG
  NSAssert((updAttr != nil) && (updName != nil) &&
           (fetAttr != nil) && (fetRels != nil),
           @"allocation of array failed !");
  
  NSAssert(self->primaryKeyAttributes,     @"no pkey attributes are set !");
  NSAssert(self->attributesUsedForLocking, @"no locking attrs are set !");
  NSAssert(self->classProperties,          @"no class properties are set !");
#endif

  //_printIds(self->attributes,               "attrs:\n", "  ");
  //_printIds(self->attributesUsedForLocking, "lock:\n", "  ");

  for (i = ([self->attributes count] - 1); i >= 0; i--) {
    EOAttribute *attr = [self->attributes objectAtIndex:i];
    BOOL pk, lk, cp, sa;

    pk = _containsObject(self->primaryKeyAttributes,     attr);
    lk = _containsObject(self->attributesUsedForLocking, attr);
    cp = _containsObject(self->classProperties,          attr);
    sa = YES;
    
#if 0
    NSLog(@"attribute %@ pk=%i lk=%i cp=%i sa=%i", 
	  [attr name], pk, lk, cp, sa);
#endif
    
    if ((pk || lk || cp) && (!_containsObject(fetAttr, attr)))
      [fetAttr addObject:attr];
    
    if ((pk || lk || cp) && (sa) && (!_containsObject(updAttr, attr))) {
      [updAttr addObject:attr];
      [updName addObject:[attr name]];
    }
  }
    
  for (i = [relationships count]-1; i >= 0; i--) {
    id rel = [relationships objectAtIndex:i];

    if (_containsObject(classProperties, rel))
      [fetRels addObject:rel];
  }

  RELEASE(self->attributesUsedForInsert);
  self->attributesUsedForInsert = [[NSArray alloc] initWithArray:updAttr];
  RELEASE(self->relationsUsedForFetch);
  self->relationsUsedForFetch   = [[NSArray alloc] initWithArray:fetRels];
  RELEASE(self->attributesUsedForFetch);
  self->attributesUsedForFetch  =
    [[NSArray alloc] initWithArray:
        [fetAttr sortedArrayUsingFunction:_compareByName context:nil]];
  RELEASE(self->attributesNamesUsedForInsert);
  attributesNamesUsedForInsert = [updName copy];

  if ([self->attributesUsedForFetch count] == 0) {
    NSLog(@"WARNING: entity %@ has no fetch attributes: "
          @"attributes=%@ !",
          self,
          [[(id)self->attributes mappedArrayUsingSelector:@selector(name)]
                                 componentsJoinedByString:@","]);
  }
    
  RELEASE(updAttr); updAttr = nil;
  RELEASE(fetAttr); fetAttr = nil;
  RELEASE(fetRels); fetRels = nil;
  RELEASE(updName); updName = nil;

  self->flags.isPropertiesCacheValid = YES;
}

- (void)invalidatePropertiesCache {
  if (flags.isPropertiesCacheValid) {
    RELEASE(self->attributesUsedForInsert);
    RELEASE(self->attributesUsedForFetch);
    RELEASE(self->relationsUsedForFetch);
    RELEASE(self->attributesNamesUsedForInsert);
        
    self->attributesUsedForInsert = nil;
    self->attributesUsedForFetch = nil;
    self->relationsUsedForFetch = nil;
    self->attributesNamesUsedForInsert = nil;
        
    flags.isPropertiesCacheValid = NO;
  }
}

// description

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p]: name=%@ className=%@ tableName=%@ "
                     @"readOnly=%s>",
                     NSStringFromClass([self class]), self,
                     [self name], [self className], [self externalName],
                     [self isReadOnly] ? "YES" : "NO"
                   ];
}

@end /* EOEntity (EOEntityCreation) */


@implementation EOEntity(ValuesConversion)

- (NSDictionary *)convertValuesToModel:(NSDictionary *)aRow {
  NSMutableDictionary *dict;
  NSEnumerator        *enumerator;
  NSString            *key;
    
  dict = [NSMutableDictionary dictionaryWithCapacity:[aRow count]];
  enumerator = [aRow keyEnumerator];
  while ((key = [enumerator nextObject]) != nil) {
    id old = [aRow objectForKey:key];
    id new = [[self attributeNamed:key] convertValueToModel:old];
    
    if (new != nil) [dict setObject:new forKey:key];
  }
  
  return [dict count] > 0 ? dict : (NSMutableDictionary *)nil;
}

static int _compareByName(id obj1, id obj2, void * context) {
  return [[(EOAttribute*)obj1 name] compare:[(EOAttribute*)obj2 name]];
}

@end /* EOAttribute (ValuesConversion) */

@implementation EOEntity(EOF2Additions)

- (BOOL)isAbstractEntity {
  return NO;
}

/* ids */

- (EOGlobalID *)globalIDForRow:(NSDictionary *)_row {
  static Class EOKeyGlobalIDClass = Nil;
  unsigned int keyCount = [self->primaryKeyAttributeNames count];
  id           values[keyCount];
  unsigned int i;
  
  for (i = 0; i < keyCount; i++) {
    NSString *attrName;

    attrName  = [self->primaryKeyAttributeNames objectAtIndex:i];
    values[i] = [_row objectForKey:attrName];

    if (values[i] == nil)
      return nil;
  }
  if (EOKeyGlobalIDClass == Nil) EOKeyGlobalIDClass = [EOKeyGlobalID class];

  return [EOKeyGlobalIDClass globalIDWithEntityName:self->name
                             keys:&(values[0])
                             keyCount:keyCount
                             zone:[self zone]];
}

- (BOOL)isPrimaryKeyValidInObject:(id)_object {
  unsigned int keyCount = [self->primaryKeyAttributeNames count];
  unsigned int i;
  
  if (_object == nil) return NO;
  
  for (i = 0; i < keyCount; i++) {
    if ([_object valueForKey:[self->primaryKeyAttributeNames objectAtIndex:i]]
        == nil)
      return NO;
  }
  return YES;
}

/* refs to other models */

- (NSArray *)externalModelsReferenced {
  NSEnumerator   *e;
  EORelationship *relship;
  NSMutableArray *result;
  EOModel        *thisModel;
  
  thisModel = [self model];
  result    = nil;
  
  e = [self->relationships objectEnumerator];
  while ((relship = [e nextObject]) != nil) {
    EOEntity *targetEntity;
    EOModel  *extModel;

    targetEntity = [relship destinationEntity];
    extModel = [targetEntity model];

    if (extModel != thisModel) {
      if (result == nil) result = [NSMutableArray array];
      [result addObject:extModel];
    }
  }
  return result != nil ? (id)result : [NSArray array];
}

/* fetch specs */

- (EOFetchSpecification *)fetchSpecificationNamed:(NSString *)_name {
  return nil;
}
- (NSArray *)fetchSpecificationNames {
  return nil;
}

/* names */

- (void)beautifyName {
  [self setName:[[self name] _beautifyEntityName]];
}

@end /* EOEntity(EOF2Additions) */

@implementation EOEntity(PropertyListCoding)

static inline void _addToPropList(NSMutableDictionary *propertyList,
                                  id _value, NSString *key) {
  if (_value) [propertyList setObject:_value forKey:key];
}

- (void)encodeIntoPropertyList:(NSMutableDictionary *)_plist {
  int i, count;

  _addToPropList(_plist, self->name,           @"name");
  _addToPropList(_plist, self->className,      @"className");
  _addToPropList(_plist, self->externalName,   @"externalName");
  _addToPropList(_plist, self->externalQuery,  @"externalQuery");
  _addToPropList(_plist, self->userDictionary, @"userDictionary");
  
  if ((count = [self->attributes count])) {
    id attributesPList;

    attributesPList = [NSMutableArray array];
    for (i = 0; i < count; i++) {
      NSMutableDictionary *attributePList;

      attributePList = [[NSMutableDictionary alloc] init];
      [[self->attributes objectAtIndex:i]
                         encodeIntoPropertyList:attributePList];
      [attributesPList addObject:attributePList];
      RELEASE(attributePList);
    }
    
    _addToPropList(_plist, attributesPList, @"attributes");
  }

  if ((count = [self->attributesUsedForLocking count])) {
    id attributesUsedForLockingPList;

    attributesUsedForLockingPList = [NSMutableArray array];
    for (i = 0; i < count; i++) {
      id attributePList;

      attributePList =
        [(EOAttribute*)[self->attributesUsedForLocking objectAtIndex:i] name];
      [attributesUsedForLockingPList addObject:attributePList];
    }
    _addToPropList(_plist, attributesUsedForLockingPList,
                   @"attributesUsedForLocking");
  }

  if ((count = [self->classProperties count])) {
    id classPropertiesPList = nil;

    classPropertiesPList = [NSMutableArray array];
    for (i = 0; i < count; i++) {
      id classPropertyPList;

      classPropertyPList = 
        [(EOAttribute*)[self->classProperties objectAtIndex:i] name];
      [classPropertiesPList addObject:classPropertyPList];
    }
    _addToPropList(_plist, classPropertiesPList, @"classProperties");
  }

  if ((count = [self->primaryKeyAttributes count])) {
    id primaryKeyAttributesPList;

    primaryKeyAttributesPList = [NSMutableArray array];
    for (i = 0; i < count; i++) {
      id attributePList;
      attributePList =
        [(EOAttribute*)[self->primaryKeyAttributes objectAtIndex:i] name];
      [primaryKeyAttributesPList addObject:attributePList];
    }
    _addToPropList(_plist, primaryKeyAttributesPList, @"primaryKeyAttributes");
  }

  if ((count = [self->relationships count])) {
    id relationshipsPList;
    
    relationshipsPList = [NSMutableArray array];
    for (i = 0; i < count; i++) {
      NSMutableDictionary *relationshipPList;

      relationshipPList = [NSMutableDictionary dictionary];
      
      [[self->relationships objectAtIndex:i]
                            encodeIntoPropertyList:relationshipPList];
      [relationshipsPList addObject:relationshipPList];
    }
    _addToPropList(_plist, relationshipsPList, @"relationships");
  }
}

@end /* EOEntity(PropertyListCoding) */

@implementation NSString(EntityBeautify)

- (NSString *)_beautifyEntityName {
  if ([self length] == 0)
    return @"";
  else {
    unsigned clen = 0;
    char     *s   = NULL;
    unsigned cnt, cnt2;

    clen = [self cStringLength];
#if GNU_RUNTIME
    s = objc_atomic_malloc(clen + 4);
#else
    s = malloc(clen + 4);
#endif

    [self getCString:s maxLength:clen];
    
    for (cnt = cnt2 = 0; cnt < clen; cnt++, cnt2++) {
      if ((s[cnt] == '_') && (s[cnt + 1] != '\0')) {
        s[cnt2] = toupper(s[cnt + 1]);
        cnt++;
      }
      else if ((s[cnt] == '2') && (s[cnt + 1] != '\0')) {
        s[cnt2] = s[cnt];
        cnt++;
        cnt2++;
        s[cnt2] = toupper(s[cnt]);
      }
      else
        s[cnt2] = tolower(s[cnt]);
    }
    s[cnt2] = '\0';

    s[0] = toupper(s[0]);

#if !LIB_FOUNDATION_LIBRARY
    {
      NSString *os;

      os = [NSString stringWithCString:s];
      free(s);
      return os;
    }
#else
    return [NSString stringWithCStringNoCopy:s freeWhenDone:YES];
#endif
  }
}

@end
