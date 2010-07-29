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

#include <NGScripting/NGScriptLanguage.h>

@interface NGJavaScriptLanguage : NGScriptLanguage
{
  id rootctx;
} 

@end

#include "NGJavaScriptObjectMappingContext.h"
#include "NGJavaScriptContext.h"
#include "NGJavaScriptShadow.h"
#include "NGJavaScriptRuntime.h"
#include "NSObject+JS.h"
#include "common.h"

@implementation NGJavaScriptLanguage

- (id)initWithLanguage:(NSString *)_language {
  if ((self = [super initWithLanguage:_language])) {
    NSLog(@"%@", [NGJavaScriptRuntime javaScriptImplementationVersion]);
    
    self->rootctx = [[NGJavaScriptObjectMappingContext alloc] init];
    [[self->rootctx jsContext] loadStandardClasses];
    [self->rootctx pushContext];
  }
  return self;
}
- (void)dealloc {
  [self->rootctx popContext];
  [self->rootctx release];
  [super dealloc];
}

- (NSString *)language {
  return @"javascript";
}

- (id)evaluateScript:(NSString *)_script onObject:(id)_object 
  source:(NSString *)_source line:(unsigned)_line
{
  NGJavaScriptObjectMappingContext *mctx;
  JSBool      res;
  jsval       lastValue;
  void        *jso;
  void        *cx;
  NSException *e;
  const char *srcname = NULL;
  
  mctx = [NGJavaScriptObjectMappingContext activeObjectMappingContext];
  NSAssert(mctx, @"no javascript mapping context is active !");
  
  jso = [mctx handleForObject:_object];
  NSAssert(jso, @"missing JS object ..");
  
  cx = [[mctx jsContext] handle];
  
  if ([_source hasPrefix:@"file://"])
    _source = [_source substringFromIndex:7];
  // TODO: use buffer
  srcname = [_source cString];
  
#if 0
  NSLog(@"%s:%i eval script on objc=0x%p js=0x%p cx=0x%p", 
	[_source cString], _line,
	_object, jso, cx);
#endif
  
  res = JS_EvaluateScript(cx, jso,
                          [_script cString],
                          [_script cStringLength],
                          srcname, /* source file */
                          _line,   /* line number */
                          &lastValue);
  
  if (res == JS_TRUE)
    return [mctx objectForJSValue:&lastValue];
  
  if ([(e = [[mctx jsContext] lastError]) retain]) {
    
    [[mctx jsContext] clearLastError];
    [[mctx jsContext] collectGarbage];
    //[[mctx jsContext] collectGarbage];
    //[[mctx jsContext] collectGarbage];
    
    [e raise];
  }
  
  {
    NSDictionary *ui;
    
    ui = [NSDictionary dictionaryWithObjectsAndKeys:
                         _script,             @"script",
                         _object,             @"objectHandler",
                         [NGJavaScriptContext jsContextForHandle:cx],
                           @"jscontext",
                         nil];
    
    e = [[NSException alloc] initWithName:@"JavaScriptEvalException"
                             reason:@"couldn't evaluate script"
                             userInfo:ui];
    [e raise];
  }
  return nil;
}

/* functions */

- (id)callFunction:(NSString *)_func onObject:(id)_object {
  NGJavaScriptObjectMappingContext *mctx;
  JSBool ret;
  void   *jso;
  jsval  result;
  
  mctx = [NGJavaScriptObjectMappingContext activeObjectMappingContext];
  NSAssert(mctx, @"no javascript mapping context is active !");
  
  jso = [mctx handleForObject:_object];
  NSAssert(jso, @"missing JS object ..");
  
  ret = JS_CallFunctionName([[mctx jsContext] handle],
                            jso,
                            [_func cString],
                            0 /* argc */, NULL /* argv */,
                            &result);
  if (ret == JS_TRUE)
    return [mctx objectForJSValue:&result];
  
  NSLog(@"%s: couldn't run function %@", __PRETTY_FUNCTION__, _func);
  return nil;
}

- (id)callFunction:(NSString *)_func
  withArgument:(id)_arg0
  onObject:(id)_object 
{
  NGJavaScriptObjectMappingContext *mctx;
  JSBool ret;
  void   *jso;
  jsval  result;
  jsval  argv[1];
  
  mctx = [NGJavaScriptObjectMappingContext activeObjectMappingContext];
  NSAssert(mctx, @"no javascript mapping context is active !");
  
  jso = [mctx handleForObject:_object];
  NSAssert(jso, @"missing JS object ..");
  
  if (![mctx jsValue:&(argv[0]) forObject:_arg0]) {
    NSLog(@"%s: couldn't get value for first function argument ..",
          __PRETTY_FUNCTION__);
    return nil;
  }
  
  ret = JS_CallFunctionName([[mctx jsContext] handle],
                            jso,
                            [_func cString],
                            1, argv,
                            &result);
  if (ret == JS_TRUE)
    return [mctx objectForJSValue:&result];
  
  NSLog(@"%s: couldn't run function %@", __PRETTY_FUNCTION__, _func);
  return nil;
}
- (id)callFunction:(NSString *)_func
  withArgument:(id)_arg0
  withArgument:(id)_arg1
  onObject:(id)_object 
{
  NGJavaScriptObjectMappingContext *mctx;
  JSBool ret;
  void   *jso;
  jsval  result;
  jsval  argv[2];
  
  mctx = [NGJavaScriptObjectMappingContext activeObjectMappingContext];
  NSAssert(mctx, @"no javascript mapping context is active !");
  
  jso = [mctx handleForObject:_object];
  NSAssert(jso, @"missing JS object ..");
  
  if (![mctx jsValue:&(argv[0]) forObject:_arg0]) {
    NSLog(@"%s: couldn't get value for first function argument ..",
          __PRETTY_FUNCTION__);
    return nil;
  }
  
  if (![mctx jsValue:&(argv[1]) forObject:_arg1]) {
    NSLog(@"%s: couldn't get value for second function argument ..",
          __PRETTY_FUNCTION__);
    return nil;
  }
  
  ret = JS_CallFunctionName([[mctx jsContext] handle],
                            jso,
                            [_func cString],
                            2, argv,
                            &result);
  if (ret == JS_TRUE)
    return [mctx objectForJSValue:&result];
  
  NSLog(@"%s: couldn't run function %@", __PRETTY_FUNCTION__, _func);
  return nil;
}

/* reflection */

- (BOOL)object:(id)_object hasFunctionNamed:(NSString *)_name {
  return [_object hasFunctionNamed:_name];
}

/* shadow objects */

- (id)createShadowForMaster:(id)_master {
  NGJavaScriptShadow *shadow;
  
  if (_master == nil)
    /* no shadow without a master ... */
    return nil;
  
  if ((shadow = [[NGJavaScriptShadow alloc] init]) == nil) {
    NSLog(@"%s: could not create shadow for master %@", 
	  __PRETTY_FUNCTION__, _master);
    return nil;
  }
  
  [shadow setMasterObject:_master];
  
  return shadow; /* returns a retained object */
}

/* mapping ctx */

- (NGObjectMappingContext *)createMappingContext {
  NGJavaScriptObjectMappingContext *ctx;
  
  ctx = [[NGJavaScriptObjectMappingContext alloc] init];
  [[ctx jsContext] loadStandardClasses];
  return ctx;
}

@end /* NGJavaScriptLanguage */
