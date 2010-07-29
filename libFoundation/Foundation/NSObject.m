/* 
   NSObject.m

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
#include <stdio.h>

#include <Foundation/common.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSException.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSTimer.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSValue.h>
#include <extensions/objc-runtime.h>
#include <Foundation/exceptions/FoundationExceptions.h>

#include "exceptions/FoundationExceptions.h"
#include "NSFrameInvocation.h"
#include "NSObject+PropLists.h"

/* this one is quite experimental, it avoids calls to NSZoneFromObject */
#define DO_NOT_USE_ZONE 1

extern NSRecursiveLock* libFoundationLock;

@interface _NSObjectDelayedExecutionHolder : NSObject
{
    id target;
    id argument;
    SEL selector;
}
+ holderForTarget:(id)target argument:(id)argument selector:(SEL)action;
- (BOOL)isEqual:(_NSObjectDelayedExecutionHolder *)anotherHolder;
- (void)execute;
@end


@implementation _NSObjectDelayedExecutionHolder

+ (id)holderForTarget:(id)_target argument:(id)_argument selector:(SEL)action
{
    _NSObjectDelayedExecutionHolder* holder = AUTORELEASE([self alloc]);

    holder->target   = RETAIN(_target);
    holder->argument = RETAIN(_argument);
    holder->selector = action;
    return holder;
}

- (unsigned)hash
{
  return [(NSObject *)self->target hash];
}

- (BOOL)isEqual:(_NSObjectDelayedExecutionHolder *)anotherHolder
{
    return [(NSObject *)self->target isEqual:anotherHolder->target]
	    && [(NSObject *)self->argument isEqual:anotherHolder->argument]
	    && SEL_EQ(self->selector, anotherHolder->selector);
}

- (void)execute
{
    [self->target performSelector:selector withObject:argument];
}

@end /* _NSObjectDelayedExecutionHolder */

Class lfNSZoneClass = Nil; /* cache NSZone class */

@implementation NSObject

static BOOL 
objc_runtime_exception(id object, int code, const char* fmt, va_list ap)
{
#if 0
#  warning TEST LOG, REMOVE ME!
    printf("ObjC: object=0x%p code=%i\n", object, code);
    if (fmt != NULL)
	vprintf(fmt, ap);
#endif
    
    [[[ObjcRuntimeException alloc] initWithFormat:
		    @"Objective-C runtime error: %@",
		    Avsprintf([NSString stringWithCString:fmt], ap)] raise];
    return NO;
}

/* Class variables */
static NSMutableDictionary* delayedExecutions = nil;
	/* dictionary of _NSObjectDelayedExecutionHolder -> timer */

/* Initializing the Class */

+ (void)initialize
{
    static BOOL initialized = NO;
    
    if(!initialized) {
	initialized = YES;
	lfNSZoneClass = [NSZone class];
#if GNU_RUNTIME
        objc_msg_lookup([NSZone class], @selector(initialize))
            ([NSZone class], @selector(initialize));
#else
	[NSZone performSelector:@selector(initialize)];
#endif
	objc_set_error_handler(objc_runtime_exception);
	delayedExecutions = [NSMutableDictionary new];
    }
}

/* Creating and Destroying Instances */

#if LIB_FOUNDATION_BOEHM_GC

+ (BOOL)requiresTypedMemory
{
    return NO;
}

#endif

+ (id)alloc
{
    return [self allocWithZone:NULL];
}

+ (id)allocWithZone:(NSZone*)zone
{
    return NSAllocateObject(self, 0, zone);
}

+ (id)new
{
    return [[self alloc] init];
}

#if LIB_FOUNDATION_BOEHM_GC
- (void)gcFinalize
{
#if 1
    fprintf(stderr, "finalize 0x%p<%s>\n",
            self,
            ((*(Class *)self != NULL) ? (*(Class *)self)->name : "NULL"));
    fflush(stderr);
#endif
}
#endif

- (void)dealloc
{
#if !LIB_FOUNDATION_BOEHM_GC
    NSDeallocateObject(self);
#endif
}

+ (void)dealloc
{
}

- (id)init
{
    return self;
}

/* Testing Class Functionality */

+ (BOOL)instancesRespondToSelector:(SEL)aSelector
{
    return aSelector
		? class_get_instance_method(self, aSelector) != METHOD_NULL
		: NO;
}

/* Testing Protocol Conformance */

+ (BOOL)conformsToProtocol:(Protocol*)aProtocol
{
    int i;
    struct objc_protocol_list *protos;

    for(protos = ((struct objc_class*)self)->protocols;
	    protos; protos = protos->next) {
	for(i = 0; i < protos->count; i++)
	    if([protos->list[i] conformsTo:aProtocol])
		return YES;
    }

    if([self superclass])
	return [[self superclass] conformsToProtocol: aProtocol];
    else return NO;
}

- (BOOL)conformsToProtocol:(Protocol*)aProtocol
{
    int i;
    struct objc_protocol_list *protos;

    for(protos = ((struct objc_class*)self)->class_pointer->protocols;
	    protos; protos = protos->next) {
	for(i = 0; i < protos->count; i++)
	    if([protos->list[i] conformsTo:aProtocol])
		return YES;
    }

    if([self superclass])
	return [[self superclass] conformsToProtocol: aProtocol];
    else return NO;
}

/* Identifying Class and Superclass */

- (Class)class
{
    return object_get_class(self);
}

- (Class)superclass
{
    return object_get_super_class(self);
}

/* Testing Class Functionality */

- (BOOL)respondsToSelector: (SEL)aSelector
{
    if (aSelector == NULL)
	return NO;
    
    return (object_is_instance(self)
            ? (class_get_instance_method(self->isa, aSelector) != METHOD_NULL)
            : (class_get_class_method(self->isa, aSelector)    != METHOD_NULL));
}

/* Managing Reference Counts */

- (id)autorelease
{
#if !LIB_FOUNDATION_BOEHM_GC
    extern void NSAutoreleasePool_AutoreleaseObject(id aObject);
    NSAutoreleasePool_AutoreleaseObject(self);
#endif
    return self;
}

+ (id)autorelease
{
    return self;
}

- (oneway void)release
{
#if !LIB_FOUNDATION_BOEHM_GC
    extern BOOL __autoreleaseEnableCheck;
    // check if retainCount is Ok
    if (__autoreleaseEnableCheck) {
	unsigned int toCome = [NSAutoreleasePool autoreleaseCountForObject:self];
	if (toCome+1 > [self retainCount]) {
	    NSLog(@"Release[%p<%@>] release check for object %@ "
                  @"has %d references "
	    	  @"and %d pending calls to release in autorelease pools\n", 
		  self, NSStringFromClass([self class]),
                  self,
                  [self retainCount], toCome);
	    return;
	}
    }
    if (NSExtraRefCount(self) == 1)
	[self dealloc];
    else
	NSDecrementExtraRefCountWasZero(self);
#endif
}

+ (oneway void)release
{
}

- (id)retain
{
#if !LIB_FOUNDATION_BOEHM_GC
    NSIncrementExtraRefCount(self);
#endif
    return self;
}

+ (id)retain
{
    return self;
}

- (unsigned int)retainCount
{
    return NSExtraRefCount(self);
}

+ (unsigned int)retainCount
{
    return (unsigned)-1;
}

/* Obtaining Method Information */

+ (IMP)instanceMethodForSelector:(SEL)aSelector
{
    if (!aSelector)
	return NULL;

    return aSelector
		? method_get_imp(class_get_instance_method(self, aSelector))
		: NULL;
}

- (IMP)methodForSelector:(SEL)aSelector
{
    if (aSelector == NULL)
	return NULL;

    return method_get_imp(object_is_instance(self)
                          ? class_get_instance_method(self->isa, aSelector)
			  : class_get_class_method(self->isa, aSelector));
}

+ (NSMethodSignature *)instanceMethodSignatureForSelector:(SEL)aSelector
{
    struct objc_method* mth;

    if (!aSelector)
	return nil;

    mth = class_get_instance_method(self, aSelector);
    return mth
	? [NSMethodSignature signatureWithObjCTypes:mth->method_types]
	: (NSMethodSignature *)nil;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    register const char *types = NULL;

    if (aSelector == NULL) // invalid selector
	return nil;

#if GNU_RUNTIME && 0
    // GNU runtime selectors may be typed, a lookup may not be necessary
    types = aSelector->sel_types;
#endif
    if (types == NULL) {
        // lookup method for selector
        struct objc_method *mth;
        mth = (object_is_instance(self) ?
               class_get_instance_method(self->isa, aSelector)
               : class_get_class_method(self->isa, aSelector));
        if (mth) types = mth->method_types;
    }
#if GNU_RUNTIME
    // GNU runtime selectors may be typed, a lookup may not be necessary
    if (types == NULL)
        types = aSelector->sel_types;
#endif
    if (types == NULL) {
        /* construct a id-signature */
        register const char *sel;
        if ((sel = sel_get_name(aSelector))) {
            register int colCount = 0;
            static char *idSigs[] = {
                "@@:", "@@:@", "@@:@@", "@@:@@@", "@@:@@@@", "@@:@@@@@",
                "@@:@@@@@@", "@@:@@@@@@", "@@:@@@@@@@", "@@:@@@@@@@@"
            };
            
            while (*sel) {
                if (*sel == ':')
                    colCount++;
                sel++;
            }
            types = idSigs[colCount];
        }
        else
            return nil;
    }

    //    NSLog(@"types: %s", types);
    return [NSMethodSignature signatureWithObjCTypes:types];
}

/* property lists */

- (NSString *)propertyListStringWithLocale:(NSDictionary *)_locale
  indent:(unsigned int)_indent
{
    if ([self respondsToSelector:@selector(descriptionWithLocale:indent:)])
        return [self descriptionWithLocale:_locale indent:_indent];
    if ([self respondsToSelector:@selector(descriptionWithLocale:)])
        return [self descriptionWithLocale:_locale];
    if ([self respondsToSelector:@selector(stringRepresentation)])
        return [self stringRepresentation];
    
    return [self description];
}

/* Describing the Object */

- (NSString*)description
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[512];

    sprintf (buffer, "<%s %p>", (char*)object_get_class_name(self), self);
    return [NSString stringWithCString:buffer];
}

+ (NSString*)description
{
    /* Don't use -[NSString stringWithFormat:] method because it can cause
       infinite recursion. */
    char buffer[512];

    sprintf (buffer, "<class %s>", (char*)object_get_class_name(self));
    return [NSString stringWithCString:buffer];
}

/* Obtaining a string representation */

- (NSString*)stringRepresentation
{
    return [self description];
}

+ (void)poseAsClass:(Class)aClass
{
    class_pose_as(self, aClass);
}

/* Error Handling */

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
    /* Don't use initWithFormat: here because it can cause infinite
       recursion. */
    char buffer[512];

    sprintf (buffer, "%s (%s) does not recognize %s",
	      object_get_class_name(self),
	      CLS_ISCLASS(isa) ? "instance" : "class",
	      aSelector ? sel_get_name(aSelector) : "\"null selector\"");
    [[[ObjcRuntimeException alloc]
	      setReason:[NSString stringWithCString:buffer]] raise];
}

/* Sending Deferred Messages */

+ (void)cancelPreviousPerformRequestsWithTarget:(id)target
  selector:(SEL)aSelector
  object:(id)anObject
{
    id holder = [_NSObjectDelayedExecutionHolder holderForTarget:target
						  argument:anObject
						  selector:aSelector];

    [libFoundationLock lock];
    [delayedExecutions removeObjectForKey:holder];
    [libFoundationLock unlock];
}

- (void)performSelector:(SEL)aSelector
  withObject:(id)anObject
  afterDelay:(NSTimeInterval)delay
{
    NSTimer* timer;
    _NSObjectDelayedExecutionHolder* holder;
    
    if (delay == 0.0) {
        /* hh: is this correct ??? (double as bool, immediate exec) */
	[self performSelector:aSelector withObject:anObject];
	return;
    }

    holder = [_NSObjectDelayedExecutionHolder holderForTarget:self
					      argument:anObject
					      selector:aSelector];
    timer = [NSTimer timerWithTimeInterval:delay
		      target:self
		      selector:@selector(_performDelayedExecution:)
		      userInfo:holder
		      repeats:NO];

    [libFoundationLock lock];
    [delayedExecutions setObject:timer forKey:holder];
    [libFoundationLock unlock];

    [[NSRunLoop currentRunLoop]
	addTimer:timer forMode:NSDefaultRunLoopMode];
}

- (void)_performDelayedExecution:(NSTimer*)timer
{
  id holder = [timer userInfo];

  [holder execute];
}

/* Forwarding Messages */

- (void)forwardInvocation:(NSInvocation*)anInvocation
{
    return [self doesNotRecognizeSelector:[anInvocation selector]];
}

/* Archiving */

- (id)awakeAfterUsingCoder:(NSCoder*)aDecoder
{
    return self;
}

- (Class)classForArchiver
{
    return [self classForCoder];
}

- (Class)classForCoder
{
    return [self class];
}

- (id)replacementObjectForArchiver:(NSArchiver*)anArchiver
{
    return [self replacementObjectForCoder:(NSCoder*)anArchiver];
}

- (id)replacementObjectForCoder:(NSCoder*)anEncoder
{
    return self;
}

+ (void)setVersion:(int)version
{
    class_set_version(self, version);
}

+ (int)version
{
    return class_get_version(self);
}

- (unsigned)hash
{
    return (unsigned)(unsigned long)self;
}

/* Identifying and Comparing Instances */

- (BOOL)isEqual:(id)anObject
{
    return self == anObject;
}

- (id)self
{
    return self;
}

/* Determining Allocation Zones */

- (NSZone *)zone
{
#if DO_NOT_USE_ZONE
    return NULL;
#else
    return NSZoneFromObject(self);
#endif
}

/* Sending Messages Determined at Run Time */

- (id)performSelector:(SEL)aSelector
{
    IMP msg = aSelector ? objc_msg_lookup(self, aSelector) : NULL;

    if(msg == NULL) {
	[[[ObjcRuntimeException alloc] initWithFormat:
	    @"invalid selector `%s' passed to %s",
	    sel_get_name(aSelector), sel_get_name(_cmd)] raise];
    }
    return (*msg)(self, aSelector);
}

- (id)performSelector:(SEL)aSelector withObject:(id)anObject
{
    struct objc_method  *mth;
    const char *argType;

    if (aSelector == NULL) {
	[[[ObjcRuntimeException alloc]
	    initWithFormat:@"invalid selector `%s' passed to %s",
	    sel_get_name(aSelector), sel_get_name(_cmd)] raise];
    }
    
    *(&mth) = object_is_instance(self)
        ? class_get_instance_method([self class], aSelector)
        : class_get_class_method([self class], aSelector);
    
    if (mth == NULL) {
        NSMethodSignature *signature;
        NSInvocation      *invocation;
        const char        *retType, *argType;
        int          i;
        unsigned int ui;

        NSAssert1(mth == NULL, @"where does the method come from (sel=%@) ???",
                  NSStringFromSelector(aSelector));
        
        if ((signature = [self methodSignatureForSelector:aSelector]) == nil)
            [self doesNotRecognizeSelector:aSelector];

        argType    = [signature getArgumentTypeAtIndex:2];
        retType    = [signature methodReturnType];
        invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self]; 
        [invocation setSelector:aSelector];
        
        switch (*argType) {
            case _C_ID:
            case _C_CLASS:
                [invocation setArgument:&anObject atIndex:2];
                break;
                
            case _C_INT: {
                i = [anObject intValue];
                [invocation setArgument:&i atIndex:2];
                break;
            }
            case _C_UINT: {
                ui = [anObject unsignedIntValue];
                [invocation setArgument:&ui atIndex:2];
                break;
            }

            case '\0':
                /* no method argument specified ! */
                break;
            
            default:
                [NSException raise:@"UnsupportedType"
                             format:@"unsupported argument type '%s' !",argType];
        }

        [invocation invoke];
        
        switch (*retType) {
            case _C_VOID:
                return self;
                
            case _C_CLASS:
            case _C_ID: {
                [invocation getReturnValue:&anObject];
                return anObject;
            }

            case _C_CHR: {
                char c;
                [invocation getReturnValue:&c];
                return [NSNumber numberWithChar:c];
            }
            case _C_UCHR: {
                unsigned char c;
                [invocation getReturnValue:&c];
                return [NSNumber numberWithUnsignedChar:c];
            }
            case _C_INT: {
                int i;
                [invocation getReturnValue:&i];
                return [NSNumber numberWithInt:i];
            }
            case _C_UINT: {
                unsigned int i;
                [invocation getReturnValue:&i];
                return [NSNumber numberWithUnsignedInt:i];
            }
            
            default:
                [NSException raise:@"UnsupportedType"
                             format:@"unsupported return type '%s' !",retType];
        }
    }
    
    argType = mth->method_types;
    if (*argType == _C_VOID) {
        const char *astype;
        
        argType = objc_skip_argspec(argType); /* skip return */
        argType = objc_skip_argspec(argType); /* skip self   */
        argType = objc_skip_argspec(argType); /* skip _cmd   */
        astype  = objc_skip_type_qualifiers(argType);

        switch (*astype) {
            case _C_ID: {
                void (*f)(id, SEL, id);
                f = (void*)mth->method_imp;
                
                (*f)(self, aSelector, anObject);
                return self;
            }
            case _C_CHR:
                ((void (*)(id, SEL, char))mth->method_imp)
                    (self, aSelector, [anObject charValue]);
                return self;
            case _C_UCHR:
                ((void (*)(id, SEL, unsigned char))mth->method_imp)
                    (self, aSelector, [anObject unsignedCharValue]);
                return self;
            case _C_SHT:
                ((void (*)(id, SEL, short))mth->method_imp)
                    (self, aSelector, [anObject shortValue]);
                return self;
            case _C_USHT:
                ((void (*)(id, SEL, unsigned short))mth->method_imp)
                    (self, aSelector, [anObject unsignedShortValue]);
                return self;
            case _C_INT:
                ((void (*)(id, SEL, int))mth->method_imp)
                    (self, aSelector, [anObject intValue]);
                return self;
            case _C_UINT:
                ((void (*)(id, SEL, unsigned int))mth->method_imp)
                    (self, aSelector, [anObject unsignedIntValue]);
                return self;
            case _C_LNG:
                ((void (*)(id, SEL, long))mth->method_imp)
                    (self, aSelector, [anObject longValue]);
                return self;
            case _C_ULNG:
                ((void (*)(id, SEL, unsigned long))mth->method_imp)
                    (self, aSelector, [anObject unsignedLongValue]);
                return self;
            case _C_FLT:
                ((void (*)(id, SEL, float))mth->method_imp)
                    (self, aSelector, [anObject floatValue]);
                return self;
            case _C_DBL:
                ((void (*)(id, SEL, double))mth->method_imp)
                    (self, aSelector, [anObject doubleValue]);
        
                return self;
            case '\0':
                /* no further argument */
                ((void (*)(id, SEL))mth->method_imp)(self, aSelector);
                return self;
        
            default:
                [NSException raise:@"UnsupportedType"
                             format:
                               @"unsupported argument type '%s' !", argType];
                return nil;
        }
    }
    else {
        const char *astype, *rettype;

        rettype = argType;
        argType = objc_skip_argspec(argType); /* skip return */
        argType = objc_skip_argspec(argType); /* skip self   */
        argType = objc_skip_argspec(argType); /* skip _cmd   */
        astype  = objc_skip_type_qualifiers(argType);

        switch (*astype) {
            case _C_ID:
                return mth->method_imp(self, aSelector, anObject);
            case _C_CHR:
                return ((id (*)(id, SEL, char))mth->method_imp)
                    (self, aSelector, [anObject charValue]);
            case _C_UCHR:
                return ((id (*)(id, SEL, unsigned char))mth->method_imp)
                    (self, aSelector, [anObject unsignedCharValue]);
            case _C_SHT:
                return ((id (*)(id, SEL, short))mth->method_imp)
                    (self, aSelector, [anObject shortValue]);
            case _C_USHT:
                return ((id (*)(id, SEL, unsigned short))mth->method_imp)
                    (self, aSelector, [anObject unsignedShortValue]);
            case _C_INT:
                return ((id (*)(id, SEL, int))mth->method_imp)
                    (self, aSelector, [anObject intValue]);
            case _C_UINT:
                return ((id (*)(id, SEL, unsigned int))mth->method_imp)
                    (self, aSelector, [anObject unsignedIntValue]);
            case _C_LNG:
                return ((id (*)(id, SEL, long))mth->method_imp)
                    (self, aSelector, [anObject longValue]);
            case _C_ULNG:
                return ((id (*)(id, SEL, unsigned long))mth->method_imp)
                    (self, aSelector, [anObject unsignedLongValue]);
            case _C_FLT:
                return ((id (*)(id, SEL, float))mth->method_imp)
                    (self, aSelector, [anObject floatValue]);
            case _C_DBL:
                return ((id (*)(id, SEL, double))mth->method_imp)
                    (self, aSelector, [anObject doubleValue]);
        
            case '\0':
                /* no further argument */
                return ((id (*)(id, SEL))mth->method_imp)(self, aSelector);
        
            default:
                [NSException raise:@"UnsupportedType"
                             format:
                               @"unsupported argument type '%s' !", argType];
                return nil;
        }
    }
}

- (id)performSelector:(SEL)aSelector
  withObject:(id)anObject
  withObject:(id)anotherObject
{
    IMP msg = aSelector ? objc_msg_lookup(self, aSelector) : NULL;

    if(!msg) {
	[[[ObjcRuntimeException alloc]
	    initWithFormat:@"invalid selector `%s' passed to %s",
	    sel_get_name(aSelector), sel_get_name(_cmd)] raise];
    }
    return (*msg)(self, aSelector, anObject, anotherObject);
}

- (id)perform:(SEL)aSelector
{
    IMP msg = aSelector ? objc_msg_lookup(self, aSelector) : NULL;

    if(!msg) {
	[[[ObjcRuntimeException alloc] initWithFormat:
	    @"invalid selector `%s' passed to %s",
	    sel_get_name(aSelector), sel_get_name(_cmd)] raise];
    }
    return (*msg)(self, aSelector);
}

- (id)perform:(SEL)aSelector withObject:(id)anObject
{
    IMP msg = aSelector ? objc_msg_lookup(self, aSelector) : NULL;

    if(msg == NULL) {
	[[[ObjcRuntimeException alloc]
	    initWithFormat:@"invalid selector `%s' passed to %s",
	    sel_get_name(aSelector), sel_get_name(_cmd)] raise];
    }
    return (*msg)(self, aSelector, anObject);
}

- (id)perform:(SEL)aSelector
  withObject:(id)anObject
  withObject:(id)anotherObject
{
    IMP msg = aSelector ? objc_msg_lookup(self, aSelector) : NULL;

    if(msg == NULL) {
	[[[ObjcRuntimeException alloc]
	    initWithFormat:@"invalid selector `%s' passed to %s",
	    sel_get_name(aSelector), sel_get_name(_cmd)] raise];
    }
    return (*msg)(self, aSelector, anObject, anotherObject);
}

/* Identifying Proxies */

- (BOOL)isProxy
{
    return NO;
}

/* Testing Inheritance Relationships */

+ (BOOL)isKindOfClass:(Class)aClass
{
    Class class;
    
    for (class = self; class != Nil; class = class_get_super_class(class))
	if(class == aClass)
	    return YES;
    return NO;
}
- (BOOL)isKindOfClass:(Class)aClass
{
    Class class;

    for(class = self->isa; class != Nil; class = class_get_super_class(class))
	if(class == aClass)
	    return YES;
    return NO;
}

- (BOOL)isMemberOfClass:(Class)aClass
{
    return self->isa == aClass;
}

/* NSCopying/NSMutableCopying shortcuts */

- (id)copy
{
    return [(id<NSCopying>)self copyWithZone:NULL];
}

- (id)mutableCopy
{
    return [(id<NSMutableCopying>)self mutableCopyWithZone:NULL];
}

#if 0
- (void)gcFinalize
{
    fprintf (stderr, "%u (%s) will finalize\n", self, self->isa->name);
}
#endif

@end /* NSObject */


@implementation NSObject (GNU)

- (Class)transmuteClassTo:(Class)aClassObject
{
    if(object_is_instance(self) && class_is_class(aClassObject)
		&& (class_get_instance_size(aClassObject)
				== class_get_instance_size(isa))
		&& [self isKindOfClass:aClassObject]) {
	Class old_isa = isa;
	isa = aClassObject;
	return old_isa;
    }
    return nil;
}

- (id)subclassResponsibility:(SEL)aSel
{
    id exception = [[ObjcRuntimeException alloc]
			    initWithFormat:@"subclass %s should override %s",
                            object_get_class_name(self),
			    sel_get_name(aSel)];
    [exception raise];
    return self;
}

- (id)shouldNotImplement:(SEL)aSel
{
    id exception = [[ObjcRuntimeException alloc]
			    initWithFormat:@"%s should not implement %s",
			    object_get_class_name(self), sel_get_name(aSel)];
    [exception raise];
    return self;
}

- (id)notImplemented:(SEL)aSel
{
    id exception = [[ObjcRuntimeException alloc]
			    initWithFormat:@"%s does not implement %s",
			    object_get_class_name(self), sel_get_name(aSel)];
    [exception raise];
    return self;
}

- (retval_t)forward:(SEL)aSel :(arglist_t)argFrame
{
    void* result;
    NSInvocation* invocation;
#if defined(NeXT_RUNTIME) && !defined(BROKEN_BUILTIN_APPLY) && defined(i386)
    const char* retType;
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

    invocation = AUTORELEASE([NSFrameInvocation new]);
    [invocation setArgumentFrame:argFrame];
    [invocation setSelector:aSel];
    [invocation setTarget:self];

    [self forwardInvocation:invocation];

    result = [invocation returnFrame];

#if GNU_RUNTIME
    return result;
#else /* NeXT_RUNTIME */
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

@end /* NSObject (GNU) */


@implementation NSObject (GNUDebugger)

/* The following two methods are necessary to make GDB to work correctly with
   Foundation objects */

- (BOOL)respondsTo: (SEL)aSelector
{
    return (object_is_instance(self) ?
	  (class_get_instance_method(self->isa, aSelector) != METHOD_NULL)
	: (class_get_class_method(self->isa, aSelector) != METHOD_NULL));
}

- (IMP)methodFor:(SEL)aSelector
{
    return method_get_imp(object_is_instance(self) ?
			      class_get_instance_method(self->isa, aSelector)
			    : class_get_class_method(self->isa, aSelector));
}

@end /* NSObject (GNUDebugger) */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
