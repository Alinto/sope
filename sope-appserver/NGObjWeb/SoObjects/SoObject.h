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

#ifndef __SoObjects_SoObject_H__
#define __SoObjects_SoObject_H__

#import <Foundation/NSObject.h>

/*
  This mostly defines a new KVC interface on NSObject. The major difference
  to KVC is, that KVC calls method keys while SoObjectLookup returns an
  invocation object.
  It also introduces a new "class" hierachy used for "web" methods and classes
  that basically mirrors the Python object system (where ivars and methods are
  both "attributes").
*/

@class NSString, NSException, NSClassDescription, NSArray;
@class SoClass, SoClassSecurityInfo;

@interface NSObject(SoObject)

/* classes */

+ (SoClass *)soClass;
- (SoClass *)soClass;
+ (SoClassSecurityInfo *)soClassSecurityInfo;
- (NSClassDescription *)soClassDescription;

/* basic names */

- (BOOL)hasName:(NSString *)_key  inContext:(id)_ctx;
- (id)lookupName:(NSString *)_key inContext:(id)_ctx acquire:(BOOL)_flag;
- (NSException *)validateName:(NSString *)_key inContext:(id)_ctx;

/* invocation */

- (BOOL)isCallable;
- (id)clientObject;
- (id)callOnObject:(id)_client inContext:(id)_ctx;
- (NSString *)defaultMethodNameInContext:(id)_ctx;
- (id)lookupDefaultMethod;

- (BOOL)isFolderish;

/* binding (returns self by default [unbound objects]) */

- (id)bindToObject:(id)_object inContext:(id)_ctx;

/* security */

- (NSString *)ownerInContext:(id)_ctx;
- (id)authenticatorInContext:(id)_ctx;

/* containment */

- (id)container;
- (void)detachFromContainer;
- (NSString *)nameInContainer;
- (NSArray *)objectContainmentStack;
- (NSArray *)pathArrayToSoObject;
- (NSArray *)reversedPathArrayToSoObject;

- (NSString *)baseURLInContext:(id)_ctx;
- (NSString *)rootURLInContext:(id)_ctx;

@end

@interface NSObject(SoObjectLookup)

/* your object can override this methods to use specialized lookup */

- (id)traverseKey:(NSString *)_key inContext:(id)_ctx;

/* traversal implementation */

- (id)handleValidationError:(NSException *)_error 
  duringTraveralOfKey:(NSString *)_key
  inContext:(id)_ctx;
- (id)traverseKey:(NSString *)_name
  inContext:(id)_ctx
  error:(NSException **)_error
  acquire:(BOOL)_acquire;

- (id)traversePathArray:(NSArray *)traversalPath
  inContext:(id)_ctx
  error:(NSException **)_error
  acquire:(BOOL)_acquire;

/*
  The following is a convenience method, it creates a context for
  traversal and returns the error as the result - the right thing
  for all "custom" lookups.
*/
- (id)traversePath:(id)_tp acquire:(BOOL)_acquire;
- (id)traversePathArray:(NSArray *)_tp acquire:(BOOL)_acquire;

@end

#endif /* __SoObjects_SoObject_H__ */
