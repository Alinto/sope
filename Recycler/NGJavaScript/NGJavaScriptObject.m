/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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
#include <NGExtensions/NGExtensions.h>
#include <NGScripting/NGObjectMappingContext.h>
#include "NGJavaScriptObjectMappingContext.h"
#include "common.h"
#include "globals.h"

//#define GREEDY_ARCHIVE 1

@interface JSIDEnum : NSEnumerator
{
  NGJavaScriptObjectMappingContext *ctx;
  JSContext *cx;
  JSIdArray *idArray;
  unsigned  pos;
  id        object;
}
- (id)initWithIdArray:(JSIdArray *)_array 
  mappingContext:(NGJavaScriptObjectMappingContext *)_ctx;
- (id)initWithIdArray:(JSIdArray *)_array 
  object:(id)_object
  mappingContext:(NGJavaScriptObjectMappingContext *)_ctx;
@end

@interface JSObjChainEnum : NSEnumerator
{
  id  object;
  SEL selector;
}
- (id)initWithObject:(id)_obj selector:(SEL)_sel;
@end

@implementation NGJavaScriptObject

- (id)initWithHandle:(void *)_handle
  inMappingContext:(NGObjectMappingContext *)_ctx
{
  NSAssert(_handle, @"Missing handle ..");
  NSAssert(_ctx,    @"Missing context ..");

  self->handle = _handle;
  self->ctx    = [_ctx retain];
  
  self->jscx =
    [[(NGJavaScriptObjectMappingContext *)self->ctx jsContext] handle];
  
  self->addedRoot =
    JS_AddNamedRoot(self->jscx, &(self->handle), self->isa->name);
  NSAssert(self->addedRoot, @"couldn't add root !");
  
  return self;
}

+ (void *)jsObjectClass {
  return NULL;
}

- (void *)createJSObjectForJSClass:(void *)_class inJSContext:(void *)jsctx {
  return JS_NewObject(jsctx, _class, NULL, NULL);
}

- (id)initWithJSClass:(void *)_class {
  NGJavaScriptObjectMappingContext *mctx;
  
  if ((mctx = [NGJavaScriptObjectMappingContext activeObjectMappingContext])) {
    void *jsctx;
    void *jso;
    
    jsctx = [[mctx jsContext] handle];
    
    if ((jso = [self createJSObjectForJSClass:_class inJSContext:jsctx])) {
      self = [self initWithHandle:jso inMappingContext:mctx];
      [mctx registerObject:self forImportedHandle:jso];
      return self;
    }
    else {
      [self release]; self = nil;
      
      [NSException raise:@"NGJavaScriptException"
                   format:@"couldn't create JS object .."];
      return nil;
    }
  }
  [self release];
  [NSException raise:@"NGJavaScriptException"
               format:@"missing active mapping context !"];
  return nil;
}
- (id)init {
  return [self initWithJSClass:[[self class] jsObjectClass]];
}

- (void)dealloc {
  if (NGJavaScriptBridge_TRACK_MEMORY) {
    NSLog(@"%s: dealloc o0x%p j0x%p ctx=0x%p jcx=0x%p",
          __PRETTY_FUNCTION__, self, self->handle,
          self->ctx, self->jscx);
  }
  
  if (self->handle) {
    if (self->addedRoot)
      JS_RemoveRoot(self->jscx, &self->handle);
    [self->ctx forgetImportedHandle:self->handle];
  }
  else {
    if (self->addedRoot)
      NSLog(@"%s: missing handle !, couldn't remove root ..", __PRETTY_FUNCTION__);
  }
  
  [self->ctx release];
  [super dealloc];
}

/* transformation */

- (BOOL)_jsGetValue:(void *)_value inJSContext:(NGJavaScriptContext *)_ctx {
  *((jsval *)_value) = OBJECT_TO_JSVAL(self->handle);
  return YES;
}
- (void *)_jsHandleInMapContext:(NGObjectMappingContext *)_ctx {
  return self->handle;
}

/* misc */

- (void)applyStandardClasses {
  if (!JS_InitStandardClasses(self->jscx, self->handle)) {
    NSLog(@"couldn't load standard classes into JS object %@", self);
    return;
  }
}

- (void)setParentObject:(id)_parent {
  JSObject *p;
  
  p = [self->ctx handleForObject:_parent];
  
  if (JS_SetParent(self->jscx, self->handle, p) == JS_FALSE) {
    NSLog(@"couldn't set parent of object %@", self);
  }
}
- (id)parentObject {
  JSObject *p;
  
  if ((p = JS_GetParent(self->jscx, self->handle)) == NULL)
    return nil;
  
  return [self->ctx objectForHandle:p];
}

- (NSEnumerator *)parentObjectChain {
  NSEnumerator *e;
  
  e = [[JSObjChainEnum alloc] 
	initWithObject:self selector:@selector(parentObject)];
  return [e autorelease];
}

- (void)setPrototypeObject:(id)_proto {
  JSObject *p;
  
  p = [self->ctx handleForObject:_proto];
  
  if (JS_SetPrototype(self->jscx, self->handle, p) == JS_FALSE) {
    NSLog(@"couldn't set prototype of object %@", self);
  }
}
- (id)prototypeObject {
  JSObject *p;
  
  if ((p = JS_GetPrototype(self->jscx, self->handle)) == NULL)
    return nil;
  
  return [self->ctx objectForHandle:p];
}

- (NSEnumerator *)prototypeObjectChain {
  NSEnumerator *e;
  
  e = [[JSObjChainEnum alloc] 
	initWithObject:self selector:@selector(prototypeObject)];
  return AUTORELEASE(e);
}

- (BOOL)hasPropertyNamed:(NSString *)_key {
  JSBool ret;
  jsval  val = JSVAL_VOID;
  unsigned int  clen;
  unsigned char *ckey;
  
  clen = [_key cStringLength];
  ckey = malloc(clen + 1);
  [_key getCString:ckey];
  
  ret = JS_LookupProperty(self->jscx, self->handle, ckey, &val);
  if (ret == JS_FALSE) {
    NSLog(@"%s: WARNING: couldn't lookup property '%@'",
          __PRETTY_FUNCTION__, _key);
    free(ckey);
    return NO;
  }
  if (val == JSVAL_VOID)
    return NO;

  return YES;
}

- (BOOL)hasFunctionNamed:(NSString *)_key {
  JSBool        ret;
  jsval         val = JSVAL_VOID;
  unsigned int  clen;
  unsigned char *ckey;
  JSType        jsType;
  
  clen = [_key cStringLength];
  ckey = malloc(clen + 1);
  [_key getCString:ckey];
  
  ret = JS_GetProperty(self->jscx, self->handle, ckey, &val);
  if (ret == JS_FALSE) {
    NSLog(@"WARNING: couldn't lookup property '%@'", _key);
    free(ckey);
    return NO;
  }
  if (val == JSVAL_VOID)
    return NO;
  
  jsType = JS_TypeOfValue(self->jscx, val);

  return jsType == JSTYPE_FUNCTION ? YES : NO;
}

/* functions */

- (BOOL)isJavaScriptFunction {
  jsval  val;
  JSType jsType;
  
  val = OBJECT_TO_JSVAL(self->handle);
  if (val == JSVAL_VOID)
    return NO;
  
  jsType = JS_TypeOfValue(self->jscx, val);

  return jsType == JSTYPE_FUNCTION ? YES : NO;
}
- (BOOL)isScriptFunction {
  return [self isJavaScriptFunction];
}

- (id)_callOn:(id)_this argc:(int)_argc argv:(jsval *)_argv {
  jsval    val;
  JSBool   ret;
  jsval    result;
  JSObject *jso;
  
  val = OBJECT_TO_JSVAL(self->handle);
  jso = [self->ctx handleForObject:_this];
  
  ret = JS_CallFunctionValue(self->jscx, jso, val,
                             _argc, _argv,
                             &result);
  if (ret == JS_TRUE)
    return [self->ctx objectForJSValue:&result];
  
  NSLog(@"%s: couldn't run function %@", __PRETTY_FUNCTION__, self);
  return nil;
}
- (id)callOn:(id)_this {
  return [self _callOn:_this argc:0 argv:NULL];
}
- (id)callOn:(id)_this withObject:(id)_arg0 {
  jsval arg0;
  
  if ([self->ctx jsValue:&arg0 forObject:_arg0])
    return [self _callOn:_this argc:1 argv:&arg0];
  
  NSLog(@"%s: couldn't convert arg0 %@ for function %@", __PRETTY_FUNCTION__,
        _arg0, self);
  return nil;
}

/* mimic dictionary */

- (NSArray *)allKeys {
  NSEnumerator   *e;
  NSString       *key;
  NSMutableArray *keys;
  
  if ((e = [self keyEnumerator]) == nil) return nil;
  keys = [NSMutableArray arrayWithCapacity:8];
  while ((key = [e nextObject]))
    [keys addObject:key];
  return keys;
}
- (NSArray *)allValues {
  NSEnumerator   *e;
  id object;
  NSMutableArray *keys;
  
  if ((e = [self objectEnumerator]) == nil) return nil;
  keys = [NSMutableArray arrayWithCapacity:8];
  while ((object = [e nextObject]))
    [keys addObject:object];
  return keys;
}

- (NSEnumerator *)keyEnumerator {
  JSIDEnum *e;
  JSIdArray *idArray;
  
  if ((idArray = JS_Enumerate(self->jscx, self->handle)) == NULL) {
    NSLog(@"couldn't enumerate object ..");
    return nil;
  }
  
  e = [[JSIDEnum alloc] initWithIdArray:idArray mappingContext:self->ctx];
  return AUTORELEASE(e);
}
- (NSEnumerator *)objectEnumerator {
  JSIDEnum *e;
  JSIdArray *idArray;
  
  if ((idArray = JS_Enumerate(self->jscx, self->handle)) == NULL) {
    NSLog(@"couldn't enumerate object ..");
    return nil;
  }
  
  e = [[JSIDEnum alloc] initWithIdArray:idArray 
			object:self
			mappingContext:self->ctx];
  return AUTORELEASE(e);
}

- (void)setObject:(id)_obj forStringKey:(NSString *)_key {
  jsval         v, lv;
  JSBool        res;
  unsigned int  clen;
  unsigned char *ckey;
  
  if (![self->ctx jsValue:&v forObject:_obj]) {
    NSLog(@"WARNING: couldn't convert ObjC value to JS: %@", _obj);
    return;
  }
  
  clen = [_key cStringLength];
  ckey = malloc(clen + 1);
  [_key getCString:ckey];
  
  res = JS_LookupProperty(self->jscx, self->handle, ckey, &lv);
  if (res == JS_FALSE) {
    NSLog(@"WARNING: couldn't lookup property '%@'", _key);
    free(ckey);
    return;
  }
  
  if (lv == JSVAL_VOID) {
    /* property does not exist */
    res = JS_DefineProperty(self->jscx, self->handle, ckey, v,
                            NULL /* getter */,
                            NULL /* setter */,
                            JSPROP_ENUMERATE|JSPROP_EXPORTED);
  }
  else {
    /* property does exist */
    res = JS_SetProperty(self->jscx, self->handle, ckey, &v);
  }
  
  free(ckey); ckey = NULL;
  
  if (res == JS_FALSE) {
    NSLog(@"WARNING: couldn't set ObjC value %@ to JS %@", _obj, _key);
    return;
  }
}

- (id)objectForStringKey:(NSString *)_key {
  JSBool ret;
  jsval  val = JSVAL_VOID;
  unsigned int  clen;
  unsigned char *ckey;
  
  clen = [_key cStringLength];
  ckey = malloc(clen + 1);
  [_key getCString:ckey];
  
  ret = JS_GetProperty(self->jscx, self->handle, ckey, &val);
  if (ret == JS_FALSE) {
    NSLog(@"WARNING(%s): couldn't get value of property %@ ",
          __PRETTY_FUNCTION__, _key);
    free(ckey);
    return nil;
  }
  
  free(ckey); ckey = NULL;
  
  if (val == JSVAL_VOID) {
    /* property is not defined */
#if 0
    NSLog(@"%s: got void for key '%s' o0x%p j0x%p",
          __PRETTY_FUNCTION__,
          ckey, self, self->handle);
#endif
    return nil;
  }
  
  return [self->ctx objectForJSValue:&val];
}

- (void)removeObjectForStringKey:(NSString *)_key {
  JSBool ret;
  
  ret = JS_DeleteProperty(self->jscx, self->handle, [_key cString]);
  if (ret == JS_FALSE) {
    NSLog(@"WARNING: couldn't delete property %@ ", _key);
    return;
  }
}

- (BOOL)isStringKey:(id)_key {
  return [_key isKindOfClass:[NSString class]];
}
- (id)unableToHandleKey:(id)_key {
  NSLog(@"Unable to handle key: %@\n  key class: %@\n  object: %@\n  object class: %@",
        _key, [_key class], self, [self class]);
  return nil;
}

- (id)objectForKey:(id)_key {
  if ([self isStringKey:_key])
    return [self objectForStringKey:_key];
  else
    return [self unableToHandleKey:_key];
}
- (void)setObject:(id)_obj forKey:(id)_key {
  if ([self isStringKey:_key]) {
    [self setObject:_obj forStringKey:(id)_key];
  }
  else
    [self unableToHandleKey:_key];
}
- (void)removeObjectForKey:(id)_key {
  if ([self isStringKey:_key])
    [self removeObjectForStringKey:_key];
  else
    [self unableToHandleKey:_key];
}

/* convert to dictionary */

- (NSDictionary *)convertToNSDictionary {
  /* could be made far more efficient ... */
  NSEnumerator   *e;
  NSString       *key;
  NSMutableDictionary *dict;
  
  if ((e = [self keyEnumerator]) == nil) return nil;

  dict = [NSMutableDictionary dictionaryWithCapacity:16];
  while ((key = [e nextObject])) {
    id value = [self objectForKey:key];
    
    [dict setObject:value?value:[NSNull null] forKey:key];
  }
  return dict;
}

/* KVC */

- (void)takeValue:(id)_value forKey:(NSString *)_key {
#if 0
  if (_value == nil)
    ;
#endif
  [self setObject:_value forKey:_key];
}
- (id)valueForKey:(NSString *)_key {
  return [self objectForKey:_key];
}

/* private */

- (void *)handle {
  return self->handle;
}

- (void)makeGlobal {
  JS_SetGlobalObject(self->jscx, self->handle);
}

- (NSString *)javaScriptClassName {
  if (self->handle == nil)
    return nil;
  return [NSString stringWithCString:JS_GetClass(self->handle)->name];
}

/* NSCoding */

- (void)decodeJavaScriptPropertiesWithCoder:(NSCoder *)_coder {
  NSDictionary *props;
  NSEnumerator *keys;
  NSString     *key;

  props = [_coder decodeObject];
    
  keys = [props keyEnumerator];
  while ((key = [keys nextObject])) {
    id value = [props objectForKey:key];
      
    if ([value isNotNull])
      [self setObject:value forKey:key];
    else
      [self setObject:nil forKey:key];
  }
}
- (void)encodeJavaScriptPropertiesWithCoder:(NSCoder *)_coder {
  NSMutableDictionary *props;
  NSEnumerator        *keys;
  NSString            *key;
  
  props = [NSMutableDictionary dictionaryWithCapacity:16];
  keys = [self keyEnumerator];
  while ((key = [keys nextObject])) {
    id value;
    
    if ((value = [self objectForKey:key])) {
      if ([value isJavaScriptFunction]) {
        [self debugWithFormat:@"did not encode JS function object: %@", value];
        continue;
      }
      
      [props setObject:value forKey:key];
    }
    else
      [props setObject:[NSNull null] forKey:key];
  }
  [_coder encodeObject:props];
}

- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [self init])) {
    NSString *jsClass;
    id lParent, lPrototype;
  
    jsClass    = [_coder decodeObject];
    lParent    = [_coder decodeObject];
    lPrototype = [_coder decodeObject];
  
    [self setParentObject:lParent];
    [self setPrototypeObject:lPrototype];

    [self decodeJavaScriptPropertiesWithCoder:_coder];
    
    if (![[self javaScriptClassName] isEqualToString:jsClass]) {
      [self logWithFormat:@"WARNING: decoded object is not JS class %@ !!", jsClass];
    }
  }
  return self;
}
- (void)encodeWithCoder:(NSCoder *)_coder {
  [_coder encodeObject:[self javaScriptClassName]];
#if GREEDY_ARCHIVE
  [_coder encodeObject:[self parentObject]];
  [_coder encodeObject:[self prototypeObject]];
#else
  [_coder encodeConditionalObject:[self parentObject]];
  [_coder encodeConditionalObject:[self prototypeObject]];
#endif
  [self encodeJavaScriptPropertiesWithCoder:_coder];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  id tmp;
  
  ms = [NSMutableString stringWithCapacity:32];
  [ms appendFormat:@"<%@[0x%p]: handle=0x%p>",
                     NSStringFromClass([self class]), self,
                     [self handle]];
  if ((tmp = [self javaScriptClassName]))
    [ms appendFormat:@" class=%@", tmp];
  
  if ([self isJavaScriptFunction])
    [ms appendString:@" function"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* NGJavaScriptObject */

@implementation JSIDEnum

- (id)initWithIdArray:(JSIdArray *)_array 
  mappingContext:(NGJavaScriptObjectMappingContext *)_ctx
{
  if (_array == NULL) {
    RELEASE(self);
    return nil;
  }
  self->idArray = _array;
  self->ctx = _ctx;
  self->cx  = [[_ctx jsContext] handle];
  return self;
}
- (id)initWithIdArray:(JSIdArray *)_array 
  object:(id)_object
  mappingContext:(NGJavaScriptObjectMappingContext *)_ctx
{
  if ((self = [self initWithIdArray:_array mappingContext:_ctx])) {
    self->object = RETAIN(_object);
  }
  return self;
}

- (void)dealloc {
  if (self->idArray)
    JS_DestroyIdArray(self->cx, self->idArray);
  RELEASE(self->object);
  [super dealloc];
}

- (id)nextObject {
  jsid  jid;
  jsval idv;
  id    jobj = nil;
  
  if (self->idArray == NULL)
    return nil;
  
  if (self->idArray->length <= self->pos) {
    JS_DestroyIdArray(self->cx, self->idArray);
    self->idArray = NULL;
    return nil;
  }
  
  jid = self->idArray->vector[self->pos];
  
  if (JS_IdToValue(self->cx, jid, &idv) == JS_FALSE) {
    NSLog(@"couldn't convert id to value ..");
    return nil;
  }
  
  jobj = [self->ctx objectForJSValue:&idv];
  
  if (self->object)
    jobj = [(NSDictionary *)self->object objectForKey:jobj];
  
  self->pos++;
  
  if (self->idArray->length <= self->pos) {
    JS_DestroyIdArray(self->cx, self->idArray);
    self->idArray = NULL;
  }
  
  return jobj;
}

- (NSString *)description {
  return [NSString stringWithFormat:
		     @"<0x%p[%@]: len=%d>",
		     self, NSStringFromClass([self class]),
		     self->idArray ? self->idArray->length : 0];
}

@end /* JSIDEnum */

@implementation JSObjChainEnum

- (id)initWithObject:(id)_obj selector:(SEL)_sel {
  self->object   = RETAIN(_obj);
  self->selector = _sel;
  return self;
}
- (void)dealloc {
  RELEASE(self->object);
  [super dealloc];
}

- (id)nextObject {
  AUTORELEASE(self->object);
  self->object = RETAIN([self->object performSelector:self->selector]);
  return self->object;
}

@end /* JSObjChainEnum */
