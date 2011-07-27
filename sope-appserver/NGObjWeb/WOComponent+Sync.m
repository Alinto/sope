/*
  Copyright (C) 2000-2007 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOAssociation.h>
#include "common.h"

#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
#  include <objc/objc.h>
#  define class_get_instance_method class_getInstanceMethod
#  define method_get_imp method_getImplementation
#endif

@implementation WOComponent(OptimizedSynching)

/*
  optimized component synchronization. Uses extensive runtime caching.
*/

static Class lastEnumClass = Nil;
static id (*nextKey)(id, SEL);
static Class lastWocDictClass = Nil;
static id (*wocObjForKey)(id, SEL, id);

#if NeXT_RUNTIME

#define CHK_ENUM_CACHE \
  if (lastEnumClass != *(Class *)keys) {\
    lastEnumClass = *(Class *)keys;\
    nextKey = (void*)[keys methodForSelector:@selector(nextObject)];\
  }

#define CHK_WOCDICT_CACHE \
  if (lastWocDictClass != *(Class *)self->wocBindings) {\
    lastWocDictClass = *(Class *)self->wocBindings;\
    wocObjForKey = (void*)[self->wocBindings methodForSelector:@selector(objectForKey:)];\
  }

#else

#define CHK_ENUM_CACHE \
  if (lastEnumClass != *(Class *)keys) {\
    lastEnumClass = *(Class *)keys;\
    nextKey = (void*)\
      method_get_imp(class_get_instance_method(*(Class *)keys, \
        @selector(nextObject)));\
  }

#define CHK_WOCDICT_CACHE \
  if (lastWocDictClass != *(Class *)self->wocBindings) {\
    lastWocDictClass = *(Class *)self->wocBindings;\
    wocObjForKey = (void*)\
      method_get_imp(class_get_instance_method(*(Class *)self->wocBindings, \
        @selector(objectForKey:)));\
  }

#endif

void WOComponent_syncFromParent(WOComponent *self, WOComponent *_parent) {
  NSEnumerator *keys;
  NSString     *key;
  void (*takeValue)(id, SEL, id, NSString *);
  
  if ((keys = [self->wocBindings keyEnumerator]) == nil)
    return;
  
  CHK_ENUM_CACHE;
  CHK_WOCDICT_CACHE;
#if NeXT_RUNTIME
  takeValue = (void *)[self methodForSelector:@selector(takeValue:forKey:)];
#elif GNUSTEP_BASE_LIBRARY
  takeValue = (void*)method_get_imp(class_get_instance_method(self->isa,
                @selector(setValue:forKey:)));
#else  
  takeValue = (void*)method_get_imp(class_get_instance_method(self->isa,
                @selector(takeValue:forKey:)));
#endif
  
  while ((key = nextKey(keys, @selector(nextObject))) != nil) {
    static   Class lastAssocClass = Nil; // THREAD
    static   id    (*valInComp)(id, SEL, WOComponent *);
    register WOAssociation *binding;
    register id value;
    
    binding = wocObjForKey(self->wocBindings, @selector(objectForKey:), key);
    
    if (*(Class *)binding != lastAssocClass) {
      lastAssocClass = *(Class *)binding;
#if NeXT_RUNTIME
      valInComp = (void *)
        [binding methodForSelector:@selector(valueInComponent:)];
#else
      valInComp = (void *)
        method_get_imp(class_get_instance_method(*(Class *)binding,
          @selector(valueInComponent:)));
#endif
    }
    
    // TODO: this is somewhat inefficient because -valueInComponent: does
    //       value=>object coercion and then takeValue:forKey: does the
    //       reverse coercion. We could improve performance for base values
    //       if we implement takeValue:forKey: on our own and just pass over
    //       the raw value (ie [self setIntA:[assoc intValueComponent:self]])
    
    value = valInComp(binding, @selector(valueInComponent:), _parent);

    // TODO: this is a bit problematic in bool contexts if the input
    //       parameter is a string because ObjC doesn't know about bool
    //       and will evaluate the string as a char value
    //       (this is common if you use const:mykey="YES" in WOx)
#if GNUSTEP_BASE_LIBRARY
    takeValue(self, @selector(setValue:forKey:), value, key);
#else
    takeValue(self, @selector(takeValue:forKey:), value, key);
#endif
  }
}

void WOComponent_syncToParent(WOComponent *self, WOComponent *_parent) {
  NSEnumerator *keys;
  NSString     *key;
  id (*getValue)(id, SEL, NSString *);
  
  if ((keys = [self->wocBindings keyEnumerator]) == nil)
    return;
  
  CHK_ENUM_CACHE;
  CHK_WOCDICT_CACHE;

#if NeXT_RUNTIME
  getValue = (void *)[self methodForSelector:@selector(valueForKey:)];
#else
  getValue = (void*)method_get_imp(class_get_instance_method(self->isa,
                @selector(valueForKey:)));
#endif
  
  while ((key = nextKey(keys, @selector(nextObject))) != nil) {
    static   Class lastAssocClass = Nil;
    static   BOOL  (*isSettable)(id, SEL);
    static   void  (*setValInComp)(id, SEL, id, WOComponent *);
    register WOAssociation *binding;
    register id value;
    
    binding = wocObjForKey(self->wocBindings, @selector(objectForKey:), key);

    if (*(Class *)binding != lastAssocClass) {
      lastAssocClass = *(Class *)binding;

#if NeXT_RUNTIME
      isSettable   = 
        (void*)[binding methodForSelector:@selector(isValueSettable)];
      setValInComp = 
        (void*)[binding methodForSelector:@selector(setValue:inComponent:)];
#else
      isSettable = (void*)
        method_get_imp(class_get_instance_method(*(Class *)binding,
          @selector(isValueSettable)));
      setValInComp = (void*)
        method_get_imp(class_get_instance_method(*(Class *)binding,
          @selector(setValue:inComponent:)));
#endif
    }
    
    if (!isSettable(binding, @selector(isValueSettable)))
      continue;
    
    value = getValue(self, @selector(valueForKey:), key);
    
    setValInComp(binding, @selector(setValue:inComponent:), value, _parent);
  }
}

@end /* WOComponent(OptimizedSynching) */
