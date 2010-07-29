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

#ifndef __NGJavaScriptObjectMappingContext_H__
#define __NGJavaScriptObjectMappingContext_H__

#include <NGScripting/NGObjectMappingContext.h>
#import <Foundation/NSMapTable.h>

@class NGJavaScriptContext, NGJavaScriptObjectHandler;

/*
  A context which maps JavaScript objects to ObjC objects.
  
  Note: do *not* create a context manually, use NGScriptLanguage
  -createMappingContext !
  
  Note: NSCoding is done by NGObjectMappingContext and either unarchives
  into the active context if one is available or creates a new context
  if no context is available yet (in other words, NSCoding is context
  sensitive)
*/

@interface NGJavaScriptObjectMappingContext : NGObjectMappingContext
{
  NSMapTable          *objcToJS; // ObjC proxies
  NSMapTable          *jsToObjC; // pure JS objects (others stored in private)
  NGJavaScriptContext *jsContext;
}

- (NGJavaScriptContext *)jsContext;

/* hierachy */

- (void)setGlobalObject:(id)_object;
- (id)globalObject;

/* mappings */

- (void)registerObject:(id)_object forImportedHandle:(void *)_handle;
- (void)forgetImportedHandle:(void *)_handle;

/* handler */

- (NGJavaScriptObjectHandler *)handlerForObject:(id)_object;

/* values */

- (id)objectForJSValue:(void *)_value;
- (BOOL)jsValue:(void *)_value forObject:(id)_obj;

@end

@interface NGJavaScriptObjectMappingContext(CombinedObjects)

- (void)makeObjectCombined:(id)_object;
- (BOOL)isCombinedObject:(id)_object;

@end

@interface JSCombinedObjectBehaviour : NSObject
- (id)evaluateScript:(NSString *)_js language:(NSString *)_language;
@end

@interface NSObject(JSCombinedObjects)
+ (BOOL)isJSCombinedObjectClass;
- (BOOL)isJSCombinedObject;
- (NGJavaScriptObjectMappingContext *)jsObjectMappingContext;
@end

@interface NGJavaScriptObjectMappingContext(Debugging)
- (void)_logExportedJavaScriptObjects;
- (void)_logExportedObjCObjects;
- (void)_logCombinedObjects;
@end

#endif /* __NGJavaScriptObjectMappingContext_H__ */
