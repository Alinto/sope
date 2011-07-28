/* 
   EOAdaptorChannel.m

   Copyright (C) 1996 Free Software Foundation, Inc.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>
   Date: October 1996

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
// $Id: EOFaultHandler.m 1 2004-08-20 10:38:46Z znek $

#include "EOFaultHandler.h"
#include "EOFault.h"
#include "common.h"

#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
#  define METHOD_NULL NULL
#  define class_get_super_class class_getSuperclass
#  define object_is_instance(object) (object!=nil?YES:NO)
#  define class_get_instance_method  class_getInstanceMethod
typedef struct objc_method      *Method_t;
#endif

#if NeXT_RUNTIME
#  if !defined(METHOD_NULL)
#    define METHOD_NULL NULL
#  endif
#endif

#if defined (__GNUSTEP_RUNTIME__)
#  define class_get_instance_method class_getInstanceMethod
#endif


@implementation EOFaultHandler

- (void)setTargetClass:(Class)_class extraData:(void *)_extraData {
  self->targetClass = _class;
  self->extraData   = _extraData;
}

- (Class)targetClass; {
  return self->targetClass;
}
- (void *)extraData {
  return self->extraData;
}

/* firing */

- (BOOL)shouldPerformInvocation:(NSInvocation *)_invocation {
  return YES;
}

- (void)faultWillFire:(EOFault *)_fault {
}

- (void)completeInitializationOfObject:(id)_object {
  [self doesNotRecognizeSelector:_cmd];
}

/* fault reflection */

- (Class)classForFault:(EOFault *)_fault {

#if GNU_RUNTIME && !defined(__GNUSTEP_RUNTIME__)

  return (object_is_instance(_fault))
    ? [self targetClass]
    : (*(Class *)_fault);
#else
#  warning TODO: add complete implementation for Apple/NeXT runtime!
  return [self targetClass];
#endif
}

- (BOOL)respondsToSelector:(SEL)_selector forFault:(EOFault *)_fault {
  Class class;

  /* first check whether fault itself responds to selector */
#if GNU_RUNTIME && !defined(__GNUSTEP_RUNTIME__)
  if (class_get_instance_method(*(Class *)_fault, _selector) != METHOD_NULL)
    return YES;
#else
#  warning TODO: add implementation for NeXT/Apple runtime!
#endif

  /* then check whether the target class does */
  class = [self targetClass];
#if GNU_RUNTIME && !defined(__GNUSTEP_RUNTIME__)
  return (class_get_instance_method(class, _selector) != NULL) ? YES : NO;
#else
#  warning TODO: use NeXT/Apple runtime function
  return [(NSObject *)class methodForSelector:_selector] ? YES : NO;
#endif
}

- (BOOL)conformsToProtocol:(Protocol *)_protocol forFault:(EOFault *)_fault {
  Class class, sClass;

#if GNU_RUNTIME && !defined(__GNUSTEP_RUNTIME__) && __GNU_LIBOBJC__ != 20100911
  struct objc_protocol_list* protos;
  int i;
  
  class = object_is_instance(_fault) ? [self targetClass] : (Class)_fault;
  for (protos = class->protocols; protos; protos = protos->next) {
    for (i = 0; i < protos->count; i++) {
      if ([protos->list[i] conformsToProtocol:_protocol])
        return YES;
    }
  }
#else
#  warning TODO: implement on NeXT/Apple runtime!
  class = [self targetClass];
#endif

  return ((sClass = [class superclass]))
    ? [sClass conformsToProtocol:_protocol]
    : NO;
}

- (BOOL)isKindOfClass:(Class)_class forFault:(EOFault *)_fault {
  Class class;

#if GNU_RUNTIME && !defined(__GNUSTEP_RUNTIME__)
  class = object_is_instance(_fault) ? [self targetClass] : (Class)_fault;
  for (; class != Nil; class = class_get_super_class(class)) {
    if (class == _class)
      return YES;
  }
#else
#  warning TODO: add implementation for NeXT/Apple runtime!
  class = [self targetClass];
#endif
  return NO;
}

- (BOOL)isMemberOfClass:(Class)_class forFault:(EOFault *)_fault {
  Class class;
#if GNU_RUNTIME && !defined(__GNUSTEP_RUNTIME__)
  class = object_is_instance(_fault) ? [self targetClass] : (Class)_fault;
#else
#  warning TODO: add implementation for NeXT/Apple runtime!
  class = [self targetClass];
#endif
  return class == _class ? YES : NO;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)_selector
  forFault:(EOFault *)_fault
{
#if NeXT_Foundation_LIBRARY || defined(__GNUSTEP_RUNTIME__)
  // probably incorrect
  return [_fault methodSignatureForSelector:_selector];
#else
  register const char *types = NULL;

  if (_selector == NULL) // invalid selector
    return nil;

#if GNU_RUNTIME && 0
  // GNU runtime selectors may be typed, a lookup may not be necessary
  types = aSelector->sel_types;
#endif

  /* first check for EOFault's own methods */

#if __GNU_LIBOBJC__ != 20100911
  if (types == NULL) {
    // lookup method for selector
    struct objc_method *mth;
    mth = class_get_instance_method(*(Class *)_fault, _selector);
    if (mth) types = mth->method_types;
  }
  
  /* then check in target class methods */
  
  if (types == NULL) {
    // lookup method for selector
    struct objc_method *mth;
    mth = class_get_instance_method([self targetClass], _selector);
    if (mth) types = mth->method_types;
  }
#endif 
 
#if GNU_RUNTIME
  // GNU runtime selectors may be typed, a lookup may not be necessary
  if (types == NULL)
    types = _selector->sel_types;
#endif
  if (types == NULL)
    return nil;
  
  return [NSMethodSignature signatureWithObjCTypes:types];
#endif
}

/* description */

- (NSString *)descriptionForObject:(id)_fault {
  return [NSString stringWithFormat:@"<%@[0x%p]: on=%@>",
                     NSStringFromClass(*(Class *)_fault),
                     _fault,
                     NSStringFromClass([self targetClass])];
}

@end /* EOFaultHandler */
