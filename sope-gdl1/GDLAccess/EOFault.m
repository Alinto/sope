/* 
   EOAttributeOrdering.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: 1996

   This file is part of the GNUstep Database Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

// $Id: EOFault.m 1 2004-08-20 10:38:46Z znek $

#include "EOFault.h"
#include "EOFaultHandler.h"
#include "common.h"

#if NeXT_RUNTIME || APPLE_RUNTIME
#  include <objc/objc-class.h>
#endif

typedef struct {
    Class isa;
} *my_objc_object;

#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
#  warning TODO: implement for NeXT/Apple runtime!
#  define object_is_instance(object) (object!=nil?YES:NO)
#  define class_get_super_class class_getSuperclass
#  define class_get_class_method class_getClassMethod
#  define class_get_instance_method class_getInstanceMethod
#  define METHOD_NULL NULL
typedef struct objc_method      *Method_t;
#else
#  define object_is_instance(object) \
      ((object!=nil)&&CLS_ISCLASS(((my_objc_object)object)->isa))
#endif

#if __GNU_LIBOBJC__ == 20100911
#  define METHOD_NULL NULL
#  define class_get_super_class class_getSuperclass
#  define object_is_instance(object) (object!=nil?YES:NO)
typedef struct objc_method      *Method_t;
#endif

/*
 * EOFault class
 */

@implementation EOFault

+ (void)makeObjectIntoFault:(id)_object withHandler:(EOFaultHandler *)_handler{
  [_handler setTargetClass:[_object class] extraData:((id *)_object)[1]];

  ((EOFault *)_object)->isa           = self;
  ((EOFault *)_object)->faultResolver = [_handler retain];
}

+ (EOFaultHandler *)handlerForFault:(id)_fault {
  if (![self isFault:_fault])
    return nil;

  return ((EOFault *)_fault)->faultResolver;
}

/* Fault class methods */

+ (void)clearFault:(id)fault {
  EOFault *aFault = (EOFault*)fault;
  int refs;

  /* check if fault */
  if (aFault->isa != self)
    return;
    
  /* get fault instance reference count + 1 set in creation methods */
  refs = aFault->faultResolver->faultReferences;

  /* make clear instance */
  aFault->isa           = [aFault->faultResolver targetClass];
  aFault->faultResolver = [aFault->faultResolver autorelease];
  aFault->faultResolver = [aFault->faultResolver extraData];
  
  /*
    set references to real instance so that
    re-implemented retain/release mechanism take control
  */
  while(refs-- > 0)
    [aFault retain];
}

+ (BOOL)isFault:(id)fault {
  static Class EOFaultClass = Nil;
  Class clazz;

  if (fault == nil) return NO;
  if (EOFaultClass == Nil) EOFaultClass = [EOFault class];

#if defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
  for (clazz = ((EOFault *)fault)->isa; clazz; clazz = class_getSuperclass(clazz)) {
#else
  for (clazz = ((EOFault *)fault)->isa; clazz; clazz = clazz->super_class) {
#endif
    if (clazz == EOFaultClass)
      return YES;
  }
  return NO;
}
+ (BOOL)isFault {
  return NO; // no class faults
}
- (BOOL)isFault {
  return YES;
}

+ (Class)targetClassForFault:(id)_fault {
  EOFault *aFault = (EOFault*)_fault;

  // Check that argument is fault
  if (aFault->isa != self)
    return nil;
    
  return [aFault->faultResolver targetClass];
}

// Fault Instance methods

- (Class)superclass {
#if GNU_RUNTIME
  return (object_is_instance(self))
    ? [[self->faultResolver classForFault:self] superclass]
    : class_get_super_class((Class)self);
#else
#  warning TODO: add complete implementation for NeXT/Apple runtime!
  return [[self->faultResolver classForFault:self] superclass];
#endif
}

+ (Class)class {
  return self;
}
- (Class)class {
  return [self->faultResolver classForFault:self];
}

- (BOOL)isKindOfClass:(Class)_class; {
  return [self->faultResolver isKindOfClass:_class forFault:self];
}
- (BOOL)isMemberOfClass:(Class)_class {
  return [self->faultResolver isMemberOfClass:_class forFault:self];
}

- (BOOL)conformsToProtocol:(Protocol *)_protocol {
  return [self->faultResolver conformsToProtocol:_protocol forFault:self];
}

+ (BOOL)respondsToSelector:(SEL)_selector {
#if GNU_RUNTIME
  return class_get_instance_method(self, _selector) != NULL;
#else
#  warning TODO: add complete implementation for Apple/NeXT runtime!
  return NO;
#endif
}

- (BOOL)respondsToSelector:(SEL)_selector {
#if GNU_RUNTIME
  return (object_is_instance(self))
    ? [self->faultResolver respondsToSelector:_selector forFault:self]
    : class_get_class_method(self->isa, _selector) != METHOD_NULL;
#else
#  warning TODO: add complete implementation for Apple/NeXT runtime!
  return [self->faultResolver respondsToSelector:_selector forFault:self];
#endif
}

// ******************** retain counting ********************

+ (id)retain {
  return self;
}
- (id)retain {
  self->faultResolver->faultReferences++;
  return self;
}

+ (oneway void)release {
}
- (oneway void)release {
  if (faultResolver->faultReferences <= 0)
    [self dealloc];
  else
    faultResolver->faultReferences--;
}

+ (NSUInteger)retainCount {
  return 1;
}
- (NSUInteger)retainCount {
  // For instance
  return faultResolver->faultReferences+1;
}

+ (id)autorelease {
  return self;
}
- (id)autorelease {
  [NSAutoreleasePool addObject:self];
  return self;
}

- (NSZone *)zone {
  return NSZoneFromPointer(self);
}

- (BOOL)isProxy {
  return NO;
}
- (BOOL)isGarbageCollectable {
  return NO;
}

+ (void)dealloc {
  NSLog(@"WARNING: tried to deallocate EOFault class ..");
}
- (void)dealloc {
  [self->isa clearFault:self];
  [self dealloc];
}

/* descriptions */

- (NSString *)description {
  return [self->faultResolver descriptionForObject:self];
}
- (NSString *)descriptionWithIndent:(unsigned)level {
  return [self description];
}
- (NSString *)stringRepresentation {
  return [self description];
}
- (NSString *)eoShallowDescription {
  return [self description];
}

- (NSString *)propertyListStringWithLocale:(NSDictionary *)_locale
  indent:(int)_i
{
  return [self description];
}

/* Forwarding stuff */

+ (void)initialize {
  /*
    Must be here as initialize is called for each root class
    without asking if it responds to it !
  */
}

static inline void _resolveFault(EOFault *self) {
  EOFaultHandler *handler;
  
  /* If in class */
  if (!object_is_instance(self)) {
    [NSException raise:@"NSInvalidArgumentException"
		 format:@"used EOFault class in forward"];
  }

  handler = self->faultResolver;
  [handler completeInitializationOfObject:self];
  
  if (self->isa == [EOFault class]) {
    [NSException raise:@"NSInvalidArgumentException" 
		 format:
		   @"fault error: %@ was not cleared during fault fetching",
		   [handler descriptionForObject:self]];
  }
}

+ (id)self {
  _resolveFault(self);
  return self;
}

#if 0

- (void)setObject:(id)object forKey:(id)key {
  _resolveFault(self);
  [self setObject:object forKey:key];
}
- (id)objectForKey:(id)key {
  _resolveFault(self);
  return [self objectForKey:key];
}
- (void)removeObjectForKey:(id)key {
  _resolveFault(self);
  [self removeObjectForKey:key];
}

- (void)takeValuesFromDictionary:(NSDictionary *)dictionary {
  _resolveFault(self);
  [self takeValuesFromDictionary:dictionary];
}
- (NSDictionary *)valuesForKeys:(NSArray *)keys {
  _resolveFault(self);
  return [self valuesForKeys:keys];
}
- (BOOL)takeValue:(id)object forKey:(id)key {
  _resolveFault(self);
  return [self takeValue:object forKey:key];
}
- (id)valueForKey:(id)key {
  _resolveFault(self);
  return [self valueForKey:key];
}

- (BOOL)kvcIsPreferredInKeyPath {
  _resolveFault(self);
  return YES;
}

#endif /* 0 */

- (NSMethodSignature *)methodSignatureForSelector:(SEL)_sel {
  return [self->faultResolver methodSignatureForSelector:_sel forFault:self];
}

- (void)forwardInvocation:(NSInvocation *)_invocation {
  if ([self->faultResolver shouldPerformInvocation:_invocation]) {
    _resolveFault(self);
    [_invocation invoke];
  }
}

@end /* EOFault */

#if 0
@implementation EOFault(RealForwarding)

#if NeXT_Foundation_LIBRARY

- (void)forwardInvocation:(NSInvocation *)_inv {
  _resolveFault(self);

  [_inv setTarget:self];
  [_inv invoke];
}

#else

- (retval_t)forward:(SEL)sel:(arglist_t)args {
#if 1 && !defined(__APPLE__)
  Method_t forward;

  forward = class_get_instance_method(objc_lookup_class("NSObject"), _cmd);
  return ((retval_t (*)(id, SEL, SEL, arglist_t))forward->method_imp)
    (self, _cmd, sel, args);
#else
  struct objc_method *m;

  _resolveFault(self);
    
  if ((m = class_get_instance_method(self->isa, sel)) == NULL) {
    NSString *r;

    r = [NSString stringWithFormat:
		    @"fault error: resolved fault does not responds to selector %s",
		    sel_get_name(sel)];
    [NSException raise:@"NSInvalidArgumentException" reason:r userInfo:nil];
  }
  return objc_msg_sendv(self, sel, args);
#endif
}
#endif
@end /* EOFault(RealForwarding) */
#endif // #if 0
