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

#include "NGJavaScriptObjectMappingContext.h"
#include "NGJavaScriptContext.h"
#include "NGJavaScriptObjectHandler.h"
#include "NGJavaScriptObject.h"
#include "NGJavaScriptShadow.h"
#include "NGJavaScriptFunction.h"
#include "NSString+JS.h"
#include "common.h"
#include "globals.h"

#if GNUSTEP_BASE_LIBRARY
#  include <GNUstepBase/behavior.h>
#endif

@interface NSObject(CombinedObjects)
- (void)jsObjectFinalized:(void *)_handle;
- (BOOL)_jsGetValue:(void *)_value inJSContext:(NGJavaScriptContext *)_ctx;
- (id)_js_parentObject;
@end

@interface NGJavaScriptObjectMappingContext(Privates)
- (void)_jsFinalizeCombinedObject:(id)_object;
@end

typedef struct {
  JSObject                         *jso;
  NGJavaScriptObjectMappingContext *ctx;
  NGJavaScriptObjectHandler        *handler;
  BOOL                             rootRef;
  unsigned short                   rc;
} JSCombinedObjInfo;

extern JSClass ObjCShadow_JSClass;

@implementation NGJavaScriptObjectMappingContext

static BOOL       logHandleForObject = NO;
static BOOL       logValueConversion = NO;
static NSMapTable *combinedToInfo = NULL; // combined objects

+ (void)initialize {
  static BOOL didInit = NO;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  if (didInit) return;
  
  NGJavaScriptBridge_LOG_PROP_DEFINITION
    = [[ud objectForKey:@"jsLogPropDef"] boolValue];
  NGJavaScriptBridge_LOG_FUNC_DEFINITION
    = [[ud objectForKey:@"jsLogFuncDef"] boolValue];

  logHandleForObject = [ud boolForKey:@"JSLogHandleForObject"];
  logValueConversion = [ud boolForKey:@"JSLogValueConversion"];
  
  didInit = YES;
}

- (id)initWithJSContext:(NGJavaScriptContext *)_ctx {
  if ((self = [super init])) {
    self->jsContext = [_ctx retain];
    
    /* 'combined' ObjC-JS objects */
    if (combinedToInfo == NULL) {
      combinedToInfo =
        NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                         NSOwnedPointerMapValueCallBacks,
                         200);
    }
    
    /* 'pure' ObjC objects */
    self->objcToJS =
      NSCreateMapTable(NSObjectMapKeyCallBacks,
                       NSNonOwnedPointerMapValueCallBacks,
                       200);
    
    /* 'pure' JS objects */
    self->jsToObjC =
      NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                       NSNonRetainedObjectMapValueCallBacks,
                       200);
    
    /* make default global */
    
    [self pushContext];
    {
      NGJavaScriptObject *glob;

      glob = [[NGJavaScriptObject alloc] init];
      [glob applyStandardClasses];
      [self setGlobalObject:glob];
      [glob release];
    }
    [self popContext];
  }
  return self;
}
- (id)init {
  NGJavaScriptContext *ctx;
  
  ctx = [[NGJavaScriptContext alloc] init];
  self = [self initWithJSContext:ctx];
  [ctx release]; ctx = nil;
  return self;
}

- (void)dealloc {
  if (self->jsToObjC) NSFreeMapTable(self->jsToObjC);
  if (self->objcToJS) NSFreeMapTable(self->objcToJS);
  [self->jsContext release];
  [super dealloc];
}

- (NGJavaScriptContext *)jsContext {
  return self->jsContext;
}

/* hierachy */

- (void)setGlobalObject:(id)_object {
  JSObject *glob;
  
  glob = [self handleForObject:_object];
  JS_SetGlobalObject([self->jsContext handle], glob);
}
- (id)globalObject {
  JSObject *glob;
  
  if ((glob = JS_GetGlobalObject([self->jsContext handle])) == NULL)
    return nil;
  
  return [self objectForHandle:glob];
}

/* proxy factory */

- (void *)proxyForObject:(id)_object {
  /* this is called by handleForObject: */
  NGJavaScriptObjectHandler *jsHandler;
  void *jso;
  
  jsHandler =
    [[NGJavaScriptObjectHandler alloc] initWithObject:_object
                                       inMappingContext:self];
  
  jso = [jsHandler handle];
  
  [jsHandler autorelease];
  
  return jso;
}
- (id)proxyForPureJSObject:(void *)_handle {
  Class proxyClass;
  id    proxy;
  JSContext *cx;
  void      *jsClazz;
  
  if (_handle == NULL)
    return nil;
  
  /* create a proxy for a 'pure' JavaScript object */
  
  cx = [self->jsContext handle];
  jsClazz = OBJ_GET_CLASS(cx, (JSObject *)_handle);
  
  /* use a configurable mapping of JS-class to ObjC class here ? */
  if (jsClazz == &js_ArrayClass)
    proxyClass = [NGJavaScriptArray class];
  else if (jsClazz == &js_FunctionClass)
    proxyClass = [NGJavaScriptFunction class];
  else
    proxyClass = [NGJavaScriptObject class];
  
  proxy = [[proxyClass alloc] initWithHandle:_handle inMappingContext:self];
  return AUTORELEASE(proxy);
}

/* mappings */

- (void *)handleForObject:(id)_object {
  /*
    What is the _object in this context ?
    - I guess it's a NGJavaScriptObject
      - often, but not always, see testjs: called with Blah and MyNum
      - only "custom" objects, not NGJavaScriptObject are registered !
    
    - it checks whether the object itself can return handle 
      (_jsHandleInMapContext:)
      - this seems always true for NGJavaScriptObject's !
    - checks, whether a proxy is already registered
      - I guess a proxy is a JS-object with an attached JSObjectHandler ?
    - otherwise create a new one
    - register new one
    - check parent object of new one
  */
  JSCombinedObjInfo *combinedObjInfo;
  void *jso;
  id   parent;
  
  if (logHandleForObject)
    NSLog(@"-proxyForObject:0x%p %@", _object, _object);
  
  if (_object == nil) {
    jso = JSVAL_TO_OBJECT(JSVAL_NULL);
    if (logHandleForObject) NSLog(@"  => is nil: 0x%p", jso);
    return jso;
  }
  
  if ([_object respondsToSelector:@selector(_jsHandleInMapContext:)]) {
    jso = [_object _jsHandleInMapContext:self];
    if (logHandleForObject) {
      NSLog(@"  obj (class %@) handles itself: 0x%p", 
	    NSStringFromClass([_object class]), jso);
    }
    return jso;
  }
  
  if ((jso = NSMapGet(self->objcToJS, _object))) {
    /* a proxy is already registered */
    if (logHandleForObject) NSLog(@"  proxy already registered: 0x%p", jso);
    return jso;
  }
  
  if ((combinedObjInfo = NSMapGet(combinedToInfo, _object))) {
    /* check for correct context */
    if (combinedObjInfo->ctx != self) {
      NSLog(@"%s: tried to access combined object 0x%p<%@> in "
            @"different mapping context (ctx=0x%p, required=0x%p)  !",
            __PRETTY_FUNCTION__, _object, NSStringFromClass([_object class]),
            self, combinedObjInfo->ctx);
      return nil;
    }
    if (logHandleForObject) NSLog(@"  proxy is combined object: 0x%p", jso);
    return combinedObjInfo->jso;
  }
  
  /* create a new proxy */
  
  if (logHandleForObject) NSLog(@"  creating proxy ...");
  if ((jso = [self proxyForObject:_object])) {
    /* register proxy */
#if DEBUG
    NSAssert1(NSMapGet(self->objcToJS, _object) == NULL,
              @"already registered a proxy for object o0x%p", _object);
#endif
    if (logHandleForObject) NSLog(@"  register handle 0x%p ...", jso);
    NSMapInsertKnownAbsent(self->objcToJS, _object, jso);
  }
  else {
    NSLog(@"ERROR(%s): proxy creation failed: %@", 
	  __PRETTY_FUNCTION__, _object);
    return NULL;
  }
  
  /* look for parent of new proxy */
  
  if ((parent = [_object _js_parentObject])) {
    void *pjso;
    JSBool res;
    
    if (logHandleForObject) 
      NSLog(@"register parent 0x%p for object .."), parent;
    
    pjso = [self handleForObject:parent];
    
    res = JS_SetParent([self->jsContext handle], jso, pjso);
    
    if (res == JS_FALSE) {
      NSLog(@"WARNING: ctx %@ couldn't register JS parent %@ on object %@",
            self, parent, _object);
    }
  }
  
  return jso;
}

- (void)registerObject:(id)_object forImportedHandle:(void *)_handle {
#if DEBUG
  NSAssert(_object, @"missing object");
  NSAssert(_handle, @"missing handle");
#endif
  NSMapInsertKnownAbsent(self->jsToObjC, _handle, _object);
}

- (id)objectForHandle:(void *)_handle {
  /*
    What does it do ? What is the return value ? TODO: Document !
  */
  extern JSClass NGJavaScriptObjectHandler_JSClass;
  JSClass *handleClass;
  id obj;
  
  if (_handle == NULL)
    return nil;
  
  if ((handleClass = JS_GetClass(_handle)) == NULL) {
    NSLog(@"couldn't get class of handle 0x%p", (unsigned)_handle);
    return nil;
  }
  
  /* check for 'reflected' JavaScript objects (combined or ObjC exported) */
  
  if (handleClass == &NGJavaScriptObjectHandler_JSClass) {
    NGJavaScriptObjectHandler *h;
    
    if ((h = JS_GetPrivate([self->jsContext handle], _handle)) == nil) {
      NSLog(@"couldn't get private of JS object 0x%p "
            @"(NGJavaScriptObjectHandler)", _handle);
      return nil;
    }
    
    return AUTORELEASE(RETAIN([h managedObject]));
  }
  
  if (handleClass == &ObjCShadow_JSClass) {
    NGJavaScriptShadow *h;
    
    if ((h = JS_GetPrivate([self->jsContext handle], _handle)) == nil) {
      NSLog(@"couldn't get private of JS shadow object 0x%p "
            @"(NGJavaScriptShadow)", _handle);
      return nil;
    }
    
    return AUTORELEASE(RETAIN([h masterObject]));
  }
  
  /* check for 'pure' JavaScript objects */
  
  if ((obj = NSMapGet(self->jsToObjC, _handle)))
    /* found */
    return AUTORELEASE(RETAIN(obj));
  
  if ((obj = [self proxyForPureJSObject:_handle])) {
    /* register proxy */
    [self registerObject:obj forImportedHandle:_handle];
    return obj;
  }
  
  /* couldn't build a proxy */
  return nil;
}

- (void)forgetObject:(id)_object {
  JSCombinedObjInfo *combinedObjInfo;
  
  NSAssert(_object, @"missing object ..");
  
  if ((combinedObjInfo = NSMapGet(combinedToInfo, _object))) {
    if (combinedObjInfo->ctx != self) {
      NSLog(@"forget combined object 0x%p in wrong context !", _object);
    }
    else
      [self _jsFinalizeCombinedObject:_object];
  }
  else {
    if (NGJavaScriptBridge_TRACK_FORGET) {
      JSObject *jso;
      
      jso = NSMapGet(self->objcToJS, _object);
      NSLog(@"forgetting non-combined object o0x%p<%@> j0x%p rc %d",
            _object, NSStringFromClass([_object class]),
            jso,
            [_object retainCount]);
    }
    
    NSMapRemove(self->objcToJS, _object);

#if 0
    [self->jsContext performSelector:@selector(collectGarbage)
                     withObject:nil
                     afterDelay:0.0];
#endif
  }
}
- (void)forgetImportedHandle:(void *)_handle {
  NSMapRemove(self->jsToObjC, _handle);
}

/* handler */

- (NGJavaScriptObjectHandler *)handlerForObject:(id)_object {
  JSObject *jso;
  
  if ((jso = [self handleForObject:_object]) == NULL) {
    NSLog(@"did not find handle for object 0x%p", _object);
    return nil;
  }
  
  return JS_GetPrivate([self->jsContext handle], jso);
}

/* garbage collection */

- (id)popContext {
  [self->jsContext collectGarbage];
  return [super popContext];
}

- (void)collectGarbage {
  [self pushContext];
  [self->jsContext collectGarbage];
  [self popContext];
}

/* logging */

- (void)_logExportedJavaScriptObjects {
  NSMapEnumerator e;
  JSObject *jso;
  JSClass  *jsClass;
  id       proxy;

  if (NSCountMapTable(jsToObjC) < 1) {
    printf("no imported JavaScript objects.\n");
    return;
  }
  
  e = NSEnumerateMapTable(jsToObjC);
  printf("imported JavaScript objects:\n");
  printf("  %-10s %-20s %-10s %-26s %-2s\n",
	 "JS",
         "JS-Class",
	 "ObjC",
	 "ObjC-Class",
	 "rc");
  while (NSNextMapEnumeratorPair(&e, (void*)&jso, (void*)&proxy)) {
    jsClass = jso ? JS_GetClass(jso) : NULL;
    
    printf("  0x%p %-20s 0x%p %-26s %2d\n",
	   (unsigned)jso,
           jsClass ? jsClass->name : "<null>",
	   (unsigned)proxy,
	   [NSStringFromClass([proxy class]) cString],
	   [proxy retainCount]);
  }
}

- (void)_logExportedObjCObjects {
  NSMapEnumerator e;
  id       object;
  JSObject *jsProxy;

  if (NSCountMapTable(objcToJS) < 1) {
    printf("no exported Objective-C objects.\n");
    return;
  }
  
  printf("exported Objective-C objects:\n");
  printf("  %-10s %-20s %-10s %-26s %-2s\n",
	 "ObjC",
	 "ObjC-Class",
	 "JS",
	 "JS-Class",
	 "rc");
  e = NSEnumerateMapTable(objcToJS);
  while (NSNextMapEnumeratorPair(&e, (void*)&object, (void*)&jsProxy)) {
    JSClass *jsClass;
    
    jsClass = jsProxy ? JS_GetClass(jsProxy) : NULL;
    
    printf("  0x%p %-20s 0x%p %-26s %2d\n",
	   (unsigned)object,
	   [NSStringFromClass([object class]) cString],
	   (unsigned)jsProxy,
           jsClass ? jsClass->name : "<null>",
	   [object retainCount]);
  }  
}

/* values */

- (id)objectForJSValue:(void *)_value {
  JSType    jsType;
  JSBool    couldConvert;
  JSContext *cx;
  
  couldConvert = JS_FALSE;
  
  if (JSVAL_IS_NULL(*(jsval *)_value))
    return nil;
  
  cx = [self->jsContext handle];
  jsType = JS_TypeOfValue(cx, *(jsval *)_value);
  switch (jsType) {
    case JSTYPE_VOID:
      return nil;
      
    case JSTYPE_FUNCTION:
    case JSTYPE_OBJECT: {
      JSObject *obj;
      
      if (!(couldConvert = JS_ValueToObject(cx, *(jsval *)_value, &obj)))
        break;
      
      return [self objectForHandle:obj];
    }
    
#if 0
    case JSTYPE_FUNCTION: {
      JSFunction *func;
      
      if ((func = JS_ValueToFunction(cx, *(jsval *)_value))) {
        static Class FuncClass = Nil;
        
        if (FuncClass == Nil)
          FuncClass = NSClassFromString(@"NGJavaScriptFunction");

        NSAssert(FuncClass, @"missing JS function class ..");
        
        return AUTORELEASE([[FuncClass alloc] initWithHandle:func
                                              mappingContext:self]);
      }
      else {
        NSLog(@"%s: couldn't get JS function ..", __PRETTY_FUNCTION__);
        couldConvert = NO;
      }
      break;
    }
#endif
      
    case JSTYPE_STRING: {
      JSString *s;

      if ((s = JS_ValueToString(cx, *(jsval *)_value))) {
        return [NSString stringWithJavaScriptString:s];
      }
      else
        couldConvert = NO;
      
      break;
    }
    
    case JSTYPE_NUMBER:
      if (JSVAL_IS_INT(*(jsval *)_value)) {
        int32 i;
        
        if ((couldConvert = JS_ValueToInt32(cx, *(jsval *)_value, &i)))
          return [NSNumber numberWithInt:i];
      }
      else {
        jsdouble d;

        if ((couldConvert = JS_ValueToNumber(cx, *(jsval *)_value, &d)))
          return [NSNumber numberWithDouble:d];
      }
      break;
      
    case JSTYPE_BOOLEAN: {
      JSBool b;
      
      couldConvert = JS_ValueToBoolean(cx, *(jsval *)_value, &b);
      if (couldConvert)
        return [NSNumber numberWithBool:b ? YES : NO];
      break;
    }

    default:
      [NSException raise:@"InvalidJavaScriptTypeException"
                   format:@"JavaScript value has unknown type %i !", jsType];
  }
  
  if (!couldConvert) {
      [NSException raise:@"JavaScriptTypeConvertException"
                   format:@"Could not convert JavaScript value of type %i !",
                     jsType];
  }
  
  return nil;
}

- (BOOL)jsValue:(void *)_value forObject:(id)_obj {
  /*
    This is used to convert ObjC object _obj to a JSVAL.
    
    Cases:
    - _obj is a proxy for a JavaScript object (eg NGJavaScriptObject),
      the proxy will return the value itself
    - _obj is a primitive Foundation object (eg NSString), the object
      will convert itself to a primitiv JavaScript type using
      _jsGetValue:inJSContext:
    - _obj is a complex object, it will be mapped to a proxy JSObject
    
    Primitive types seem to be broken in certain cases right now.
  */
  if (_obj == nil) {
    *(jsval *)_value = JSVAL_NULL;
    return YES;
  }
  
  if ([_obj respondsToSelector:@selector(_jsGetValue:inJSContext:)]) {
    if (logValueConversion) {
      NSLog(@"%s(0x%p, 0x%p<%@>) => own handling ..", 
	      __PRETTY_FUNCTION__,
	      _value, _obj, NSStringFromClass([_obj class]));
    }
    /* eg this is called on NSString */
    return [_obj _jsGetValue:_value inJSContext:self->jsContext];
  }
  else if (_value) {
    JSObject *jso;

    if (logValueConversion) {
      NSLog(@"%s(0x%p, 0x%p<%@>) => get handle ..", 
	      __PRETTY_FUNCTION__,
	      _value, _obj, NSStringFromClass([_obj class]));
    }
    
    if ((jso = [self handleForObject:_obj]) == NULL)
      return NO;
    
    *((jsval *)_value) = OBJECT_TO_JSVAL(jso);
    return YES;
  }
  else {
    if (logValueConversion) {
      NSLog(@"%s(0x%p, 0x%p<%@>) => missing value store ?", 
	      __PRETTY_FUNCTION__,
	      _value, _obj, NSStringFromClass([_obj class]));
    }
    return NO;
  }
}

@end /* NGJavaScriptObjectMappingContext */

@implementation NGJavaScriptObjectMappingContext(CombinedObjects)

/* combined objects */

- (void)makeObjectCombined:(id)_object {
  Class    clazz;
  unsigned oldRC;
  JSCombinedObjInfo *combinedObjInfo;
  id handler;
  
  if (NSMapGet(combinedToInfo, _object))
    /* object is already a combined one */
    return;
  
  oldRC = [_object retainCount];
  clazz = [_object class];
  
  handler = [[NGJavaScriptObjectHandler alloc]
                                        initWithObject:_object
                                        inMappingContext:self];
  
  if (![clazz isJSCombinedObjectClass]) {
    // TODO: is this correct shouldn't we add combined behaviour only
    //       *on* combined classes ??, explain !

#if NeXT_RUNTIME || APPLE_RUNTIME
    NSLog(@"ERROR(%s): combined objects not supported on this runtime!",
          __PRETTY_FUNCTION__);
    /* TODO: port to MacOSX */
#else
    static Class BehaviourClass = Nil;
    BehaviourClass = NSClassFromString(@"JSCombinedObjectBehaviour");
    NSAssert(BehaviourClass, @"did not find JSCombinedObjectBehaviour !");
#if GNUSTEP_BASE_LIBRARY
    behavior_class_add_class(clazz, BehaviourClass);
#else
    class_add_behavior(clazz, BehaviourClass);
#endif
#endif
  }
  
  combinedObjInfo = calloc(1, sizeof(JSCombinedObjInfo));
  combinedObjInfo->jso     = [handler handle];
  combinedObjInfo->handler = handler;
  combinedObjInfo->ctx     = self;
  combinedObjInfo->rc      = oldRC; // -1 ???
  
  combinedObjInfo->rootRef = YES;
  [handler jsRetain];
  AUTORELEASE(handler);
  
  NSMapInsertKnownAbsent(combinedToInfo,  _object, combinedObjInfo);
  
  if (NGJavaScriptBridge_TRACK_MEMORY) {
    NSLog(@"combine: o0x%p<%@>->j0x%p "
          @"(handler=0x%p, old-rc=%d, new-rc=%d)",
          _object, NSStringFromClass([_object class]),
          combinedObjInfo->jso, combinedObjInfo->handler, oldRC, [_object retainCount]);
  }
  
#if DEBUG
  NSAssert([_object isJSCombinedObject], @"still not a combined object !");
#endif
}

- (BOOL)isCombinedObject:(id)_object {
  return NSMapGet(combinedToInfo, _object) ? YES : NO;
}

- (void)_logCombinedObjects {
  NSMapEnumerator e;
  id                object;
  JSCombinedObjInfo *combinedObjInfo;
  
  printf("Combined objects:\n");
  printf("  %-10s %-16s %-2s %-10s %-10s %-10s %-2s %-2s\n",
	 "ObjC",
	 "Class",
	 "o#",
	 "JS",
	 "Ctx",
	 "Handler",
	 "/#",
	 "h#");
  e = NSEnumerateMapTable(combinedToInfo);
  while (NSNextMapEnumeratorPair(&e, (void*)&object, (void*)&combinedObjInfo)) {
    printf("  0x%p %-16s %2d 0x%p 0x%p 0x%p %2d %2d\n", 
	   (unsigned)object, [NSStringFromClass([object class]) cString],
	   [object retainCount],
	   (unsigned)combinedObjInfo->jso,
	   (unsigned)combinedObjInfo->ctx,
	   (unsigned)combinedObjInfo->handler,
	   [combinedObjInfo->handler jsRootRetainCount],
	   [combinedObjInfo->handler retainCount]);
  }
}

- (void)_jsFinalizeCombinedObject:(id)_object {
  /*
    This should never be called if ObjC RC > 0 !, since the ObjC object
    keeps a root-ref to the JS object !
  */
  JSCombinedObjInfo *combinedObjInfo;
  
  if (_object == nil) return;
  
  if ((combinedObjInfo = NSMapGet(combinedToInfo, _object))) {
    NSAssert(combinedObjInfo->ctx == self, @"invalid ctx for combined finalization !");
    
    if (combinedObjInfo->rc == 0) {
      if (combinedObjInfo->rootRef) {
        [combinedObjInfo->handler jsRelease];
        combinedObjInfo->rootRef = NO;
      }
      
      if (NGJavaScriptBridge_TRACK_MEMORY) {
        NSLog(@"FREEING COMBINED OBJECT o%p<%@>-j%p (handler 0x%p).",
              _object, NSStringFromClass([_object class]),
              combinedObjInfo->jso, combinedObjInfo->handler);
      }
      
      NSMapRemove(combinedToInfo, _object);
      combinedObjInfo = NULL;
      
      /* deallocate Objective-C memory of object */
      [_object dealloc];
    }
    else {
      NSLog(@"WARNING: finalized JS object, but handler RC > 0 !");
    }
  }
}

@end /* NGJavaScriptObjectMappingContext */

@implementation NSObject(JSCombinedObjects)

+ (BOOL)isJSCombinedObjectClass {
  return NO;
}

- (BOOL)isJSCombinedObject {
  return NO;
}
- (NGJavaScriptObjectMappingContext *)jsObjectMappingContext {
  return nil;
}

@end /* NSObject(JSCombinedObjects) */

@implementation JSCombinedObjectBehaviour

- (NGJavaScriptObjectMappingContext *)jsObjectMappingContext {
  JSCombinedObjInfo *combinedObjInfo;
  
  if ((combinedObjInfo = NSMapGet(combinedToInfo, self)) == NULL)
    return nil;
  
  return combinedObjInfo->ctx;
}

+ (BOOL)isJSCombinedObjectClass {
  return YES;
}

- (BOOL)isJSCombinedObject {
  return NSMapGet(combinedToInfo, self) ? YES : NO;
}

/* retain-counting */

- (id)retain {
  JSCombinedObjInfo *combinedObjInfo;
  
  if ((combinedObjInfo = NSMapGet(combinedToInfo, self)) == NULL) {
    if (NGJavaScriptBridge_TRACK_NOINFO_MEMORY) {
      NSLog(@"CO: NO INFO retain: o%p<%@>, rc=%d",
            self, NSStringFromClass([self class]), [self retainCount]);
    }
    return [super retain];
  }
  
  if (combinedObjInfo->handler == nil) {
    if (NGJavaScriptBridge_TRACK_MEMORY) {
      NSLog(@"CO: NO HANDLER retain: o%p<%@>-j0x%p, rc=%d",
            self, NSStringFromClass([self class]),
            combinedObjInfo->jso, [self retainCount]);
    }
    return [super retain];
  }
  
  if (combinedObjInfo->rc == 0) {
    /* life, but not specially retained (RC=1) */
    
    if (!combinedObjInfo->rootRef) {
      /* ensure that the JS object is life */
      [combinedObjInfo->handler jsRetain];
      combinedObjInfo->rootRef = YES;
    }
  }
  combinedObjInfo->rc++;
  
  if (NGJavaScriptBridge_TRACK_MEMORY_RC) {
    NSLog(@"CO: retain: o%p<%@>-j%p (handler=0x%p), rc=%d, root-rc=%d",
          self, NSStringFromClass([self class]), combinedObjInfo->jso, combinedObjInfo->handler,
          combinedObjInfo->rc, [combinedObjInfo->handler jsRootRetainCount]);
  }
  
  return self;
}

- (oneway void)release {
  JSCombinedObjInfo *combinedObjInfo;

  if ((combinedObjInfo = NSMapGet(combinedToInfo, self)) == NULL) {
    if (NGJavaScriptBridge_TRACK_NOINFO_MEMORY)
      NSLog(@"CO: NO INFO release: o%p, rc=%d", self, [self retainCount]);
    
    [super release];
    return;
  }
  
  if (combinedObjInfo->handler == nil) {
    if (NGJavaScriptBridge_TRACK_MEMORY) {
      NSLog(@"CO: NO HANDLER release: o%p<%@>-j0x%p, rc=%d",
            self, NSStringFromClass([self class]),
            combinedObjInfo->jso, [self retainCount]);
    }
    
    [super release];
    return;
  }
  
  if (NGJavaScriptBridge_TRACK_MEMORY_RC) {
    NSLog(@"CO: release: o%p<%@>-j%p (handler=0x%p), rc=%d, root-rc=%d",
          self, NSStringFromClass([self class]), combinedObjInfo->jso, combinedObjInfo->handler,
          [self retainCount], [combinedObjInfo->handler jsRootRetainCount]);
  }
  NSAssert1(combinedObjInfo->handler,
            @"missing handler for combined object 0x%p ..", self);

  
  /*
    this does never dealloc the ObjC object - the ObjC object is deallocated
    in the JS destructor !
  */

  combinedObjInfo->rc--;
  
  if (combinedObjInfo->rc == 0) {
    /* not specially retained in the ObjC side anymore */
    
    /* JS object is still live, release our root-ref .. */
    NSAssert(combinedObjInfo->rootRef, @"missing JS root-reference");
    [combinedObjInfo->handler jsRelease];
    combinedObjInfo->rootRef = NO;
    
    if (NGJavaScriptBridge_TRACK_MEMORY) {
      NSLog(@"%s: released last ObjC reference of o%p-j%p, %d root-refs ..",
            __PRETTY_FUNCTION__,
            self, combinedObjInfo->jso, [combinedObjInfo->handler jsRootRetainCount]);
    }
    
    [combinedObjInfo->ctx performSelector:@selector(collectGarbage)
                withObject:nil
                afterDelay:0.0];
  }
}

- (unsigned)retainCount {
  JSCombinedObjInfo *combinedObjInfo;
  
  if ((combinedObjInfo = NSMapGet(combinedToInfo, self)) == NULL)
    return [super retainCount];
  
  if (combinedObjInfo->handler == nil)
    return [super retainCount];

  return combinedObjInfo->rc;
}

/* evaluation */

- (id)evaluateScript:(NSString *)_js language:(NSString *)_language {
  JSCombinedObjInfo *combinedObjInfo;
  
  if ((combinedObjInfo = NSMapGet(combinedToInfo, self)) == NULL) {
    /* what to do ? */
    return [[[NGJavaScriptObjectMappingContext activeObjectMappingContext]
                                               handlerForObject:self]
                                               evaluateScript:_js];
  }
  
  return [combinedObjInfo->handler evaluateScript:_js];
}
- (id)evaluateJavaScript:(NSString *)_js {
  /* deprecated */
  return [self evaluateScript:_js language:@"javascript"];
}

@end /* JSCombinedObjectBehaviour */
