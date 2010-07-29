/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#ifndef __NGExtensions_NGCString_H__
#define __NGExtensions_NGCString_H__

#import <Foundation/NSObject.h>

@class NSString;

@interface NGCString : NSObject < NSCopying, NSMutableCopying, NSCoding >
{
  char         *value;
  unsigned int len;
}

+ (id)stringWithCString:(const char *)_value length:(unsigned)_len;
+ (id)stringWithCString:(const char *)_value;
- (id)initWithCString:(const char *)_value length:(unsigned)_len;
- (id)initWithCString:(const char *)_value;

// unicode

- (unsigned int)length;
- (unichar)characterAtIndex:(unsigned int)_idx;

// comparing

- (BOOL)isEqual:(id)_object;
- (BOOL)isEqualToCString:(NGCString *)_cstr;
- (BOOL)isEqualToString:(NSString *)_str;
- (unsigned)hash;

// copying

- (id)copyWithZone:(NSZone *)_zone;
- (id)mutableCopyWithZone:(NSZone *)_zone;

// archiving

- (void)encodeWithCoder:(NSCoder *)_coder;
- (id)initWithCoder:(NSCoder *)_decoder;

// getting C strings

- (const char *)cString;
- (unsigned int)cStringLength;
- (void)getCString:(char *)_buffer;
- (void)getCString:(char *)_buffer maxLength:(unsigned int)_maxLength;
- (char)charAtIndex:(unsigned int)_idx;

// getting numeric values

- (double)doubleValue;
- (float)floatValue;
- (int)intValue;
- (NSString *)stringValue;

// description

- (NSString *)description;

@end

@interface NGMutableCString : NGCString
{
  unsigned int capacity;
}

// appending

- (void)appendString:(id)_str; // either NSString or NGCString
- (void)appendCString:(const char *)_cstr;
- (void)appendCString:(const char *)_cstr length:(unsigned)_len;

// removing

- (void)removeAllContents;

@end

#endif /* __NGExtensions_NGCString_H__ */
