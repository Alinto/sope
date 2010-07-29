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

#ifndef __NGExtensions_NSObject_Values_H__
#define __NGExtensions_NSObject_Values_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>

@protocol NGBaseTypeValues

- (BOOL)boolValue;

- (signed char)charValue;
- (unsigned char)unsignedCharValue;
- (signed short)shortValue;
- (unsigned short)unsignedShortValue;
- (signed int)intValue;
- (unsigned int)unsignedIntValue;
- (signed long)longValue;
- (unsigned long)unsignedLongValue;
- (signed long long)longLongValue;
- (unsigned long long)unsignedLongLongValue;
- (float)floatValue;

@end

/*
  The default basetype methods perform their operation on the
  string-representation of the object.
  
  -boolValue returns YES per default. (id != nil)
*/
@interface NSObject(NGValues) < NGBaseTypeValues >

- (double)doubleValue;

- (NSString *)stringValue;

@end

@interface NSString(NGValues)

- (BOOL)boolValue;
- (NSString *)stringValue;

@end

#endif /* __NGExtensions_NSObject_Values_H__ */
