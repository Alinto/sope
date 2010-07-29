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

#include "NGJavaScriptRuntime.h"
#include "NGJavaScriptContext.h"
#include "common.h"
#include "globals.h"

extern NSMapTable *jsctxToObjC;

@implementation NGJavaScriptRuntime

static JSBool jsGCCallback(JSContext *cx, JSGCStatus status)
     __attribute__((unused));

+ (void)initialize {
  static BOOL didInit = NO;

  if (!didInit) {
    NSUserDefaults *ud;
    didInit = YES;
    
    ud = [NSUserDefaults standardUserDefaults];
    
    NGJavaScriptBridge_TRACK_FINALIZATION =
      [ud boolForKey:@"JSTrackFinalization"];
    NGJavaScriptBridge_TRACK_NOINFO_MEMORY =
      [ud boolForKey:@"JSTrackNoInfoMemory"];
    NGJavaScriptBridge_TRACK_MEMORY =
      [ud boolForKey:@"JSTrackMemory"];
    NGJavaScriptBridge_TRACK_MEMORY_RC =
      [ud boolForKey:@"JSTrackMemoryRC"];
    NGJavaScriptBridge_TRACK_FORGET =
      [ud boolForKey:@"JSTrackForget"];

    NGJavaScriptBridge_LOG_PROP_DEFINITION =
      [ud boolForKey:@"JSTrackPropDefinition"];
    NGJavaScriptBridge_LOG_FUNC_DEFINITION =
      [ud boolForKey:@"JSTrackFuncDefinition"];

    NGJavaScriptBridge_LOG_PROP_GET = [ud boolForKey:@"JSTrackPropGet"];
    NGJavaScriptBridge_LOG_PROP_SET = [ud boolForKey:@"JSTrackPropSet"];
    NGJavaScriptBridge_LOG_PROP_DEL = [ud boolForKey:@"JSTrackPropDel"];
    NGJavaScriptBridge_LOG_PROP_ADD = [ud boolForKey:@"JSTrackPropAdd"];
  }
}

+ (id)standardJavaScriptRuntime {
  static id stdrt = nil;

  if (stdrt == nil) {
    stdrt = [[self alloc] init];
  }
  return stdrt;
}

- (id)initWithGCCollectSize:(unsigned)_size {
  self->handle = JS_NewRuntime(_size ? _size : 1024 * 1024 /* 1 MB default */);
  if (self->handle == NULL) {
    RELEASE(self);
    return nil;
  }

  // JSSetGCCallbackRT(self->handle, jsGCCallback);
  
  return self;
}
- (id)init {
  return [self initWithGCCollectSize:
                 [[NSUserDefaults standardUserDefaults]
                                  integerForKey:@"JSGCCollectSize"]];
}

- (void)dealloc {
  if (self->handle)
    JS_DestroyRuntime(self->handle);
  [super dealloc];
}

- (void *)handle {
  return self->handle;
}

/* named roots */

static void rootDumper(const char *name, void *rp, void *data)
     __attribute__((unused));

static void rootDumper(const char *name, void *rp, void *data) {
  printf("ROOT: %s rp=0x%p rt=0x%p\n", name, (unsigned)rp, (unsigned)data);
}

- (void)dumpNamedRoots {
#if DEBUG && 0
  JS_DumpNamedRoots(self->handle, rootDumper, self);
#endif
}

/* garbage collector */

- (BOOL)beginGarbageCollectionInContext:(NGJavaScriptContext *)_ctx {
  return YES;
}
- (BOOL)endGarbageCollectionInContext:(NGJavaScriptContext *)_ctx {
  return YES;
}

/* contexts */

- (NSArray *)contexts {
  JSContext *ctx, *iterp;
  NSMutableArray *cts;

  cts = [NSMutableArray array];
  
  for (iterp = NULL; (ctx = JS_ContextIterator(self->handle, &iterp)) != NULL;) {
    NGJavaScriptContext *octx;

    octx = NSMapGet(jsctxToObjC, ctx);
    [cts addObject:octx];
  }
  return AUTORELEASE([cts copy]);
}

/* globals */

+ (NSString *)javaScriptImplementationVersion {
  return [NSString stringWithCString:JS_GetImplementationVersion()];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p]: handle=0x%p>",
                     NSStringFromClass([self class]), self,
                     [self handle]
                   ];
}

/* statics */

static JSBool jsGCCallback(JSContext *cx, JSGCStatus status) {
  NGJavaScriptContext *ctx;
  NGJavaScriptRuntime *rt;
  
  ctx = NSMapGet(jsctxToObjC, cx);
  rt  = [ctx runtime];
  
  return (status == JSGC_BEGIN)
    ? ([rt beginGarbageCollectionInContext:ctx] ? JSVAL_TRUE : JSVAL_FALSE)
    : ([rt endGarbageCollectionInContext:ctx]   ? JSVAL_TRUE : JSVAL_FALSE);
}

@end /* NGJavaScriptRuntime */
