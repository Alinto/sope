/* 
   EOEntity.h

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

#ifndef __EOEntity_h__
#define __EOEntity_h__

#import <Foundation/NSString.h>

@class EOModel, EOAttribute, EORelationship;
@class EOSQLQualifier, EOExpressionArray;
@class NSMutableDictionary;

@interface EOEntity : NSObject
{
    NSString            *name;
    NSString            *className;
    NSString            *externalName;
    NSString            *externalQuery;
    NSDictionary        *userDictionary;
    NSArray             *primaryKeyAttributeNames; /* sorted array of names */
    NSArray             *attributesNamesUsedForInsert;
    NSArray             *classPropertyNames;

    /* Garbage collectable objects */
    EOModel             *model;                   /* non-retained */
    EOSQLQualifier      *qualifier;
    NSArray             *attributes;
    NSMutableDictionary *attributesByName;
    NSArray             *relationships;
    NSMutableDictionary *relationshipsByName;     // name/EORelationship
    NSArray             *primaryKeyAttributes;
    NSArray             *classProperties;          // EOAttribute/EORelationship
    NSArray             *attributesUsedForLocking;

    /* Cached properties */
    NSArray             *attributesUsedForInsert;  // cache from classProperties
    NSArray             *attributesUsedForFetch;   // cache from classProperties
    NSArray             *relationsUsedForFetch;    // cache from classProperties

    struct {
        BOOL isReadOnly:1;
        BOOL createsMutableObjects:1;
        BOOL isPropertiesCacheValid:1;
    } flags;
}

/* Initializing instances */
- (id)initWithName:(NSString *)name;

/* Accessing the name */
- (NSString *)name;
- (BOOL)setName:(NSString *)name;
+ (BOOL)isValidName:(NSString *)name;

/* Accessing the model */
- (void)setModel:(EOModel *)model;
- (EOModel *)model;
- (void)resetModel;
- (BOOL)hasModel;

/* Getting the qualifier */
- (EOSQLQualifier *)qualifier;

/* Accessing attributes */
- (BOOL)addAttribute:(EOAttribute *)attribute;
- (void)removeAttributeNamed:(NSString *)name;
- (EOAttribute *)attributeNamed:(NSString *)attributeName;
- (NSArray *)attributes;

/* Accessing relationships */
- (BOOL)addRelationship:(EORelationship *)relationship;
- (void)removeRelationshipNamed:(NSString *)name;
- (EORelationship *)relationshipNamed:(NSString *)relationshipName;
- (NSArray *)relationships;

/* Accessing primary key attributes */
- (BOOL)setPrimaryKeyAttributes:(NSArray *)keys;
- (NSArray *)primaryKeyAttributes;
- (NSArray *)primaryKeyAttributeNames;
- (BOOL)isValidPrimaryKeyAttribute:(EOAttribute *)anAttribute;

/* Getting primary keys and snapshot for row */
- (NSDictionary *)primaryKeyForRow:(NSDictionary *)row;
- (NSDictionary *)snapshotForRow:(NSDictionary *)aRow;

/* Getting attributes used for fetch/insert/update operations */
- (NSArray *)attributesUsedForInsert;
- (NSArray *)attributesUsedForFetch;
- (NSArray *)relationsUsedForFetch;
- (NSArray *)attributesNamesUsedForInsert;

/* Accessing class properties */
- (BOOL)setClassProperties:(NSArray *)properties;
- (NSArray *)classProperties;
- (NSArray *)classPropertyNames;
- (BOOL)isValidClassProperty:(id)aProp;
- (id)propertyNamed:(NSString *)name;
- (NSArray *)relationshipsNamed:(NSString *)_relationshipPath;

/* Accessing locking attributes */
- (BOOL)setAttributesUsedForLocking:(NSArray *)attributes;
- (NSArray *)attributesUsedForLocking;
- (BOOL)isValidAttributeUsedForLocking:(EOAttribute *)anAttribute;

/* Accessing the enterprise object class */
- (void)setClassName:(NSString *)name;
- (NSString *)className; 

/* Accessing external information */
- (void)setExternalName:(NSString *)name;
- (NSString *)externalName;

/* Accessing the external query */
- (void)setExternalQuery:(NSString *)query;
- (NSString *)externalQuery;

/* Accessing read-only status */
- (void)setReadOnly:(BOOL)flag;
- (BOOL)isReadOnly;

/* Accessing the user dictionary */
- (void)setUserDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)userDictionary;

- (BOOL)referencesProperty:property;

@end


@interface EOEntity (EOEntityPrivate)

+ (EOEntity *)entityFromPropertyList:(id)propertyList model:(EOModel *)model;
- (void)replaceStringsWithObjects;

- (id)propertyList;
- (void)setCreateMutableObjects:(BOOL)flag;
- (BOOL)createsMutableObjects;

- (void)validatePropertiesCache;
- (void)invalidatePropertiesCache;

@end

@interface EOEntity(ValuesConversion)

- (NSDictionary *)convertValuesToModel:(NSDictionary *)aRow;

@end /* EOAttribute (ValuesConversion) */

@class EOGlobalID, EOFetchSpecification;

@interface EOEntity(EOF2Additions)

- (BOOL)isAbstractEntity;

/* ids */

- (EOGlobalID *)globalIDForRow:(NSDictionary *)_row;
- (BOOL)isPrimaryKeyValidInObject:(id)_object;

/* refs to other models */

- (NSArray *)externalModelsReferenced;

/* fetch specs */

- (EOFetchSpecification *)fetchSpecificationNamed:(NSString *)_name;
- (NSArray *)fetchSpecificationNames;

/* names */

- (void)beautifyName;

@end

@class NSMutableDictionary;

@interface EOEntity(PropertyListCoding)

- (void)encodeIntoPropertyList:(NSMutableDictionary *)_plist;

@end

#import <EOControl/EOClassDescription.h>

@interface EOEntityClassDescription : EOClassDescription
{
  EOEntity *entity;
}

- (id)initWithEntity:(EOEntity *)_entity;
- (EOEntity *)entity;

@end

#endif /* __EOEntity_h__ */
