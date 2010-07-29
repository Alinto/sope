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

#include "common.h"

#define LOG_OBJECT_OPS 1

extern JS_IMPORT_DATA(JSObjectOps) js_ObjectOps;

typedef struct {
  JSObjectMap map;
  void *backend;
} jso_ObjectMap;

static JSObjectMap *
jop_newMap(JSContext *cx, jsrefcount nrefs,
            JSObjectOps *ops, JSClass *clasp,
            JSObject *obj)
{
  /*
    The object map stores property information for the object, and is
    created when the object is created. 
  */
  JSObjectMap *map;
  jso_ObjectMap *emap;

#if LOG_OBJECT_OPS
  NSLog(@"new map: cx=0x%p, nrefs=%i, ops=0x%p, class=0x%p, obj=0x%p",
	cx, nrefs, ops, clasp, obj);
#endif
  
  map  = js_ObjectOps.newObjectMap(cx, nrefs, ops, clasp, obj);
  emap = calloc(1, sizeof(jso_ObjectMap));
  memcpy(emap, map, sizeof(JSObjectMap));
  free(map);
  return (JSObjectMap *)emap;
}

static void jop_delMap(JSContext *cx, JSObjectMap *map) {
  /* the function that destroys the object map when it is no longer needed. */
  js_ObjectOps.destroyObjectMap(cx, map);
}

static JSBool jop_lookup(JSContext *cx, JSObject *obj, jsid jid,
                         JSObject **objp, JSProperty **propp
#if defined JS_THREADSAFE && defined DEBUG
			    , const char *file, uintN line
#endif
                         )
{
  /* custom property lookup method for the object. */
}

static JSBool jop_define(JSContext *cx, JSObject *obj, jsid jid, jsval value,
                         JSPropertyOp getter, JSPropertyOp setter,
                         uintN attrs, JSProperty **propp)
{
  /* custom property creation method for the object. */
}

static JSBool jop_get(JSContext *cx, JSObject *obj, jsid jid, jsval *vp) {
}
static JSBool jop_set(JSContext *cx, JSObject *obj, jsid jid, jsval *vp) {
}
static JSBool jop_del(JSContext *cx, JSObject *obj, jsid jid, jsval *vp) {
}

static JSBool jop_attrsget(JSContext *cx, JSObject *obj, jsid jid,
                           JSProperty *prop, uintN *attrsp)
{
}
static JSBool jop_attrsset(JSContext *cx, JSObject *obj, jsid jid,
                           JSProperty *prop, uintN *attrsp)
{
}

static JSBool 
jop_defValue(JSContext *cx, JSObject *obj, JSType type, jsval *vp)
{
}

static JSBool jop_enum(JSContext *cx, JSObject *obj,
                       JSIterateOp enum_op,
                       jsval *statep, jsid *idp)
{
}

static JSBool jop_chkaccess(JSContext *cx, JSObject *obj, jsid jid,
                            JSAccessMode mode, jsval *vp, uintN *attrsp)
{
}

struct JSObjectOps NGJavaScriptObjectHandler_JSObjectOps = {
  /* Mandatory non-null function pointer members. */
  jop_newMap,    /* JSNewObjectMapOp    newObjectMap; */
  jop_delMap,    /* JSObjectMapOp       destroyObjectMap; */
  jop_lookup,    /* JSLookupPropOp      lookupProperty; */
  jop_define,    /* JSDefinePropOp      defineProperty; */
  jop_get,       /* JSPropertyIdOp      getProperty; */
  jop_set,       /* JSPropertyIdOp      setProperty; */
  jop_attrsget,  /* JSAttributesOp      getAttributes; */
  jop_attrsset,  /* JSAttributesOp      setAttributes; */
  jop_del,       /* JSPropertyIdOp      deleteProperty; */
  jop_defValue,  /* JSConvertOp         defaultValue; */
  jop_enum,      /* JSNewEnumerateOp    enumerate; */
  jop_chkaccess, /* JSCheckAccessIdOp   checkAccess; */
  
  /* Optionally non-null members start here. */
  NULL, /* JSObjectOp          thisObject; */
  NULL, /* JSPropertyRefOp     dropProperty; */
  NULL, /* JSNative            call; */
  NULL, /* JSNative            construct; */
  NULL, /* JSXDRObjectOp       xdrObject; */
  NULL, /* JSHasInstanceOp     hasInstance; */
  NULL, /* JSSetObjectSlotOp   setProto; */
  NULL, /* JSSetObjectSlotOp   setParent; */
  0,    /* jsword              spare1; */
  0,    /* jsword              spare2; */
  0,    /* jsword              spare3; */
  0,    /* jsword              spare4; */
};

/* JS class */

static JSObjectOps *_getObjOps(JSContext *cx, JSClass *clazz) {
  return &NGJavaScriptObjectHandler_JSObjectOps;
}

static JSBool _convert(JSContext *cx, JSObject *obj, JSType type, jsval *vp) {
  return JS_TRUE;
}

static void _finalize(JSContext *cx, JSObject *obj) {
}

struct JSClass NGJavaScriptObjectHandler_JSObjectOpsClass = {
  "ObjC",
  JSCLASS_HAS_PRIVATE,
  NULL, NULL, NULL, NULL,
  NULL, NULL, 
  _convert,
  _finalize,
  /* Optionally non-null members start here. */
  _getObjOps, //JSGetObjectOps getObjectOps;
  NULL, //JSCheckAccessOp checkAccess;
  NULL, //JSNative call;
  NULL, //JSNative construct;
  NULL, //JSXDRObjectOp xdrObject;
  NULL  //JSHasInstanceOp hasInstance;
  //prword spare[2];
};
