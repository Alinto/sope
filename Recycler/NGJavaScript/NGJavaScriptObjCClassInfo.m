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

#include "NGJavaScriptObjCClassInfo.h"
#include "NGJavaScriptObjectHandler.h"
#include <NGExtensions/NGObjCRuntime.h>
#include "globals.h"
#include "common.h"

#if 0
#  warning needs to be rewritten for tinyIds
#endif

@interface NGJavaScriptObjectHandler(Misc)
+ (void *)jsStaticFuncDispatcher;
@end

#ifndef JSPROP_NOSLOT
// new in 1.5 rc3
#  define PROP_READONLY_FLAGS  (JSPROP_READONLY | JSPROP_SHARED)
#  define PROP_READWRITE_FLAGS (JSPROP_SHARED)
#else
// special version of 1.5 rc
#  define PROP_READONLY_FLAGS  (JSPROP_READONLY | JSPROP_NOSLOT)
#  define PROP_READWRITE_FLAGS (JSPROP_NOSLOT)
#endif
//#define PROP_READONLY_FLAGS  (JSPROP_READONLY | JSPROP_PERMANENT)

@implementation NGJavaScriptObjCClassInfo

- (id)initWithClass:(Class)_clazz
  setter:(JSPropertyOp)_setter
  getter:(JSPropertyOp)_getter
  caller:(JSNative)_caller
{
  NSEnumerator   *e;
  NSString       *mname;
  NSMutableArray *funcs;
  NSMutableArray *props;
  NSMutableArray *roProps;
  
  self->clazz  = _clazz;
  self->setter = _setter;
  self->getter = _getter;
  self->caller = _caller;
  
  funcs = props = roProps = nil;
  
  self->idToKey = NSCreateMapTable(NSIntMapKeyCallBacks,
                                   NSOwnedPointerMapValueCallBacks,
                                   64);
  
  e = [_clazz hierachyMethodNameEnumerator];
  while ((mname = [e nextObject])) {
    if ([mname hasPrefix:@"_jsfunc_"]) {
      NSString *f;
      
      if (funcs == nil)
        funcs = [NSMutableArray arrayWithCapacity:64];

      f = [mname substringFromIndex:8];
      f = [f substringToIndex:([f length] - 1)];
      
      [funcs addObject:f];
    }
    else if ([mname hasPrefix:@"_jsprop_"] && ![mname hasSuffix:@":"]) {
      char     *buf;
      unsigned len;
      NSString *propName;
      SEL      setSel;
      
      len = [mname length];
      buf = malloc(len + 3);
      [mname getCString:buf];
      
      propName = [NSString stringWithCString:&(buf[8])];

      /* get set-selector */
      buf[len] = ':';
      buf[len + 1] = '\0';
#if NeXT_RUNTIME || APPLE_RUNTIME
      setSel = sel_getUid(buf);
#else
      setSel = sel_get_uid(buf);
#endif

      if ((setSel != NULL) && [_clazz instancesRespondToSelector:setSel]) {
        if (props == nil)
          props = [NSMutableArray arrayWithCapacity:64];
        [props addObject:propName];
      }
      else {
        if (roProps == nil)
          roProps = [NSMutableArray arrayWithCapacity:64];
        [roProps addObject:propName];
      }
    }
  }
  
  self->jsFuncNames = [funcs copy];
  self->jsPropNames = [props copy];
  self->jsReadOnlyPropNames = [roProps copy];
  
  return self;
}

- (void)dealloc {
  //NSLog(@"DEALLOC ClassInfo ..");

#if 0 // BUGGY, need to leak
  if (self->funcSpecs) {
    unsigned i;
    
    while (self->funcSpecs[i].name)
      free((void *)self->funcSpecs[i].name);
    
    free(self->funcSpecs);
  }
  if (self->idToKey) {
    NSFreeMapTable(self->idToKey);
    self->idToKey = NULL;
  }
#endif
  [self->jsFuncNames         release];
  [self->jsReadOnlyPropNames release];
  [self->jsPropNames         release];
  [super dealloc];
}

- (NSArray *)jsFuncNames {
  return self->jsFuncNames;
}
- (NSArray *)jsPropNames {
  return self->jsPropNames;
}
- (NSArray *)jsReadOnlyPropNames {
  return self->jsReadOnlyPropNames;
}

- (JSFunctionSpec *)functionSpecs {
  unsigned i, count;
  
  if (self->funcSpecs)
    return self->funcSpecs;
  
  if ((count = [self->jsFuncNames count]) == 0)
    return NULL;
  
  self->funcSpecs = calloc(count + 1, sizeof(JSFunctionSpec));
  for (i = 0; i < count; i++) {
    NSString *oname;
    unsigned clen;
    
    oname = [self->jsFuncNames objectAtIndex:i];
    clen  = [oname cStringLength];
    
    self->funcSpecs[i].name = malloc(clen + 4);
    [oname getCString:(char *)self->funcSpecs[i].name];
    
    //NSLog(@"  def JS func '%s'\n", self->funcSpecs[i].name);
    
    self->tinyId++;
    // TODO: explain the comment below
    //***BUG: copy 'name'!
    NSMapInsert(self->idToKey, (void*)(int)self->tinyId,
                self->funcSpecs[i].name);
    
    self->funcSpecs[i].call  = self->caller;
    self->funcSpecs[i].nargs = 0;
    self->funcSpecs[i].flags = 0;
    self->funcSpecs[i].extra = 0;
  }
  return self->funcSpecs;
}

- (BOOL)isStaticProperty:(NSString *)_prop {
  if ([self->jsFuncNames containsObject:_prop])
    return YES;
  if ([self->jsReadOnlyPropNames containsObject:_prop])
    return YES;
  if ([self->jsPropNames containsObject:_prop])
    return YES;
  return NO;
}

/* resolving IDs */

- (SEL)getSelectorForPropertyId:(void *)_idval inJSContext:(void *)_cx {
  jsval      _id = *(jsval *)_idval;
  const char *propName = NULL;
  SEL        sel       = NULL;
  
  if (JSVAL_IS_STRING(_id)) {
    if ((propName = JS_GetStringBytes(JS_ValueToString(_cx, _id))) == NULL)
      NSLog(@"%s: got no string for string id val ..", __PRETTY_FUNCTION__);
  }
  else if (JSVAL_IS_INT(_id)) {
    int ttid;
    
    ttid = JSVAL_TO_INT(_id);
    if ((propName = NSMapGet(self->idToKey, (void*)(int)ttid)) == NULL)
      NSLog(@"%s: got no INT id val %i ..", __PRETTY_FUNCTION__, ttid);
  }
  else {
#if DEBUG
    NSLog(@"%s: GOT invalid id value ..", __PRETTY_FUNCTION__);
    abort();
#else
    NSLog(@"%s: GOT invalid id value ..", __PRETTY_FUNCTION__);
    return NULL;
#endif
  }
  
  if (propName) {
    char *msgname;
    
    msgname = malloc(strlen(propName) + 12);
    strcpy(msgname, "_jsprop_");
    strcat(msgname, propName);
#if NeXT_RUNTIME
    sel = sel_getUid(msgname);
#else
    sel = sel_get_any_uid(msgname);
#endif
    if (sel == NULL)
      NSLog(@"%s: got no selector for msg '%s'", __PRETTY_FUNCTION__, msgname);
    free(msgname);
  }
  return sel;
}
- (SEL)setSelectorForPropertyId:(void *)_idval inJSContext:(void *)_cx {
  jsval      _id = *(jsval *)_idval;
  const char *propName = NULL;
  SEL        sel       = NULL;
  
  if (JSVAL_IS_STRING(_id)) {
    if ((propName = JS_GetStringBytes(JS_ValueToString(_cx, _id))) == NULL)
      NSLog(@"%s: got no string for string id val ..", __PRETTY_FUNCTION__);
  }
  else if (JSVAL_IS_INT(_id)) {
    int ttid;
    
    ttid     = JSVAL_TO_INT(_id);
    if ((propName = NSMapGet(self->idToKey, (void*)(int)ttid)) == NULL)
      NSLog(@"%s: got no INT id val %i ..", __PRETTY_FUNCTION__, ttid);
  }
  else {
#if DEBUG
    NSLog(@"%s: GOT invalid id value ..", __PRETTY_FUNCTION__);
    abort();
#else
    NSLog(@"%s: GOT invalid id value ..", __PRETTY_FUNCTION__);
    return NULL;
#endif
  }

  if (propName) {
    char *msgname;
    
    msgname = malloc(strlen(propName) + 12);
    strcpy(msgname, "_jsprop_");
    strcat(msgname, propName);
    strcat(msgname, ":");

#if NeXT_RUNTIME
    sel = sel_getUid(msgname);
#else
    sel = sel_get_any_uid(msgname);
#endif
    if (sel == NULL)
      NSLog(@"%s: got no selector for msg '%s'", __PRETTY_FUNCTION__, msgname);
    free(msgname);
  }
  
  return sel;
}

/* apply on JSObject */

- (unsigned char)tinyIdForKey:(NSString *)_key {
  char *ckey;
  
  self->tinyId++;
  ckey = malloc([_key cStringLength] + 1);
  [_key getCString:ckey];
  NSMapInsert(self->idToKey, (void*)(int)self->tinyId, ckey);
  
  return self->tinyId;
}

- (JSBool)defineProperty:(NSString *)mname readOnly:(BOOL)_ro
  onObject:(void *)_jso inJSContext:(void *)_cx
{
  JSBool ret;
  
  if (NGJavaScriptBridge_LOG_PROP_DEFINITION) {
    NSLog(@"%s: definition of %@ property '%@' on j0x%p",
          __PRETTY_FUNCTION__, _ro ? @"ro/noslot" : @"rw/noslot", 
	  mname, _jso);
  }

#if WITH_TINY_ID
  ret = JS_DefinePropertyWithTinyId(_cx, _jso,
                                    [mname cString],
                                    [self tinyIdForKey:mname],
                                    JSVAL_NULL,
                                    self->getter, ro ? NULL : self->setter,
                                    _ro ? PROP_READONLY_FLAGS : PROP_READWRITE_FLAGS);
#else
  ret = JS_DefineProperty(_cx, _jso,
                          [mname cString],
                          JSVAL_NULL,
                          self->getter, _ro ? NULL : self->setter,
                          _ro ? PROP_READONLY_FLAGS : PROP_READWRITE_FLAGS);
#endif
  return ret;
}

- (BOOL)applyOnJSObject:(void *)_jso inJSContext:(void *)_cx {
  NSEnumerator *mnames;
  NSString     *mname;
  JSFunctionSpec *fspecs;
  
  if ((fspecs = [self functionSpecs])) {  
    if (!JS_DefineFunctions(_cx, _jso, fspecs)) {
      NSLog(@"ERROR(%s): couldn't define static JS functions (0x%p) on "
	    @"JSObject 0x%p in JSContext 0x%p ..", 
	    __PRETTY_FUNCTION__, fspecs, _jso, _cx);
      return NO;
    }
  }
  
  mnames = [[self jsPropNames] objectEnumerator];
  while ((mname = [mnames nextObject])) {
    JSBool ret;
    
    ret = [self defineProperty:mname readOnly:NO 
                onObject:_jso inJSContext:_cx];
    if (!ret) {
      NSLog(@"ERROR(%s): couldn't define property '%@' on "
	    @"JSObject 0x%p in JSContext 0x%p", 
	    __PRETTY_FUNCTION__, mname, _jso, _cx);
      continue;
    }
  }
  
  mnames = [[self jsReadOnlyPropNames] objectEnumerator];
  while ((mname = [mnames nextObject])) {
    JSBool ret;
    
    ret = [self defineProperty:mname readOnly:YES
                onObject:_jso inJSContext:_cx];
    if (!ret)
      continue;
  }

  return YES;
}

@end /* NGJavaScriptObjCClassInfo */
