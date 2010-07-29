/* 
   NSProxy.m

   Copyright (C) 1998 MDlink online service center, Helge Hess
   All rights reserved.

   Author: Helge Hess (helge@mdlink.de)

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
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSUtilities.h>
#include <Foundation/exceptions/GeneralExceptions.h>
#include <extensions/objc-runtime.h>
#include "NSProxy.h"

@implementation NSProxy

+ (id)alloc
{
    return [self allocWithZone:NULL];
}
+ (id)allocWithZone:(NSZone *)_zone
{
    return NSAllocateObject(self, 0, _zone);
}

- (void)dealloc
{
#if !LIB_FOUNDATION_BOEHM_GC
    NSDeallocateObject((NSObject *)self);
#endif
}

// getting the class

+ (Class)class {
    return self;
}

// handling unimplemented methods

- (void)forwardInvocation:(NSInvocation *)_invocation
{
    [[[InvalidArgumentException new]
              setReason:@"NSProxy subclass should override forwardInvocation:"] raise];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)_selector
{
    [[[InvalidArgumentException new]
      setReason:@"NSProxy subclass should override methodSignatureForSelector:"] raise];
    return nil;
}

// description

- (NSString *)description
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[512];

    sprintf (buffer, "<%s %p>", (char*)object_get_class_name(self), self);
    return [NSString stringWithCString:buffer];
}

// ******************** Class methods ************************

/*
  Usually instance methods of root classes are inherited to the class object
  of the root class. This isn't the case for most proxy methods, since the
  proxy implementations usually just forward to the real object using
  forwardInvocation:.
*/

/* Identifying Class and Superclass */

+ (Class)superclass
{
    return class_get_super_class(self);
}

/* Determining Allocation Zones */
+ (NSZone*)zone
{
    return NSZoneFromObject(self);
}

/* Identifying Proxies */
+ (BOOL)isProxy
{
    // while instances of NSProxy are proxies, the class itself isn't
    return NO;
}

/* Testing Inheritance Relationships */
+ (BOOL)isKindOfClass:(Class)aClass
{
    // this is the behaviour specified in the MacOSX docs
    return (aClass == [NSObject class]) ? YES : NO;
}
+ (BOOL)isMemberOfClass:(Class)aClass
{
    // behaviour as specified in the MacOSX docs
    return NO;
}

/* Testing for Protocol Conformance */
+ (BOOL)conformsToProtocol:(Protocol*)aProtocol
{
    struct objc_protocol_list *protos;

    for (protos = ((struct objc_class*)self)->protocols;
         protos; protos = protos->next) {
        int i;
        
	for(i = 0; i < protos->count; i++)
	    if([protos->list[i] conformsTo:aProtocol])
		return YES;
    }

    return [self superclass]
	? [[self superclass] conformsToProtocol: aProtocol]
        : NO;
}

/* Testing Class Functionality */
+ (BOOL)respondsToSelector:(SEL)aSelector
{
    return (!aSelector)
	? NO
        : (class_get_class_method(self, aSelector) != METHOD_NULL);
}

/* Managing Reference Counts */
+ (id)autorelease
{
    return self;
}
+ (oneway void)release
{
}
+ (id)retain
{
    return self;
}
+ (unsigned int)retainCount
{
    return (unsigned)-1;
}

/* Identifying and Comparing Instances */
+ (unsigned)hash
{
    return (unsigned)(unsigned long)self;
}
+ (BOOL)isEqual:(id)anObject
{
    return (self == anObject) ? YES : NO;
}   
+ (id)self
{
    return self;
}

/* Sending Messages Determined at Run Time */
+ (id)performSelector:(SEL)aSelector
{
    IMP msg = aSelector ? objc_msg_lookup(self, aSelector) : NULL;

    if(msg == NULL) {
	[[[ObjcRuntimeException alloc] initWithFormat:
	    @"invalid selector `%s' passed to %s",
	    sel_get_name(aSelector), sel_get_name(_cmd)] raise];
    }
    return (*msg)(self, aSelector);
}
+ (id)performSelector:(SEL)aSelector withObject:(id)anObject
{
    IMP msg = aSelector ? objc_msg_lookup(self, aSelector) : NULL;

    if(msg == NULL) {
	[[[ObjcRuntimeException alloc] initWithFormat:
	    @"invalid selector `%s' passed to %s",
	    sel_get_name(aSelector), sel_get_name(_cmd)] raise];
    }
    return (*msg)(self, aSelector, anObject);
}
+ (id)performSelector:(SEL)aSelector withObject:(id)anObject
  withObject:(id)anotherObject
{
    IMP msg = aSelector ? objc_msg_lookup(self, aSelector) : NULL;

    if(msg == NULL) {
	[[[ObjcRuntimeException alloc] initWithFormat:
	    @"invalid selector `%s' passed to %s",
	    sel_get_name(aSelector), sel_get_name(_cmd)] raise];
    }
    return (*msg)(self, aSelector, anObject, anotherObject);
}

/* Describing the Object */
+ (NSString *)description
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[512];

    sprintf (buffer, "<class %s>", (char*)object_get_class_name(self));
    return [NSString stringWithCString:buffer];
}

// ******************** NSObject protocol ********************

static inline NSInvocation *
_makeInvocation(NSProxy *self, SEL _cmd, const char *sig)
{
    NSMethodSignature *s;
    NSInvocation      *i;

    s = [NSMethodSignature signatureWithObjCTypes:sig];
    if (s == nil) return nil;
    i = [NSInvocation invocationWithMethodSignature:s];
    if (i == nil) return nil;

    [i setSelector:_cmd];
    [i setTarget:self];

    return i;
}
static inline NSInvocation *
_makeInvocation1(NSProxy *self, SEL _cmd, const char *sig, id _object)
{
    NSInvocation *i = _makeInvocation(self, _cmd, sig);
    [i setArgument:&_object atIndex:2];
    return i;
}

- (id)autorelease
{
#if !LIB_FOUNDATION_BOEHM_GC
    [NSAutoreleasePool addObject:self];
#endif
    return self;
}
- (id)retain
{
#if !LIB_FOUNDATION_BOEHM_GC
    NSIncrementExtraRefCount(self);
#endif
    return self;
}
- (oneway void)release
{
    if (NSExtraRefCount(self) == 1)
	[self dealloc];
    else
	NSDecrementExtraRefCountWasZero(self);
}
- (unsigned)retainCount
{
    return NSExtraRefCount(self);
}

- (Class)class
{
    // Note that this returns the proxy class, not the real one !
    return self->isa;
}
- (Class)superclass
{
    // Note that this returns the proxy's class superclass, not the real one !
    return class_get_super_class(self->isa);
}

- (BOOL)conformsToProtocol:(Protocol *)_protocol
{
    NSInvocation *i = _makeInvocation1(self, _cmd, "C@:@", _protocol);
    BOOL         r;
    [i invoke];
    [i getReturnValue:&r];
    return r;
}
- (BOOL)isKindOfClass:(Class)_class
{
    NSInvocation *i = _makeInvocation1(self, _cmd, "C@:@", _class);
    BOOL result;
    [i invoke];
    [i getReturnValue:&result];
    return result;
}
- (BOOL)isMemberOfClass:(Class)_class
{
    NSInvocation *i = _makeInvocation1(self, _cmd, "C@:@", _class);
    BOOL result;
    [i invoke];
    [i getReturnValue:&result];
    return result;
}

- (BOOL)isProxy
{
    return YES;
}

- (BOOL)respondsToSelector:(SEL)_selector
{
    NSInvocation *i;
    BOOL         r;

    if (_selector) {
        if (objc_msg_lookup(self, _selector)) return YES;
    }

    i = _makeInvocation(self, _cmd, "C@::");
    [i setArgument:&_selector atIndex:2];
    [i invoke];
    [i getReturnValue:&r];
    return r;
}

- (id)performSelector:(SEL)_selector
{
    NSInvocation *i;
    id           result;
    IMP          msg;

    if (_selector == NULL) {
        [[[InvalidArgumentException new]
             setReason:@"passed NULL selector to performSelector:"]
             raise];
    }

    if ((msg = objc_msg_lookup(self, _selector)))
        return msg(self, _selector);

    i = [NSInvocation invocationWithMethodSignature:
                        [NSMethodSignature signatureWithObjCTypes:"@@:"]];
    [i setTarget:self];
    [i setSelector:_selector];
    [i invoke];
    [i getReturnValue:&result];
    return result;
}
- (id)performSelector:(SEL)_selector withObject:(id)_object
{
    NSInvocation *i;
    id           result;
    IMP          msg;

    if (_selector == NULL) {
        [[[InvalidArgumentException new]
                  setReason:@"passed NULL selector to performSelector:"] raise];
    }

    if ((msg = objc_msg_lookup(self, _selector)))
        return msg(self, _selector, _object);
    
    i = [NSInvocation invocationWithMethodSignature:
                        [NSMethodSignature signatureWithObjCTypes:"@@:@"]];
    [i setTarget:self];
    [i setSelector:_selector];
    [i setArgument:&_object atIndex:2];
    [i invoke];
    [i getReturnValue:&result];
    return result;
}
- (id)performSelector:(SEL)_selector withObject:(id)_object withObject:(id)_object2
{
    NSInvocation *i;
    id           result;
    IMP          msg;

    if (_selector == NULL) {
        [[[InvalidArgumentException new]
                  setReason:@"passed NULL selector to performSelector:"] raise];
    }

    if ((msg = objc_msg_lookup(self, _selector)))
        return msg(self, _selector, _object, _object2);
    
    i = [NSInvocation invocationWithMethodSignature:
                        [NSMethodSignature signatureWithObjCTypes:"@@:@@"]];
    [i setTarget:self];
    [i setSelector:_selector];
    [i setArgument:&_object  atIndex:2];
    [i setArgument:&_object2 atIndex:3];
    [i invoke];
    [i getReturnValue:&result];
    return result;
}

- (id)self
{
    return self;
}

- (NSZone *)zone
{
    return NSZoneFromObject((NSObject *)self);
}

- (BOOL)isEqual:(id)_object
{
    NSInvocation *i = _makeInvocation1(self, _cmd, "C@:@", _object);
    BOOL result;

    [i invoke];
    [i getReturnValue:&result];
    return result;
}
- (unsigned)hash
{
    NSInvocation *i = _makeInvocation(self, _cmd, "I@:");
    unsigned hc;
    [i invoke];
    [i getReturnValue:&hc];
    return hc;
}

// ******************** forwarding ********************

- (retval_t)forward:(SEL)_selector:(arglist_t)argFrame {
  void         *result;
  NSInvocation *invocation;
#if defined(NeXT_RUNTIME) && !defined(BROKEN_BUILTIN_APPLY) && defined(i386)
  const char   *retType;
#endif

#if NeXT_RUNTIME
  /*  On NeXT the argFrame represents the stack zone with all the arguments.
      We create a frame like that required by __builtin_apply. This is done
      by __builtin_apply_args. This builtin function also sets correctly the
      structure value return address if any. */
  arglist_t frame = __builtin_apply_args();

  frame->arg_ptr = (void*)argFrame;
  argFrame = frame;
#endif

  invocation = [NSInvocation invocationWithMethodSignature:
                               [self methodSignatureForSelector:_selector]];
  [invocation setArgumentFrame:argFrame];
  [invocation setTarget:self];
  [invocation setSelector:_selector];

  [self forwardInvocation:invocation];

  result = [invocation returnFrame];
  
#if GNU_RUNTIME
  return result;
#else // NeXT_RUNTIME
# if !defined(BROKEN_BUILTIN_APPLY) && defined(i386)
  /* Special hack to avoid pushing the poped float value back to the fp
     stack on i386 machines. This happens with NeXT runtime and 2.7.2
     compiler. If the result value is floating point don't call
     __builtin_return anymore. */
  retType = [[invocation methodSignature] methodReturnType];
  if(*retType == _C_FLT || *retType == _C_DBL) {
    long double value = *(long double*)(((char*)result) + 8);
    asm("fld %0" : : "f" (value));
  }
  else
# endif
    __builtin_return(result);
#endif /* NeXT_RUNTIME */
}

@end

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
