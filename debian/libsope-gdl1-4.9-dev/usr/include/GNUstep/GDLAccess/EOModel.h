/* 
   EOModel.h

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

#ifndef __EOModel_h__
#define __EOModel_h__

#import <Foundation/NSString.h>

@class EOEntity;

@interface EOModel : NSObject
{
    NSString     *name;
    NSString     *path;
    NSString     *adaptorName;
    NSString     *adaptorClassName;
    NSDictionary *connectionDictionary;
    NSDictionary *pkeyGeneratorDictionary;
    NSDictionary *userDictionary;

    NSArray             *entities;             // values with EOEntities
    NSMutableDictionary *entitiesByName;      // name/value with EOEntity
    NSMutableDictionary *entitiesByClassName; // class name/value with EOEntity

    struct {
        BOOL createsMutableObjects:1;
        BOOL errors:1;
    } flags;
}

/* Searching for a model file */
+ (NSString*)findPathForModelNamed:(NSString*)name;

/* Initializing instances */
- (id)initWithContentsOfFile:(NSString*)filename;
- (id)initWithPropertyList:propertyList;
- (id)initWithName:(NSString*)name;

/* Getting the filename */
- (NSString*)path;

/* Getting a property list representation */
- (id)modelAsPropertyList;

/* Getting the name */
- (NSString*)name;

/* Using entities */
- (BOOL)addEntity:(EOEntity *)entity;
- (void)removeEntityNamed:(NSString *)name;
- (EOEntity *)entityNamed:(NSString *)name;
- (NSArray *)entities;

/* Checking references */
- (NSArray *)referencesToProperty:(id)property; 

/* Getting an object's entity */
- (EOEntity *)entityForObject:(id)object;

/* Adding model information */
- (BOOL)incorporateModel:(EOModel *)model;

/* Accessing the adaptor bundle */
- (void)setAdaptorName:(NSString *)adaptorName;
- (NSString *)adaptorName;

/* Setting and getting the adaptor class name. */
- (void)setAdaptorClassName:(NSString *)adaptorClassName;
- (NSString *)adaptorClassName;

/* Accessing the connection dictionary */
- (void)setConnectionDictionary:(NSDictionary *)connectionDictionary;
- (NSDictionary *)connectionDictionary;

/* Accessing the pkey generator dictionary */
- (void)setPkeyGeneratorDictionary:(NSDictionary *)connectionDictionary;
- (NSDictionary *)pkeyGeneratorDictionary;

/* Accessing the user dictionary */
- (void)setUserDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)userDictionary;

@end


@interface EOModel (EOModelPrivate)

- (void)setCreateMutableObjects:(BOOL)flag;
- (BOOL)createsMutableObjects;

- (void)errorInReading;

@end /* EOModel (EOModelPrivate) */

@interface EOModel(NewInEOF2)

- (void)loadAllModelObjects;

@end

#endif /* __EOModel_h__ */
