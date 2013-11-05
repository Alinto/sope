/* 
   EORelationship.m

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
#import "EOAttribute.h"
#import "EOEntity.h"
#import "EORelationship.h"
#import "EOExpressionArray.h"
#import "EOFExceptions.h"
#import <EOControl/EONull.h>

static EONull *null = nil;

@interface EOJoin : EORelationship // for adaptor compability
@end

@implementation EORelationship

+ (void)initialize {
  if (null == nil) null = [[EONull null] retain];
}

- (id)init {
  if ((self = [super init])) {
    self->flags.createsMutableObjects = YES;
    self->entity = nil;
    self->destinationEntity = nil;
  }
  return self;
}

- (id)initWithName:(NSString*)_name {
  if ((self = [self init])) {
    self->name = _name;
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->name);
  RELEASE(self->definition);
  RELEASE(self->userDictionary);
  self->entity            = nil;
  if ([self->destinationEntity isKindOfClass:[NSString class]])
    RELEASE(self->destinationEntity);
  // else: non-retained EOEntity
  self->destinationEntity = nil;
  RELEASE(self->componentRelationships);
  RELEASE(self->sourceAttribute);
  RELEASE(self->destinationAttribute);
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
  return [self->name hash];
}

+ (BOOL)isValidName:(NSString*)_name {
  return [EOEntity isValidName:_name];
}

- (void)setDefinition:(NSString *)def {
  // TODO: do we need this?
  if (def == nil) {
    [NSException raise:NSInvalidArgumentException
		 format:@"invalid (nil) definition argument ..."];
  }

  if ([def isNameOfARelationshipPath]) {
    NSArray *defArray = nil;
    int     count;
    
    defArray               = [def componentsSeparatedByString:@"."];
    count                  = [defArray count];
    
    RELEASE(self->componentRelationships);
    self->componentRelationships =
      [[NSMutableArray alloc] initWithCapacity:count];
    
    flags.isFlattened      = YES;
    
    NS_DURING {
      EOEntity *currentEntity = self->entity;
      id       relationship   = nil;
      int      i;
      
      for (i = 0; i < count; i++) {
        id relationshipName = [defArray objectAtIndex:i];
    
        /* Take the address of `relationship' to force the compiler
           to not allocate it into a register. */
        *(&relationship) = [currentEntity relationshipNamed:
                                          relationshipName];
        if (!relationship)
          [[[InvalidPropertyException alloc]
                                           initWithName:relationshipName
                                           entity:currentEntity] raise];
        [self->componentRelationships addObject:relationship];
        flags.isToMany |= [relationship isToMany];
        currentEntity = [relationship destinationEntity];
      }
      if (self->destinationEntity &&
          ![self->destinationEntity isEqual:currentEntity])
        [[[DestinationEntityDoesntMatchDefinitionException alloc]
                                      initForDestination:self->destinationEntity
                                      andDefinition:def
                                      relationship:self] raise];
      if ([self->destinationEntity isKindOfClass:[NSString class]])
        RELEASE(self->destinationEntity);
      self->destinationEntity = currentEntity; /* non-retained */
      if ([self->destinationEntity isKindOfClass:[NSString class]])
        RETAIN(self->destinationEntity);
    }
    NS_HANDLER {
      RELEASE(self->componentRelationships);
      self->componentRelationships = nil;
      [localException raise];
    }
    NS_ENDHANDLER;
  }
  else
    [[[InvalidNameException alloc] initWithName:def] raise];

  ASSIGN(self->definition, def);
}

- (BOOL)setToMany:(BOOL)_flag {
  if ([self isFlattened]) return NO;
  self->flags.isToMany = _flag;
  return YES;
}
- (BOOL)isToMany {
  return self->flags.isToMany;
}

- (BOOL)setName:(NSString *)_name {
  if ([self->entity referencesProperty:_name])
    return NO;
  ASSIGN(self->name, _name);
  return NO;
}
- (NSString *)name {
  return self->name;
}

- (BOOL)isCompound {
  return NO;
}

- (NSString *)expressionValueForContext:(id<EOExpressionContext>)_ctx {
  return self->name;
}

- (void)setEntity:(EOEntity *)_entity {
  self->entity = _entity; /* non-retained */
}
- (EOEntity *)entity {
  return self->entity;
}
- (void)resetEntities {
  self->entity = nil;
  self->destinationEntity = nil;
}
- (BOOL)hasEntity {
  return (self->entity != nil) ? YES : NO;
}
- (BOOL)hasDestinationEntity {
  return (self->destinationEntity != nil) ? YES : NO;
}

- (void)setUserDictionary:(NSDictionary *)dict {
  ASSIGN(self->userDictionary, dict);
}
- (NSDictionary *)userDictionary {
  return self->userDictionary;
}

- (NSArray *)joins {
  return self->sourceAttribute ? [NSArray arrayWithObject:self] : nil;
}

- (NSString *)definition {
  return self->definition;
}
- (NSArray *)sourceAttributes {
  return [NSArray arrayWithObject:self->sourceAttribute];
}
- (NSArray *)destinationAttributes {
  return [NSArray arrayWithObject:self->destinationAttribute];
}
- (EOEntity *)destinationEntity {
  return self->destinationEntity;
}
- (BOOL)isFlattened {
  return self->flags.isFlattened;
}
- (NSArray *)componentRelationships {
  return self->componentRelationships;
}

- (BOOL)referencesProperty:(id)_property {
  if ([self->sourceAttribute isEqual:_property])
    return YES;
  if ([self->destinationAttribute isEqual:_property])
    return YES;

  if ([self->componentRelationships indexOfObject:_property] != NSNotFound)
    return YES;
  return NO;
}

- (NSDictionary *)foreignKeyForRow:(NSDictionary *)_row {
  int j, i, n = [_row count];
  id  keys[n], vals[n];
    
  for (i = j = 0, n = 1; j < n; j++) {
    EOAttribute *keyAttribute  = self->sourceAttribute;
    EOAttribute *fkeyAttribute = self->destinationAttribute;
    NSString    *key  = nil;
    NSString    *fkey = nil;
    id          value = nil;

    key   = [keyAttribute  name];
    fkey  = [fkeyAttribute name];
    value = [_row objectForKey:key];

    if (value) {
      vals[i] = value;
      keys[i] = fkey;
      i++;
    }
    else {
      NSLog(@"%s: could not get value of key %@ (foreignKey=%@)",
            __PRETTY_FUNCTION__, key, fkey);
    }
  }
    
  return AUTORELEASE([[NSDictionary alloc]
                                    initWithObjects:vals
                                    forKeys:keys count:i]);
}

- (NSString *)description {
  return [[self propertyList] description];
}

@end /* EORelationship */


@implementation EORelationship (EORelationshipPrivate)

+ (EORelationship *)relationshipFromPropertyList:(id)_plist
  model:(EOModel *)model
{
  NSDictionary   *plist = _plist;
  EORelationship *relationship = nil;
  NSArray        *array      = nil;
  NSEnumerator   *enumerator = nil;
  id             joinPList   = nil;

  relationship = [[[EORelationship alloc] init] autorelease];
  [relationship setCreateMutableObjects:YES];
  [relationship setName:[plist objectForKey:@"name"]];
  [relationship setUserDictionary:
                [plist objectForKey:@"userDictionary"]];

  if ((array = [plist objectForKey:@"joins"])) {
    enumerator = [array objectEnumerator];

    joinPList = [enumerator nextObject];
    [relationship loadJoinPropertyList:joinPList];
    joinPList = [enumerator nextObject];
    NSAssert(joinPList == nil, @"a relationship only supports one join !");
  }
  else {
    [relationship loadJoinPropertyList:_plist];
  }
  
  relationship->destinationEntity =
    RETAIN([plist objectForKey:@"destination"]);
  // retained string

  relationship->flags.isToMany =
    [[plist objectForKey:@"isToMany"] isEqual:@"Y"];

  relationship->flags.isMandatory =
    [[plist objectForKey:@"isMandatory"] isEqual:@"Y"];
  
  /* Do not send here the -setDefinition: message because the relationships
     are not yet created from the model file. */
  relationship->definition
    = RETAIN([plist objectForKey:@"definition"]);

  return relationship;
}

- (void)replaceStringsWithObjects {
  EOModel *model = [self->entity model];
  
  if (self->destinationEntity) {
    // now self->destinationEntity is NSString and retained !!
    id destinationEntityName = AUTORELEASE(self->destinationEntity);
    self->destinationEntity = [model entityNamed:destinationEntityName];
    // now hold entity non-retained
    
    if (self->destinationEntity == nil) {
      NSLog(@"invalid entity name '%@' specified as destination entity "
            @"for relationship '%@' in entity '%@'",
            destinationEntityName, name, [self->entity name]);
      [model errorInReading];
    }
  }

  if (!(self->destinationEntity || self->definition)) {
    NSLog(@"relationship '%@' in entity '%@' is incompletely specified: "
          @"no destination entity or definition.", name, [self->entity name]);
    [model errorInReading];
  }

  if (self->definition && (self->sourceAttribute != nil)) {
    NSLog(@"relationship '%@' in entity '%@': flattened relationships "
          @"cannot have joins", name, [self->entity name]);
    [model errorInReading];
  }
  
  if (self->sourceAttribute) {
    EOEntity    *attributeEntity;
    EOAttribute *attribute = nil;
    
#if 0
    attributeEntity = self->flags.isToMany
      ? self->destinationEntity
      : self->entity;
#endif
    attributeEntity = self->entity;
    attribute =
      [attributeEntity attributeNamed:(NSString*)self->sourceAttribute];
    
    if (attribute)
      [self setSourceAttribute:attribute];
    else {
      [model errorInReading];
      NSLog(@"invalid attribute name '%@' specified as source attribute for "
            @"join in relationship '%@' in entity '%@' (dest='%@')",
            sourceAttribute, [self name],
            [self->entity name], [self->destinationEntity name]);
    }

#if 0
    attributeEntity = self->flags.isToMany
      ? self->entity
      : self->destinationEntity;
#endif
    attributeEntity = self->destinationEntity;
    attribute = [attributeEntity attributeNamed:(NSString*)destinationAttribute];
    
    if (attribute)
      [self setDestinationAttribute:attribute];
    else {
      [model errorInReading];
      NSLog(@"invalid attribute name '%@' specified as destination "
            @"attribute for join in relationship '%@' in entity '%@' (dest='%@')",
            destinationAttribute, [self name],
            [self->entity name], [self->destinationEntity name]);
    }
  }
  [self setCreateMutableObjects:NO];
}

- (void)initFlattenedRelationship {
  if (self->definition) {
    NS_DURING
      [self setDefinition:self->definition];
    NS_HANDLER {
      NSLog([localException reason]);
      [[self->entity model] errorInReading];
    }
    NS_ENDHANDLER;
  }
}

- (id)propertyList {
  NSMutableDictionary *propertyList = nil;

  propertyList = [NSMutableDictionary dictionary];
  [self encodeIntoPropertyList:propertyList];
  return propertyList;
}

- (void)setCreateMutableObjects:(BOOL)flag {
  if (self->flags.createsMutableObjects == flag)
    return;

  self->flags.createsMutableObjects = flag;
}

- (BOOL)createsMutableObjects {
  return self->flags.createsMutableObjects;
}

- (int)compareByName:(EORelationship *)_other {
  return [[(EORelationship *)self name] compare:[_other name]];
}

/* EOJoin */

- (void)loadJoinPropertyList:(id)propertyList {
  NSDictionary *plist = propertyList;
  NSString *joinOperatorPList;
  NSString *joinSemanticPList;
  id tmp;

  tmp = [plist objectForKey:@"sourceAttribute"];
  [self setSourceAttribute:tmp];
  tmp = [plist objectForKey:@"destinationAttribute"];
  [self setDestinationAttribute:tmp];
  
  if ((joinOperatorPList = [plist objectForKey:@"joinOperator"])) {
    NSAssert([joinOperatorPList isEqual:@"EOJoinEqualTo"],
             @"only EOJoinEqualTo is supported as the join operator !");
  }

  if ((joinSemanticPList = [plist objectForKey:@"joinSemantic"])) {
    NSAssert([joinSemanticPList isEqual:@"EOInnerJoin"],
             @"only EOInnerJoin is supported as the join semantic !");
  }
}

- (void)setDestinationAttribute:(EOAttribute*)attribute {
  ASSIGN(self->destinationAttribute, attribute);
}
- (EOAttribute*)destinationAttribute {
  return self->destinationAttribute;
}

- (void)setSourceAttribute:(EOAttribute *)attribute {
  ASSIGN(self->sourceAttribute, attribute);
}
- (EOAttribute*)sourceAttribute	{
  return self->sourceAttribute;
}

- (EOJoinOperator)joinOperator {
  return EOJoinEqualTo;
}
- (EOJoinSemantic)joinSemantic {
  return EOInnerJoin;
}

- (EORelationship*)relationship {
  return self;
}

// misc

- (void)addJoin:(EOJoin *)_join {
  [self setSourceAttribute:[_join sourceAttribute]];
  [self setDestinationAttribute:[_join destinationAttribute]];
}

/* PropertyListCoding */

static inline void _addToPropList(NSMutableDictionary *_plist,
                                  id _value, NSString *key) {
  if (_value) [_plist setObject:_value forKey:key];
}

- (void)encodeIntoPropertyList:(NSMutableDictionary *)_plist {
  _addToPropList(_plist, self->name,           @"name");
  _addToPropList(_plist, self->definition,     @"definition");
  _addToPropList(_plist, self->userDictionary, @"userDictionary");

  if (self->sourceAttribute) { // has join ?
    _addToPropList(_plist, [self->sourceAttribute name], @"sourceAttribute");
    _addToPropList(_plist, [self->destinationAttribute name],
                   @"destinationAttribute");
    _addToPropList(_plist, [[self->sourceAttribute entity] name],
                   @"destination");
  }
  
  if (![self isFlattened] && self->destinationEntity) {
    _addToPropList(_plist, [self->destinationEntity name], @"destination");
  }

  if (![self isFlattened])
    _addToPropList(_plist, flags.isToMany ? @"Y" : @"N", @"isToMany");
  
  if (![self isMandatory])
    _addToPropList(_plist, flags.isMandatory ? @"Y" : @"N", @"isMandatory");
}

/* EOF2Additions */

/* constraints */

- (void)setIsMandatory:(BOOL)_flag {
  self->flags.isMandatory = _flag ? 1 : 0;
}
- (BOOL)isMandatory {
  return self->flags.isMandatory ? YES : NO;
}

- (NSException *)validateValue:(id *)_value {
  if (_value == NULL) return nil;
  
  /* check 'mandatory' constraint */
  
  if (self->flags.isMandatory) {
    if (self->flags.isToMany) {
      if ([*_value count] == 0) {
        NSLog(@"WARNING(%s): tried to use value %@"
              @"with mandatory toMany relationship %@",
              __PRETTY_FUNCTION__, *_value, self);
      }
    }
    else {
      if ((*_value == nil) || (*_value == null)) {
        NSLog(@"WARNING(%s): tried to use value %@"
              @"with mandatory toOne relationship %@",
              __PRETTY_FUNCTION__, *_value, self);
      }
    }
  }
  
  return nil;
}

@end /* EORelationship */

@implementation EOJoin
@end /* EOJoin */
