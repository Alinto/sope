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

#ifndef __SoObjects_SoClass_H__
#define __SoObjects_SoClass_H__

#import <Foundation/NSObject.h>

/*
  SoClass
  
  Abstract baseclass for SoObject classes. SoClasses collect common keys
  and security info for sets of objects.
  
  See SoObjCClass and SoExtClass for examples of concrete SoClasses.
*/

@class NSString, NSMutableDictionary, NSArray, NSClassDescription;
@class SoClassSecurityInfo;

@interface SoClass : NSObject
{
  SoClass             *soSuperClass;
  NSMutableDictionary *slots;
  SoClassSecurityInfo *security;
}

- (id)initWithSoSuperClass:(SoClass *)_soClass;

/* hierachy */

- (SoClass *)soSuperClass;

/* keys (traverse hierarchy) */

- (BOOL)hasKey:(NSString *)_key  inContext:(id)_ctx;
- (id)lookupKey:(NSString *)_key inContext:(id)_ctx;
- (NSArray *)allKeys;

/* slots (only works on the exact class) */

- (void)setValue:(id)_value forSlot:(NSString *)_key;
- (id)valueForSlot:(NSString *)_key;
- (NSArray *)slotNames;

/* security */

- (SoClassSecurityInfo *)soClassSecurityInfo;

/* factory */

- (id)instantiateObject;
- (NSClassDescription *)soClassDescription;
- (NSString *)className;

@end

#endif /* __SoObjects_SoClass_H__ */
