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
#include "NGJavaScriptRuntime.h"
#include "NGJavaScriptObject.h"
#include "NGJavaScriptFunction.h"
#include "NGJavaScriptObjectHandler.h"
#include "NGJavaScriptError.h"
#include "NSString+JS.h"
#include "common.h"


@interface NGJavaScriptContext(PrivateMethods)

@end

static JSBool
Print(JSContext *cx, JSObject *obj, uintN argc, jsval *argv, jsval *rval);

@implementation NGJavaScriptContext

static BOOL abortOnJSError = NO;
static BOOL debugDealloc   = NO;
NSMapTable *jsctxToObjC = NULL;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  abortOnJSError = [ud boolForKey:@"JSAbortOnError"];
  debugDealloc   = [ud boolForKey:@"JSDebugContextDealloc"];
}

static JSFunctionSpec functions[] = {
    {"print",           Print,          0},
    {0}
};


static void jsErrorReporter(JSContext *cx, const char *msg, JSErrorReport *rp);
static JSBool jsGCCallback(JSContext *cx, JSGCStatus status)
     __attribute__((unused));


static JSBool global_resolve(JSContext *cx, JSObject *obj, jsval _id)
     __attribute__((unused));
static JSBool global_resolve(JSContext *cx, JSObject *obj, jsval _id) {
  NGJavaScriptContext *self;
  
  self = NSMapGet(jsctxToObjC, cx);
  
  NSLog(@"resolve called on %@.", self);
  return JS_ResolveStub(cx, obj, _id);
}

+ (NGJavaScriptContext *)jsContextForHandle:(void *)_handle {
  NGJavaScriptContext *ctx;

  ctx = NSMapGet(jsctxToObjC, _handle);
  return ctx;
}

- (id)initWithRuntime:(NGJavaScriptRuntime *)_rt
  maximumStackSize:(unsigned)_size
{
  self->handle = JS_NewContext([_rt handle], _size ? _size : 8192);
  if (self->handle == NULL) {
    NSLog(@"WARNING(%s): got no handle !", __PRETTY_FUNCTION__);
    [self release];
    return nil;
  }
  
  if (jsctxToObjC == NULL) {
    jsctxToObjC = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
                                   NSNonRetainedObjectMapValueCallBacks,
                                   200);
  }
  NSMapInsert(jsctxToObjC, self->handle, self);
  JS_SetErrorReporter(self->handle, jsErrorReporter);
  
  // JSSetGCCallback(self->handle, jsGCCallback);
  
#if 0
  /* setup initial global */
  {
    NGJavaScriptObject *oglob;
    
    oglob = [[NGJavaScriptObject alloc] initWithJSContext:self];
    if (oglob == nil) {
      [self release];
      return nil;
    }
    [oglob makeGlobal];
    
    [oglob release]; oglob = nil;
  }
#endif
  
  ASSIGN(self->rt, _rt);
  
  return self;
}
- (id)initWithRuntime:(NGJavaScriptRuntime *)_rt {
  return [self initWithRuntime:_rt maximumStackSize:0];
}
- (id)init {
  return [self initWithRuntime:[NGJavaScriptRuntime standardJavaScriptRuntime]
               maximumStackSize:0];
}

- (void)dealloc {
  if (debugDealloc) NSLog(@"dealloc context: %@", self);
  
  [self collectGarbage];
  
  if (self->handle) {
    JS_DestroyContext(self->handle);
    NSMapRemove(jsctxToObjC, self->handle);
  }

  [self->rt release];
  [super dealloc];
  
  if (debugDealloc) NSLog(@"did dealloc context: 0x%p", self);
}

- (BOOL)loadStandardClasses {
  JSObject *glob;
  
  if ((glob = JS_GetGlobalObject(self->handle)) == NULL) {
    NSLog(@"NGJavaScriptContext: no global object set ..");
    return NO;
  }
  
  //NSLog(@"NGJavaScriptContext: loading std classes ..");
  
  if (!JS_InitStandardClasses(self->handle, glob)) {
    NSLog(@"NGJavaScriptContext: could not init standard classes ...");
    return NO;
  }
  if (!JS_DefineFunctions(self->handle, glob, functions)) {
    NSLog(@"NGJavaScriptContext: could not define global funcs ...");
    return NO;
  }
  
  return YES;
}

- (void *)handle {
  return self->handle;
}

/* accessors */

- (NGJavaScriptRuntime *)runtime {
  return self->rt;
}

- (BOOL)isRunning {
  return JS_IsRunning(self->handle) ? YES : NO;
}

- (BOOL)isConstructing {
  return JS_IsConstructing(self->handle) ? YES : NO;
}

- (void)setJavaScriptVersion:(int)_version {
  JS_SetVersion(self->handle, _version);
}
- (int)javaScriptVersion {
  return JS_GetVersion(self->handle);
}

/* global object */

- (id)globalObject {
  JSObject                  *global;
  NGJavaScriptObjectHandler *oglobal;
  
  global = JS_GetGlobalObject(self->handle);
  NSAssert(global, @"missing global object !");
  
  if ((oglobal = JS_GetPrivate(self->handle, global)) == nil)
    return nil;
  
  return [[oglobal retain] autorelease];
}

/* evaluation */

- (id)evaluateScript:(NSString *)_script {
  return [[self globalObject] evaluateScript:_script];
}

/* invocation */

- (id)callFunctionNamed:(NSString *)_funcName, ... {
  return [[self globalObject] callFunctionNamed:_funcName, nil];
}

/* errors */

- (void)reportException:(NSException *)_exc {
  JS_ReportError(self->handle, "%s", [[_exc description] cString]);
}

- (void)reportError:(NSString *)_fmt, ... {
  NSString *s;
  va_list va;
  
  va_start(va, _fmt);

#if NG_VARARGS_AS_REFERENCE /* in common.h */
  s = [[[NSString alloc] initWithFormat:_fmt arguments:va] autorelease];
#else
  s = [NSString stringWithFormat:_fmt arguments:&va];
#endif
  va_end(va);
  
  JS_ReportError(self->handle, "%s", [s cString]);
}

- (void)reportOutOfMemory {
  JS_ReportOutOfMemory(self->handle);
}

- (void)logReportedJavaScriptError:(NGJavaScriptError *)_error {
  NSLog(@"JS ERROR(%@:%d): %@", [_error path], [_error line], [_error reason]);
  if (abortOnJSError) abort();
}

- (void)reportError:(NSString *)_msg
  inFile:(NSString *)_path inLine:(unsigned)_line
  report:(void *)_report
{
  NGJavaScriptError *e;
  
  e = [[NGJavaScriptError alloc] initWithErrorReport:_report message:_msg context:self];
  
  [self logReportedJavaScriptError:e];
  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"AbortOnJSError"])
    abort();
    
  ASSIGN(self->lastError, e);

  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"RaiseOnJSError"])
    [self->lastError raise];
}

- (NSException *)lastError {
  return self->lastError;
}
- (void)clearLastError {
  [self->lastError release]; self->lastError = nil;
}

/* garbage collector */

- (void)collectGarbage {
  JS_GC(self->handle);
}
- (void)maybeCollectGarbage {
  JS_MaybeGC(self->handle);
}

- (void *)malloc:(unsigned)_size {
  return JS_malloc(self->handle, _size);
}
- (void *)realloc:(void *)_pointer size:(unsigned)_size {
  return JS_realloc(self->handle, _pointer, _size);
}
- (void)freePointer:(void *)_pointer {
  JS_free(self->handle, _pointer);
}

- (BOOL)addRootPointer:(void *)_root {
  return JS_AddRoot(self->handle, _root) ? YES : NO;
}
- (BOOL)addRootPointer:(void *)_root name:(NSString *)_name {
  return JS_AddNamedRoot(self->handle, _root, [_name cString]) ? YES : NO;
}
- (BOOL)removeRootPointer:(void *)_root {
  return JS_RemoveRoot(self->handle, _root) ? YES : NO;
}

- (BOOL)lockGCThing:(void *)_ptr {
  return JS_LockGCThing(self->handle, _ptr) ? YES : NO;
}
- (BOOL)unlockGCThing:(void *)_ptr {
  return JS_UnlockGCThing(self->handle, _ptr) ? YES : NO;
}

- (BOOL)beginGarbageCollection {
  return YES;
}
- (BOOL)endGarbageCollection {
  return YES;
}

/* threads */

#if JS_THREADSAFE
- (void)beginRequest {
  JS_BeginRequest(self->handle);
}
- (void)endRequest {
  JS_EndRequest(self->handle);
}
- (void)suspendRequest {
  JS_SuspendRequest(self->handle);
}
- (void)resumeRequest {
  JS_ResumeRequest(self->handle);
}
#else
- (void)beginRequest {
#if LIB_FOUNDATION_LIBRARY
  [self notImplemented:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
#endif
}
- (void)endRequest {
#if LIB_FOUNDATION_LIBRARY
  [self notImplemented:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
#endif
}
- (void)suspendRequest {
#if LIB_FOUNDATION_LIBRARY
  [self notImplemented:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
#endif
}
- (void)resumeRequest {
#if LIB_FOUNDATION_LIBRARY
  [self notImplemented:_cmd];
#else
  [self doesNotRecognizeSelector:_cmd];
#endif
}
#endif

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p]: %@%@handle=0x%p version=%i runtime=%@>",
                     NSStringFromClass([self class]), self,
                     [self isRunning]      ? @"running "      : @"",
                     [self isConstructing] ? @"constructing " : @"",
                     [self handle],
                     [self javaScriptVersion],
                     [self runtime]];
}

/* statics */

static void jsErrorReporter(JSContext *cx, const char *msg, JSErrorReport *rp) {
  NGJavaScriptContext *self;

  self = NSMapGet(jsctxToObjC, cx);

  if (self == NULL) {
    fprintf(stderr, "ERROR(missing ObjC object): %s\n", msg);
  }
  
  [self reportError:msg?[NSString stringWithCString:msg]:@"unknown JavaScript error"
        inFile:rp->filename?[NSString stringWithCString:rp->filename]:@""
        inLine:rp->lineno
        report:rp];
}

static JSBool jsGCCallback(JSContext *cx, JSGCStatus status) {
  NGJavaScriptContext *self;
  
  self = NSMapGet(jsctxToObjC, cx);

  return (status == JSGC_BEGIN)
    ? ([self beginGarbageCollection] ? JSVAL_TRUE : JSVAL_FALSE)
    : ([self endGarbageCollection]   ? JSVAL_TRUE : JSVAL_FALSE);
}

@end /* NGJavaScriptContext */

static JSBool
Print(JSContext *cx, JSObject *obj, uintN argc, jsval *argv, jsval *rval)
{
    uintN i, n;
    JSString *str;

    for (i = n = 0; i < argc; i++) {
	str = JS_ValueToString(cx, argv[i]);
	if (!str)
	    return JS_FALSE;
	fprintf(stdout, "%s%s", i ? " " : "", JS_GetStringBytes(str));
    }
    n++;
    if (n)
        fputc('\n', stdout);
    return JS_TRUE;
}
