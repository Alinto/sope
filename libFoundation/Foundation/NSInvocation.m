/* 
   NSInvocation.m

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

#include <Foundation/common.h>
#include <Foundation/NSException.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <Foundation/exceptions/NSInvocationExceptions.h>
#include <extensions/objc-runtime.h>

#if WITH_FFCALL
#  include "FFCallInvocation.h"
#else
#  include "NSFrameInvocation.h"
#  include "NSObjectInvocation.h"
#endif

@implementation NSInvocation

- (id)initWithSignature:(NSMethodSignature *)_signature
{
    self->signature = RETAIN(_signature);
    self->isValid   = 1;
    return self;
}

+ (NSInvocation *)invocationWithMethodSignature:(NSMethodSignature *)sig
{
    NSInvocation *invocation;
#if !WITH_FFCALL
    const char *retType;
#endif

    if (sig == nil) {
      [[[InvalidArgumentException new]
                setReason:@"passed 'nil' signature to "
                          @"invocationWithMethodSignature:"] raise];
    }

#if WITH_FFCALL
    invocation = [[FFCallInvocation alloc] initWithSignature:sig];
#else
    retType = [sig methodReturnType];
    if (*retType == _C_VOID || *retType == _C_ID || *retType == _C_CLASS) {
        register int argCount;
        
        if ((argCount = [sig numberOfArguments]) > 1) {
            register const char *types = [sig types];
            register int i;
            BOOL allObjects = YES;
        
            types = objc_skip_argspec(types); // skip return value
            NSAssert1(*types == _C_ID || *types == _C_CLASS,
                      @"invalid self type (%s)", types);
            types = objc_skip_argspec(types); // skip self
            NSAssert1(*types == _C_SEL, @"invalid _cmd type (%s)", types);
            types = objc_skip_argspec(types); // skip _cmd
            argCount -= 2;

            // check whether all 
            for (i = 0; (i < argCount) && allObjects; i++) {
                switch (*types) {
                    case _C_ID:
                    case _C_CLASS:
                        break;
                        
                    default:
                        allObjects = NO;
                        break;
                }
                types = objc_skip_argspec(types);
            }
            
            if (allObjects) {
                invocation = [[NSObjectInvocation allocForArgumentCount:argCount
                                                  zone:nil]
                                                  initWithSignature:sig];
                return AUTORELEASE(invocation);
            }
        }
    }
    
    invocation = [[NSFrameInvocation alloc] initWithSignature:sig];
#endif
    return AUTORELEASE(invocation);
}

- (void)dealloc
{
    RELEASE(self->signature);
    [super dealloc];
}

// arguments

- (void)setTarget:(id)_target
{
    if (self->argumentsRetained)
	ASSIGN(self->target, _target);
    else
        self->target = _target;
}
- (id)target
{
    return self->target;
}

- (void)setSelector:(SEL)_selector
{
    self->selector = _selector;
}
- (SEL)selector
{
    return self->selector;
}

- (void)setArgument:(void *)_value atIndex:(int)_idx
{
    [self subclassResponsibility:_cmd];
}
- (void)getArgument:(void *)_value atIndex:(int)_idx
{
    [self subclassResponsibility:_cmd];
}

- (void)retainArguments
{
    [self subclassResponsibility:_cmd];
}
- (BOOL)argumentsRetained
{
    return self->argumentsRetained ? YES : NO;
}

- (NSMethodSignature *)methodSignature
{
    return self->signature;
}

// return values

- (void)setReturnValue:(void *)_value
{
    [self subclassResponsibility:_cmd];
}
- (void)getReturnValue:(void *)_value
{
    [self subclassResponsibility:_cmd];
}

// validation

- (void)invalidate
{
    [self subclassResponsibility:_cmd];
}

// invoking

- (void)invokeWithTarget:(id)_target
{
    [self subclassResponsibility:_cmd];
}

- (void)invoke
{
    [self invokeWithTarget:self->target];
}

@end

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
