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

#include "NGJavaScriptContext.h"
#include "../common.h"

@interface _NGJSIndexEnumerator : NSEnumerator
{
  int i;
  int toGo;
}
+ (id)indexEnumeratorForCount:(int)_count;
@end

#include "NGJavaScriptObjectMappingContext.h"

@implementation NSArray(NGJavaScript)

- (BOOL)_jsGetValue:(jsval *)_value inJSContext:(NGJavaScriptContext *)_ctx {
  /* transform to JavaScript Array ... */
  unsigned    count;
  JSObject    *jsarray;
  JSContext   *cx;
  BOOL        addedRoot;
  void        *root;
  NSException *exception;
  BOOL        retcode;
  
  cx = [_ctx handle];
  
  if ((jsarray = JS_NewArrayObject(cx, 0, NULL)) == NULL) {
    NSLog(@"ERROR(%s): couldn't create JavaScript array ...",
          __PRETTY_FUNCTION__);
    return NO;
  }
  *_value = OBJECT_TO_JSVAL(jsarray);
  
  count = [self count];
  exception = nil;
  retcode   = YES;

  if (count > 0) {
    NGJavaScriptObjectMappingContext *mapctx;
    
    mapctx = [NGJavaScriptObjectMappingContext activeObjectMappingContext];
    
    /* temporarily add as root */
    addedRoot = JS_AddNamedRoot(cx, &root, __PRETTY_FUNCTION__);

    NS_DURING {
      unsigned i;
    
      for (i = 0; i < count; i++) {
        id    item;
        jsval v;
      
        item = [self objectAtIndex:i];
        
        if (![mapctx jsValue:&v forObject:item]) {
          retcode = NO;
          NSLog(@"%s: couldn't get JS value for item %@", __PRETTY_FUNCTION__,
                item);
          break;
        }
      
        if (!JS_SetElement(cx, jsarray, i, &v)) {
          retcode = NO;
          NSLog(@"%s: couldn't set item at index %d in JS array",
                __PRETTY_FUNCTION__, i);
          break;
        }
      }
    }
    NS_HANDLER {
      exception = [localException retain];
      retcode = NO;
    }
    NS_ENDHANDLER;
  
    /* remove temporary root */
    if (addedRoot) JS_RemoveRoot(cx, &root);
    root = NULL;

    if (exception) {
      NSLog(@"%s: catched exception: %@", __PRETTY_FUNCTION__, exception);
      RELEASE(exception);
    }
  }
  
  return retcode;
}

- (id)valueForJSPropertyAtIndex:(int)_idx {
  return [self objectAtIndex:_idx];
}

/* searching */

- (id)_jsfunc_objectAtIndex:(NSArray *)_args {
  return [self objectAtIndex:[[_args objectAtIndex:0] intValue]];
}
- (id)_jsfunc_indexOfObject:(NSArray *)_args {
  unsigned idx;
  
  idx = [self indexOfObject:[_args objectAtIndex:0]];
  if (idx == NSNotFound)
    return nil;

  return [NSNumber numberWithInt:idx];
}
- (id)_jsfunc_indexOfObjectIdenticalTo:(NSArray *)_args {
  unsigned idx;

  idx = [self indexOfObjectIdenticalTo:[_args objectAtIndex:0]];
  if (idx == NSNotFound)
    return nil;
  
  return [NSNumber numberWithInt:idx];
}
- (id)_jsfunc_lastObject:(NSArray *)_args {
  return [self lastObject];
}

/* strings */

- (id)_jsfunc_componentsJoinedByString:(NSArray *)_args {
  return [self componentsJoinedByString:[_args componentsJoinedByString:@""]];
}

/* IO */

- (id)_jsfunc_writeToFile:(NSArray *)_args {
  BOOL atomically;
  
  atomically =  ([_args count] > 1)
    ? [[_args objectAtIndex:1] boolValue]
    : YES;
  
   atomically = [self writeToFile:[[_args objectAtIndex:0] stringValue]
                      atomically:atomically];
   return [NSNumber numberWithBool:atomically];
}

/* properties */

- (id)_jsprop_count {
  return [NSNumber numberWithInt:[self count]];
}
- (id)_jsprop_length {
  return [self _jsprop_count];
}

/* enumerator */

- (NSEnumerator *)indexEnumerator {
  return [_NGJSIndexEnumerator indexEnumeratorForCount:[self count]];
}

- (NSEnumerator *)jsObjectEnumerator {
  return [self indexEnumerator];
}

@end /* NSArray(NGJavaScript) */

@implementation NSMutableArray(NGJavaScript)

- (BOOL)takeValue:(id)_value forJSPropertyAtIndex:(int)_idx {
  if (_value == nil)
      return NO;
  
  [self replaceObjectAtIndex:_idx withObject:_value];
  return YES;
}

/* adding objects */

- (id)_jsfunc_addObject:(NSArray *)_objs {
  [self addObjectsFromArray:_objs];
  return self;
}
- (id)_jsfunc_addObjectsFromArray:(NSArray *)_objs {
  NSEnumerator *e;
  NSArray *array;

  e = [_objs objectEnumerator];
  while ((array = [e nextObject]))
    [self addObjectsFromArray:array];
  return self;
}

/* inserting objects */

- (id)_jsfunc_insertObjectAtIndex:(NSArray *)_objs {
  [self insertObject:[_objs objectAtIndex:0]
        atIndex:[[_objs objectAtIndex:1] intValue]];
  return self;
}

/* removing objects */

- (id)_jsfunc_removeObject:(NSArray *)_objs {
  [self removeObjectsInArray:_objs];
  return self;
}
- (id)_jsfunc_removeObjectsInArray:(NSArray *)_objs {
  NSEnumerator *e;
  NSArray *array;

  e = [_objs objectEnumerator];
  while ((array = [e nextObject]))
    [self removeObjectsInArray:array];
  return self;
}
- (id)_jsfunc_removeAllObjects:(NSArray *)_objs {
  [self removeAllObjects];
  return self;
}
- (id)_jsfunc_removeObjectAtIndex:(NSArray *)_objs {
  NSEnumerator *e;
  id idx;

  e = [_objs objectEnumerator];
  while ((idx = [e nextObject]))
    [self removeObjectAtIndex:[idx intValue]];
  return self;
}

@end /* NSMutableArray(NGJavaScript) */

@implementation _NGJSIndexEnumerator

static Class NSNumberClass = Nil;

+ (id)indexEnumeratorForCount:(int)_count {
  _NGJSIndexEnumerator *e;
  
  if (_count == 0)
    return nil;

  if (NSNumberClass == Nil)
    NSNumberClass = [NSNumber class];

  e = [[self alloc] init];
  e->toGo = _count;
  return AUTORELEASE(e);
}

- (id)nextObject {
  id o;
  
  if (self->i >= self->toGo)
    return nil;
  
  o = [NSNumberClass numberWithInt:self->i];
  
  self->i++;
  return o;
}

@end /* _NGJSIndexEnumerator */
