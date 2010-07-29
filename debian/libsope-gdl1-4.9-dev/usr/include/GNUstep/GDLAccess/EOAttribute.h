/* 
   EOAttribute.h

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

#ifndef __EOAttribute_h__
#define __EOAttribute_h__

#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSDate.h>

@class NSString, NSTimeZone, NSDate, NSException;
@class NSMutableArray;
@class EOEntity;

@interface EOAttribute : NSObject
{
    NSString     *name;
    NSString     *calendarFormat;
    NSTimeZone   *clientTimeZone;
    NSTimeZone   *serverTimeZone;
    NSString     *columnName;
    NSString     *externalType;
    NSString     *valueClassName;
    NSString     *valueType;
    NSDictionary *userDictionary;
    EOEntity     *entity;             /* non-retained */
    unsigned     width;

    struct {
	int allowsNull:1;
	int reserved:31;
    } flags;
}

/* Initializing new instances */
- (id)initWithName:(NSString *)name;

/* Accessing the entity */
- (void)setEntity:(EOEntity*)entity;
- (EOEntity*)entity;
- (void)resetEntity;
- (BOOL)hasEntity;

/* Accessing the name */
- (BOOL)setName:(NSString *)name;
- (NSString *)name;
+ (BOOL)isValidName:(NSString *)name;

/* Accessing date information */
+ (NSString *)defaultCalendarFormat;
- (void)setCalendarFormat:(NSString *)format;
- (NSString *)calendarFormat;
- (void)setClientTimeZone:(NSTimeZone*)tz;
- (NSTimeZone*)clientTimeZone;
- (void)setServerTimeZone:(NSTimeZone*)tz;
- (NSTimeZone*)serverTimeZone;

/* Accessing external definitions */
- (void)setColumnName:(NSString *)columnName;
- (NSString *)columnName;
- (void)setExternalType:(NSString *)type;
- (NSString *)externalType;

/* Accessing value type information */
- (void)setValueClassName:(NSString *)name;
- (NSString *)valueClassName;
- (void)setValueType:(NSString *)type;
- (NSString *)valueType;

/* Checking type information */
- (BOOL)referencesProperty:property;

/* Accessing the user dictionary */
- (void)setUserDictionary:(NSDictionary*)dictionary;
- (NSDictionary*)userDictionary;

/* Obsolete. This method always return NO, because you should always release
   a property. */
- (BOOL)referencesProperty:property;

@end


@interface EOAttribute (EOAttributePrivate)

+ (EOAttribute*)attributeFromPropertyList:(id)propertyList;
- (void)replaceStringsWithObjects;
- (id)propertyList;

@end /* EOAttribute (EOAttributePrivate) */

@interface EOAttribute(ValuesConversion)

- (id)convertValue:(id)aValue
  toClass:(Class)aClass
  forType:(NSString *)aValueType;
- (id)convertValueToModel:(id)aValue;

@end /* EOAttribute (ValuesConversion) */

@interface NSString (EOAttributeTypeCheck)

- (BOOL)isNameOfARelationshipPath;

@end

@class NSMutableDictionary;

@interface EOAttribute(PropertyListCoding)

- (void)encodeIntoPropertyList:(NSMutableDictionary *)_plist;

@end

@interface EOAttribute(EOF2Additions)

- (void)beautifyName;

/* constraints */

- (void)setAllowsNull:(BOOL)_flag;
- (BOOL)allowsNull;
- (void)setWidth:(unsigned)_width;
- (unsigned)width;

- (NSException *)validateValue:(id *)_value;

@end

#endif /* __EOAttribute_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
