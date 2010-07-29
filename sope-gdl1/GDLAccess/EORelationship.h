/* 
   EORelationship.h

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

#ifndef __EORelationship_h__
#define __EORelationship_h__

#import <Foundation/NSString.h>
#import <GDLAccess/EOJoinTypes.h>

@class NSString, NSDictionary, NSException;
@class EOModel, EOEntity, EOAttribute;

@interface EORelationship : NSObject
{
    NSString     *name;
    NSString     *definition;
    NSDictionary *userDictionary;

    /* Garbage collectable objects */
    EOEntity     *entity; /* non-retained */
    EOEntity     *destinationEntity; /* non-retained */

    /* Computed values */
    NSMutableArray *componentRelationships;

    struct {
	BOOL	isFlattened:1;
	BOOL	isToMany:1;
	BOOL	createsMutableObjects:1;
        BOOL    isMandatory:1;
    } flags;

    // EOJoin

    EOAttribute *sourceAttribute;
    EOAttribute *destinationAttribute;
}

/* Initializing instances */
- (id)initWithName:(NSString*)name;

/* Accessing the name */
- (BOOL)setName:(NSString*)name;
- (NSString*)name;
+ (BOOL)isValidName:(NSString*)name;

/* Using joins */

- (NSArray*)joins;

/* Convering source row in destination row */
- (NSDictionary*)foreignKeyForRow:(NSDictionary*)row;

/* Accessing the definition */
- (NSArray*)componentRelationships;
- (void)setDefinition:(NSString*)definition;
- (NSString*)definition;

/* Accessing the entities joined */
- (void)setEntity:(EOEntity*)entity;
- (EOEntity*)entity;
- (void)resetEntities;
- (BOOL)hasEntity;
- (BOOL)hasDestinationEntity;
- (EOEntity*)destinationEntity;

/* Checking type */
- (BOOL)isCompound;  // always NO (no compound joins supported)
- (BOOL)isFlattened;

/* Accessing to-many property */
- (BOOL)setToMany:(BOOL)flag;
- (BOOL)isToMany;

/* Checking references */
- (BOOL)referencesProperty:(id)property;

/* Accessing the user dictionary */
- (void)setUserDictionary:(NSDictionary*)dictionary;
- (NSDictionary*)userDictionary;

@end

@interface EORelationship(EOJoin)

- (void)loadJoinPropertyList:(id)propertyList;

/* Accessing join properties */
- (void)setDestinationAttribute:(EOAttribute*)attribute;
- (EOAttribute*)destinationAttribute;
- (void)setSourceAttribute:(EOAttribute*)attribute;
- (EOAttribute*)sourceAttribute;
- (EORelationship*)relationship;

@end

@interface EORelationship (EORelationshipPrivate)

+ (EORelationship*)relationshipFromPropertyList:(id)propertyList
  model:(EOModel*)model;
- (void)replaceStringsWithObjects;
- (void)initFlattenedRelationship;

- (id)propertyList;

- (void)setCreateMutableObjects:(BOOL)flag;
- (BOOL)createsMutableObjects;

@end /* EORelationship (EORelationshipPrivate) */

@class NSMutableDictionary;

@interface EORelationship(PropertyListCoding)

- (void)encodeIntoPropertyList:(NSMutableDictionary *)_plist;

@end

@class NSException;

@interface EORelationship(EOF2Additions)

/* constraints */

- (void)setIsMandatory:(BOOL)_flag;
- (BOOL)isMandatory;

- (NSException *)validateValue:(id *)_value;

@end

#endif /* __EORelationship_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
