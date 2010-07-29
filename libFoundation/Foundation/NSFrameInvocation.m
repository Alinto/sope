/* 
   NSFrameInvocation.m

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
           Helge Hess <helge.hess@mdlink.de>

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

#include <Foundation/common.h>

#if HAVE_STRING_H
# include <string.h>
#endif

#if HAVE_MEMORY_H
# include <memory.h>
#endif

#if !HAVE_MEMCPY
# define memcpy(d, s, n)       bcopy((s), (d), (n))
# define memmove(d, s, n)      bcopy((s), (d), (n))
#endif

#include <Foundation/NSException.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <Foundation/exceptions/NSInvocationExceptions.h>

#include <extensions/objc-runtime.h>

#include "NSFrameInvocation.h"

/*
 * Will set *seltype to point to the type of the nth argument, excluding
 * from type the type specifiers.
 */
static void* get_nth_argument(arglist_t argframe, NSArgumentInfo argInfo)
{
    const char* t = objc_skip_typespec(argInfo.type);

    if(*t == '+')
	return argframe->arg_regs + argInfo.offset;
    else
	return argframe->arg_ptr +
	    (argInfo.offset - OBJC_FORWARDING_STACK_OFFSET);
}

@implementation NSFrameInvocation

- (void)_releaseArguments
{
    if (self->argumentsRetained) {
	self->argumentsRetained = 0;
	RELEASE(self->target);
	if (frame && signature) {
	    int index, numberOfArguments = [signature numberOfArguments];

	    for(index = 2; index < numberOfArguments; index++) {
		NSArgumentInfo argInfo = [signature argumentInfoAtIndex:index];
		if(*argInfo.type == _C_CHARPTR) {
		    char* str;
		    [self getArgument:&str atIndex:index];
		    lfFree(str);
		}
		else if(*argInfo.type == _C_ID) {
		    id object;
		    [self getArgument:&object atIndex:index];
		    RELEASE(object);
		}
	    }
	}
    }
}

- (void)_verifySignature
{
    struct objc_method_description* mth;
    
    if(self->target == nil)
	[[NullTargetException new] raise];

    if(self->selector == NULL)
	[[NullSelectorException new] raise];

    mth = (struct objc_method_description*)
	(CLS_ISCLASS(((struct objc_class*)self->target)->class_pointer)
         ? class_get_instance_method(
	    ((struct objc_class*)target)->class_pointer, self->selector)
	 : class_get_class_method(
	    ((struct objc_class*)target)->class_pointer, self->selector));

    if (mth) {
        /* a method matching the selector does exist */
        const char *types;
        
        self->selector = mth ? mth->name : (SEL)0;

        if(self->selector == NULL)
            [[NullSelectorException new] raise];

        types = mth->types;
        if(types == NULL)
            [[[CouldntGetTypeForSelector alloc] initForSelector:selector] raise];

        if(self->signature) {
            if(!sel_types_match(types, [signature types]))
                [[[TypesDontMatchException alloc]
                          initWithTypes:types :[signature types]] raise];
        }
        else {
            self->signature = [NSMethodSignature signatureWithObjCTypes:types];
            self->signature = RETAIN(self->signature);
        }
    }
    else {
        /* no method matching the selector does exist */
        self->signature =
            [self->target methodSignatureForSelector:self->selector];
        self->signature = RETAIN(self->signature);
    }

    if (self->signature == NULL)
       [[[CouldntGetTypeForSelector alloc] initForSelector:selector] raise];
}

- (void)invalidate
{
    if (self->isValid) {
	[self _releaseArguments];
	self->isValid = 0;
    }
}

- (void)dealloc
{
    if (self->isValid)
	[self _releaseArguments];
    if(self->frame && self->ownsFrame) {
	lfFree(((arglist_t)self->frame)->arg_ptr);
	lfFree(self->frame);
    }
    lfFree(self->returnFrame);
#ifndef __alpha__
    /* Temporary comment this out on Alpha machines since it makes the programs
       crash; don't ask me why ;-) */
    if(self->ownsReturnValue)
	lfFree(self->returnValue);
#endif
    [super dealloc];
}

static inline void _setupFrame(NSFrameInvocation *self)
{
    /* Set up a new frame */
    int stack_argsize = [self->signature sizeOfStackArguments];

    NSCAssert(self->frame == NULL, @"frame already setup ..");

    self->frame = (arglist_t)NSZoneCalloc([self zone], APPLY_ARGS_SIZE, 1);
    self->frame->arg_ptr = stack_argsize
        ? NSZoneCalloc([self zone], stack_argsize, 1)
        : NULL;
    self->ownsFrame = 1;
}

static inline void
_fixReturnValue(NSFrameInvocation *self, const char *retType, int retSize)
{
    if(!self->returnFrame && retSize)
	self->returnFrame = NSZoneCalloc([self zone], APPLY_RESULT_SIZE, 1);

    if(!self->ownsFrame) {
	/*  Was called from the forward:: method. If the original method
	    returns a struct by value, then we must set the returnValue to
	    the address of the structure value. Otherwise the returnValue
	    will still have the null value. */
	if (*retType != _C_VOID)
	    self->returnValue = GET_STRUCT_VALUE_ADDRESS(self->frame, retType);
    }
    if(!self->returnValue && retSize) {
	self->ownsReturnValue = YES;
	self->returnValue = NSZoneCalloc([self zone], retSize, 1);
	if (*retType != _C_VOID)
	    SET_STRUCT_VALUE_ADDRESS(self->frame, self->returnValue, retType);
    }
}

- (void)getArgument:(void*)argumentLocation atIndex:(int)index
{
    [self _verifySignature];
    
    NSAssert(self->signature, @"You must previously set the signature object");
    NSAssert(self->frame,     @"You must previously set the arguments frame");

    if((unsigned)index >= [signature numberOfArguments]) {
	[[[IndexOutOfRangeException alloc]
                     initForSize:[signature numberOfArguments] index:index] raise];
	return;
    }
    else {
	NSArgumentInfo argInfo = [signature argumentInfoAtIndex:index];
	void* frameData = get_nth_argument(frame, argInfo);

#ifdef FRAME_GET_ARGUMENT
        FRAME_GET_ARGUMENT(frameData, argumentLocation, argInfo);
#else /* !FRAME_GET_ARGUMENT */
# if WORDS_BIGENDIAN
	if(argInfo.size < sizeof(void*))
	    memcpy(argumentLocation,
                   ((char*)frameData) + sizeof(void*) - argInfo.size,
                   argInfo.size);
	else
# endif /* WORDS_BIGENDIAN */
            memcpy(argumentLocation, frameData, argInfo.size);
#endif /* FRAME_GET_ARGUMENT */
    }		
}

- (void)setArgument:(void*)argumentLocation atIndex:(int)index
{
    /* If the argument to be set is not the target, verify the signature */
    if(index)
        [self _verifySignature];

    if(!frame)
        _setupFrame(self);

    if(index >= (int)[signature numberOfArguments])
	[[[IndexOutOfRangeException alloc]
		    initForSize:[signature numberOfArguments] index:index] raise];
    else {
	if (argumentLocation) {
            NSArgumentInfo argInfo = [signature argumentInfoAtIndex:index];
            void* frameData = get_nth_argument(frame, argInfo);

#ifdef FRAME_SET_ARGUMENT
            FRAME_SET_ARGUMENT(frameData, argumentLocation, argInfo);
#else /* !FRAME_SET_ARGUMENT */
# if WORDS_BIGENDIAN
            if(argInfo.size < sizeof(void*))
                memcpy(((char*)frameData) + sizeof(void*) - argInfo.size,
                       argumentLocation,
                       argInfo.size);
            else
# endif /* WORDS_BIGENDIAN */
                memcpy(frameData, argumentLocation, argInfo.size);
#endif /* !FRAME_SET_ARGUMENT */
        }
    }
}

- (void)getReturnValue:(void*)retLoc
{
    const char* retType;
    int retLength;

    NSAssert(signature, @"You must previously set the signature object");
    NSAssert(frame, @"You must previously set the arguments frame,"
	      @"either by invoking -invoke or -invokeWithTarget: methods");

    retType = [signature methodReturnType];
    if(*retType != _C_VOID) {
	retLength = [signature methodReturnLength];
	memcpy(retLoc, returnValue, retLength);
    }
}

- (void)setReturnValue:(void*)retLoc
{
    const char* retType;
    int retSize;

    [self _verifySignature];

    NSAssert(signature, @"You must previously set the signature object");
    NSAssert(frame,     @"You must previously set the arguments frame");

    retType = [signature methodReturnType];
    retSize = [signature methodReturnLength];

    if (returnValue == NULL) {
        // this is executed if the invocation wasn't invoked
        // (but dispatched in user code, like in DO)
        _fixReturnValue(self, retType, retSize);
    }
    
    if(*retType != _C_VOID) {
#if 0 && WORDS_BIGENDIAN
	if(retSize < sizeof(void*)) {
	    *(void**)returnValue = 0;
	    memcpy(returnValue, ((char*)retLoc) + sizeof(void*) - retSize, retSize);
	}
	else
#endif
#if WORDS_BIGENDIAN
	if(retSize < sizeof(void*))
	    retSize = sizeof(void*);
#endif
	memcpy(returnValue, retLoc, retSize);
    }
    FUNCTION_SET_VALUE(retType, frame, returnFrame, returnValue);
}

- (void)retainArguments
{
    int index, numberOfArguments;

    NSAssert(signature, @"You must previously set the signature object");

    if (self->argumentsRetained)
	return;

    self->argumentsRetained = 1;
    (void)RETAIN(self->target);
    numberOfArguments = [signature numberOfArguments];
    if (numberOfArguments <= 2)
	return;

    NSAssert(frame, @"You must previously set the arguments frame");

    for(index = 2; index < numberOfArguments; index++) {
	NSArgumentInfo argInfo = [signature argumentInfoAtIndex:index];
        
	if(*argInfo.type == _C_CHARPTR) {
	    char* str;
	    [self getArgument:&str atIndex:index];
	    str = Strdup(str);
	    [self setArgument:&str atIndex:index];
	}
	else if(*argInfo.type == _C_ID) {
	    id object;
	    [self getArgument:&object atIndex:index];
	    (void)RETAIN(object);
	}
    }
}

- (void)invokeWithTarget:(id)_target
{
    id         old_target = target;
    retval_t   retframe;
    const char *retType;
    int        retSize;

    /*  Set the target. We assign '_target' to 'target' because some
        of the NSInvocation's methods assume a valid target. */
    target = _target;
    [self _verifySignature];

    if((frame == NULL) && [signature numberOfArguments] > 2)
	[[FrameIsNotSetupException new] raise];

    if(frame == NULL)
        _setupFrame(self);

    retType = [signature methodReturnType];
    retSize = [signature methodReturnLength];
    _fixReturnValue(self, retType, retSize);

    /* Restore the old target. */
    target = old_target;

#if GNU_RUNTIME
    {
        Method *m;
        const char *type;

        m = class_get_instance_method(*(Class *)_target, selector);
        
        *((id*)method_get_first_argument (m, frame, &type)) = _target;
        *((SEL*)method_get_next_argument (frame, &type)) = selector;
        retframe = __builtin_apply((apply_t)m->method_imp, 
                                   frame,
                                   method_get_sizeof_arguments(m));
    }
#else /* !GNU_RUNTIME */
    retframe = objc_msg_sendv(_target, selector, frame);
#endif /* !GNU_RUNTIME */

    if (retSize) {
        FUNCTION_VALUE(retType, frame, retframe, returnValue);
        memcpy(returnFrame, retframe, APPLY_RESULT_SIZE);
    }
}

- (void)invokeWithTarget:(id)_target lookupAtClass:(Class)_class
{
    id         old_target = target;
    retval_t   retframe;
    const char *retType;
    int        retSize;

    /*  Set the target. We assign '_target' to 'target' because some
        of the NSInvocation's methods assume a valid target. */
    target = _target;
    [self _verifySignature];

    if((frame == NULL) && [signature numberOfArguments] > 2)
	[[FrameIsNotSetupException new] raise];

    if(frame == NULL)
        _setupFrame(self);

    retType = [signature methodReturnType];
    retSize = [signature methodReturnLength];
    _fixReturnValue(self, retType, retSize);

    /* Restore the old target. */
    target = old_target;

#if GNU_RUNTIME
    {
        Method *m;
        const char *type;

        m = class_get_instance_method(_class, selector);
        
        *((id*)method_get_first_argument (m, frame, &type)) = _target;
        *((SEL*)method_get_next_argument (frame, &type)) = selector;
        retframe = __builtin_apply((apply_t)m->method_imp, 
                                   frame,
                                   method_get_sizeof_arguments(m));
    }
#else /* !GNU_RUNTIME */
#warning "super invocation supported with GNU runtime only !"
    abort();
    /* retframe = objc_msg_sendv(_target, selector, frame); */
#endif /* !GNU_RUNTIME */

    if (retSize) {
        FUNCTION_VALUE(retType, frame, retframe, returnValue);
        memcpy(returnFrame, retframe, APPLY_RESULT_SIZE);
    }
}
- (void)superInvokeWithTarget:(id)_target
{
    [self invokeWithTarget:_target
          lookupAtClass:(*(Class *)_target)->super_class];
}

- (NSString*)description
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[1024];

    sprintf (buffer, "<%s %p selector: %s target: %s>", \
                (char*)object_get_class_name(self), \
                self, \
                selector ? [NSStringFromSelector(selector) cString] : "nil", \
                target ? [NSStringFromClass([target class]) cString] : "nil" \
                );

    return [NSString stringWithCString:buffer];
}

@end /* NSInvocation */


@implementation NSFrameInvocation (Extensions)

- (void)setArgumentFrame:(void*)_frame
{
    self->frame     = _frame;
    self->ownsFrame = 0;
}

- (retval_t)returnFrame
{
    return self->returnFrame;
}
- (void*)returnValue
{
    return self->returnValue;
}

@end /* NSInvocation (Extensions) */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
