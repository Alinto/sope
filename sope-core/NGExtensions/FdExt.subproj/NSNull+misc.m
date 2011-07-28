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

#include "NSNull+misc.h"
#include "common.h"

#if LIB_FOUNDATION_LIBRARY || GNUSTEP_BASE_LIBRARY
#if __GNU_LIBOBJC__ == 20100911
#  include <objc/runtime.h>
#else
#  include <objc/objc-api.h>
#  include <objc/objc.h>
#  include <objc/encoding.h>
#endif
#  ifndef GNUSTEP
#    import <extensions/objc-runtime.h>
#  endif
#else
#  import <objc/objc-class.h>
#endif

@implementation NSNull(misc)

static int _doAbort = -1;
static inline BOOL doAbort(void) {
  if (_doAbort == -1) {
    _doAbort = [[NSUserDefaults standardUserDefaults]
		                boolForKey:@"NSNullAbortOnMessage"] ? 1 : 0;
  }
  return _doAbort ? YES : NO;
}

- (BOOL)isNotNull {
  return NO;
}
- (BOOL)isNotEmpty {
  return NO;
}
- (BOOL)isNull {
#if DEBUG
  NSLog(@"WARNING(%s): called deprecated -isNull on NSNull (use -isNotNull) !",
        __PRETTY_FUNCTION__);
  if (doAbort()) abort();
#endif
  return YES;
}

- (NSString *)stringValue {
#if DEBUG && 0
  NSLog(@"WARNING(%s): "
        @"NSNull -stringValue returns empty string.",
        __PRETTY_FUNCTION__);
  if (doAbort()) abort();
#endif
  return @"";
}
- (double)doubleValue {
#if DEBUG && 0
  NSLog(@"WARNING(%s): "
        @"NSNull -doubleValue returns 0.0.",
        __PRETTY_FUNCTION__);
  if (doAbort()) abort();
#endif
  return 0.0;
}

- (unsigned int)length {
#if DEBUG
  NSLog(@"WARNING(%s): "
        @"called NSNull -length (returns 0) !!!",
        __PRETTY_FUNCTION__);
  if (doAbort()) abort();
#endif
  return 0;
}
- (unsigned int)count {
#if DEBUG
  NSLog(@"WARNING(%s): "
        @"called NSNull -count (returns 0) !!!",
        __PRETTY_FUNCTION__);
  if (doAbort()) abort();
#endif
  return 0;
}

- (BOOL)isEqualToString:(NSString *)_s {
  /* Note: I think we can keep this as a regular method */
  return _s == (id)self || _s == nil ? YES : NO;
}
- (BOOL)hasPrefix:(NSString *)_s {
  /* Note: I think we can keep this as a regular method */
  return _s == (id)self || _s == nil ? YES : NO;
}
- (BOOL)hasSuffix:(NSString *)_s {
  /* Note: I think we can keep this as a regular method */
  return _s == (id)self || _s == nil ? YES : NO;
}

- (unichar)characterAtIndex:(unsigned int)_idx {
#if DEBUG
  NSLog(@"WARNING(%s): "
        @"called NSNull -characterAtIndex:%d - returning 0!",
        __PRETTY_FUNCTION__, _idx);
  if (doAbort()) abort();
#endif
  return 0;
}

/* key-value coding */

- (void)takeValue:(id)_value forKey:(NSString *)_key {
  /* do nothing */
}
- (id)valueForKey:(NSString *)_key {
  if ([_key isEqualToString:@"isNotNull"]) {
    static NSNumber *noNum  = nil;
    
    if (noNum == nil)
      noNum = [NSNumber numberWithBool:NO];
    
    return noNum;
  }
  if ([_key isEqualToString:@"isNull"]) {
    static NSNumber *yesNum = nil;
    
    if (yesNum == nil)
      yesNum = [NSNumber numberWithBool:YES];
    return yesNum;
  }
  
  /* do nothing */
  return nil;
}

/* forwarding ... */

#if !GNU_RUNTIME
- (BOOL)respondsToSelector:(SEL)_sel {
  /* fake that we have a selector */
  return YES;
}

- (NSString *)descriptionWithLocale:(id)_locale indent:(int)_indent {
  return @"<null>";
}
- (NSString *)descriptionWithLocale:(id)_locale {
  return @"<null>";
}

#endif

- (void)forwardInvocation:(NSInvocation *)_invocation {
  NSMethodSignature *sig;
  
  NSLog(@"ERROR(%s): called selector %@ on NSNull !",
        __PRETTY_FUNCTION__,
        NSStringFromSelector([_invocation selector]));
  if (doAbort()) abort();
  
  if ((sig = [_invocation methodSignature])) {
    const char *ret;
    
    if ((ret = [sig methodReturnType])) {
      switch (*ret) {
        case _C_INT: {
          int v = 0;
          [_invocation setReturnValue:&v];
          break;
        }
        case _C_UINT: {
          unsigned int v = 0;
          [_invocation setReturnValue:&v];
          break;
        }
          
        case _C_ID:
        case _C_CLASS: {
          id v = nil;
          [_invocation setReturnValue:&v];
          break;
        }
        
        default:
          NSLog(@"  didn't set return value for type '%s'", ret);
          break;
      }
    }
    else
      NSLog(@"  no method return type in signature %@", sig);
  }
  else
    NSLog(@"  no method signature in invocation %@", _invocation);
}

@end /* NSNull(misc) */


@implementation NSObject(NSNullMisc)

- (BOOL)isNotNull {
  return YES;
}
- (BOOL)isNotEmpty {
  return [self isNotNull];
}

- (BOOL)isNull {
#if DEBUG
  NSLog(@"%s: WARNING, called -isNull on NSObject (use -isNotNull) !",
        __PRETTY_FUNCTION__);
#endif
  return NO;
}

@end /* NSObject(NSNullMisc) */


@implementation NSString(NSNullMisc)

- (BOOL)isNotEmpty {
  unsigned i, len;
  
  if ((len = [self length]) == 0)
    return NO;
  
  // TODO: just check the first char for performance ...
  // But: a single space should be treated as emtpy, since this is very common
  //      in SQL (Sybase in special)
  for (i = 0; i < len; i++) {
    if (!isspace([self characterAtIndex:i]))
      return YES;
  }
  
  return NO;
}

@end /* NSString(NSNullMisc) */

@implementation NSArray(NSNullMisc)

- (BOOL)isNotEmpty {
  return [self count] == 0 ? NO : YES;
}

@end /* NSArray(NSNullMisc) */

@implementation NSSet(NSNullMisc)

- (BOOL)isNotEmpty {
  return [self count] == 0 ? NO : YES;
}

@end /* NSSet(NSNullMisc) */

@implementation NSDictionary(NSNullMisc)

- (BOOL)isNotEmpty {
  return [self count] == 0 ? NO : YES;
}

@end /* NSDictionary(NSNullMisc) */

@implementation NSData(NSNullMisc)

- (BOOL)isNotEmpty {
  return [self length] == 0 ? NO : YES;
}

@end /* NSData(NSNullMisc) */
