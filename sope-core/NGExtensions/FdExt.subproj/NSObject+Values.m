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

#include "NSObject+Values.h"
#include "common.h"

@implementation NSObject(NGValues)

- (BOOL)boolValue {
  // this returns always YES (the id != nil)
  return YES;
}

- (signed char)charValue {
  return (char)[self intValue];
}
- (unsigned char)unsignedCharValue {
  return (unsigned char)[self intValue];
}
- (signed short)shortValue {
  return (short)[self intValue];
}
- (unsigned short)unsignedShortValue {
  return (unsigned short)[self unsignedIntValue];
}

- (signed int)intValue {
  return [[self stringValue] intValue];
}
- (unsigned int)unsignedIntValue {
  return (unsigned int)[self intValue];
}

- (signed long)longValue {
  return (long)[self intValue];
}
- (unsigned long)unsignedLongValue {
  return (unsigned long)[self unsignedIntValue];
}

- (signed long long)longLongValue {
  return [[self stringValue] longLongValue];
}
- (unsigned long long)unsignedLongLongValue {
  return [[self stringValue] unsignedLongLongValue];
}

- (float)floatValue {
  return [[self stringValue] floatValue];
}
- (double)doubleValue {
  return [[self stringValue] doubleValue];
}

- (NSString *)stringValue {
  return [self description];
}

@end /* NSObject(Values) */

@implementation NSString(NGValues)

- (BOOL)boolValue {
  unsigned len;
  unichar  c1;

  if ((len = [self length]) == 0)
    return NO;

  switch (len) {
  case 1:
    c1 = [self characterAtIndex:0];
    if (c1 == '1') return YES;
    return NO;
    
  case 2:
    // NO, no (this is false in any case ;-)
    return NO;
    
  case 3:
    c1 = [self characterAtIndex:0];
    if (c1 != 'Y' && c1 != 'y')
      return NO;
    
    if ([@"YES" isEqualToString:self]) return YES;
    if ([@"yes" isEqualToString:self]) return YES;
    break;
    
  case 4:
    c1 = [self characterAtIndex:0];
    if (c1 != 'T' && c1 != 't')
      return NO;
    
    if ([@"TRUE" isEqualToString:self]) return YES;
    if ([@"true" isEqualToString:self]) return YES;
    break;
    
  case 5:
    // FALSE, false (this is false in any case ;-)
    return NO;
  }
  
  return NO;
}

- (NSString *)stringValue {
  return self;
}

- (unsigned char)unsignedCharValue {
  /*
    Note: this is a hack to support bool values with KVC operations. Problem 
          is, that bools in Objective-C have no own type code and the runtime 
          will use uchar to represent a bool.
	  
    Note: there are platforms where int as used as the BOOL base type?
  */
  register unsigned len;
  register unichar  c1;
  
  if ((len = [self length]) == 0)
    return 0;
  
  c1 = [self characterAtIndex:0];
  if (!isdigit(c1)) {
    switch (len) {
    case 2:
      // NO, no (this is false in any case ;-)
      break;
    case 3:
      c1 = [self characterAtIndex:0];
      if (c1 != 'Y' && c1 != 'y')
	return NO;
    
      if ([@"YES" isEqualToString:self]) return YES;
      if ([@"yes" isEqualToString:self]) return YES;
      break;
    case 4:
      c1 = [self characterAtIndex:0];
      if (c1 != 'T' && c1 != 't')
	return NO;
    
      if ([@"TRUE" isEqualToString:self]) return YES;
      if ([@"true" isEqualToString:self]) return YES;
      break;
    }
  }
  
  return [self intValue];
}

@end /* NSString(Values) */

@implementation NSMutableString(NGValues)

- (NSString *)stringValue {
  return [[self copy] autorelease];
}

@end /* NSMutableString(Values) */

void __link_NGExtensions_NSObjectValues(void) {
  /* required for static linking */
  __link_NGExtensions_NSObjectValues();
}
