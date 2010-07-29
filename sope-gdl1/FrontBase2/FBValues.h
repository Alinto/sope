/* 
   FBValues.h

   Copyright (C) 1999 MDlink online service center GmbH and Helge Hess

   Author: Helge Hess (helge.hess@mdlink.de)

   This file is part of the FrontBase Adaptor Library

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/
// $Id: FBValues.h 1 2004-08-20 10:38:46Z znek $

#ifndef ___FB_Values_H___
#define ___FB_Values_H___

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSData.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSValue.h>
#import <GDLAccess/EONull.h>
#import "FBException.h"
#import "FBHeaders.h"

@class EOAttribute;
@class FrontBaseChannel;

@protocol FBValues

+ (id)valueFromBytes:(const char *)_bytes
  length:(unsigned)_length
  frontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute
  adaptorChannel:(FrontBaseChannel *)_channel;

- (NSData *)dataValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute;

- (NSString *)stringValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute;

@end

@interface NSString(FBValues) < FBValues >
@end

@interface NSNumber(FBValues) < FBValues >
@end

@interface NSData(FBValues) < FBValues >
@end

@interface NSCalendarDate(FBValues) < FBValues >
@end

@interface EONull(FBValues)

- (NSData *)dataValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute;

- (NSString *)stringValueForFrontBaseType:(int)_type
  attribute:(EOAttribute *)_attribute;

@end

#endif
