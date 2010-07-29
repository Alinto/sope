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

#ifndef __NGObjWeb_WOValueAssociation_H__
#define __NGObjWeb_WOValueAssociation_H__

#include <NGObjWeb/WOAssociation.h>

/*
  WOValueAssociation
  
  Represents a constant value.
*/

@interface WOValueAssociation : WOAssociation < NSCoding, NSCopying >
{
  id value;
  struct {
    unsigned int smallValue:16;
    unsigned int boolValue:2; // 0 - not cache, 1 - true, 2 - false
    unsigned int hasSmallValue:1;
    unsigned int hasNoSmallValue:1;
    unsigned int reserved:12;
  } cacheFlags;
}

+ (WOAssociation *)associationWithValue:(id)_value;
- (id)initWithValue:(id)_value;

/* value */

- (BOOL)isValueConstant; // returns YES
- (BOOL)isValueSettable; // returns NO

@end

@interface _WOBoolValueAssociation : WOAssociation < NSCopying >
{
  BOOL value;
}

+ (WOAssociation *)associationWithValue:(id)_value;
+ (WOAssociation *)associationWithBool:(BOOL)_value;

/* value */

- (BOOL)isValueConstant; // returns YES
- (BOOL)isValueSettable; // returns NO

@end

#endif /* __NGObjWeb_WOValueAssociation_H__ */
