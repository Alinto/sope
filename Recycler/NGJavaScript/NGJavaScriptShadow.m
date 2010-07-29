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

#include "NGJavaScriptShadow.h"
#include "NGJavaScriptObjCClassInfo.h"
#include "NGJavaScriptObjectMappingContext.h"
#include <NGScripting/NGScriptLanguage.h>
#include "common.h"
#include "globals.h"

static BOOL IsInPropDefMode = NO;

@interface NGJavaScriptShadow(Privates)
- (BOOL)_applyStaticDefs;
@end

@implementation NGJavaScriptShadow

static NGScriptLanguage *jslang = nil;

static inline NGScriptLanguage *_JS(void) {
  if (jslang == nil)
    jslang = [[NGScriptLanguage languageWithName:@"javascript"] retain];
  return jslang;
}

static void _finalize(JSContext *cx, JSObject *obj) {
  NGJavaScriptShadow *self;
  
  if ((self = JS_GetPrivate(cx, obj)) == NULL) {
    //printf("finalized JS shadow ..\n");
  }
  else {
    NSLog(@"ERROR(%s): finalizing JS shadow j0x%p, "
          @"still has a private o0x%p !!!",
          __PRETTY_FUNCTION__, obj, self);
  }
}

JSClass ObjCShadow_JSClass = {
  "NGObjCShadow",
  JSCLASS_HAS_PRIVATE /* flags */,
  JS_PropertyStub,
  JS_PropertyStub,
  JS_PropertyStub,
  JS_PropertyStub,
  JS_EnumerateStub,
  JS_ResolveStub,
  JS_ConvertStub,
  _finalize,
  /* Optionally non-null members start here. */
  NULL, //JSGetObjectOps getObjectOps;
  NULL, //JSCheckAccessOp checkAccess;
  NULL, //JSNative call;
  NULL, //JSNative construct;
  NULL, //JSXDRObjectOp xdrObject;
  NULL, //JSHasInstanceOp hasInstance;
  //prword spare[2];
};

+ (void *)jsObjectClass {
  return &ObjCShadow_JSClass;
}

static JSBool shadow_FuncDispatcher
(JSContext *cx, JSObject *obj, uintN argc, jsval *argv, jsval *rval);
static JSBool shadow_setStaticProp
(JSContext *cx, JSObject *obj, jsval _id, jsval *vp);
static JSBool shadow_getStaticProp
(JSContext *cx, JSObject *obj, jsval _id, jsval *vp);

static NSMutableDictionary *classToInfo = nil;

static void relInfo(void) {
  if (classToInfo)
    RELEASE(classToInfo); classToInfo = nil;
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
                                     setter:shadow_setStaticProp
                                     getter:shadow_getStaticProp
                                     caller:shadow_FuncDispatcher];
    [classToInfo setObject:ci forKey:_class];
    AUTORELEASE(ci);
  }
  
  return ci;
}

- (id)initWithHandle:(void *)_handle
  inMappingContext:(NGObjectMappingContext *)_ctx
{
  if ((self = [super initWithHandle:_handle inMappingContext:_ctx])) {
    JS_SetPrivate(self->jscx, _handle, self);
  }
  return self;
}

- (void)dealloc {
  if (NGJavaScriptBridge_TRACK_MEMORY) {
    NSLog(@"%s: dealloc shadow o0x%p j0x%p ctx=0x%p jcx=0x%p",
          __PRETTY_FUNCTION__, self, self->handle,
          self->ctx, self->jscx);
  }
  
  if (self->handle)
    JS_SetPrivate(self->jscx, self->handle, NULL);
  
  [super dealloc];
}

- (void)setMasterObject:(id)_master {
  if ((self->masterObject = _master)) {
    if (![self _applyStaticDefs]) {
      self->masterObject = nil;
      NSLog(@"%s: resetted master object, because static defs could "
	    @"not be applied: %@", __PRETTY_FUNCTION__, _master);
    }
  }
  else {
    if (NGJavaScriptBridge_TRACK_MEMORY) {
      NSLog(@"%s: resetted shadow master (rc now %i)",
            __PRETTY_FUNCTION__,
            [self retainCount]);
    }
  }
}
- (id)masterObject {
  return self->masterObject;
}
- (void)invalidateShadow {
  [self setMasterObject:nil];
}

- (BOOL)_applyStaticDefs {
  NGJavaScriptObjCClassInfo *ci;
  BOOL ok;
  
  if (self->masterObject == nil)
    return NO;
  
  ci = jsClassInfo([self->masterObject class]);
  
  IsInPropDefMode = YES;
  ok = [ci applyOnJSObject:self->handle inJSContext:self->jscx];
  if (!ok)
    NSLog(@"ERROR(%s): couldn't apply static defs !", __PRETTY_FUNCTION__);
  IsInPropDefMode = NO;
  return ok;
}

/* static definition declarations */

static JSBool shadow_setStaticProp
(JSContext *cx, JSObject *obj, jsval _id, jsval *vp)
{
  NGJavaScriptObjCClassInfo *ci;
  NGJavaScriptShadow *self;
  SEL sel;
  id  value;
  
  if ((self = JS_GetPrivate(cx, obj)) == NULL)
    return JS_FALSE;
  
  if (self->masterObject == nil) {
    NSLog(@"%s: master object was deallocated !", __PRETTY_FUNCTION__);
    return JS_FALSE;
  }
  
  ci = jsClassInfo([self->masterObject class]);
  NSCAssert(ci, @"missing class info ..");
  
  sel = [ci setSelectorForPropertyId:&_id inJSContext:cx];
  
  if (sel == NULL) {
    NSLog(@"%s: did not find selector for id !", __PRETTY_FUNCTION__);
    return JS_FALSE;
  }
  
  value = [self->ctx objectForJSValue:vp];
  [self->masterObject performSelector:sel withObject:value];
  
  return JS_TRUE;
}
static JSBool shadow_getStaticProp
(JSContext *cx, JSObject *obj, jsval _id, jsval *vp)
{
  NGJavaScriptObjCClassInfo *ci;
  NGJavaScriptShadow *self;
  SEL sel;
  id  result;
  
  if ((self = JS_GetPrivate(cx, obj)) == NULL) {
    NSLog(@"%s: did not find private of JS shadow object !",
          __PRETTY_FUNCTION__);
    return JS_FALSE;
  }
  
  if (self->masterObject == nil) {
    NSLog(@"%s: master object was deallocated !", __PRETTY_FUNCTION__);
    return JS_FALSE;
  }
  
  ci  = jsClassInfo([self->masterObject class]);
  sel = [ci getSelectorForPropertyId:&_id inJSContext:cx];
  
  if (sel == NULL) {
    NSLog(@"%s: did not find selector for id !", __PRETTY_FUNCTION__);
    return JS_FALSE;
  }
  
  result = [self->masterObject performSelector:sel];
  //NSLog(@"result is %@", result);
  
  return [self->ctx jsValue:vp forObject:result]
    ? JS_TRUE
    : JS_FALSE;
}

static JSBool shadow_FuncDispatcher
(JSContext *cx, JSObject *obj, uintN argc, jsval *argv, jsval *rval)
{
  NGJavaScriptShadow *self;
  JSFunction  *funobj;
  const char  *funcName;
  char        *msgname;
  SEL         sel;
  unsigned    i;
  id          *args;
  NSArray     *argArray;
  id          result;
  NSException *exception;
  JSBool      retcode = 0;
  
  if (JS_IsConstructing(cx)) 
    obj = JS_GetParent(cx, obj);
  
#if DEBUG
  if (JS_GetClass(obj) != &ObjCShadow_JSClass) {
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
    result  = [self->masterObject performSelector:sel withObject:argArray];
    retcode = [self->ctx jsValue:rval forObject:result] ? JS_TRUE : JS_FALSE;
  }
  NS_HANDLER {
    exception = RETAIN(localException);
  }
  NS_ENDHANDLER;
  
  if (exception) {
    jsval exval;
    
#if DEBUG
    NSLog(@"%s: catched exception: %@", __PRETTY_FUNCTION__, exception);
#endif
    
    retcode = JS_FALSE;
    
    if ([self->ctx jsValue:&exval forObject:[exception description]]) {
      JS_SetPendingException(cx, exval);
    }
    else {
      NSLog(@"%s: couldn't get JS value for exception: %@",
            __PRETTY_FUNCTION__, exception);
    }
  }
  
  return retcode;
}

/* specialized calls */

- (id)callScriptFunction:(NSString *)_func {
  return [_JS() callFunction:_func onObject:self];
}
- (id)callScriptFunction:(NSString *)_func withObject:(id)_obj {
  return [_JS() callFunction:_func withArgument:_obj onObject:self];
}
- (BOOL)hasFunctionNamed:(NSString *)_func {
  return [super hasFunctionNamed:_func];
}

- (id)evaluateScript:(NSString *)_script 
  source:(NSString *)_src line:(unsigned)_line 
{
  return [_JS() evaluateScript:_script onObject:self source:_src line:_line];
}
- (id)evaluateScript:(NSString *)_script {
  return [self evaluateScript:_script source:@"<string>" line:0];
}

/* NSCoding */

- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder])) {
    [self setMasterObject:[_coder decodeObject]];
  }
  return self;
}
- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];
  [_coder encodeObject:[self masterObject]];
}

@end /* NGJavaScriptShadow */
