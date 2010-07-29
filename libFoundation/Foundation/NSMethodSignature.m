/* 
   NSMethodSignature.m

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

#include <config.h>
#include <Foundation/common.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/exceptions/GeneralExceptions.h>

#include <extensions/objc-runtime.h>

#define WITH_METHOD_SIGNATURE_CACHE 1

/*
 * Return the type of the nth argument. The target and selector are not
 * counted as arguments.
 */
static const char*
get_nth_argument_type_with_qualifiers(char* types, int index)
{
    const char* seltype = types;

    // skip return type
    seltype = objc_skip_argspec(seltype);

    while(index--)
        seltype = objc_skip_argspec(seltype);

    return seltype;
}

static const char*
get_nth_argument_type(char* types, int index)
{
    return objc_skip_type_qualifiers(
                get_nth_argument_type_with_qualifiers(types, index));
}

static NSString*
isolate_type(const char* types)
{
    const char* p = objc_skip_typespec(types);
    return [NSString stringWithCString:types length:(unsigned)(p - types)];
}

@implementation NSMethodSignature

#if WITH_METHOD_SIGNATURE_CACHE
static NSMapTable *methodSignatureCache = NULL;
#endif

+ (void)initialize {
#if WITH_METHOD_SIGNATURE_CACHE
    if (methodSignatureCache == NULL) {
        methodSignatureCache =
            NSCreateMapTable(NSNonOwnedCStringMapKeyCallBacks,
                             NSObjectMapValueCallBacks,
                             64);
    }
#endif
}

+ (NSMethodSignature *)signatureWithObjCTypes:(const char *)_types
{
    extern NSLock       *libFoundationLock;
    NSMethodSignature   *signature;
    const char *p;

    if(_types == NULL) {
	[[[InvalidArgumentException new]
		setReason:@"Null types passed to signatureWithObjCTypes:"] raise];
	return nil;
    }

#if WITH_METHOD_SIGNATURE_CACHE
    [libFoundationLock lock];
    signature = NSMapGet(methodSignatureCache, _types);
    signature = RETAIN(signature);
    [libFoundationLock unlock];
    if (signature) 
        return AUTORELEASE(signature);
#endif

    signature = AUTORELEASE([NSMethodSignature alloc]);
    NSAssert(signature, @"couldn't allocate method signature");

    /* Determine if _types also contains the position info. If not, determine
	a new one. This encoding is used later instead of original one. */
    p = objc_skip_typespec(_types);
    if(!isdigit(*p)) {
	CUMULATIVE_ARGS cumulative_args;
	int stack_argsize = 0;
	id encoding = AUTORELEASE([NSMutableString new]);
	const char* retval = _types;

	/* Skip returned value. */
	_types = objc_skip_typespec(_types);

	signature->numberOfArguments = 0;

	INIT_CUMULATIVE_ARGS(cumulative_args);
	while(*_types) {
	    [encoding appendString:
		    FUNCTION_ARG_ENCODING(cumulative_args,
					isolate_type(_types),
					stack_argsize)];
	    _types = objc_skip_typespec(_types);
	    signature->numberOfArguments++;
	}
	encoding = [NSString stringWithFormat:@"%@%d%@",
				isolate_type(retval), stack_argsize, encoding];
	signature->types = Strdup([encoding cString]);
    }
    else {
	signature->types = Strdup(_types);

	/* Compute no of arguments. The first type is the return type. */
	for(signature->numberOfArguments = -1;
		    *_types; signature->numberOfArguments++)
	    _types = objc_skip_argspec(_types);
    }

#if WITH_METHOD_SIGNATURE_CACHE
    [libFoundationLock lock];
    NSMapInsert(methodSignatureCache, _types, signature);
    [libFoundationLock unlock];
#endif
    
    return signature;
}

- (void)dealloc
{
    lfFree(self->types);
    [super dealloc];
}

- (unsigned)hash
{
    return hashjb(self->types, Strlen(self->types));
}

- (BOOL)isEqual:(id)anotherSignature
{
    if (self == anotherSignature) return YES;
    if (![anotherSignature isKindOfClass:self->isa]) return NO;
    if (Strcmp(self->types, [anotherSignature types]) != 0) return NO;
    return YES;
}

- (NSArgumentInfo)argumentInfoAtIndex:(unsigned)index
{
    NSArgumentInfo argInfo;
    argInfo.type   = get_nth_argument_type(self->types, index);
    argInfo.size   = objc_sizeof_type(argInfo.type);
    argInfo.offset = Atoi(objc_skip_typespec(argInfo.type));
    return argInfo;
}

- (const char *)getArgumentTypeAtIndex:(unsigned int)_index
{
    return get_nth_argument_type(self->types, _index);
}

- (unsigned)frameLength
{
    return [self sizeOfStackArguments];
}

- (BOOL)isOneway
{
    return objc_get_type_qualifiers(types) & _F_ONEWAY;
}

- (unsigned)methodReturnLength
{
    const char* ptypes = objc_skip_type_qualifiers(self->types);
    int size = 0;

    if (*ptypes != _C_VOID)
	size = objc_sizeof_type (ptypes);
    return size;
}

- (const char*)methodReturnType
{
    return objc_skip_type_qualifiers(self->types);
}

- (unsigned)numberOfArguments
{
    return self->numberOfArguments;
}

/* description */

- (NSString *)description
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[512];

    sprintf (buffer, "<%s %p types=%s>",
             (char*)object_get_class_name(self), self, self->types);
    return [NSString stringWithCString:buffer];
}

@end /* NSMethodSignature */


@implementation NSMethodSignature (Extensions)

- (const char *)types
{
    return self->types;
}
- (const char *)methodType
{
    /* for GNUstep compatibility */
    return self->types;
}

- (unsigned)sizeOfStackArguments
{
    const char* ptype = objc_skip_typespec(self->types);
    return Atoi(ptype);
}

- (unsigned)sizeOfRegisterArguments
{
    const char* type = strrchr(self->types, '+');
    int size = 0;
    if (type) size = objc_sizeof_type(type - 1) + atoi(type + 1);
    return size;
}

- (unsigned)typeSpecifiersOfArgumentAt:(int)index
{
    if(index >= numberOfArguments) {
        [[[IndexOutOfRangeException alloc]
		initForSize:numberOfArguments index:index] raise];
        return 0;
    }

    return objc_get_type_qualifiers(
            get_nth_argument_type_with_qualifiers(self->types, index));
}

- (BOOL)isInArgumentAt:(int)index
{
    unsigned flags = [self typeSpecifiersOfArgumentAt:index];
    return !flags || (flags & _F_IN);
}

- (BOOL)isOutArgumentAt:(int)index
{
    return [self typeSpecifiersOfArgumentAt:index] & _F_OUT;
}

- (BOOL)isBycopyArgumentAt:(int)index
{
    return [self typeSpecifiersOfArgumentAt:index] & _F_BYCOPY;
}

@end /* NSMethodSignature (Extensions) */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
