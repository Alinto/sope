/* 
   NSInvocation.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSInvocation_h__
#define __NSInvocation_h__

#ifndef GNUSTEP
#  if !NEXT_RUNTIME
#    define GNU_RUNTIME 1
#  endif
#endif

#include <Foundation/NSMethodSignature.h>

@interface NSInvocation : NSObject
{
    SEL               selector;
    id                target;
    NSMethodSignature *signature;
    BOOL              argumentsRetained;
    BOOL              isValid;
}

/* Creating Invocations */

+ (NSInvocation *)invocationWithMethodSignature:(NSMethodSignature *)sig;

/* Managing Invocation Arguments */

- (BOOL)argumentsRetained;
- (void)retainArguments;
- (NSMethodSignature *)methodSignature;

- (void)setArgument:(void *)argumentLocation atIndex:(int)index;
- (void)getArgument:(void *)argumentLocation atIndex:(int)index;

- (void)setReturnValue:(void *)retLoc;
- (void)getReturnValue:(void *)retLoc;

- (void)setSelector:(SEL)selector;
- (SEL)selector;

- (void)setTarget:(id)target;
- (id)target;

/* Dispatching an Invocation */

- (void)invoke;
- (void)invokeWithTarget:(id)target;

@end


@interface NSInvocation (Extensions)
- (void)setArgumentFrame:(void*)frame;
- (retval_t)returnFrame;
- (void*)returnValue;
@end /* NSInvocation (Extensions) */

/* typing stuff (added in MacOSX) */

#if GNU_RUNTIME
#  include <objc/objc-api.h>
#  ifndef _C_LNG_LNG
#    define _C_LNG_LNG  'q' /* old versions of gcc do not define this */
#    define _C_ULNG_LNG 'Q'
#  endif
#endif

enum _NSObjCValueType {
#if GNU_RUNTIME
    NSObjCNoType       = 0,
    NSObjCVoidType     = _C_VOID,
    NSObjCCharType     = _C_CHR,
    NSObjCShortType    = _C_SHT,
    NSObjCLongType     = _C_LNG,
    NSObjCLonglongType = _C_LNG_LNG,
    NSObjCFloatType    = _C_FLT,
    NSObjCDoubleType   = _C_DBL,
    NSObjCSelectorType = _C_SEL,
    NSObjCObjectType   = _C_ID,
    NSObjCStructType   = _C_STRUCT_B,
    NSObjCPointerType  = _C_PTR,
    NSObjCStringType   = _C_CHARPTR,
    NSObjCArrayType    = _C_ARY_B,
    NSObjCUnionType    = _C_UNION_B,
    NSObjCBitfield     = _C_BFLD
#elif NEXT_RUNTIME
    NSObjCNoType       = 0,
    NSObjCVoidType     = 'v',
    NSObjCCharType     = 'c',
    NSObjCShortType    = 's',
    NSObjCLongType     = 'l',
    NSObjCLonglongType = 'q',
    NSObjCFloatType    = 'f',
    NSObjCDoubleType   = 'd',
    NSObjCSelectorType = ':',
    NSObjCObjectType   = '@',
    NSObjCStructType   = '{',
    NSObjCPointerType  = '^',
    NSObjCStringType   = '*',
    NSObjCArrayType    = '[',
    NSObjCUnionType    = '(',
    NSObjCBitfield     = 'b'
#else
#   error unsupported ObjC runtime !!!
#endif
};

typedef struct {
    enum _NSObjCValueType type;
    union {
        char      charValue;
        short     shortValue;
        long      longValue;
        long long longlongValue;
        float     floatValue;
        double    doubleValue;
        SEL       selectorValue;
        id        objectValue;
        void      *pointerValue;
        void      *structLocation;
        char      *cStringLocation;
    } value;
} NSObjCValue;

#endif /* __NSInvocation_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
