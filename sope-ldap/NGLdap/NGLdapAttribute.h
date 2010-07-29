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

#ifndef __NGLdapAttribute_H__
#define __NGLdapAttribute_H__

#import <Foundation/NSObject.h>

@class NSString, NSArray, NSData, NSEnumerator;

@interface NGLdapAttribute : NSObject < NSCopying >
{
  NSString *name;
  NSArray  *values;
  BOOL     didChange;
}

- (id)initWithAttributeName:(NSString *)_name;
- (id)initWithAttributeName:(NSString *)_name values:(NSArray *)_values;

/* attribute name operations */

- (NSString *)attributeName;

+ (NSString *)baseNameOfAttributeName:(NSString *)_attrName;
- (NSString *)attributeBaseName;

+ (NSArray *)subtypesOfAttributeName:(NSString *)_attrName;
- (NSArray *)subtypes;
- (BOOL)hasSubtype:(NSString *)_subtype;
- (NSString *)langSubtype;

/* values */

- (unsigned)count;

- (void)addValue:(NSData *)_value;
- (NSArray *)allValues;
- (NSEnumerator *)valueEnumerator;

- (void)addStringValue:(NSString *)_value;
- (NSArray *)allStringValues;
- (NSEnumerator *)stringValueEnumerator;
- (NSString *)stringValueAtIndex:(unsigned)_idx;

@end

#endif /* __NGLdapAttribute_H__ */
