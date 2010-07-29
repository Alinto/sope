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

#ifndef __NGObjWeb_WOAssociation_H__
#define __NGObjWeb_WOAssociation_H__

#import <Foundation/NSObject.h>

@class WOComponent, WOContext;

@interface WOAssociation : NSObject /* abstract/cluster */
{
}

+ (WOAssociation *)associationWithKeyPath:(NSString *)_keyPath;
+ (WOAssociation *)associationWithValue:(id)_value;

/* value */

- (void)setValue:(id)_value inContext:(WOContext *)_ctx;
- (id)valueInContext:(WOContext *)_ctx;
- (void)setValue:(id)_value inComponent:(WOComponent *)_component;
- (id)valueInComponent:(WOComponent *)_component;

- (BOOL)isValueConstant;
- (BOOL)isValueSettable;

/* deprecated methods */

- (void)setValue:(id)_value; // deprecated in WO4
- (id)value;                 // deprecated in WO4

@end

@interface WOAssociation(SpecialsValues)

- (void)setUnsignedCharValue:(unsigned char)_v inComponent:(WOComponent *)_c;
- (void)setCharValue:(signed char)_value inComponent:(WOComponent *)_component;
- (void)setUnsignedIntValue:(unsigned int)_v inComponent:(WOComponent *)_comp;
- (void)setIntValue:(signed int)_value inComponent:(WOComponent *)_component;
- (void)setBoolValue:(BOOL)_value inComponent:(WOComponent *)_component;

- (unsigned char)unsignedCharValueInComponent:(WOComponent *)_component;
- (signed char)charValueInComponent:(WOComponent *)_component;
- (unsigned int)unsignedIntValueInComponent:(WOComponent *)_component;
- (signed int)intValueInComponent:(WOComponent *)_component;
- (BOOL)boolValueInComponent:(WOComponent *)_component;

- (void)setStringValue:(NSString *)_v inComponent:(WOComponent *)_component;
- (NSString *)stringValueInComponent:(WOComponent *)_component;

/* special context values */

- (void)setUnsignedCharValue:(unsigned char)_v inContext:(WOContext *)_c;
- (void)setCharValue:(signed char)_value       inContext:(WOContext *)_ctx;
- (void)setUnsignedIntValue:(unsigned int)_v   inContext:(WOContext *)_c;
- (void)setIntValue:(signed int)_value         inContext:(WOContext *)_ctx;
- (void)setBoolValue:(BOOL)_value              inContext:(WOContext *)_ctx;

- (unsigned char)unsignedCharValueInContext:(WOContext *)_ctx;
- (signed char)charValueInContext:(WOContext *)_ctx;
- (unsigned int)unsignedIntValueInContext:(WOContext *)_ctx;
- (signed int)intValueInContext:(WOContext *)_ctx;
- (BOOL)boolValueInContext:(WOContext *)_ctx;

- (void)setStringValue:(NSString *)_v inContext:(WOContext *)_ctx;
- (NSString *)stringValueInContext:(WOContext *)_ctx;

@end

#endif /* __NGObjWeb_WOAssociation_H__ */
