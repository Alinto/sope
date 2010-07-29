/* 
   GeneralExceptions.h

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

#ifndef __GeneralExceptions_h__
#define __GeneralExceptions_h__

#include <extensions/support.h>
#include <extensions/exceptions/FoundationException.h>

@class NSString;

#if LIB_FOUNDATION_LIBRARY

@class MemoryExhaustedException;

extern MemoryExhaustedException* memoryExhaustedException;

@interface MemoryExhaustedException : FoundationException
{
    void** pointer;
    unsigned size;
}
- setPointer:(void**)pointer memorySize:(unsigned)size;
@end


@interface MemoryDeallocationException : FoundationException
{
    void** pointer;
    unsigned size;
}
- setPointer:(void**)pointer memorySize:(unsigned)size;
@end


@interface MemoryCopyException : FoundationException
@end

#endif /* LIB_FOUNDATION_LIBRARY */

@interface FileNotFoundException : FoundationException
- initWithFilename:(NSString*)f;
- (NSString*)filename;
@end


@interface SyntaxErrorException : FoundationException
@end


@interface UnknownTypeException : NSException
- initForType:(const char*)type;
@end


@interface UnknownClassException : NSException
- setClassName:(NSString*)className;
@end


@interface ObjcRuntimeException : FoundationException
@end


@interface InternalInconsistencyException : NSException
@end


@interface InvalidArgumentException : NSException
- initWithReason:(NSString*)aReason;
@end


@interface IndexOutOfRangeException : FoundationException
- initForSize:(int)size index:(int)pos;
@end


@interface RangeException : IndexOutOfRangeException
- initWithReason:(NSString*)aReason size:(int)size index:(int)index;
@end


@interface InvalidUseOfMethodException : NSException
@end

@interface PosixFileOperationException : NSException
@end


#endif /* __GeneralExceptions_h__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
