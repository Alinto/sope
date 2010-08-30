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

#ifndef __SaxAttributes_H__
#define __SaxAttributes_H__

#import <Foundation/NSObject.h>

@class NSString, NSArray, NSMutableArray, NSDictionary;

/*
  new in SAX 2.0beta, replaces the SaxAttributeList
*/

@protocol SaxAttributes

/* lookup indices */

- (NSUInteger)indexOfRawName:(NSString *)_rawName;
- (NSUInteger)indexOfName:(NSString *)_localPart uri:(NSString *)_uri;

/* lookup data by index */

- (NSString *)nameAtIndex:(NSUInteger)_idx;
- (NSString *)rawNameAtIndex:(NSUInteger)_idx;
- (NSString *)typeAtIndex:(NSUInteger)_idx;
- (NSString *)uriAtIndex:(NSUInteger)_idx;
- (NSString *)valueAtIndex:(NSUInteger)_idx;

/* lookup data by name */

- (NSString *)typeForRawName:(NSString *)_rawName;
- (NSString *)typeForName:(NSString *)_localName uri:(NSString *)_uri;
- (NSString *)valueForRawName:(NSString *)_rawName;
- (NSString *)valueForName:(NSString *)_localName uri:(NSString *)_uri;

/* list size */

- (NSUInteger)count;

@end

/* simple attributes implementation, should be improved */

@interface SaxAttributes : NSObject < SaxAttributes, NSCopying >
{
@private
  NSMutableArray *names;
  NSMutableArray *uris;
  NSMutableArray *rawNames;
  NSMutableArray *types;
  NSMutableArray *values;
}

- (id)initWithAttributes:(id<SaxAttributes>)_attrs;
- (id)initWithDictionary:(NSDictionary *)_dict;

- (void)addAttribute:(NSString *)_localName uri:(NSString  *)_uri
  rawName:(NSString *)_rawName
  type:(NSString *)_type
  value:(NSString *)_value;

- (void)clear;

@end

#include <SaxObjC/SaxAttributeList.h>

@interface SaxAttributes(Compatibility)
- (id)initWithAttributeList:(id<SaxAttributeList>)_attrList;
@end

#endif /* __SaxAttributes_H__ */
