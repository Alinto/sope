/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

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

#include "NGJavaScriptContext.h"
#import <Foundation/Foundation.h>
#include "../common.h"

@implementation NSNumber(JS)

- (BOOL)_jsGetValue:(jsval *)_value inJSContext:(NGJavaScriptContext *)_ctx {
  static NSNumber *boolYes = nil;
  static NSNumber *boolNo  = nil;
  const char *type;

  if (boolYes == nil) boolYes = [[NSNumber numberWithBool:YES] retain];
  if (boolNo  == nil) boolNo  = [[NSNumber numberWithBool:NO]  retain];
  
  if (self == boolYes) {
    *_value = BOOLEAN_TO_JSVAL(YES);
    return YES;
  }
  if (self == boolNo) {
    *_value = BOOLEAN_TO_JSVAL(NO);
    return YES;
  }
#if LIB_FOUNDATION_LIBRARY
  {
    static Class BoolClass = Nil;
    if (BoolClass == Nil) BoolClass = NSClassFromString(@"NSBoolNumber");
    if (*(Class*)self == BoolClass) {
      /* it's a bool number */

      *_value = BOOLEAN_TO_JSVAL([self boolValue]);
      return YES;
    }
  }
#elif APPLE_Foundation_LIBRARY || NeXT_Foundation_LIBRARY
  /* check that, at least on Panther bool NSNumbers are singletons */
#else
#  warning what about BOOLs on this platform ? (hopefully it uses singletons ...)
#endif

  type = [self objCType];
  //NSLog(@"getval (%s) for number %@", type, self);
  switch (*type) {
    case _C_DBL:
    case _C_FLT:
      return JS_NewDoubleValue([_ctx handle], [self doubleValue], _value);

    case _C_UINT:
      return JS_NewDoubleValue([_ctx handle], [self doubleValue], _value);
      
    default:
      if (INT_FITS_IN_JSVAL([self intValue]))
        *_value = INT_TO_JSVAL([self intValue]);
      else
        return JS_NewDoubleValue([_ctx handle], [self doubleValue], _value);
      break;
  }
  return YES;
}

@end /* NSNumber(JS) */
