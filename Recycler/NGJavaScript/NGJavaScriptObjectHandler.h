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

#ifndef __NGJavaScriptObjectHandle_H__
#define __NGJavaScriptObjectHandle_H__

#import <Foundation/NSObject.h>

@class NGJavaScriptContext;
@class NGJavaScriptObjectMappingContext;
@class NGObjectMappingContext;

/*
  This object manages the access to an JavaScript object
  by the NGJavaScriptObject class (that is, it's more or
  less the "private" implementation of NGJavaScriptObject)
  
  For example it manages the "retain count" of JavaScript
  objects. To make JS objects survive a garbage collection,
  the JS objects must be either stored as a value in a
  another surviving object or it must be marked as a root
  object. Almost all Objective-C objects are marked as
  root objects since they exist completly independed from
  their JS containers.
  
  Note: The object-handler is stored as in the private
        field of the JS object structure.
  
  BTW: Maybe root objects aren't necessary anymore:
  ---snip---
  In point of fact, you do not need JS_AddRoot/JS_RemoveRoot to protect 
  GC-thing strong references in private data nowadays: you should consider 
  implementing your own JSClass.mark hook, which could call JS_MarkGCThing 
  on each strong ref.  Then your getter could live only in the prototype, 
  you would use JSPROP_SHARED, and memory use would be minimized.
  ---snap---
*/

@interface NGJavaScriptObjectHandler : NSObject
{
  NGJavaScriptObjectMappingContext *ctx; // non-retained ?
  void           *jsContext;    // JavaScript ctx handle
  void           *jsObject;     // JavaScript object handle
  id             managedObject; // non-ret. (is this the NGJavaScriptObject ?)
@private
  unsigned short jsRootRC;
}

- (id)initWithJSContext:(NGJavaScriptContext *)_ctx;

- (id)initWithObject:(id)_object
  inMappingContext:(NGObjectMappingContext *)_ctx;

/* accessors */

- (NGJavaScriptContext *)jsContext;
- (void *)handle;
- (id)managedObject;

/* JS root references */

- (id)jsRetain;
- (void)jsRelease;
- (unsigned)jsRootRetainCount;

/* properties */

- (BOOL)hasPropertyNamed:(NSString *)_propName;
- (BOOL)hasElementAtIndex:(unsigned)_idx;

- (void)setValue:(id)_value ofPropertyNamed:(NSString *)_propName;
- (id)valueOfPropertyNamed:(NSString *)_propName;

/* scripts */

- (id)callFunctionNamed:(NSString *)_funcName, ...;
- (id)evaluateScript:(NSString *)_script;

/* misc */

- (BOOL)loadStandardClasses;
- (void)makeGlobal;

@end

#endif /* __NGJavaScriptObjectHandle_H__ */
