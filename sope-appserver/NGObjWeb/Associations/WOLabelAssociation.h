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

#ifndef __NGObjWeb_WOLabelAssociation_H__
#define __NGObjWeb_WOLabelAssociation_H__

#include <NGObjWeb/WOAssociation.h>

/*
  WOLabelAssociation

  String value syntax:
    "next"       - lookup key 'next' in table 'nil'   with default 'next'
    "table/next" - lookup key 'next' in table 'table' with default 'next'
  
  This association performs a string lookup in the components 
  WOResourceManager (or the app's manager if the component has none). It uses 
  the session and browser languages for the key lookup.
  
  Note that this also supports keypathes by prefixing the values with an
  "$", eg: "$currentDay" will first evaluate "currentDay" in the component
  and then pipe the result through the label processor.
  We consider that a bit hackish, but given that it is often required in
  practice, a pragmatic implementation.
*/

@interface WOLabelAssociation : WOAssociation < NSCopying >
{
  NSString *key;
  NSString *table;
  NSString *defaultValue;
  struct {
    int isKeyKeyPath:1;
    int isTableKeyPath:1;
    int isValueKeyPath:1;
    int reserved:29;
  } flags;
}

- (id)initWithKey:(NSString *)_key inTable:(NSString *)_table
  withDefaultValue:(NSString *)_default;

- (id)initWithString:(NSString *)_str;

/* value */

- (BOOL)isValueConstant; // returns NO
- (BOOL)isValueSettable; // returns NO

@end

#endif /* __NGObjWeb_WOLabelAssociation_H__ */
