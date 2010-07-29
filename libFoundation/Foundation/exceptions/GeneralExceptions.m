/* 
   GeneralExceptions.m

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

#include <stdarg.h>
#include <stdio.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSValue.h>

#include <extensions/NSException.h>
#include <extensions/exceptions/GeneralExceptions.h>

#if GNUSTEP_BASE_LIBRARY || LIBOBJECTS_LIBRARY
# define name_ivar     e_name
# define reason_ivar   e_reason
# define userInfo_ivar e_info
#else
# define name_ivar     name
# define reason_ivar   reason
# define userInfo_ivar userInfo
#endif

#if LIB_FOUNDATION_LIBRARY
@implementation MemoryExhaustedException

MemoryExhaustedException* memoryExhaustedException = nil;

- __init
{
    name = [NSMallocException retain];
    reason = @"Memory exhausted";
    return self;
}

+ (void)initialize
{
    memoryExhaustedException = [NSAllocateObject(self, 0, NULL) init];
}

+ (id)alloc
{
    return memoryExhaustedException;
}

+ (id)allocWithZone:(NSZone*)zone
{
    return memoryExhaustedException;
}

- (void)release
{
    pointer = NULL;
    size = 0;
}

- (id)init
{
    return self;
}

- setPointer:(void**)_pointer memorySize:(unsigned)_size
{
    pointer = _pointer;
    size = _size;
    return self;
}

@end /* MemoryExhaustedException */


@implementation MemoryDeallocationException

- setPointer:(void**)_pointer memorySize:(unsigned)_size
{
    pointer = _pointer;
    size = _size;
    name = NSMallocException;
    reason = @"Deallocation error";
    return self;
}

@end  /* MemoryDeallocationException */


@implementation MemoryCopyException
@end

#endif /* LIB_FOUNDATION_LIBRARY */


@implementation FileNotFoundException
- initWithFilename:(NSString*)f
{
    id aux =  @"filename";
    id message = [@"File not found: " stringByAppendingString:f];

    self = [self initWithName:@"FileNotFoundException"
	reason:message
	userInfo:[NSDictionary dictionaryWithObjectsAndKeys:f, aux, nil]];
    return self;
}

- (NSString*)filename
{
    return [[self userInfo] objectForKey:@"filename"];
}
@end /* FileNotFoundException */


@implementation AssertException
- init
{
    self = [self initWithName:NSInternalInconsistencyException
		    reason:nil userInfo:nil];
    return self;
}
@end /* AssertException */


@implementation SyntaxErrorException
- init
{
    self = [self initWithName:@"Syntax error" reason:nil userInfo:nil];
    return self;
}
- initWithReason:(NSString*)aReason
{
    self = [self initWithName:@"Syntax error" reason:aReason userInfo:nil];
    return self;
}
@end /* SyntaxErrorException */


@implementation UnknownTypeException
- initForType:(const char*)type
{
    self = [self initWithName:NSInvalidArgumentException
		    reason:@"Unknown Objective-C type encoding"
		    userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			    [NSString stringWithCString:type], @"type",
			    nil]];
    return self;
}
@end /* UnknownTypeException */


@implementation UnknownClassException
- setClassName:(NSString*)className
{
    self = [[self setName:NSInvalidArgumentException]
		initWithFormat:@"Unknown Objective-C class '%@'", className];
    return self;
}
@end /* UnknownClassException */


@implementation ObjcRuntimeException
@end /* ObjcRuntimeException */


@implementation InternalInconsistencyException
- init
{
    self = [self initWithName:@"Internal inconsistency exception" reason:nil userInfo:nil];
    return self;
}
@end /* InternalInconsistencyException */


@implementation InvalidArgumentException
- init
{
    self = [self initWithName:NSInvalidArgumentException reason:nil userInfo:nil];
    return self;
}
- initWithReason:(NSString*)aReason
{
    self = [self initWithName:NSInvalidArgumentException 
	    reason:aReason userInfo:nil];
    return self;
}
@end /* InvalidArgumentException */


@implementation IndexOutOfRangeException
- init
{
    self = [self initWithName:@"Index out of range"
		    reason:nil userInfo:nil];
    return self;
}

- initForSize:(int)size index:(int)index
{
    id keys[] = { @"size", @"index" };
    id values[] = { [NSNumber numberWithInt:size],
		    [NSNumber numberWithInt:index] };
    self = [self initWithName:@"Index out of range"
	    reason:nil
	    userInfo:[NSDictionary dictionaryWithObjects:values
				    forKeys:keys
				    count:2]];
    return self;
}

@end /* IndexOutOfRangeException */


@implementation RangeException
- init
{
    self = [self initWithName:NSRangeException reason:nil userInfo:nil];
    return self;
}

- initWithReason:(NSString*)aReason size:(int)size index:(int)index
{
    id keys[] = { @"size", @"index" };
    id values[] = { [NSNumber numberWithInt:size],
		    [NSNumber numberWithInt:index] };
    self = [self initWithName:@"Index out of range"
	    reason:aReason
	    userInfo:[NSDictionary dictionaryWithObjects:values
				    forKeys:keys
				    count:2]];
    return self;
}
@end /* RangeException */


@implementation InvalidUseOfMethodException
@end

@implementation PosixFileOperationException : NSException
- (NSString*)name
{
    return @"NSPosixFileOperationException";
}
@end
/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/

