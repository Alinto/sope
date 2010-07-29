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

#ifndef __NGObjWeb_WOResourceManager_H__
#define __NGObjWeb_WOResourceManager_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSHashTable.h>

@class NSString, NSArray, NSData;
@class WORequest, WOComponent, WOElement, WOSession;

@interface WOResourceManager : NSObject < NSLocking >
{
@protected
  NSString   *base;
@private
  NSString   *w3resources;
  NSString   *resources;
  NSMapTable *componentDefinitions; // name.language => definition
  NSMapTable *stringTables;         // path => tableinfo
  NSMapTable *existingPathes;
  NSMapTable *keyedResources;
}

- (NSString *)pathForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages;

- (NSString *)urlForResourceNamed:(NSString *)_name
  inFramework:(NSString *)_frameworkName
  languages:(NSArray *)_languages
  request:(WORequest *)_request;

/* string tables */

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_default
  languages:(NSArray *)_languages;

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_defaultValue
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages;

@end

@interface WOResourceManager(KeyedData)

/* keyed storage */

- (void)setData:(NSData *)_data
  forKey:(NSString *)_key
  mimeType:(NSString *)_type
  session:(WOSession *)_session;
- (void)removeDataForKey:(NSString *)_key session:(WOSession *)_session;
- (void)flushDataCache;

@end

@interface WOResourceManager(PrivateMethods)

- (id)initWithPath:(NSString *)_path;
+ (void)setResourcePrefix:(NSString *)_prefix;

- (WOElement *)templateWithName:(NSString *)_name languages:(NSArray *)_langs;
- (id)pageWithName:(NSString *)_name languages:(NSArray *)_langs;

- (NSString *)pathToComponentNamed:(NSString *)_name
  inFramework:(NSString *)_framework
  languages:(NSArray *)_langs;

- (void)setCachingEnabled:(BOOL)_flag;
- (BOOL)isCachingEnabled;

/* string tables */

- (id)stringTableWithName:(NSString *)_tableName
  inFramework:(NSString *)_framework
  languages:(NSArray *)_languages;

@end

@interface WOResourceManager(DeprecatedMethods)

- (NSString *)pathForResourceNamed:(NSString *)_name;
- (NSString *)pathForResourceNamed:(NSString *)_name ofType:(NSString *)_type;
- (NSString *)urlForResourceNamed:(NSString *)_name;
- (NSString *)urlForResourceNamed:(NSString *)_name ofType:(NSString *)_type;

@end

#endif /* __NGObjWeb_WOResourceManager_H__ */
