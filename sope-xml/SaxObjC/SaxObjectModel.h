/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __SaxObjC_SaxObjectModel_H__
#define __SaxObjC_SaxObjectModel_H__

#import <Foundation/NSObject.h>

@class NSDictionary, NSString, NSArray;
@class SaxTagModel;

@interface SaxObjectModel : NSObject
{
  NSDictionary *nsToModel;
}

+ (id)modelWithName:(NSString *)_name;
+ (id)modelWithContentsOfFile:(NSString *)_path;
+ (NSString *)libraryDriversSubDir;

- (id)initWithDictionary:(NSDictionary *)_dict;

/* queries */

- (SaxTagModel *)modelForTag:(NSString *)_localName namespace:(NSString *)_ns;

@end

@interface SaxNamespaceModel : NSObject
{
  NSDictionary *tagToModel;
}

/* queries */

- (SaxTagModel *)modelForTag:(NSString *)_localName;

@end

@interface SaxTagModel : NSObject
{
  NSString     *className;
  NSString     *key;
  NSString     *tagKey;       /* the key to store the tag name under */
  NSString     *namespaceKey; /* the key to store the namespace uri under */
  NSString     *parentKey;    /* the key to store the parent object under */
  NSString     *contentKey;   /* the key to store the cdata content under */
  NSArray      *toManyRelationshipKeys;
  NSDictionary *defaultValues;
  NSDictionary *tagToKey;
  NSDictionary *attrToKey;
}

/* accessors */

- (NSString *)className;
- (NSString *)key;
- (NSString *)tagKey;
- (NSString *)namespaceKey;
- (NSString *)parentKey;
- (NSString *)contentKey;
- (NSDictionary *)defaultValues;

- (NSString *)propertyKeyForChildTag:(NSString *)_tag;

- (BOOL)isToManyKey:(NSString *)_key;
- (NSArray *)toManyRelationshipKeys;

- (NSArray *)attributeKeys;
- (NSString *)propertyKeyForAttribute:(NSString *)_attr;

/* object operations */

- (void)addValue:(id)_val toPropertyWithKey:(NSString *)_key ofObject:(id)_obj;

@end

#endif /* __SaxObjC_SaxObjectModel_H__ */
