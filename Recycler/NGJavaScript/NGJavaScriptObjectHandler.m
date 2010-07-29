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

#include "NGJavaScriptObjectHandler.h"
#include "NGJavaScriptObjectMappingContext.h"
#include "common.h"
#include "NGJavaScriptContext.h"
#include "NSString+JS.h"
#include "NSObject+JS.h"
#include "NGJavaScriptObjCClassInfo.h"
#include "NGJavaScriptRuntime.h"
#include <NGExtensions/NGObjCRuntime.h>
#import <EOControl/EONull.h>

//#define USE_ENUM 1
//#define LOG_PROP_RESOLVE 1

#define PROP_READONLY_FLAGS  0
#define PROP_READWRITE_FLAGS 0
//#define PROP_READONLY_FLAGS  (JSPROP_READONLY | JSPROP_PERMANENT)

@interface NGJavaScriptObjectHandler(Privates)
- (BOOL)_applyStaticDefs;
- (NSString *)stringValue;
@end

static BOOL IsInPropDefMode = NO;

@interface NSObject(JSFinalization)
- (BOOL)isJSCombinedObject;
- (NSEnumerator *)jsObjectEnumerator;
@end

#include "globals.h"

@implementation NGJavaScriptObjectHandler

static JSBool 
staticFuncDispatcher
(JSContext *cx, JSObject *obj, uintN argc, jsval *argv, jsval *rval);
static JSBool NGJavaScriptBridge_setStaticProp
(JSContext *cx, JSObject *obj, jsval _id, jsval *vp);
static JSBool NGJavaScriptBridge_getStaticProp
(JSContext *cx, JSObject *obj, jsval _id, jsval *vp);

static NSMutableDictionary *classToInfo = nil;

static void relInfo(void) {
  if (classToInfo)
    [classToInfo release]; classToInfo = nil;
}
static NGJavaScriptObjCClassInfo *jsClassInfo(Class _class) {
  NGJavaScriptObjCClassInfo  *ci;

  if (_class == Nil)
    return nil;

  if (classToInfo == nil) {
    classToInfo = [[NSMutableDictionary alloc] initWithCapacity:64];
    atexit(relInfo);
  }

  if ((ci = [classToInfo objectForKey:_class]) == nil) {
    ci = [[NGJavaScriptObjCClassInfo alloc]
                                     initWithClass:_class
                                     setter:NGJavaScriptBridge_setStaticProp
                                     getter:NGJavaScriptBridge_getStaticProp
                                     caller:&staticFuncDispatcher];
    [classToInfo setObject:ci forKey:_class];
    [ci autorelease];
  }
  
  return ci;
}

static Class NSStringClass = Nil;
static Class ObjInfoClass  = Nil;

static JSBool _addProp(JSContext *cx, JSObject *obj, jsval _id, jsval *vp);
static JSBool _delProp(JSContext *cx, JSObject *obj, jsval _id, jsval *vp);
static JSBool _getProp(JSContext *cx, JSObject *obj, jsval _id, jsval *vp);
static JSBool _setProp(JSContext *cx, JSObject *obj, jsval _id, jsval *vp);
static JSBool _resolve(JSContext *cx, JSObject *obj, jsval _id);
static JSBool _convert(JSContext *cx, JSObject *obj, JSType type, jsval *vp);
static void   _finalize(JSContext *cx, JSObject *obj);
//static JSBool _construct
//(JSContext *cx, JSObject *obj, uintN argc, jsval *argv, jsval *rval);

#if USE_ENUM
static JSBool
_newEnumObj(JSContext *cx, JSObject *obj,
            JSIterateOp op, jsval *statep, jsid *idp);
#endif

JSClass NGJavaScriptObjectHandler_JSClass = {
  "NGJavaScriptObjectHandler",
#if USE_ENUM
  JSCLASS_HAS_PRIVATE | JSCLASS_NEW_ENUMERATE /* flags */,
#else
  JSCLASS_HAS_PRIVATE /* flags */,
#endif
  _addProp,
  _delProp,
  _getProp,
  _setProp,
#if USE_ENUM
  (JSEnumerateOp)_newEnumObj,
#else
  JS_EnumerateStub,
#endif
  _resolve,
  _convert,
  _finalize,
  /* Optionally non-null members start here. */
  NULL, //JSGetObjectOps getObjectOps;
  NULL, //JSCheckAccessOp checkAccess;
  NULL, //JSNative call;
  NULL,// _construct //JSNative construct;
  NULL, //JSXDRObjectOp xdrObject;
  NULL, //JSHasInstanceOp hasInstance;
  //prword spare[2];
};

+ (void)initialize {
  if (NSStringClass == Nil) NSStringClass = [NSString class];
  if (ObjInfoClass  == Nil) ObjInfoClass  = [NGJavaScriptObjCClassInfo class];
}

+ (void *)defaultJSClassHandle {
  return &NGJavaScriptObjectHandler_JSClass;
}
- (void *)jsclassHandle {
  return [[self class] defaultJSClassHandle];
}

- (id)initWithJSContext:(NGJavaScriptContext *)_ctx {
  /*
    TODO: This *is* used. But where ? Document !
    
    -testSequence:
      blah = [[Blah alloc] init];
      [global setObject:blah forKey:@"blah"];
    The setObject: triggers the initWithJSContext:.
  */
  JSContext *cx;
  
  cx = [_ctx handle];
  
  self->jsObject = JS_NewObject(cx,
                                [self jsclassHandle],
                                NULL /* prototype */,
                                NULL /* parent    */);
  if (self->jsObject == NULL) {
    NSLog(@"WARNING(%s): got no JS object ...", __PRETTY_FUNCTION__);
    [self release];
    return nil;
  }
  
  // TODO: is it correct that private is retained ?
  JS_SetPrivate(cx, self->jsObject, [self retain]);
  
  self->jsContext = [_ctx handle];
  
  return self;
}
- (id)initWithJSContext:(NGJavaScriptContext *)_ctx handler:(id)_handler {
  // TODO: is this actually used anywhere
  if ((self = [self initWithJSContext:_ctx])) {
    self->managedObject = _handler;
    
    if (![self _applyStaticDefs]) {
      NSLog(@"ERROR(%s): rejecting creation of handler for %@ in ctx %@ "
	    @"because the static defs could not be applied !",
	    __PRETTY_FUNCTION__, _handler, _ctx);
      [self release];
      return nil;
    }
  }
  return self;
}

- (id)initWithObject:(id)_object
  inMappingContext:(NGObjectMappingContext *)_ctx
{
  /* 
     this one is called by -proxyForObject: and makeObjectCombined: of 
     NGJavaScriptObjectMappingContext
  */
  if ((self = [self initWithJSContext:[(id)_ctx jsContext]])) {
    self->ctx           = (NGJavaScriptObjectMappingContext *)_ctx;
    self->managedObject = _object;
    
    if (![self _applyStaticDefs]) {
      NSLog(@"ERROR(%s): rejecting creation of handler for %@ in ctx %@ "
	    @"because the static defs could not be applied !",
	    __PRETTY_FUNCTION__, _object, _ctx);
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  JSContext *cx;
  
  /* 
     Note: managedObject could already be deallocated at this stage ! 
     BUT: if managedObject is deallocated, the "ctx" is not retained
          by the managedObject and therefore possibly broken !
  */
  
  if (NGJavaScriptBridge_TRACK_MEMORY) {
    NSLog(@"%s: dealloc 0x%p<%@> at 0x%p on j0x%p",
          __PRETTY_FUNCTION__,
          self, NSStringFromClass([self class]),
          self->managedObject,
          self->jsObject);
  }
  
  cx = self->jsContext;
  
  if (self->jsObject) {
    if (cx) {
      id priv;
      
      while (self->jsRootRC > 0) 
        JS_RemoveRoot(cx, self->jsObject);
      self->jsRootRC = 0;
      
      priv = JS_GetPrivate(cx, self->jsObject);
      if (priv == self) {
        NSLog(@"ERROR(%s): object handler 0x%p still has a private ???",
              __PRETTY_FUNCTION__, self);
        JS_SetPrivate(cx, self->jsObject, NULL);
      }
    }
  }
  else {
    if (self->jsRootRC > 0) {
      NSLog(@"WARNING(%s): jsRootRc > 0, but jsObject is missing 0x%p",
            __PRETTY_FUNCTION__, self);
    }
  }
  
  [super dealloc];
}

/* accessors */

- (NGJavaScriptContext *)jsContext {
  return [NGJavaScriptContext jsContextForHandle:self->jsContext];
}
- (void *)handle {
  return self->jsObject;
}

- (NSString *)javaScriptClassName {
  JSClass *clazz;
  
  if (self->jsObject == nil)
    return nil;
  
  if ((clazz = JS_GetClass(self->jsObject)))
    return nil;
  
  return [NSStringClass stringWithCString:clazz->name];
}

- (id)managedObject {
  return self->managedObject;
}

- (id)parentObject {
  JSObject *pjso;

  if ((pjso = JS_GetParent(self->jsContext, self->jsObject)) == NULL)
    return nil;
  
  return [self->ctx objectForHandle:pjso];
}

/* JS root references */

- (const char *)_jsRCName {
#if DEBUG && 0
  /* WATCH OUT: leaks memory ! */
  char *buf;
  buf = malloc(32);
  sprintf(buf, "ObjC:0x%p", (unsigned)self);
  return buf;
#else
  return "ObjC root";
#endif
}

- (id)jsRetain {
  if (self->jsRootRC > 0) {
    self->jsRootRC++;
  }
  else {
    JSBool     ret;
    const char *c;
    JSContext  *cx;
    
    cx = self->jsContext;
    
    NSAssert(self->jsObject,  @"missing JS object !");
    NSAssert(cx,              @"missing JS context !");
    
    c = [self _jsRCName];
    ret = c != NULL
      ? JS_AddNamedRoot(cx, &self->jsObject, c)
      : JS_AddRoot(cx, &self->jsObject);
    
    NSAssert(ret, @"couldn't add JS root !");
    self->jsRootRC = 1;
  }
  return self;
}
- (void)jsRelease {
  if (self->jsRootRC < 1) {
    NSLog(@"WARNING(%s): called jsRelease on JS object which is not retained !");
    return;
  }
  self->jsRootRC--;
  
  if (self->jsRootRC == 0)
    JS_RemoveRoot(self->jsContext, &self->jsObject);
}
- (unsigned)jsRootRetainCount {
  return self->jsRootRC;
}

/* properties */

- (BOOL)hasPropertyNamed:(NSString *)_propName {
  JSBool r;
  jsval  v;

  r = JS_LookupProperty(self->jsContext,
                       self->jsObject,
                        [_propName cString],
                       &v);
  if (!r) {
    NSLog(@"WARNING: JS_LookupProperty call failed !");
    return NO;
  }
  return v == JSVAL_VOID ? NO : YES;
}

- (BOOL)hasElementAtIndex:(unsigned)_idx {
  JSBool r;
  jsval  v;
  
  r = JS_LookupElement(self->jsContext,
                       self->jsObject,
                       _idx,
                       &v);
  if (!r) return NO;
  return v == JSVAL_VOID ? NO : YES;
}

- (void)setValue:(id)_value ofPropertyNamed:(NSString *)_propName {
  JSBool ret;
  jsval  val;

  if (![self->ctx jsValue:&val forObject:_value]) {
    NSLog(@"WARNING: couldn't convert ObjC value to JS: %@", _value);
    return;
  }
  
  ret = JS_SetProperty(self->jsContext,
                       self->jsObject,
                       [_propName cString],
                       &val);
  if (!ret) {
    NSLog(@"WARNING: couldn't set value of property %@ ", _propName);
    return;
  }
}
- (id)valueOfPropertyNamed:(NSString *)_propName {
  JSBool ret;
  jsval  val;

  ret = JS_GetProperty(self->jsContext,
                       self->jsObject,
                       [_propName cString],
                       &val);
  if (!ret) {
    NSLog(@"WARNING: couldn't get value of property %@ ", _propName);
    return nil;
  }

  if (val == JSVAL_VOID)
    /* property is not defined */
    return nil;

  return [self->ctx objectForJSValue:&val];
}

/* scripts */

- (id)callFunctionNamed:(NSString *)_funcName, ... {
  va_list  va;
  unsigned argc, i;
  JSBool   res;
  jsval    result;
  jsval    *argv;
  id       arg;
  
  argc = 0;
  argv = NULL;
  
  va_start(va, _funcName);
  for (arg = va_arg(va, id); arg; arg = va_arg(va, id))
    argc++;
  va_end(va);
  
  if (argc > 0) {
    argv = calloc(argc, sizeof(jsval));
    va_start(va, _funcName);
    for (arg = va_arg(va, id), i = 0; arg; arg = va_arg(va, id), i++) {
      if (![self->ctx jsValue:&(argv[i]) forObject:arg])
        NSLog(@"couldn't convert func argument !");
    }
    va_end(va);
  }
  
  res = JS_CallFunctionName(self->jsContext,
                            self->jsObject,
                            [_funcName cString],
                            argc,
                            argv,
                            &result);
  if (argv) free(argv);
  
  if (res)
    return [self->ctx objectForJSValue:&result];
  
  [NSException raise:@"JavaScriptEvalException"
               format:@"could not call function '%@' !", _funcName];
  return nil;
}

- (id)evaluateScript:(NSString *)_script {
  JSBool   res;
  jsval    lastValue;
  
  NSAssert(self->jsObject, @"missing JS object ..");
  
  res = JS_EvaluateScript(self->jsContext,
                          self->jsObject /* script obj */,
                          [_script cString],
                          [_script cStringLength],
                          "<string>",  /* source file */
                          0,           /* line number */
                          &lastValue);
  
  if (res == JS_TRUE)
    return [self->ctx objectForJSValue:&lastValue];
  
  {
    NSException  *e;
    NSDictionary *ui;

    ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         _script,         @"script",
                         self,            @"objectHandler",
                         [NGJavaScriptContext jsContextForHandle:
                                              self->jsContext], @"jscontext",
                         nil];
    
    e = [[NSException alloc] initWithName:@"JavaScriptEvalException"
                             reason:@"couldn't evaluate script"
                             userInfo:ui];
    [e raise];
  }
  return nil;
}

/* static definition declarations */

static JSBool NGJavaScriptBridge_setStaticProp
(JSContext *cx, JSObject *obj, jsval _id, jsval *vp)
{
  NGJavaScriptObjectHandler *self;
  NGJavaScriptObjCClassInfo *ci;
  SEL        sel;
  id         value;
  
  if ((self = JS_GetPrivate(cx, obj)) == NULL)
    return JS_FALSE;
  
  ci  = jsClassInfo([self->managedObject class]);
  sel = [ci setSelectorForPropertyId:&_id inJSContext:cx];
  
  if (sel == NULL) {
    NSLog(@"%s: did not find selector for id !", __PRETTY_FUNCTION__);
    return JS_FALSE;
  }
  
  value = [self->ctx objectForJSValue:vp];
  [self->managedObject performSelector:sel withObject:value];
  
  return JS_TRUE;
}
static JSBool NGJavaScriptBridge_getStaticProp
(JSContext *cx, JSObject *obj, jsval _id, jsval *vp)
{
  NGJavaScriptObjCClassInfo *ci;
  NGJavaScriptObjectHandler *self;
  SEL sel;
  id  result;
  
  if ((self = JS_GetPrivate(cx, obj)) == NULL) {
    NSLog(@"%s: did not get private of JS object !", __PRETTY_FUNCTION__);
    return JS_FALSE;
  }
  
  ci  = jsClassInfo([self->managedObject class]);
  sel = [ci getSelectorForPropertyId:&_id inJSContext:cx];
  
  if (sel == NULL) {
    NSLog(@"%s: did not find selector for id !", __PRETTY_FUNCTION__);
    return JS_FALSE;
  }
  
  result = [self->managedObject performSelector:sel];
  //NSLog(@"result is %@", result);
  
  return [self->ctx jsValue:vp forObject:result]
    ? JS_TRUE
    : JS_FALSE;
}

static JSBool 
staticFuncDispatcher
(JSContext *cx, JSObject *obj, uintN argc, jsval *argv, jsval *rval)
{
  NGJavaScriptObjectHandler *self;
  NSException *exception;
  JSFunction  *funobj;
  const char  *funcName;
  char        *msgname;
  SEL         sel;
  unsigned    i;
  id          *args;
  NSArray     *argArray;
  id          result;
  JSBool      retcode = 0;

#if DEBUG && 0
  {
    JSClass *clazz;
    const char *cname;

    if ((clazz = JS_GetClass(obj)))
      cname = clazz->name;
    else
      cname = "<no class>";
    
    printf("%s: cx=0x%p, obj=0x%p<%s>, argc=%d\n",
           __PRETTY_FUNCTION__,
           cx, obj, cname, argc);
  }
#endif
  
  if (JS_IsConstructing(cx))
    obj = JS_GetParent(cx, obj);
  
#if DEBUG
  if (JS_GetClass(obj) != &NGJavaScriptObjectHandler_JSClass) {
    NSLog(@"%s: invoked on invalid object class (eg using 'new' ?) !",
          __PRETTY_FUNCTION__);
    return JS_FALSE;
  }
#endif
  
  if ((self = JS_GetPrivate(cx, obj)) == NULL)
    return JS_FALSE;
  
#if DEBUG
  NSCAssert(JS_TypeOfValue(cx, argv[-2]) == JSTYPE_FUNCTION,
            @"expected function in argv[-2] !");
#endif
  
  funobj   = JS_GetPrivate(cx, JSVAL_TO_OBJECT(argv[-2]));
  funcName = JS_GetFunctionName(funobj);
  
  msgname = malloc(strlen(funcName) + 10);
  strcpy(msgname, "_jsfunc_");
  strcat(msgname, funcName);
  strcat(msgname, ":");
#if APPLE_RUNTIME || NeXT_RUNTIME
  sel = sel_getUid(msgname); /* TODO: should be registerName? */
#else
  sel = sel_get_any_uid(msgname);
#endif
  
  if (argc > 0) {
    args = calloc(argc, sizeof(id));
    for (i = 0; i < argc; i++) {
      args[i] =
        [self->ctx objectForJSValue:&(argv[i])];
      
      if (args[i] == nil) args[i] = [EONull null];
    }
    argArray = [NSArray arrayWithObjects:args count:argc];
    free(args);
  }
  else
    argArray = [NSArray array];

#if 0  
  NSLog(@"calling function '%s'(%s), %d args %@\n",
        funcName, msgname, argc, argArray);
#endif
  
  exception = nil;
  NS_DURING {
    result  = [self->managedObject performSelector:sel withObject:argArray];
    retcode = [self->ctx jsValue:rval forObject:result] ? JS_TRUE : JS_FALSE;
  }
  NS_HANDLER {
    exception = [localException retain];
  }
  NS_ENDHANDLER;
  
  if (exception) {
    jsval exval;
    
#if DEBUG
    NSLog(@"%s: catched exception: %@", __PRETTY_FUNCTION__, exception);
#endif
    retcode   = JS_FALSE;
    
    if ([self->ctx jsValue:&exval forObject:exception]) {
      JS_SetPendingException(cx, exval);
    }
    else {
      NSLog(@"%s: couldn't get JS value for exception: %@",
            __PRETTY_FUNCTION__, exception);
    }
  }
  
#if 0
  NSLog(@"result is %@", result);
#endif
  
  return retcode;
}

+ (void *)jsStaticFuncDispatcher {
  return &staticFuncDispatcher;
}

- (BOOL)_applyStaticDefs {
  NGJavaScriptObjCClassInfo *ci;
  BOOL ok;
  
  if (self->managedObject == nil) {
    NSLog(@"WARNING(%s): cannot apply defs on nil ...", __PRETTY_FUNCTION__);
    return NO;
  }
  
  ci = jsClassInfo([self->managedObject class]);
  
  IsInPropDefMode = YES;
  ok = [ci applyOnJSObject:self->jsObject inJSContext:self->jsContext];
  if (!ok)
    NSLog(@"ERROR(%s): couldn't apply static defs !", __PRETTY_FUNCTION__);
  IsInPropDefMode = NO;
  return ok;
}

- (BOOL)isStaticProperty:(NSString *)_name {
  NGJavaScriptObjCClassInfo *ci;
  ci = jsClassInfo([self->managedObject class]);
  return [ci isStaticProperty:_name];
}

/* misc */

- (BOOL)loadStandardClasses {
  NSLog(@"NGJavaScriptObjectHandler: load std classes ...");
  if (!JS_InitStandardClasses(self->jsContext, self->jsObject)) {
    NSLog(@"NGJavaScriptObjectHandler: failed to load std classes ...");
    return NO;
  }
  return YES;
}

- (void)makeGlobal {
  JS_SetGlobalObject(self->jsContext, self->jsObject);
}

/* unknown id */

- (void)failureUnknownIDType:(jsval)_id {
#if DEBUG
  abort();
#else
  NSLog(@"SERIOUS ERROR(%s:%i): unknown id type ..",
        __PRETTY_FUNCTION__, __LINE__);
#endif
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  [ms appendFormat:@" handle=0x%p", [self handle]];
  [ms appendFormat:@" class=%@", [self javaScriptClassName]];
  [ms appendFormat:@" parent=%@", [self parentObject]];
  [ms appendString:@">"];
  
  return ms;
}

/* JS class methods */

typedef enum {
  NGPropOp_add,
  NGPropOp_del,
  NGPropOp_set,
  NGPropOp_get,
  NGPropOp_resolve
} NGPropOp;

static inline JSBool _propOp(JSContext *cx, NGPropOp op,
                             JSObject *obj, jsval _id, jsval *vp)
{
  NGJavaScriptObjectHandler *self;
  BOOL res = NO;
  
  if ((self = JS_GetPrivate(cx, obj)) == nil) {
    NSLog(@"WARNING: missing private in NGJavaScriptObjectHandler JS object !");
    return JS_PropertyStub(cx, obj, _id, vp);
  }
  
  if (IsInPropDefMode)
    return JS_PropertyStub(cx, obj, _id, vp);

  NSCAssert2(self->managedObject,
             @"missing managed object (handler=%@, j0x%p) !",
             self, obj);
  
  if (JSVAL_IS_INT(_id)) {
    /* lookup by key */
    int sel;
    
    sel = JSVAL_TO_INT(_id);
    
    switch (op) {
      case NGPropOp_get: {
        if (NGJavaScriptBridge_LOG_PROP_GET)
          NSLog(@"JS: get by sel %i", sel);
        
        if (sel > 0) {
          if ([self->managedObject respondsToSelector:
                   @selector(valueForJSPropertyAtIndex:)]) {
            id v;
          
            v   = [self->managedObject valueForJSPropertyAtIndex:sel];
            res = [self->ctx jsValue:vp forObject:v];
          }
        }
        break;
      }

      case NGPropOp_set: {
        if (NGJavaScriptBridge_LOG_PROP_SET)
          NSLog(@"JS: set by sel %i", sel);
        
        if (sel > 0) {
          if ([self->managedObject respondsToSelector:
                   @selector(takeValue:forJSPropertyAtIndex:)]) {
            id v;
          
            v = [self->ctx objectForJSValue:vp];
          
            res = [self->managedObject takeValue:v forJSPropertyAtIndex:sel];
          }
        }
        
        break;
      }
      
      case NGPropOp_resolve:
#if LOG_PROP_RESOLVE
        NSLog(@"RESOLVE '%i'", idx);
#endif
        break;
        
      case NGPropOp_del:
      case NGPropOp_add:
        NSLog(@"int keys are not supported for this operation (%i) !", op);
        return JS_FALSE;
    }
  }
  else if (JSVAL_IS_STRING(_id)) {
    /* lookup by name */
    NSString *name;
    JSString *jsname;

    res = YES;
      
    jsname = JS_ValueToString(cx, _id);
    name   = [NSStringClass stringWithJavaScriptString:jsname];
    
    switch (op) {
      case NGPropOp_resolve: {
#if LOG_PROP_RESOLVE
        NSLog(@"RESOLVE '%@'", name);
#endif
#if 0
        res  = [self resolvePropertyByName:name];
#endif
        break;
      }
      
      case NGPropOp_del: {
        if ([self isStaticProperty:name])
          break;
        
        if (NGJavaScriptBridge_LOG_PROP_DEL)
          NSLog(@"JS: NOT REALLY SUPPORTED del by name %@", name);
        
        break;
      }
      
      case NGPropOp_add: {
        if (NGJavaScriptBridge_LOG_PROP_ADD) {
          NSLog(@"JS: add by name '%@' type %s "
                @"j0x%p o0x%p<%@> on o0x%p<%@>",
                name, JS_GetTypeName(cx, JS_TypeOfValue(cx, *vp)),
                obj, self, NSStringFromClass([self class]),
                self->managedObject,
                NSStringFromClass([self->managedObject class]));
        }

        if ([self->managedObject respondsToSelector:
                 @selector(takeValue:forJSPropertyNamed:)]) {
          id v;
        
          if ((v = [self->ctx objectForJSValue:vp]) == nil)
            v = [EONull null];
        
          res = [self->managedObject takeValue:v forJSPropertyNamed:name];
        }
        
        break;
      }
      
      case NGPropOp_get: {
        if ([self isStaticProperty:name])
          break;
        
        if (NGJavaScriptBridge_LOG_PROP_GET) {
          NSLog(@"JS: get by name '%@' type %s "
                @"j0x%p o0x%p<%@> on o0x%p<%@>",
                name, JS_GetTypeName(cx, JS_TypeOfValue(cx, *vp)),
                obj, self, NSStringFromClass([self class]),
                self->managedObject,
                NSStringFromClass([self->managedObject class]));
        }
        
        if ([self->managedObject respondsToSelector:
                 @selector(valueForJSPropertyNamed:)]) {
          NS_DURING {
            id v;
          
            v   = [self->managedObject valueForJSPropertyNamed:name];
            
            if (NGJavaScriptBridge_LOG_PROP_GET) {
              NSLog(@"  return value o0x%p<%@>",
                    v, NSStringFromClass([v class]));
            }
            
            res = [self->ctx jsValue:vp forObject:v];
          }
          NS_HANDLER {
            [[self->ctx jsContext] reportException:localException];
            res = NO;
          }
          NS_ENDHANDLER;
        }
        break;
      }
      
      case NGPropOp_set: {
        if ([self isStaticProperty:name])
          break;
        
        if (NGJavaScriptBridge_LOG_PROP_SET) {
          NSLog(@"JSObjectHandler: set by name '%@' type %s "
                @"j0x%p o0x%p<%@> on o0x%p<%@>",
                name, JS_GetTypeName(cx, JS_TypeOfValue(cx, *vp)),
                obj, self, NSStringFromClass([self class]),
                self->managedObject,
                NSStringFromClass([self->managedObject class]));
        }
      
        if ([self->managedObject respondsToSelector:
                 @selector(takeValue:forJSPropertyNamed:)]) {
          id v;
        
          v   = [self->ctx objectForJSValue:vp];
          res = [self->managedObject takeValue:v forJSPropertyNamed:name];
        }
        break;
      }
    }
  }
  else {
    [self failureUnknownIDType:_id];
    res = NO;
  }
  
  return res ? JS_TRUE : JS_FALSE;
}

static JSBool _addProp(JSContext *cx, JSObject *obj, jsval _id, jsval *vp) {
  return _propOp(cx, NGPropOp_add, obj, _id, vp);
}
static JSBool _delProp(JSContext *cx, JSObject *obj, jsval _id, jsval *vp) {
  return _propOp(cx, NGPropOp_del, obj, _id, vp);
}
static JSBool _getProp(JSContext *cx, JSObject *obj, jsval _id, jsval *vp) {
  return _propOp(cx, NGPropOp_get, obj, _id, vp);
}
static JSBool _setProp(JSContext *cx, JSObject *obj, jsval _id, jsval *vp) {
  return _propOp(cx, NGPropOp_set, obj, _id, vp);
}

#if USE_ENUM
static JSBool
_newEnumObj(JSContext *cx, JSObject *obj,
            JSIterateOp op, jsval *statep, jsid *idp)
{
  NGJavaScriptObjectHandler *self;

  if ((self = JS_GetPrivate(cx, obj)) == nil)
    return JS_TRUE;
  else {
    NSEnumerator *e;
    
    NSCAssert(self->managedObject, @"missing managed object !");
    
    if (![self->managedObject respondsToSelector:@selector(jsObjectEnumerator)])
      return JS_TRUE;
    
    switch (op) {
      case JSENUMERATE_INIT:
        e = [[self->managedObject jsObjectEnumerator] retain];
        *statep = PRIVATE_TO_JSVAL(e);
        if (idp) *idp = JSVAL_ZERO;
        break;
        
      case JSENUMERATE_NEXT: {
        id nextObj;
        
        e = JSVAL_TO_PRIVATE(*statep);
        
        if ((nextObj = [e nextObject])) {
          jsval idval;
          
          // NSLog(@"next id %@ ..", nextObj);
#if 0 // can someone explain that ?
          if (![self->ctx jsValue:&idval forObject:nextObject])
            return JS_FALSE;
#else
          idval = INT_TO_JSVAL([nextObj intValue]);
#endif
          
          if (!JS_ValueToId(cx, idval, idp))
            return JS_FALSE;
          
          break;
        }
        //NSLog(@"no more IDs ..");
        /* else fall through */
      }
      case JSENUMERATE_DESTROY: {
        //NSLog(@"destroying enum ..");
        if (*statep != JSVAL_NULL) {
          if ((e = JSVAL_TO_PRIVATE(*statep))) {
            [e release];
            e = nil;
          }
          *statep = JSVAL_NULL;
        }
        break;
      }
    }
    return JS_TRUE;
  }
}
#endif

#if 0
static JSBool _construct
(JSContext *cx, JSObject *obj, uintN argc, jsval *argv, jsval *rval)
{
  NSLog(@"construct called ..");
  return JS_FALSE;
}
#endif

static JSBool _resolve(JSContext *cx, JSObject *obj, jsval _id) {
  return _propOp(cx, NGPropOp_resolve, obj, _id, NULL);
}

static JSBool _convert(JSContext *cx, JSObject *obj, JSType type, jsval *vp) {
  NGJavaScriptObjectHandler *self;
  
  if ((self = JS_GetPrivate(cx, obj)) == nil)
    return JS_ConvertStub(cx, obj, type, vp);
  else {
    NSCAssert(self->managedObject, @"missing managed object !");
    
    switch (type) {
      case JSTYPE_VOID:
      case JSTYPE_STRING: {
        NSString *s;
        
        s = [self->managedObject stringValue];
        return [self->ctx jsValue:vp forObject:s];
      }
      
      case JSTYPE_NUMBER:
        *vp = INT_TO_JSVAL([self->managedObject intValue]);
        return JS_TRUE;
        
      case JSTYPE_BOOLEAN:
        *vp = [self->managedObject boolValue] ? JSVAL_TRUE : JSVAL_FALSE;
        return JS_TRUE;
        
      case JSTYPE_OBJECT:
      case JSTYPE_FUNCTION:
      default:
        return JS_ConvertStub(cx, obj, type, vp);
    }
  }
}

static void _finalize(JSContext *cx, JSObject *obj) {
  NGJavaScriptObjectHandler *self;
  
  if ((self = JS_GetPrivate(cx, obj)) == nil) {
    JS_FinalizeStub(cx, obj);
  }
  else if (self->jsObject == obj) {
    /* the managed JS object is the same as the finalizing object */
    
    NSCAssert(self->managedObject, @"missing managed object !");
    
    if (NGJavaScriptBridge_TRACK_FINALIZATION) {
      NSLog(@"finalizing j0x%p o0x%p<%@>",
            obj, 
            self->managedObject, 
	    NSStringFromClass([self->managedObject class]));
    }
    
    [self->ctx forgetObject:self->managedObject];
    
#if DEBUG && 0
#warning RC watch is on !
    if ([self retainCount] != 1) {
      NSLog(@"WARNING: JS object %@ was collected, "
            @"but handle is still live (rc=%d) "
            @"(could be pending autorelease refs: pending: %d) !",
            self, [self retainCount],
            [NSAutoreleasePool autoreleaseCountForObject:self]);
    }
#endif
    
    JS_SetPrivate(self->jsContext, obj, NULL);
    self->jsObject = NULL;
    
    /* release private ref */
    NSCAssert(self, @"where got self ??");
    [self release]; self = nil;
  }
  else {
#if DEBUG
    fprintf(stderr, "%s: finalization error ...\n", __PRETTY_FUNCTION__);
    abort();
#else
    fprintf(stderr, "%s: finalization error ...\n", __PRETTY_FUNCTION__);
#endif
  }
}

@end /* NGJavaScriptObjectHandler */
