/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#ifndef __SoObjects_SoProduct_H__
#define __SoObjects_SoProduct_H__

#import <Foundation/NSObject.h>

/*
  SoProduct
  
  SoProduct are packages of SOPE pages, methods, resources etc. SoProducts
  are usually represented by bundles and defined using the product.plist
  manifest resource inside of the bundle.
  
  The manifest.plist has four root keys:
    "classes"         - classes declared by the product
    "categories"      - categories declared by the product
    "requires"        - products this product depends upon
    "publicResources" - names of the resources exported to the web
*/

@class NSString, NSException, NSBundle, NSMutableDictionary, NSArray;
@class WOApplication, WOResourceManager;
@class SoProductResourceManager;

@interface SoProduct : NSObject
{
  NSBundle                 *bundle;
  NSMutableDictionary      *classes;
  NSMutableDictionary      *categories;
  NSArray                  *requiredProducts;
  NSArray                  *publicResources;
  SoProductResourceManager *resourceManager;
  
  struct {
    BOOL isLoaded:1;
    BOOL isCodeLoaded:1;
    int  reserved:30;
  } flags;
}

- (id)initWithBundle:(NSBundle *)_bundle;

/* accessors */

- (NSArray *)requiredProducts;
- (BOOL)isPublicResource:(NSString *)_key;
- (NSBundle *)bundle;
- (NSString *)productName;
- (BOOL)isMainProduct;

/* loading */

- (BOOL)load;
- (BOOL)reloadIfPossible;

/* resource manager */

- (WOResourceManager *)resourceManager;

@end

#endif /* __SoObjects_SoProduct_H__ */
