/* 
   NSMethodSignature.h

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

#ifndef __NSMethodSignature_h__
#define __NSMethodSignature_h__

#include <Foundation/NSObject.h>

typedef struct {
    int	offset;
    int	size;
    const char* type;
} NSArgumentInfo;

@interface NSMethodSignature : NSObject
{
    char *types;
    int  numberOfArguments;
}

+ (NSMethodSignature*)signatureWithObjCTypes:(const char*)types;

- (NSArgumentInfo)argumentInfoAtIndex:(unsigned)index;
- (const char *)getArgumentTypeAtIndex:(unsigned int)_index; // new in Rhapsody

- (unsigned)frameLength;
- (BOOL)isOneway;
- (unsigned)methodReturnLength;
- (const char*)methodReturnType;
- (unsigned)numberOfArguments;
@end

@interface NSMethodSignature (Extensions)
- (const char *)types;
- (unsigned)sizeOfStackArguments;
- (unsigned)sizeOfRegisterArguments;
- (unsigned)typeSpecifiersOfArgumentAt:(int)index;
- (BOOL)isInArgumentAt:(int)index;
- (BOOL)isOutArgumentAt:(int)index;
- (BOOL)isBycopyArgumentAt:(int)index;
@end

@interface NSMethodSignature(GNUstepCompatibility)
- (const char *)methodType;
@end

#endif /* __NSMethodSignature_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
