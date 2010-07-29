// $Id: EOModelGroup.h 1 2004-08-20 10:38:46Z znek $

#ifndef __EOAccess_EOModelGroup_H__
#define __EOAccess_EOModelGroup_H__

#import <Foundation/NSObject.h>

@class NSDictionary;
@class EOGlobalID, EOFetchSpecification;
@class EOModelGroup, EOModel, EOEntity, EORelationship;

@protocol EOModelGroupClassDelegation < NSObject >

- (EOModelGroup *)defaultModelGroup;

@end

@protocol EOModelGroupDelegation < NSObject >

- (Class)entity:(EOEntity *)_entity
  classForObjectWithGlobalID:(EOGlobalID *)_oid;

- (Class)entity:(EOEntity *)_entity
  failedToLookupClassNamed:(NSString *)_className;

- (EOEntity *)relationship:(EORelationship *)_relship
  failedToLookupDestinationNamed:(NSString *)_entityName;

- (EOEntity *)subEntityForEntity:(EOEntity *)_entity
  primaryKey:(NSDictionary *)_pkey
  isFinal:(BOOL *)_flag;

- (EOModel *)modelGroup:(EOModelGroup *)_group
  entityNamed:(NSString *)_name;

- (EORelationship *)entity:(EOEntity *)_entity
  relationshipForRow:(NSDictionary *)_row
  relationship:(EORelationship *)_relship;

@end

@class NSArray, NSMutableDictionary;

@interface EOModelGroup : NSObject
{
  NSMutableDictionary        *nameToModel;
  id<EOModelGroupDelegation> delegate; /* non-retained */
}

+ (void)setDefaultGroup:(EOModelGroup *)_group;
+ (EOModelGroup *)defaultGroup;

+ (EOModelGroup *)globalModelGroup;

/* class delegate */

+ (void)setClassDelegate:(id<EOModelGroupClassDelegation>)_delegate;
+ (id<EOModelGroupClassDelegation>)classDelegate;

/* instance delegate */

- (void)setDelegate:(id<EOModelGroupDelegation>)_delegate;
- (id<EOModelGroupDelegation>)delegate;

/* models */

- (void)addModel:(EOModel *)_model;
- (void)removeModel:(EOModel *)_model;

- (EOModel *)modelNamed:(NSString *)_name;
- (NSArray *)modelNames;
- (NSArray *)models;
- (EOModel *)modelWithPath:(NSString *)_path;
- (EOModel *)addModelWithFile:(NSString *)_path;

- (void)loadAllModelObjects;

/* entities */

- (EOEntity *)entityForObject:(id)_object;
- (EOEntity *)entityNamed:(NSString *)_name;

- (EOFetchSpecification *)fetchSpecificationNamed:(NSString *)_name
  entityNamed:(NSString *)_entityName;

@end

#endif /* __EOAccess_EOModelGroup_H__ */
