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

#ifndef __SaxAttributeList_H__
#define __SaxAttributeList_H__

#import <Foundation/NSObject.h>

@class NSString, NSMutableArray;

/* deprecated in SAX 2.0beta */

@protocol SaxAttributeList

- (NSString *)nameAtIndex:(NSUInteger)_idx;
- (NSString *)typeAtIndex:(NSUInteger)_idx;
- (NSString *)valueAtIndex:(NSUInteger)_idx;
- (NSString *)typeForName:(NSString *)_name;
- (NSString *)valueForName:(NSString *)_name;

- (NSUInteger)count;

@end

@interface SaxAttributeList : NSObject < SaxAttributeList, NSCopying >
{
@private
  NSMutableArray *names;
  NSMutableArray *types;
  NSMutableArray *values;
}

- (id)init;
- (id)initWithAttributeList:(id<SaxAttributeList>)_attrList;

- (void)setAttributeList:(id<SaxAttributeList>)_attrList;
- (void)clear;

- (void)addAttribute:(NSString *)_name
  type:(NSString *)_type
  value:(NSString *)_value;
- (void)removeAttribute:(NSString *)_attr;

@end

#include <SaxObjC/SaxAttributes.h>

@interface SaxAttributeList(Compatibility)
- (id)initWithAttributes:(id<SaxAttributes>)_attrs;
@end

#endif /* __SaxAttributeList_H__ */
