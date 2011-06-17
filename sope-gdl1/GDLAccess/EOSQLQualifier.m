/* 
   EOSQLQualifier.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@apache.org>
           Helge Hess <helge.hess@opengroupware.org>
   Date:   September 1996
           November  1999

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

#include <stdio.h>
#import "common.h"
#import "EOSQLQualifier.h"
#import "EOAdaptor.h"
#import "EOAttribute.h"
#import "EOEntity.h"
#import "EOExpressionArray.h"
#import "EOFExceptions.h"
#import "EORelationship.h"
#import "EOSQLExpression.h"
#include <EOControl/EOKeyValueCoding.h>
#include <EOControl/EONull.h>
#import "EOQualifierScanner.h"

#if LIB_FOUNDATION_LIBRARY
#  include <extensions/DefaultScannerHandler.h>
#  include <extensions/PrintfFormatScanner.h>
#else
#  include "DefaultScannerHandler.h"
#  include "PrintfFormatScanner.h"
#endif

@interface EOQualifierJoinHolder : NSObject
{
  id source;
  id destination;
}
+ (id)valueForSource:(id)source destination:(id)destination;
- (NSString*)expressionValueForContext:(EOSQLExpression*)context;
- (id)source;
- (id)destination;
@end

@implementation EOQualifierJoinHolder

static Class  AttributeClass = Nil;
static EONull *null          = nil;

+ (void)initialize {
  AttributeClass = [EOAttribute class];
  null           = [[NSNull null] retain];
}

+ (id)valueForSource:(id)_source destination:(id)_destination {
  EOQualifierJoinHolder *value;
  
  value              = [[[self alloc] init] autorelease];
  value->source      = [_source      retain];
  value->destination = [_destination retain];
  return value;
}

- (NSString *)expressionValueForContext:(EOSQLExpression *)context {
  NSMutableString *result         = nil;
  EOAdaptor       *adaptor        = nil;
  NSString        *formattedLeft  = nil;
  NSString        *formattedRight = nil;
  BOOL            checkNull       = NO;

  adaptor = [context adaptor];
  
  if ([source isKindOfClass:AttributeClass]) {
    formattedLeft = [(EOAttribute *)source expressionValueForContext:context];
  }
  else {
    NSAssert([destination isKindOfClass:AttributeClass],
             @"either one of source or destination should be EOAttribute");
    if ([source isEqual:null] || (source == nil))
      checkNull = YES;
    
    formattedLeft = [adaptor formatValue:(source ? source : (id)null)
                             forAttribute:destination];
  }

  if ([destination isKindOfClass:AttributeClass]) {
    NSString *tmp = formattedLeft;
    
    formattedLeft  = 
      [(EOAttribute *)destination expressionValueForContext:context];
    formattedRight = tmp;
  }
  else {
    NSAssert([source isKindOfClass:AttributeClass],
             @"either one of source or destination should be EOAttribute");
    
    if ([destination isEqual:null] || (destination == nil))
      checkNull = YES;
    
    formattedRight = [adaptor formatValue:(destination ? destination :(id)null)
                              forAttribute:source];
  }

  result = [NSMutableString stringWithCapacity:64];
  [result appendString:formattedLeft];
  [result appendString:checkNull ? @" IS " : @"="];
  [result appendString:formattedRight];
  return result;
}

- (id)source {
    return self->source;
}
- (id)destination {
    return self->destination;
}

@end /* EOQualifierJoinHolder */


@implementation EOSQLQualifier

+ (EOSQLQualifier*)qualifierForRow:(NSDictionary*)row
  entity:(EOEntity*)_entity
{
  EOSQLQualifier  *qualifier     = nil;
  NSEnumerator    *enumerator    = nil;
  NSString        *attributeName = nil;
  EOAttribute     *attribute     = nil;
  id              value          = nil;
  BOOL            first          = YES;

  enumerator = [row keyEnumerator];    
  qualifier  = [[[EOSQLQualifier alloc] init] autorelease];

  while ((attributeName = [enumerator nextObject])) {
    attribute = [_entity attributeNamed:attributeName];
    value = [row objectForKey:attributeName];

    if ((value == nil) || (attribute == nil))
      /* return nil when is unable to build a qualifier for all keys
         in the given row
      */
      return nil;

    if (first)
      first = NO;
    else
      [qualifier->content addObject:@" AND "];

    [qualifier->content addObject:
              [EOQualifierJoinHolder valueForSource:attribute destination:value]];
  }

  qualifier->entity = RETAIN(_entity);
  [qualifier _computeRelationshipPaths];

  return qualifier;
}

+ (EOSQLQualifier*)qualifierForPrimaryKey:(NSDictionary*)dictionary
  entity:(EOEntity*)_entity
{
  NSDictionary *pkey = nil;

  pkey = [_entity primaryKeyForRow:dictionary];
    /* return nil when is unable to build a complete qualifier
       for all primary key attributes
    */
  return pkey != nil
    ? [self qualifierForRow:pkey entity:_entity] : (EOSQLQualifier *)nil;
}

+ (EOSQLQualifier*)qualifierForRow:(NSDictionary*)row 
  relationship:(EORelationship*)relationship
{
  NSArray        *componentRelationships = nil;
  EOSQLQualifier *qualifier              = nil;
  NSArray        *sourceAttributes       = nil;
  id             tmpRelationship         = nil;
  EOAttribute    *sourceAttribute        = nil;
  EOAttribute    *destinationAttribute   = nil;
  id             value                   = nil;
  int            j                       = 0;
  int            count2                  = 0;

  componentRelationships = [relationship componentRelationships];
  tmpRelationship        = relationship;
  qualifier              = [[[EOSQLQualifier alloc] init] autorelease];

  /* Make a qualifier string in the following manner. If the relationship is
     not flattened we must join using the join operator the values from `row'
     and the foreign keys taken from the destination entity of relatioship.
     If the relationship is flattend we must append then joins between the
     components of relationship. */

  if (componentRelationships) {
    tmpRelationship = [componentRelationships objectAtIndex:0];
        
    sourceAttributes =
      [NSArray arrayWithObject:[tmpRelationship sourceAttribute]];
  }
  else {
    sourceAttributes =
      [NSArray arrayWithObject:[relationship sourceAttribute]];
  }

  sourceAttribute = [tmpRelationship sourceAttribute];
  value           = [row objectForKey:[sourceAttribute name]];
  if (value == nil)
    /* Returns nil if `row' does not contain all the values needed to 
       create a complete qualifier
    */
    return nil;

  destinationAttribute = [tmpRelationship destinationAttribute];
  [qualifier->content addObject:
            [EOQualifierJoinHolder valueForSource:destinationAttribute
                                   destination:value]];

  if (componentRelationships) {
    EOEntity *tempEntity = [tmpRelationship destinationEntity];

    /* The relationship is flattened. Iterate over the components and 
       add joins that `link' the components between them.
    */
    count2 = [componentRelationships count];
    for (j = 1; j < count2; j++) {
      relationship = [componentRelationships objectAtIndex:j];
            
      if ([relationship sourceAttribute]) {
        [qualifier->content addObject:@" AND "];
        [qualifier->content addObject:
                  [EOQualifierJoinHolder valueForSource:
                                         [relationship sourceAttribute]
                                         destination:
                                         [relationship destinationAttribute]]];
      }
    }

    /* Here we make a hack because later we need to use this qualifier in
       a SELECT expression in which the qualifier's entity should be the
       final destination entity of the flattened relationship. In addition
       we need in the FROM clause all the entities corresponding to the
       components of the relationship to be able to insert the joins
       between the values given in row and the final attributes from the
       destination entity of the last component of relationship. */
    ASSIGN(qualifier->entity, tempEntity);
    [qualifier _computeRelationshipPaths];
    ASSIGN(qualifier->entity, [relationship destinationEntity]);
    return qualifier;
  }
  else {
    ASSIGN(qualifier->entity, [relationship destinationEntity]);
    return qualifier;
  }
}

+ (EOSQLQualifier *)qualifierForObject:sourceObject 
  relationship:(EORelationship *)relationship
{
  return [self qualifierForRow:
                 [sourceObject valueForKey:[[relationship sourceAttribute] name]]
               relationship:relationship];
}

- (id)init {
  NSZone *z = [self zone];
    
  RELEASE(self->content);            self->content            = nil;
  RELEASE(self->relationshipPaths);  self->relationshipPaths  = nil;
  RELEASE(self->additionalEntities); self->additionalEntities = nil;

  self->content            = [[EOExpressionArray allocWithZone:z] init];
  self->relationshipPaths  = [[NSMutableSet allocWithZone:z] init];
  self->additionalEntities = [[NSMutableSet allocWithZone:z] init];
  return self;
}

- (id)initWithEntity:(EOEntity *)_entity 
  qualifierFormat:(NSString *)_qualifierFormat
  argumentsArray:(NSArray *)_args
{
  PrintfFormatScanner           *formatScanner       = nil;
  EOQualifierEnumScannerHandler *scannerHandler      = nil;
  NSString                      *qualifierString     = nil;
  NSMutableArray                *myRelationshipPaths = nil;
  NSEnumerator                  *args                = nil;

  myRelationshipPaths = [[NSMutableArray allocWithZone:[self zone]] init];
    
  [self init];
  ASSIGN(self->entity, _entity);

  if (_qualifierFormat == nil)
    return self;

  formatScanner  = [[PrintfFormatScanner alloc] init];
  scannerHandler = [[EOQualifierEnumScannerHandler alloc] init];
  [formatScanner setAllowOnlySpecifier:YES];

  args = [_args objectEnumerator];
  [scannerHandler setEntity:_entity];
    
  [formatScanner setFormatScannerHandler:scannerHandler];
  /*
    Note: This is an ugly hack. Arguments is supposed to be a va_args
          structure, but an NSArray is passed in.
          It works because the value is casted to -parseFormatString:context:
          which gives control to the scannerHandler which casts the va_args
          back to an array (the EOQualifierEnumScannerHandler does that).
          Works on ix86, but *NOT* on iSeries or zServer !!
  */
#if defined(__s390__) || defined(__arm__)
  qualifierString =
    [formatScanner performSelector:@selector(stringWithFormat:arguments:)
                   withObject:_qualifierFormat
                   withObject:args];
#else
  // TODO: args is an NSArray, PrintfFormatScanner expects a va_list?
  //       I think that this is OK because we use EOQualifierEnumScannerHandler
  qualifierString = 
    [formatScanner stringWithFormat:_qualifierFormat
                   arguments:(void *)args];
#endif

  [formatScanner  release]; formatScanner  = nil;
  [scannerHandler release]; scannerHandler = nil;
  
  [self->content release]; self->content = nil;
  self->content =
         [[EOExpressionArray parseExpression:qualifierString
                            entity:entity
                            replacePropertyReferences:YES
                            relationshipPaths:myRelationshipPaths]
	   retain];
  [self _computeRelationshipPaths:myRelationshipPaths];
  [myRelationshipPaths release]; myRelationshipPaths = nil;
  return self;
}

- (id)initWithEntity:(EOEntity*)_entity 
  qualifierFormat:(NSString *)qualifierFormat, ...
{
  va_list        ap;
  id             formatScanner        = nil;
  id             scannerHandler       = nil;
  NSString       *qualifierString     = nil;
  NSMutableArray *myRelationshipPaths = nil;

  if ((self = [self init]) == nil)
    return nil;
  
  myRelationshipPaths = [[NSMutableArray alloc] init];
  ASSIGN(self->entity, _entity);
  
  if (qualifierFormat == nil) {
    return self;
  }
  
  formatScanner  = [[PrintfFormatScanner alloc] init];
  scannerHandler = [[EOQualifierScannerHandler alloc] init];
  [formatScanner setAllowOnlySpecifier:YES];
  
  va_start(ap, qualifierFormat);
  [scannerHandler setEntity:_entity];
  [formatScanner setFormatScannerHandler:scannerHandler];
  qualifierString = [formatScanner stringWithFormat:qualifierFormat
                                   arguments:ap];
  va_end(ap);

  [formatScanner  release];
  [scannerHandler release];

  [self->content release]; self->content = nil;
  self->content =
         [[EOExpressionArray parseExpression:qualifierString
                            entity:entity
                            replacePropertyReferences:YES
                            relationshipPaths:myRelationshipPaths] retain];
  [self _computeRelationshipPaths:myRelationshipPaths];
  [myRelationshipPaths release]; myRelationshipPaths = nil;
  return self;
}

- (void)_computeRelationshipPaths {
  [self _computeRelationshipPaths:nil];
}

static void
handle_attribute(EOSQLQualifier *self, id object, id _relationshipPaths)
{
  [self->additionalEntities addObject:[object entity]];
}

- (void)_computeRelationshipPaths:(NSArray *)_relationshipPaths {
  int i, count;

  [relationshipPaths removeAllObjects];

  if (_relationshipPaths) {
    NSEnumerator *pathEnum = [_relationshipPaths objectEnumerator];
    NSArray      *relPath  = nil;
        
    while ((relPath = [pathEnum nextObject])) {
      NSEnumerator   *relEnum = nil;
      EORelationship *rel     = nil;

      relEnum = [relPath objectEnumerator];

      while ((rel = [relEnum nextObject])) {
        [additionalEntities addObject:[rel destinationEntity]];
      }
    }
    [relationshipPaths addObjectsFromArray:_relationshipPaths];
  }
  for (i = 0, count = [content count]; i < count; i++) {
    id object = [content objectAtIndex:i];

    /* The objects from content can only be NSString, values or
       EOAttribute. */
    if ([object isKindOfClass:[EOAttribute class]]) {
      handle_attribute (self, object, _relationshipPaths);
    }
    else if ([object isKindOfClass:[EOQualifierJoinHolder class]]) {
      id source      = nil;
      id destination = nil;

      source      = [object source];
      destination = [object destination];

      if ([source isKindOfClass:[EOAttribute class]])
        handle_attribute (self, source, _relationshipPaths);
      if ([destination isKindOfClass:[EOAttribute class]])
        handle_attribute (self, destination, _relationshipPaths);
    }
    else if ([object isKindOfClass:[EORelationship class]]) {
      [[[InvalidPropertyException alloc]
                                       initWithFormat:@"cannot refer a EORelat"
                                       @"ionship in a EOSQLQualifier: '%@'",
                                       [(EORelationship*)object name]] raise];
    }
  }
}

- (void)dealloc {
  RELEASE(self->relationshipPaths);
  RELEASE(self->additionalEntities);
  
  RELEASE(self->entity);
  RELEASE(self->content);
  [super dealloc];
}

- (id)copy {
  return [self copyWithZone:NSDefaultMallocZone()];
}

- (id)copyWithZone:(NSZone*)zone {
  EOSQLQualifier* copy = nil;

  copy                    = [[self->isa allocWithZone:zone] init];
  copy->entity            = RETAIN(self->entity);
  copy->content           = [self->content           mutableCopyWithZone:zone];
  copy->relationshipPaths = [self->relationshipPaths mutableCopyWithZone:zone];
  copy->usesDistinct      = self->usesDistinct;
  return copy;
}

- (void)negate {
  [self->content insertObject:@"NOT (" atIndex:0];
  [self->content addObject:@")"];
}

- (void)conjoinWithQualifier:(EOSQLQualifier*)qualifier {
  if (![qualifier isKindOfClass:[EOSQLQualifier class]]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"argument of conjoinWithQualifier: method must "
                     @"be EOSQLQualifier"];
  }

  if (self->entity != qualifier->entity) {
    [NSException raise:NSInvalidArgumentException
		 format:@"qualifier argument of conjoinWithQualifier: "
                             @"must have the same entity as receiver"];
  }

  [self->content insertObject:@"(" atIndex:0];
  [self->content addObject:@") AND ("];
  [self->content addObjectsFromExpressionArray:qualifier->content];
  [self->content addObject:@")"];
  [self->relationshipPaths unionSet:qualifier->relationshipPaths];
}

- (void)disjoinWithQualifier:(EOSQLQualifier*)qualifier {
  if (![qualifier isKindOfClass:[EOSQLQualifier class]]) {
    [NSException raise:NSInvalidArgumentException
		 format:@"argument of disjoinWithQualifier: method must "
                    @"be EOSQLQualifier"];
  }

  if (self->entity != qualifier->entity) {
    [NSException raise:NSInvalidArgumentException
		 format:@"qualifier argument of disjoinWithQualifier: "
                    @"must have the same entity as receiver"];
  }

  [self->content insertObject:@"(" atIndex:0];
  [self->content addObject:@") OR ("];
  [self->content addObjectsFromExpressionArray:qualifier->content];
  [self->content addObject:@")"];
  [self->relationshipPaths unionSet:qualifier->relationshipPaths];
}

- (EOEntity*)entity {
  return self->entity;
}
- (BOOL)isEmpty {
  return (self->entity == nil) ? YES : NO;
}
- (void)setUsesDistinct:(BOOL)flag {
  self->usesDistinct = flag;
}
- (BOOL)usesDistinct {
  return self->usesDistinct;
}
- (NSMutableSet*)relationshipPaths {
  return self->relationshipPaths;
}
- (NSMutableSet*)additionalEntities {
  return self->additionalEntities;
}

- (NSString*)expressionValueForContext:(id<EOExpressionContext>)ctx {
    return [self->content expressionValueForContext:ctx];
}

- (EOSQLQualifier *)sqlQualifierForEntity:(EOEntity *)_entity {
  NSAssert3(self->entity == _entity,
            @"passed invalid entity to %@ (contains %@, got %@)",
            self, self->entity, _entity);
  return (EOSQLQualifier *)self;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:\n", self, NSStringFromClass([self class])];

  [ms appendFormat:@" entity=%@", [self->entity name]];
  
  if (self->content)
    [ms appendFormat:@" content=%@", self->content];
  
  if (self->usesDistinct)
    [ms appendString:@" distinct"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* EOSQLQualifier */
