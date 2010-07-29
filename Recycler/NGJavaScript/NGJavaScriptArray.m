/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "NGJavaScriptObject.h"
#include "NGJavaScriptContext.h"
#include "NGJavaScriptObjectMappingContext.h"
#include "common.h"

#define ARCHIVE_AS_NSARRAY 1

@interface NGJavaScriptArray(Private)
- (NSArray *)convertToNSArray;
@end

@implementation NGJavaScriptArray

+ (void)initialize {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;
#if NeXT_RUNTIME || APPLE_RUNTIME || GNUSTEP_BASE_LIBRARY
    NSLog(@"WARNING(%s): adding NSMutableArray behaviour to "
          @"NGJavaScriptArray is not supported with the current"
          @"runtime!", __PRETTY_FUNCTION__);
    /* TODO: port to MacOSX/GNUstep */
#else
    class_add_behavior(self, [NSMutableArray class]);
#endif
  }
}

- (void *)createJSObjectForJSClass:(void *)_class inJSContext:(void *)jsctx {
  /* this is called by initWithClassHandle ... */
  return JS_NewArrayObject(jsctx, 0 /* length */, NULL /* vector */);
  //return JS_NewObject(jsctx, _class, NULL, NULL);
}

+ (void *)jsObjectClass {
  return &js_ArrayClass;
}

/* convert to array */

- (NSArray *)convertToNSArray {
  jsint   i, count;
  id      *objs;
  NSArray *array;
  
  if (!JS_GetArrayLength(self->jscx, self->handle, &count))
    return nil;
  
  if (count <= 0)
    return [NSArray array];

  objs = calloc(count, sizeof(id));
  for (i = 0; i < count; i++) {
    static id null = nil;
    jsval val;

    if (null == nil)
      null = [[NSClassFromString(@"EONull") alloc] init];

    if (!JS_GetElement(self->jscx, self->handle, i, &val))
      objs[i] = null;
    else
      objs[i] = [self->ctx objectForJSValue:&val];
  }
  array = [[NSArray alloc] initWithObjects:objs count:count];
  free(objs);
  return [array autorelease];
}

- (NSArray *)copyWithZone:(NSZone *)_zone {
  return [[self convertToNSArray] copyWithZone:_zone];
}
- (NSMutableArray *)mutableCopyWithZone:(NSZone *)_zone {
  return [[self convertToNSArray] mutableCopyWithZone:_zone];
}

/* NSCoding */

#if ARCHIVE_AS_NSARRAY

- (id)replacementObjectForCoder:(NSCoder*)anEncoder {
  id array;
  
  array = [[[self convertToNSArray] mutableCopy] autorelease];
  NSLog(@"%s: replace %@ with %@", __PRETTY_FUNCTION__, self, array);
  return array;
}
#if 0
- (Class)classForCoder {
  return [NSMutableArray class];
}
#endif
#endif

- (void)decodeJavaScriptPropertiesWithCoder:(NSCoder *)_coder {
  unsigned i, count;
  
  [_coder decodeValueOfObjCType:@encode(unsigned) at:&count];
  for (i = 0; i < count; i++) {
    id obj = [_coder decodeObject];
    [self addObject:obj];
  }
}
- (void)encodeJavaScriptPropertiesWithCoder:(NSCoder *)_coder {
  unsigned i, count;
  
  count = [self count];
  [_coder encodeValueOfObjCType:@encode(unsigned) at:&count];
  
  for (i = 0; i < count; i++)
    [_coder encodeObject:[self objectAtIndex:i]];
}

/* description */

- (NSString *)description {
  return [[self convertToNSArray] description];
}

@end /* NGJavaScriptArray */

@implementation NGJavaScriptArray(NSArrayCompatibility)

- (unsigned)count {
  jsint v;
  
  if (JS_GetArrayLength(self->jscx, self->handle, &v))
    return v;
  
  return 0;
}

- (id)objectAtIndex:(unsigned)_idx {
  jsval obj;

  if (JS_GetElement(self->jscx, self->handle, _idx, &obj))
    return [self->ctx objectForJSValue:&obj];
  
  /* get failed */
  return nil;
}

- (NSEnumerator *)objectEnumerator {
  return [[self convertToNSArray] objectEnumerator];
}

- (id)lastObject {
  jsint v;

  if (JS_GetArrayLength(self->jscx, self->handle, &v)) {
    jsval obj;

    if (JS_GetElement(self->jscx, self->handle, v, &obj))
      return [self->ctx objectForJSValue:&obj];
  }
  /* failed */
  return nil;
}

- (BOOL)containsObject:(id)_obj {
  // to be improved ...
  return [[self convertToNSArray] containsObject:_obj];
}

/* Deriving New Array */

- (NSArray *)arrayByAddingObject:(id)anObject {
  return [[self convertToNSArray] arrayByAddingObject:anObject];
}
- (NSArray *)arrayByAddingObjectsFromArray:(NSArray *)anotherArray {
  return [[self convertToNSArray] arrayByAddingObjectsFromArray:anotherArray];
}

- (NSArray *)sortedArrayUsingFunction:
  (int(*)(id element1, id element2, void *userData))comparator
  context:(void*)context
{
  return [[self convertToNSArray]
                sortedArrayUsingFunction:comparator
                context:context];
}
- (NSArray *)sortedArrayUsingSelector:(SEL)comparator {
  return [[self convertToNSArray] sortedArrayUsingSelector:comparator];
}

- (NSArray *)subarrayWithRange:(NSRange)_range {
  // to be improved ...
  return [[self convertToNSArray] subarrayWithRange:_range];
}

@end /* NGJavaScriptArray(NSArrayCompatibility) */

@implementation NGJavaScriptArray(NSMutableArrayCompatibility)

- (void)setObject:(id)_obj atIndex:(unsigned)_idx {
  jsval obj;
  
  if ([self->ctx jsValue:&obj forObject:_obj]) {
    if (JS_SetElement(self->jscx, self->handle, _idx, &obj))
      // ok
      return;
  }
  
  NSAssert2(NO, @"set element failed (%@ at idx %d) !", self, _idx);
}

static inline void
_removeObjectsFrom(NGJavaScriptArray *self,
                   unsigned int _idx, unsigned int _count)
{
  jsint i, itemsCount;

#if 0
  /* cannot use DeleteElement ! this doesn't adjust indizes !! */
  NSAssert(JS_DeleteElement(self->jscx, self->handle, _idx),
           @"delete-element failed in JS");
#endif
  
  if (_count == 0)
    return;
  if (!JS_GetArrayLength(self->jscx, self->handle, &itemsCount))
    goto failed;
  if ((_idx + _count) > itemsCount)
    goto failed;

  /* move to front */
  for (i = (_idx + _count); i < itemsCount; i++, _idx++) {
    jsval val;
    
    if (!JS_GetElement(self->jscx, self->handle, i, &val))
      goto failed;
    
    if (!JS_SetElement(self->jscx, self->handle, _idx, &val))
      goto failed;
  }
  
  /* shorten array */
  if (JS_SetArrayLength(self->jscx, self->handle, itemsCount - _count)) {
    /* ok */
    return;
  }
  
 failed:
  NSCAssert3(NO, @"element remove failed (%@ at idx %d,%d) !",
             self, _idx, _count);
}

- (void)removeObjectsInRange:(NSRange)aRange {
  _removeObjectsFrom(self, aRange.location, aRange.length);
}
- (void)removeAllObjects {
  _removeObjectsFrom(self, 0, [self count]);
}
- (void)removeLastObject {
  unsigned itemsCount;
  itemsCount = [self count];
  if (itemsCount > 0) _removeObjectsFrom(self, (itemsCount - 1), 1);
}
- (void)removeObjectAtIndex:(unsigned)_idx {
  _removeObjectsFrom(self, _idx, 1);
}

- (void)insertObject:(id)_object atIndex:(unsigned)_idx {
  jsval obj;
  jsint i, itemsCount;

#if 0
  NSLog(@"%s: before: %@", __PRETTY_FUNCTION__,
        [[[self convertToNSArray]
                valueForKey:@"description"]
                componentsJoinedByString:@","]);
#endif
  
  if (!JS_GetArrayLength(self->jscx, self->handle, &itemsCount))
    goto failed;
  
  if (_idx > itemsCount)
    /* range exception ... */
    goto failed;
  
  /* move items up */
  for (i = itemsCount; i > _idx; i--) {
    jsval val;
    
    if (!JS_GetElement(self->jscx, self->handle, (i - 1), &val))
      goto failed;
    
    if (!JS_SetElement(self->jscx, self->handle, i, &val))
      goto failed;
  }
  
  /* get JS value of new object */
  if (![self->ctx jsValue:&obj forObject:_object])
    goto failed;
  
  /* place new item */
  if (JS_SetElement(self->jscx, self->handle, _idx, &obj)) {
    /* ok */
#if 0
    NSLog(@"%s: after: %@", __PRETTY_FUNCTION__,
          [[[self convertToNSArray]
                  valueForKey:@"description"]
                  componentsJoinedByString:@","]);
#endif
    return;
  }
  
 failed:
  NSAssert2(NO, @"element insert failed (%@ at idx %d) !", self, _idx);
}
- (void)addObject:(id)_object {
  [self insertObject:_object atIndex:[self count]];
}

@end /* NGJavaScriptArray(NSMutableArrayCompatibility) */
