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

#import <Foundation/Foundation.h>
#import <NGJavaScript/NGJavaScript.h>
#import <NGJavaScript/NGJavaScriptObjectMappingContext.h>

#import "JSObjectOps.m"

id mapCtx = nil;

static char *cstr = "print('this is '+this);\n";

static void testinctx(void) {
  JSContext *cx;
  JSObject  *jso;
  JSBool    res;
  jsval     lastValue;
  
  cx = [[mapCtx jsContext] handle];
  
  jso = JS_NewObject(cx,
		     &NGJavaScriptObjectHandler_JSObjectOpsClass,
		     NULL, NULL);
  NSCAssert(jso, @"couldn't create JS object ..");

  res = JS_EvaluateScript(cx, jso,
			  cstr, strlen(cstr),
                          "<string>",  /* source file */
                          0,           /* line number */
                          &lastValue);
  NSCAssert(res == JS_TRUE, @"couldn't evaluate script ..");
}

#include <NGExtensions/NGExtensions.h>

int main(int argc, char **argv, char **env) {
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif

  {
    mapCtx = [[NGJavaScriptObjectMappingContext alloc] init];
  
    if (![[mapCtx jsContext] loadStandardClasses])
      ;
  
    [mapCtx pushContext];
    testinctx();
    [mapCtx popContext];
  
    RELEASE(mapCtx);
  }

  [NGExtensions class];
  return 0;
}
