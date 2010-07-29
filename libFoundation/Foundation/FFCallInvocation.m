/* 
   NSFFCallInvocation.m

   Copyright (C) 2000, MDlink online service center GmbH, Helge Hess
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
// $Id: FFCallInvocation.m 1319 2006-07-14 13:06:21Z helge $

#include "FFCallInvocation.h"
#include <Foundation/NSException.h>

@interface NSInvocation(PrivateMethods)
- (id)initWithSignature:(NSMethodSignature *)_signature;
@end

@interface FFCallInvocation(PrivateMethods)
- (void)_releaseArguments;
@end

@implementation FFCallInvocation

#if OBJC_METHOD_LOOKUP_HOOKS

static void *cb;

static IMP ffObjCMsgLookup(id self, SEL _cmd)
{
    /* invoked during method dispatch */
    return cb;
}
static IMP ffClassGetMethod(Class clazz, SEL _cmd)
{
    /* invoked during method_get */
    return cb;
}

static void freeCallback(void)
{
    if (cb) { free_callback(cb); cb = NULL; }
}

+ (void)load
{
    cb = alloc_callback(&NSInvocationCallbackDispatcher,
                        @selector(forwardInvocation:));
    atexit(&freeCallback);
    
    __objc_msg_lookup       = ffObjCMsgLookup;
    __objc_class_get_method = ffClassGetMethod;
}
#endif

+ (id)invocationWithMethodSignature:(NSMethodSignature *)_signature
{
    id o;
    o = [[self alloc] initWithSignature:_signature];
    AUTORELEASE(o);
    return o;
}

- (id)init
{
    abort();
    return nil;
}
- (id)initWithSignature:(NSMethodSignature *)_signature
{
    NSAssert(_signature, @"method signature required !");
    
    self->types = [_signature types];
    
    if ((self = [super initWithSignature:_signature])) {
        /* setup argument buffers */
        register const char *ltypes;
        unsigned total, count;
        
        ltypes = self->types;
    
        /* alloc return buffer */
        self->retvalLen = objc_sizeof_type(objc_skip_type_qualifiers(ltypes));
        self->retvalue  = malloc(self->retvalLen);
    
        ltypes = objc_skip_argspec(ltypes); // skip retval
        ltypes = objc_skip_argspec(ltypes); // skip self
        ltypes = objc_skip_argspec(ltypes); // skip _cmd
    
        /* calc total buffer size & argument count */
        for (total = 0, count = 0; *ltypes; ltypes = objc_skip_argspec(ltypes)) {
            total += objc_sizeof_type(ltypes);
            count++;
        }
    
        /* reset type-ptr to arguments */
        ltypes = self->types;
        ltypes = objc_skip_argspec(ltypes); // skip retval
        ltypes = objc_skip_argspec(ltypes); // skip self
        ltypes = objc_skip_argspec(ltypes); // skip _cmd
    
        /* allocate arg buffer */
        self->buffer   = malloc(total);
        self->idxToPtr = malloc(sizeof(void *)   * count);
        self->idxToLen = malloc(sizeof(unsigned) * count);
        for (total = 0, count = 0; *ltypes; ltypes = objc_skip_argspec(ltypes)) {
            self->idxToPtr[count] = self->buffer + total;
            self->idxToLen[count] = objc_sizeof_type(ltypes);
            total += self->idxToLen[count];
            count++;
        }
    }
    return self;
}

- (void)dealloc
{
    [self _releaseArguments];
    
    if (self->retvalue) free(self->retvalue);
    if (self->buffer)   free(self->buffer);
    if (self->idxToPtr) free(self->idxToPtr);
    if (self->idxToLen) free(self->idxToLen);
    [super dealloc];
}

static inline void
_setArg(FFCallInvocation *self, SEL _cmd, void *_value, int _idx)
{
    switch (_idx) {
        case 0:
            [self setTarget:*(id *)_value];
            break;
        case 1:
            [self setSelector:*(SEL *)_value];
        default:
            if (self->argumentsRetained) {
                ; // not supported yet
            }
            _idx -= 2;
            memcpy(self->idxToPtr[_idx], _value, self->idxToLen[_idx]);
            break;
    }
}

static inline void
_getArg(FFCallInvocation *self, SEL _cmd, void *_value, int _idx)
{
    switch (_idx) {
        case 0:
            *(id *)_value = [self target];
            break;
        case 1:
            *(SEL *)_value = [self selector];
            break;
        default:
            _idx -= 2;
            memcpy(_value, self->idxToPtr[_idx], self->idxToLen[_idx]);
            break;
    }
}

static inline void _getRetVal(FFCallInvocation *self, SEL _cmd, void *_value)
{
    memcpy(_value, self->retvalue, self->retvalLen);
}

- (void)setArgument:(void *)_value atIndex:(int)_idx
{
    _setArg(self, _cmd, _value, _idx);
}
- (void)getArgument:(void *)_value atIndex:(int)_idx
{
    _getArg(self, _cmd, _value, _idx);
}

- (void)_releaseArguments
{
    const char *ltypes;
    unsigned   idx;
    
    if (!self->argumentsRetained) return;
    self->argumentsRetained = NO;
    
    ltypes = self->types;
    if ((*ltypes == _C_ID) || (*ltypes == _C_CLASS))
        RELEASE(*(id *)self->retvalue);
    
    ltypes = objc_skip_argspec(ltypes); // skip retval
    ltypes = objc_skip_argspec(ltypes); // skip 'self'
    ltypes = objc_skip_argspec(ltypes); // skip _cmd
    RELEASE(self->target);

    for (idx = 2; *ltypes; idx++) {
        if ((*ltypes == _C_ID) || (*ltypes == _C_CLASS)) {
            id object;

            _getArg(self, _cmd, &object, idx);
            RELEASE(object);
            break;
        }
        ltypes = objc_skip_argspec(ltypes);
    }
}

- (void)retainArguments
{
    const char *ltypes;
    unsigned   idx;
  
    if (self->argumentsRetained) return;
    self->argumentsRetained = YES;
    
    ltypes = self->types;
    if ((*ltypes == _C_ID) || (*ltypes == _C_CLASS))
        RETAIN(*(id *)self->retvalue);
    
    ltypes = objc_skip_argspec(ltypes); // skip retval
    ltypes = objc_skip_argspec(ltypes); // skip 'self'
    ltypes = objc_skip_argspec(ltypes); // skip _cmd
    RETAIN(self->target);
  
    for (idx = 2; *ltypes; idx++) {
        if ((*ltypes == _C_ID) || (*ltypes == _C_CLASS)) {
            id object;

            _getArg(self, _cmd, &object, idx);
            RETAIN(object);
            break;
        }
        ltypes = objc_skip_argspec(ltypes);
    }
}

- (void)setReturnValue:(void *)_value
{
    if (self->argumentsRetained) {
        switch (*(self->types)) {
            case _C_ID:
            case _C_CLASS: {
                id old = *(id *)self->retvalue;
                RETAIN(*(id *)_value);
                RELEASE(old);
                break;
            }
        }
    }
    memcpy(self->retvalue, _value, self->retvalLen);
}
- (void)getReturnValue:(void *)_value
{
    _getRetVal(self, _cmd, _value);
}

/* invalidation */

- (void)invalidate
{
    self->isValid = NO;
    [self _releaseArguments];
}

/* invocation */

- (void)invokeWithTarget:(id)_target
{
    IMP        method;
    const char *ltypes;
    av_alist   alist;
    unsigned   idx;
    
    /* get the Objective-C type signature */
  
    ltypes  = self->types;
    
    /* find the function implementing the method */
    
    method =
        method_get_imp(class_get_instance_method(*(Class *)_target, self->selector));
    
    /* if the method couldn't be found, forward the invocation */
    
    if (method == NULL) {
        [_target forwardInvocation:self];
        return;
    }
    
    /* start with return type */
  
    switch (*ltypes) {
        case _C_VOID:
            av_start_void(alist, method);
            break;
    
        case _C_ID:
            av_start_ptr(alist, method, id, self->retvalue);
            break;
        case _C_CLASS:
            av_start_ptr(alist, method, Class, self->retvalue);
            break;
        case _C_SEL:
            av_start_ptr(alist, method, SEL, self->retvalue);
            break;
        case _C_CHARPTR:
            av_start_ptr(alist, method, char *, self->retvalue);
            break;
        case _C_PTR:
            av_start_ptr(alist, method, void *, self->retvalue);
            break;
    
        case _C_CHR:
            av_start_char(alist, method, self->retvalue);
            break;
        case _C_UCHR:
            av_start_uchar(alist, method, self->retvalue);
            break;
    
        case _C_SHT:
            av_start_short(alist, method, self->retvalue);
            break;
        case _C_USHT:
            av_start_ushort(alist, method, self->retvalue);
            break;

        case _C_LNG:
        case _C_INT:
            av_start_int(alist, method, self->retvalue);
            break;
        case _C_ULNG:
        case _C_UINT:
            av_start_uint(alist, method, self->retvalue);
            break;
    
        case _C_FLT:
            av_start_float(alist, method, self->retvalue);
            break;
        case _C_DBL:
            av_start_double(alist, method, self->retvalue);
            break;
      
        default:
            fprintf(stderr, "Unsupported return type: '%s' !\n", ltypes);
            fflush(stderr);
            abort();
    }
  
    /* push target & _cmd arguments */
  
    av_ptr(alist, id,  _target);
    av_ptr(alist, SEL, self->selector);
  
    ltypes = objc_skip_argspec(ltypes); // skip retval
    ltypes = objc_skip_argspec(ltypes); // skip self
    ltypes = objc_skip_argspec(ltypes); // skip _cmd

    /* process method arguments */
  
    for (idx = 0; *ltypes; idx++) {
        register void     *ptr;
        register unsigned len;

        ptr = self->idxToPtr[idx];
        len = self->idxToLen[idx];
    
        switch (*ltypes) {
            case _C_CLASS:
            case _C_ID: {
                id o;
                memcpy(&o, ptr, len);
                av_ptr(alist, id, o);
                break;
            }
            case _C_SEL: {
                SEL s;
                memcpy(&s, ptr, len);
                av_ptr(alist, SEL, s);
                break;
            }

            case _C_CHARPTR:
            case _C_PTR: {
                void *p;
                memcpy(&p, ptr, len);
                av_ptr(alist, void *, p);
                break;
            }
      
            case _C_CHR: {
                char c;
                memcpy(&c, ptr, len);
                av_char(alist, c);
                break;
            }
            case _C_UCHR: {
                unsigned char c;
                memcpy(&c, ptr, len);
                av_uchar(alist, c);
                break;
            }
      
            case _C_SHT: {
                short c;
                memcpy(&c, ptr, len);
                av_short(alist, c);
                break;
            }
            case _C_USHT: {
                unsigned short c;
                memcpy(&c, ptr, len);
                av_ushort(alist, c);
                break;
            }

            case _C_LNG:
            case _C_INT: {
                int c;
                memcpy(&c, ptr, len);
                av_int(alist, c);
                break;
            }
            case _C_ULNG:
            case _C_UINT: {
                unsigned int c;
                memcpy(&c, ptr, len);
                av_uint(alist, c);
                break;
            }
      
            case _C_FLT: {
                float c;
                memcpy(&c, ptr, len);
                av_float(alist, c);
                break;
            }
            case _C_DBL: {
                double c;
                memcpy(&c, ptr, len);
                av_double(alist, c);
                break;
            }
      
            default:
                fprintf(stderr, "Unsupported argument type: '%s' !\n", ltypes);
                fflush(stderr);
                abort();
        }
    
        ltypes = objc_skip_argspec(ltypes);
    }

    /* invoke method */
    av_call(alist);
}

- (NSString *)description
{
    char buf[1024];
    sprintf(buf, "<%s[0x%p]: target=0x%p selector=%s sig=%s>",
            class_get_class_name([self class]), (unsigned)self,
            (unsigned)self->target, sel_get_name(self->selector),
            self->types);
  return [NSString stringWithCString:buf];
}

/* a dispatcher function for use with ffcall's callback */

void NSInvocationCallbackDispatcher(void *dispatchSelector, va_alist args)
{
    static Class FFCallInvocationClass = Nil;
    id                returnValue;
    id                self;
    SEL               _cmd;
    NSMethodSignature *signature;
    FFCallInvocation  *invocation;
    const char *types;
    unsigned idx;
    
    if (FFCallInvocationClass == Nil)
        FFCallInvocationClass = [FFCallInvocation class];
    
    va_start_ptr(args, id);
    self = va_arg_ptr(args, id);
    _cmd = va_arg_ptr(args, SEL);
    
    /* method reflection */
    
    signature = [self methodSignatureForSelector:_cmd];
    NSAssert(signature, @"missing signature for selector '%@'",
             NSStringFromSelector(_cmd));

    // NSLog(@"sel %@ sig %@", NSStringFromSelector(_cmd), signature);
    
    /* setup invocation object */
    
    invocation =
        [[FFCallInvocationClass alloc] initWithSignature:signature];
    
    [invocation setTarget:self];
    [invocation setSelector:_cmd];
    
    types = invocation->types;
    types = objc_skip_argspec(types);
    types = objc_skip_argspec(types);
    types = objc_skip_argspec(types);
    
    for (idx = 2; *types; idx++) {
        switch (*types) {
            case _C_CLASS:
            case _C_ID: {
                id o = va_arg_ptr(args, id);
                _setArg(invocation, _cmd, &o, idx);
                break;
            }
            
            case _C_SEL: {
                SEL s = va_arg_ptr(args, SEL);
                _setArg(invocation, _cmd, &s, idx);
                break;
            }
            case _C_PTR: {
                void *ptr = va_arg_ptr(args, void *);
                _setArg(invocation, _cmd, &ptr, idx);
                break;
            }
            case _C_CHARPTR: {
                char *ptr = va_arg_ptr(args, char *);
                _setArg(invocation, _cmd, &ptr, idx);
                break;
            }

            case _C_CHR: {
                char s = va_arg_char(args);
                _setArg(invocation, _cmd, &s, idx);
                break;
            }
            case _C_UCHR: {
                unsigned char s = va_arg_uchar(args);
                _setArg(invocation, _cmd, &s, idx);
                break;
            }
            
            case _C_SHT: {
                short s = va_arg_short(args);
                _setArg(invocation, _cmd, &s, idx);
                break;
            }
            case _C_USHT: {
                unsigned short s = va_arg_ushort(args);
                _setArg(invocation, _cmd, &s, idx);
                break;
            }
            
            case _C_INT: {
                int i = va_arg_int(args);
                _setArg(invocation, _cmd, &i, idx);
                break;
            }
            case _C_UINT: {
                unsigned int i = va_arg_uint(args);
                _setArg(invocation, _cmd, &i, idx);
                break;
            }
        
            case _C_FLT: {
                float f = va_arg_float(args);
                _setArg(invocation, _cmd, &f, idx);
                break;
            }
            case _C_DBL: {
                double d = va_arg_double(args);
                _setArg(invocation, _cmd, &d, idx);
                break;
            }
            
            default:
                fprintf(stderr, "Unsupported argument type: '%s' !\n", types);
                fflush(stderr);
                abort();
        }
      
        types = objc_skip_argspec(types);
    }
    
    /* forward */
    
    //[self performSelector:dispatchSelector withObject:invocation];
    [self forwardInvocation:invocation];
    
    /* apply return value */
    _getRetVal(invocation, _cmd, &returnValue);
    
    /* invalidate invocation object */
    [invocation invalidate];
    RELEASE(invocation);
    
    /* return from dispatcher */
    va_return_ptr(args, id, returnValue);
}

@end /* FFCallInvocation */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
