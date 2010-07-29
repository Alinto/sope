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

#include "NGJavaScriptCallable.h"
#include "common.h"

@implementation NGJavaScriptCallable

static void _finalize(JSContext *cx, JSObject *obj);

JSClass NGJavaScriptCallable_JSClass = {
  "NGJavaScriptCallable",
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
  return &NGJavaScriptCallable_JSClass;
}

static void _finalize(JSContext *cx, JSObject *obj) {
  NGJavaScriptCallable *self;
  
  if ((self = JS_GetPrivate(cx, obj)) == nil) {
    JS_FinalizeStub(cx, obj);
  }
  else if (self->handle == obj) {
  }
  else {
#if DEBUG
    fprintf(stderr, "%s: aborting ..\n", __PRETTY_FUNCTION__);
    abort();
#else
    fprintf(stderr, "%s: invalid finalize ..\n", __PRETTY_FUNCTION__);
#endif
  }
}

@end /* NGJavaScriptCallable */
