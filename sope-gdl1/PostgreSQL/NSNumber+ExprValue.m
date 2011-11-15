/* 
   NSNumber+ExprValue.m

   Copyright (C) 2007 Helge Hess
   
   Author: Helge Hess (helge@opengroupware.org)

   This file is part of the PostgreSQL Adaptor Library

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

#if GNUSTEP_BASE_LIBRARY

#include "common.h"

@implementation NSNumber(ExprValue)

- (NSString *)expressionValueForContext:(id)_context {
  /*
    on gstep-base -stringValue of bool's return YES or NO, which seems to
    be different on Cocoa and liBFoundation.
  */
  static Class BoolClass = Nil;
      
  if (BoolClass == Nil) BoolClass = NSClassFromString(@"NSBoolNumber");
  
  if ([self isKindOfClass:BoolClass])
    return [self boolValue] ? @"1" : @"0";
  
  return [self stringValue];
}

@end /* NSNumber(ExprValue) */

#endif /* GNUSTEP_BASE_LIBRARY */
