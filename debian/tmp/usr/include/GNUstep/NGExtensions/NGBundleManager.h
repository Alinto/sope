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

#ifndef __NGExtensions_NGBundleManager_H__
#define __NGExtensions_NGBundleManager_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSMapTable.h>
#include <NGExtensions/NGExtensionsDecls.h>

@class NSString, NSArray, NSMutableArray, NSDictionary, NSMutableSet;
@class EOQualifier;

/*
  NGBundleManager

  NGBundleManager is a class similiar to a Java class loader. It searches
  for dynamically loadable bundles in a specified path set.

  The default bundle search path is:

    1. bundles contained in the main-bundle
    2. pathes specified by the 'NGBundlePath' user default
    3. pathes specified by the 'NGBundlePath' environment variable

  Bundles managed by NGBundleManager can specify load-requirements, this
  is done via the 'bundle-info.plist' file contained at the root of the
  bundle directory. The file is a property list file and can specify required
  and provided classes.
  
  Example bundle-info.plist:
    {
      bundleHandler = "MyBundleManager";
      
      provides = {
        classes = ( { name = MyClass; } );
      };
      requires = {
        bundleManagerVersion = 1;
        bundles = ( { name = Foundation; type = framework; } );
        classes = ( { name = NSObject; exact-version = 1; } );
      };
    }
*/

NGExtensions_EXPORT NSString *NGBundleWasLoadedNotificationName;

@class NGBundleManager;

typedef BOOL (*NGBundleResourceSelector)(NSString        *_resourceName,
                                         NSString        *_resourceType,
                                         NSString        *_path,
                                         NSDictionary    *_resourceConfig,
                                         NGBundleManager *_bundleManager,
                                         void            *_context);

@interface NGBundleManager : NSObject
{
@private
  NSMutableArray *bundleSearchPaths;
  NSMapTable     *pathToBundle;
  NSMapTable     *pathToBundleInfo;
  NSMapTable     *nameToBundle;

  /* bundles loaded by the manager (NSBundle->BundleManager) */
  NSMapTable     *loadedBundles;

  /* the following are maintained using NSBundleDidLoadNotification .. */
  NSMapTable     *classToBundle;
  NSMapTable     *classNameToBundle;
  NSMapTable     *categoryNameToBundle;

  // transient
  NSMutableSet *loadingBundles;
}

+ (id)defaultBundleManager;

/* accessors */

- (void)setBundleSearchPaths:(NSArray *)_paths;
- (NSArray *)bundleSearchPaths;

/* bundle access */

- (NSBundle *)bundleWithName:(NSString *)name type:(NSString *)_type;
- (NSBundle *)bundleWithName:(NSString *)name; // type=='bundle'
- (NSBundle *)bundleForClassNamed:(NSString *)aClassName;
- (NSBundle *)bundleForClass:(Class)aClass;
- (NSBundle *)bundleWithPath:(NSString *)path;

/* dependencies */

/* returns the names of the bundles required by the bundle */
- (NSArray *)bundlesRequiredByBundle:(NSBundle *)_bundle;

/* returns the names of the classes provided by the bundle */
- (NSArray *)classesProvidedByBundle:(NSBundle *)_bundle;

/* returns the names of the classes required by the bundle */
- (NSArray *)classesRequiredByBundle:(NSBundle *)_bundle;

/* loading */

- (id)loadBundle:(NSBundle *)_bundle;

/* bundle manager object */

- (id)principalObjectOfBundle:(NSBundle *)_bundle;

/* resources */

- (NSDictionary *)configForResource:(id)_resource ofType:(NSString *)_type
  providedByBundle:(NSBundle *)_bundle;

- (NSBundle *)bundleProvidingResource:(id)_resourceName
  ofType:(NSString *)_resourceType;

- (NSArray *)bundlesProvidingResource:(id)_resourceName
  ofType:(NSString *)_resourceType;

- (NSBundle *)bundleProvidingResourceOfType:(NSString *)_resourceType
  matchingQualifier:(EOQualifier *)_qual;
- (NSBundle *)bundlesProvidingResourcesOfType:(NSString *)_resourceType
  matchingQualifier:(EOQualifier *)_qual;

/*
  This returns an array of NSDictionaries describing the provided
  resources.
*/
- (NSArray *)providedResourcesOfType:(NSString *)_resourceType;

- (NSString *)pathForBundleProvidingResource:(id)_resourceName
  ofType:(NSString *)_type
  resourceSelector:(NGBundleResourceSelector)_selector
  context:(void *)_context;

@end /* NGBundleManager */

@interface NSBundle(NGLanguageResourceExtensions)

- (NSString *)pathForResource:(NSString *)_name ofType:(NSString *)_ext
  inDirectory:(NSString *)_directory
  languages:(NSArray *)_languages;

- (NSString *)pathForResource:(NSString *)_name ofType:(NSString *)_ext
  languages:(NSArray *)_languages;

@end /* NSBundle(NGLanguageResourceExtensions) */

@interface NSBundle(NGBundleManagerExtensions)

/* Returns the object managing the bundle (might be the principal class) */
- (id)principalObject;

- (NSArray *)providedResourcesOfType:(NSString *)_resourceType;

/* Returns the name of the bundle */
- (NSString *)bundleName;

/* Returns the type of the bundle */
- (NSString *)bundleType;

/* Returns the names of the classes provided by the bundle */
- (NSArray *)providedClasses;

/* Returns the names of the classes required by the bundle */
- (NSArray *)requiredClasses;

/* Returns the names of other bundles required for loading this bundle */
- (NSArray *)requiredBundles;

/* Return a NSDictionary with bundle-info configuration of the specified rsrc */
- (NSDictionary *)configForResource:(id)_resource ofType:(NSString *)_type;

@end /* NSBundle(NGBundleManagerExtensions) */

@interface NSObject(BundleManager)

- (id)initForBundle:(NSBundle *)_bundle bundleManager:(NGBundleManager *)_mng;

/*
  This method is invoked if the bundle was successfully loaded.
*/
- (void)bundleManager:(NGBundleManager *)_manager
  didLoadBundle:(NSBundle *)_bundle;

@end /* NSObject(BundleManager) */

@interface NGBundle : NSBundle
@end

#endif
