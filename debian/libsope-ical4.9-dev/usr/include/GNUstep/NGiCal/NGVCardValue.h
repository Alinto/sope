/*
  Copyright (C) 2005 Helge Hess

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

#ifndef __NGiCal_NGVCardValue_H__
#define __NGiCal_NGVCardValue_H__

#import <Foundation/NSObject.h>

/*
  NGVCardValue
  
  An abstract superclass to represents a value in a vCard object.
  
  Note: all NGVCardValue's are treated as immutable objects.
  
  - types
  - arguments
*/

@class NSString, NSMutableString, NSArray, NSDictionary;

@interface NGVCardValue : NSObject < NSCopying, NSCoding >
{
  NSString     *group;
  NSArray      *types;
  NSDictionary *arguments;
}

- (id)initWithGroup:(NSString *)_group types:(NSArray *)_types
  arguments:(NSDictionary *)_a;

/* accessors */

- (NSString *)group;
- (NSArray *)types;
- (NSDictionary *)arguments;
- (BOOL)isPreferred;

/* values */

- (NSString *)stringValue;
- (NSString *)xmlString;
- (NSString *)vCardString;
- (id)propertyList;

/* misc support methods */

- (void)appendXMLTag:(NSString *)_tag value:(NSString *)_val
  to:(NSMutableString *)_ms;
- (void)appendVCardValue:(NSString *)_val to:(NSMutableString *)_ms;

/* description */

- (void)appendAttributesToDescription:(NSMutableString *)_ms;

@end

#endif /* __NGiCal_NGVCardValue_H__ */
