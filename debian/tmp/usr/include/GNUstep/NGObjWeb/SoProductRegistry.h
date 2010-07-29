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

#ifndef __SoObjects_SoProductRegistry_H__
#define __SoObjects_SoProductRegistry_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSBundle.h>

@class NSString, NSMutableDictionary, NSArray, NSBundle;
@class SoProduct;

@interface SoProductRegistry : NSObject
{
  NSMutableDictionary *products;
  NSMutableDictionary *bundlePathToFirstName;
}

+ (id)sharedProductRegistry;

/* operations */

- (void)scanForAvailableProducts;
- (void)scanForProductsInDirectory:(NSString *)_path;
- (void)registerProductAtPath:(NSString *)_path;

/* registering products */

- (BOOL)loadProductNamed:(NSString *)_name;
- (BOOL)loadAllProducts;

- (void)registerProductBundle:(NSBundle *)_bundle;

/* lookup products */

- (SoProduct *)productWithName:(NSString *)_name;
- (NSArray *)registeredProductNames;

/* bundle */

- (SoProduct *)productForBundle:(NSBundle *)_bundle;

@end

#endif /* __SoObjects_SoProductRegistry_H__ */
