/* 
   NSObjectInvocation.m

   Copyright (C) 1999 Helge Hess.
   All rights reserved.

   Author: Helge Hess <helge.hess@mdlink.de>

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
#include <Foundation/NSUtilities.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <Foundation/exceptions/NSInvocationExceptions.h>
#include "NSObjectInvocation.h"

// method prototypes
typedef void (*mVoid_Id0) (id, SEL);
typedef void (*mVoid_Id1) (id, SEL, id);
typedef void (*mVoid_Id2) (id, SEL, id, id);
typedef void (*mVoid_Id3) (id, SEL, id, id, id);
typedef void (*mVoid_Id4) (id, SEL, id, id, id, id);
typedef void (*mVoid_Id5) (id, SEL, id, id, id, id, id);
typedef void (*mVoid_Id6) (id, SEL, id, id, id, id, id, id);
typedef void (*mVoid_Id7) (id, SEL, id, id, id, id, id, id, id);
typedef void (*mVoid_Id8) (id, SEL, id, id, id, id, id, id, id, id);
typedef void (*mVoid_Id9) (id, SEL, id, id, id, id, id, id, id, id, id);
typedef void (*mVoid_Id10)(id, SEL, id, id, id, id, id, id, id, id, id, id);
typedef id   (*mId_Id0)   (id, SEL);
typedef id   (*mId_Id1)   (id, SEL, id);
typedef id   (*mId_Id2)   (id, SEL, id, id);
typedef id   (*mId_Id3)   (id, SEL, id, id, id);
typedef id   (*mId_Id4)   (id, SEL, id, id, id, id);
typedef id   (*mId_Id5)   (id, SEL, id, id, id, id, id);
typedef id   (*mId_Id6)   (id, SEL, id, id, id, id, id, id);
typedef id   (*mId_Id7)   (id, SEL, id, id, id, id, id, id, id);
typedef id   (*mId_Id8)   (id, SEL, id, id, id, id, id, id, id, id);
typedef id   (*mId_Id9)   (id, SEL, id, id, id, id, id, id, id, id, id);
typedef id   (*mId_Id10)  (id, SEL, id, id, id, id, id, id, id, id, id, id);

@interface NSInvocation(PrivateMethods)
- (id)initWithSignature:(NSMethodSignature *)_signature;
@end

@interface NSObjectInvocation(PrivateMethods)
- (void)_releaseArguments;
@end

@implementation NSObjectInvocation

+ (id)allocForArgumentCount:(int)_count zone:(NSZone *)_zone
{
    NSObjectInvocation *i = (NSObjectInvocation *)
	NSAllocateObject(self, _count * sizeof(id), _zone);
    i->argumentCount = _count;
    return i;
}

- (id)initWithSignature:(NSMethodSignature *)_signature
{
    self = [super initWithSignature:_signature];
    self->isVoid = (*[_signature methodReturnType] == _C_VOID);
    return self;
}

- (void)dealloc
{
    if (self->isValid) [self _releaseArguments];
    [super dealloc];
}

// arguments

- (void)_releaseArguments
{
    if (self->argumentsRetained) {
        int i;
        
        self->argumentsRetained = 0;
        RELEASE(self->target);

        for (i = 0; i < self->argumentCount; i++)
            RELEASE(self->arguments[i]);
        RELEASE(self->returnValue);
    }
}

- (void)getArgument:(void*)argumentLocation atIndex:(int)index
{
    NSAssert(self->signature, @"You must previously set the signature object");
    if (index >= (self->argumentCount + 2)) {
	[[[IndexOutOfRangeException alloc]
                     initForSize:(self->argumentCount + 2) index:index] raise];
	return;
    }

    if (index == 0) // target
        *((id *)argumentLocation) = [self target];
    else if (index == 1) // selector
        *((SEL *)argumentLocation) = [self selector];
    else // argument
        *((id *)argumentLocation) = self->arguments[(index - 2)];
}
- (void)setArgument:(void*)argumentLocation atIndex:(int)index
{
    NSAssert(self->signature, @"You must previously set the signature object");
    if (index >= (self->argumentCount + 2)) {
	[[[IndexOutOfRangeException alloc]
                     initForSize:(self->argumentCount + 2) index:index] raise];
	return;
    }
    if (index == 0) // target
        [self setTarget:*((id *)argumentLocation)];
    else if (index == 1) // selector
        [self setSelector:*((SEL *)argumentLocation)];
    else { // argument
        if (self->argumentsRetained) {
            id tmp = self->arguments[(index - 2)];
            self->arguments[(index - 2)] = RETAIN(*((id *)argumentLocation));
            RELEASE(tmp); tmp = nil;
        }
        else
            self->arguments[(index - 2)] = *((id *)argumentLocation);
    }
}

- (void)retainArguments
{
    int i;
    
    NSAssert(self->signature, @"You must previously set the signature object");
    
    if (self->argumentsRetained)
	return;

    self->argumentsRetained = 1;
    
    self->target      = RETAIN(self->target);
    self->returnValue = RETAIN(self->returnValue);

    for (i = 0; i < self->argumentCount; i++)
        self->arguments[i] = RETAIN(self->arguments[i]);
}

// return value

- (void)getReturnValue:(void *)retLoc
{
    NSAssert(self->signature, @"You must previously set the signature object");
    
    *(id *)retLoc = self->returnValue;
}
- (void)setReturnValue:(void *)retLoc
{
    NSAssert(self->signature, @"You must previously set the signature object");
    
    if (self->argumentsRetained) {
        id tmp = self->returnValue;
        self->returnValue = RETAIN(*(id *)retLoc);
        RELEASE(tmp); tmp = nil;
    }
    else
        self->returnValue = *(id *)retLoc;
}

// validation

- (void)invalidate
{
    if (self->isValid) {
	[self _releaseArguments];
	self->isValid = 0;
    }
}

// invocation

static inline void _invoke(NSObjectInvocation *self, id _t, Class _lookup);

- (void)invokeWithTarget:(id)_target
{
    _invoke(self, _target, Nil);
}
- (void)invokeWithTarget:(id)_target lookupAtClass:(Class)_class
{
    _invoke(self, _target, _class);
}
- (void)superInvokeWithTarget:(id)_target
{
    Class superClass = (*(Class *)_target)->super_class;
    _invoke(self, _target, superClass);
}

static void _invoke(NSObjectInvocation *self, id _target, Class _lookupClass) {
    IMP method = NULL;
    SEL sel    = [self selector];
    
    NSCAssert(self->argumentCount < 11, @"Unsupported argument count !");

    if (_target == nil)
        _target = [self target];
    if (_target == nil) {
        if (!self->isVoid) [self setReturnValue:&_target];
        return;
    }
    
    if (sel == NULL) {
        [_target doesNotRecognizeSelector:sel];
        return;
    }
    
    if (_lookupClass)
        method = method_get_imp(class_get_instance_method(_lookupClass, sel));
    else {
        method = method_get_imp(object_is_instance(self)
                   ? class_get_instance_method(*(Class *)_target, sel)
                   : class_get_class_method(*(Class *)_target, sel));
    }

    if (method == NULL) {
        /* no method for dispatch, so forward invocation .. */
        [_target forwardInvocation:self];
        /* [_target doesNotRecognizeSelector:sel]; */
        return;
    }
    
    if (self->isVoid) {
        switch (self->argumentCount) {
            case 0:
                ((mVoid_Id0)method)(_target, sel);
                break;
            case 1:
                ((mVoid_Id1)method)(_target, sel, self->arguments[0]);
                break;
            case 2:
                ((mVoid_Id2)method)(_target, sel,
                                    self->arguments[0],
                                    self->arguments[1]);
                break;
            case 3:
                ((mVoid_Id3)method)(_target, sel,
                                    self->arguments[0],
                                    self->arguments[1],
                                    self->arguments[2]);
                break;
            case 4:
                ((mVoid_Id4)method)(_target, sel,
                                    self->arguments[0],
                                    self->arguments[1],
                                    self->arguments[2],
                                    self->arguments[3]);
                break;
            case 5:
                ((mVoid_Id5)method)(_target, sel,
                                    self->arguments[0],
                                    self->arguments[1],
                                    self->arguments[2],
                                    self->arguments[3],
                                    self->arguments[4]);
                break;
            case 6:
                ((mVoid_Id6)method)(_target, sel,
                                    self->arguments[0],
                                    self->arguments[1],
                                    self->arguments[2],
                                    self->arguments[3],
                                    self->arguments[4],
                                    self->arguments[5]);
                break;
            case 7:
                ((mVoid_Id7)method)(_target, sel,
                                    self->arguments[0],
                                    self->arguments[1],
                                    self->arguments[2],
                                    self->arguments[3],
                                    self->arguments[4],
                                    self->arguments[5],
                                    self->arguments[6]);
                break;
            case 8:
                ((mVoid_Id8)method)(_target, sel,
                                    self->arguments[0],
                                    self->arguments[1],
                                    self->arguments[2],
                                    self->arguments[3],
                                    self->arguments[4],
                                    self->arguments[5],
                                    self->arguments[6],
                                    self->arguments[7]);
                break;
            case 9:
                ((mVoid_Id9)method)(_target, sel,
                                    self->arguments[0],
                                    self->arguments[1],
                                    self->arguments[2],
                                    self->arguments[3],
                                    self->arguments[4],
                                    self->arguments[5],
                                    self->arguments[6],
                                    self->arguments[7],
                                    self->arguments[8]);
                break;
            case 10:
                ((mVoid_Id10)method)(_target, sel,
                                    self->arguments[0],
                                    self->arguments[1],
                                    self->arguments[2],
                                    self->arguments[3],
                                    self->arguments[4],
                                    self->arguments[5],
                                    self->arguments[6],
                                    self->arguments[7],
                                    self->arguments[8],
                                    self->arguments[9]);
                break;
        }
    }
    else {
        id retVal;
        
        switch (self->argumentCount) {
            case 0:
                retVal = ((mId_Id0)method)(_target, sel);
                break;
            case 1:
                retVal = ((mId_Id1)method)(_target, sel, self->arguments[0]);
                break;
            case 2:
                retVal = ((mId_Id2)method)(_target, sel,
                                           self->arguments[0],
                                           self->arguments[1]);
                break;
            case 3:
                retVal = ((mId_Id3)method)(_target, sel,
                                           self->arguments[0],
                                           self->arguments[1],
                                           self->arguments[2]);
                break;
            case 4:
                retVal = ((mId_Id4)method)(_target, sel,
                                           self->arguments[0],
                                           self->arguments[1],
                                           self->arguments[2],
                                           self->arguments[3]);
                break;
            case 5:
                retVal = ((mId_Id5)method)(_target, sel,
                                           self->arguments[0],
                                           self->arguments[1],
                                           self->arguments[2],
                                           self->arguments[3],
                                           self->arguments[4]);
                break;
            case 6:
                retVal = ((mId_Id6)method)(_target, sel,
                                           self->arguments[0],
                                           self->arguments[1],
                                           self->arguments[2],
                                           self->arguments[3],
                                           self->arguments[4],
                                           self->arguments[5]);
                break;
            case 7:
                retVal = ((mId_Id7)method)(_target, sel,
                                           self->arguments[0],
                                           self->arguments[1],
                                           self->arguments[2],
                                           self->arguments[3],
                                           self->arguments[4],
                                           self->arguments[5],
                                           self->arguments[6]);
                break;
            case 8:
                retVal = ((mId_Id8)method)(_target, sel,
                                           self->arguments[0],
                                           self->arguments[1],
                                           self->arguments[2],
                                           self->arguments[3],
                                           self->arguments[4],
                                           self->arguments[5],
                                           self->arguments[6],
                                           self->arguments[7]);
                break;
            case 9:
                retVal = ((mId_Id9)method)(_target, sel,
                                           self->arguments[0],
                                           self->arguments[1],
                                           self->arguments[2],
                                           self->arguments[3],
                                           self->arguments[4],
                                           self->arguments[5],
                                           self->arguments[6],
                                           self->arguments[7],
                                           self->arguments[8]);
                break;
            case 10:
                retVal = ((mId_Id10)method)(_target, sel,
                                            self->arguments[0],
                                            self->arguments[1],
                                            self->arguments[2],
                                            self->arguments[3],
                                            self->arguments[4],
                                            self->arguments[5],
                                            self->arguments[6],
                                            self->arguments[7],
                                            self->arguments[8],
                                            self->arguments[9]);
                break;
        }
        [self setReturnValue:&retVal];
    }
}

- (NSString *)description
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

@end

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
