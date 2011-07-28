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

#include "NSObject+WO.h"
#include "common.h"
#include <string.h>

#if APPLE_RUNTIME || NeXT_RUNTIME
#  include <objc/objc-class.h>
#endif

#if NeXT_Foundation_LIBRARY || APPLE_FOUNDATION_LIBRARY || \
    COCOA_Foundation_LIBRARY

#ifndef __APPLE__
@implementation NSObject(FoundationCompability)

- (id)copyWithZone:(NSZone *)_z {
  return [self retain];
}

@end /* NSObject(FoundationCompability) */
#endif

#endif /* NeXT_Foundation_LIBRARY */

#if GNUSTEP_BASE_LIBRARY
extern BOOL __objc_responds_to(id, SEL);
#endif

@implementation NSObject(NGObjWebKVC)

- (BOOL)kvcIsPreferredInKeyPath {
  return NO;
}

@end /* NSObject(NGObjWebKVC) */

@implementation NSDictionary(NGObjWebKVC)

- (BOOL)kvcIsPreferredInKeyPath {
  return YES;
}

@end /* NSDictionary(NGObjWebKVC) */

@implementation NSObject(Faults)
#ifndef __APPLE__
+ (BOOL)isFault {
  return NO;
}
- (BOOL)isFault {
  return NO;
}
#endif
@end /* NSObject(Faults) */

// ******************** KVC methods ********************

static inline void _getSetSelName(register unsigned char *buf,
                                  register const unsigned char *_key,
                                  register unsigned _len) {
  buf[0] = 's';
  buf[1] = 'e';
  buf[2] = 't';

  switch (_len) {
    case 0: break;

    case 1:
      buf[3] = _key[0];
      break;
    case 2:
      buf[3] = _key[0];
      buf[4] = _key[1];
      break;
    case 3:
      buf[3] = _key[0];
      buf[4] = _key[1];
      buf[5] = _key[2];
      break;
    case 4:
      buf[3] = _key[0];
      buf[4] = _key[1];
      buf[5] = _key[2];
      buf[6] = _key[3];
      break;
    case 5:
      buf[3] = _key[0];
      buf[4] = _key[1];
      buf[5] = _key[2];
      buf[6] = _key[3];
      buf[7] = _key[4];
      break;
    case 6:
      buf[3] = _key[0];
      buf[4] = _key[1];
      buf[5] = _key[2];
      buf[6] = _key[3];
      buf[7] = _key[4];
      buf[8] = _key[5];
      break;
      
    default:
      memcpy(&(buf[3]), _key, _len);
      break;
  }
  buf[3] = toupper(buf[3]);
  buf[_len + 3] = ':';
  buf[_len + 4] = '\0';
}
static inline SEL _getSetSel(register const unsigned char *_key,
                             register unsigned _len) {
  char buf[259];
  _getSetSelName((unsigned char *)buf, _key, _len);
#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
  return sel_getUid(buf);
#else
  return sel_get_uid(buf);
#endif
}

typedef union {
  IMP            method; // real method or takeValue:ForKey:
  char           (*cmethod) (id, SEL);
  unsigned char  (*ucmethod)(id, SEL);
  int            (*imethod) (id, SEL);
  unsigned int   (*uimethod)(id, SEL);
  short          (*smethod) (id, SEL);
  unsigned short (*usmethod)(id, SEL);
  const char *   (*strmethod)(id, SEL);
  float          (*fmethod)(id, SEL);
  double         (*dmethod)(id, SEL);
} WOGetMethodType;

typedef union {
  IMP  method; // real method or takeValue:ForKey:
  void (*omethod)  (id, SEL, id);
  void (*cmethod)  (id, SEL, char);
  void (*ucmethod) (id, SEL, unsigned char);
  void (*imethod)  (id, SEL, int);
  void (*uimethod) (id, SEL, unsigned int);
  void (*smethod)  (id, SEL, short);
  void (*usmethod) (id, SEL, unsigned short);
  void (*strmethod)(id, SEL, const char *);
  void (*fmethod)  (id, SEL, float);
  void (*dmethod)  (id, SEL, double);
} WOSetMethodType;

BOOL WOSetKVCValueUsingMethod(id object, NSString *_key, id _value) {
  NSMethodSignature *sig = nil;
  WOSetMethodType   sm;
  const char        *argType;
  SEL               setSel;
  unsigned          keyLen;
  char              *buf;
  
  if (object == nil) return NO;
  if (_key   == nil) return NO;

  keyLen = [_key cStringLength];
  
  buf = malloc(keyLen + 2);
  [_key getCString:buf];
  setSel = _getSetSel((unsigned char *)buf, keyLen);
  free(buf); buf = NULL;
  
  if (setSel == NULL) // no such selector
    return NO;

  sig = [object methodSignatureForSelector:setSel];
  if (sig == nil) // no signature
    return NO;
  
  sm.method = [object methodForSelector:setSel];
  if (sm.method) {
    argType = [sig getArgumentTypeAtIndex:2];
    
    switch (*argType) {
      case _C_CLASS:
      case _C_ID:
        sm.omethod(object, setSel, _value);
        break;

      case _C_CHR:
        sm.cmethod(object, setSel, [(NSValue *)_value charValue]);
        break;
      case _C_UCHR:
        sm.ucmethod(object, setSel, [_value unsignedCharValue]);
        break;

      case _C_SHT:
        sm.smethod(object, setSel, [_value shortValue]);
        break;
      case _C_USHT:
        sm.usmethod(object, setSel, [_value unsignedShortValue]);
        break;
            
      case _C_INT:
        sm.imethod(object, setSel, [_value intValue]);
        break;
      case _C_UINT:
        sm.uimethod(object, setSel, [_value unsignedIntValue]);
        break;
        
      case _C_FLT:
        sm.fmethod(object, setSel, [_value floatValue]);
        break;
        
      case _C_DBL:
        sm.dmethod(object, setSel, [_value doubleValue]);
        break;

      case _C_CHARPTR: {
        char *s;
        s = NGMallocAtomic([_value cStringLength] + 1);
        [_value getCString:s];
        sm.strmethod(object, setSel, s);
        NGFree(s); s = NULL;
        break;
      }
      
      default:
        NSLog(@"%s: cannot set type '%c' yet (key=%@, method=%@) ..",
              __PRETTY_FUNCTION__,
              *argType, _key, NSStringFromSelector(setSel));
        [NSException raise:@"WORuntimeException"
                     format:@"cannot set type '%c' yet (key=%@, method=%@)",
                       *argType, _key, NSStringFromSelector(setSel)];
        return NO;
    }
    return YES;
  }
  else // did not find method
    return NO;
}

IMP WOGetKVCGetMethod(id object, NSString *_key) {
  register SEL getSel;
  
  if (object == nil) return NULL;
  if (_key   == nil) return NULL;

#if GNU_RUNTIME && !(defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911))
  {
    unsigned keyLen;
    char     *buf;
    
    keyLen = [_key cStringLength];
    buf = malloc(keyLen + 1);
    [_key getCString:buf]; buf[keyLen] = '\0';
    getSel = sel_get_uid(buf);
    free(buf);

    if (getSel == NULL) // no such selector
      return NULL;
#if GNUSTEP_BASE_LIBRARY
    if (!__objc_responds_to(object, getSel))
      return NULL;
#endif

    return [object methodForSelector:getSel];
  }
#else
  if ((getSel = NSSelectorFromString(_key)) == NULL) // no such selector
    return NULL;

  if ([object respondsToSelector:getSel])
    return [object methodForSelector:getSel];

  return NULL;
#endif
}

id WOGetKVCValueUsingMethod(id object, NSString *_key) {
  NSMethodSignature *sig = nil;
  WOGetMethodType   gm;
  const char        *retType;
  SEL               getSel;
  unsigned          keyLen;
  
  if (object == nil) return nil;
  if (_key   == nil) return nil;
  
  // TODO: this su***
  // TODO: add support for ivars
  keyLen = [_key cStringLength];

  {
    char *buf;
    buf = malloc(keyLen + 1);
    [_key getCString:buf];
#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
    getSel = sel_getUid(buf);
#else
    getSel = sel_get_uid(buf);
#endif
    if (getSel == NULL) // no such selector
      return nil;
    free(buf); buf = NULL;
  }
#if GNUSTEP_BASE_LIBRARY
  if (!__objc_responds_to(object, getSel))
    return nil;
#endif
  
  gm.method = [object methodForSelector:getSel];
  if (gm.method == NULL) // no such method
    return nil;
  
  sig = [object methodSignatureForSelector:getSel];
  if (sig == nil) // no signature
    return nil;

  {
    static Class NSNumberClass = Nil;
    id value = nil;

    if (NSNumberClass == Nil)
      NSNumberClass = [NSNumber class];
    
    retType = [sig methodReturnType];
    
    switch (*retType) {
      case _C_CLASS:
      case _C_ID:
        value = gm.method(object, getSel);
        value = AUTORELEASE(RETAIN(value));
        break;

      case _C_CHR:
        value = [NSNumberClass numberWithChar:gm.cmethod(object, getSel)];
        break;
      case _C_UCHR:
        value = [NSNumberClass numberWithUnsignedChar:
                                 gm.ucmethod(object, getSel)];
        break;

      case _C_SHT:
        value = [NSNumberClass numberWithShort:gm.smethod(object, getSel)];
        break;
      case _C_USHT:
        value = [NSNumberClass numberWithUnsignedShort:
                                 gm.usmethod(object, getSel)];
        break;
            
      case _C_INT:
        value = [NSNumberClass numberWithInt:gm.imethod(object, getSel)];
        break;
      case _C_UINT:
        value = [NSNumberClass numberWithUnsignedInt:
                                 gm.uimethod(object, getSel)];
        break;

      case _C_FLT:
        value = [NSNumberClass numberWithFloat:gm.fmethod(object, getSel)];
        break;
      case _C_DBL:
        value = [NSNumberClass numberWithDouble:gm.dmethod(object, getSel)];
        break;
        
      case _C_CHARPTR: {
        const char *cstr = gm.strmethod(object, getSel);
        value = cstr ? [NSString stringWithCString:cstr] : nil;
        break;
      }
            
      default:
        NSLog(@"%s: cannot get type '%c' yet (key=%@, method=%@) ..",
              __PRETTY_FUNCTION__,
              *retType, _key, NSStringFromSelector(getSel));
        [NSException raise:@"WORuntimeException"
                     format:@"cannot get type '%c' yet (key=%@, method=%@)",
                       *retType, _key, NSStringFromSelector(getSel)];
        return nil;
    }
    return value;
  }
}
