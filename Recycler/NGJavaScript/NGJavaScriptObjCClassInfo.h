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

#ifndef __NGJavaScriptObjCClassInfo_H__
#define __NGJavaScriptObjCClassInfo_H__

#include "common.h"
#import <Foundation/NSMapTable.h>

@class NSString, NSArray, NSMutableDictionary;

/*
  This class determines and stores the mapping information for 
  Objective-C objects, that is, the properties and selectors of
  the class which are exposed to JavaScript.
  It should be probably modified to mirror the AppleScript classes in
  Foundation, that is, we should add a NGScriptClassDescription etc.
  
  Property Mapping: Objective-C classes export properties by
  declaring get/set accessor methods that start with "_jsprop_":
  
    - (id)_jsprop_a;
    
  to retrieve a property named "a" and
  
    - (void)_jsprop_a:(id)_value
    
  to set a property named "a". If no set accessors can be found,
  the property is registered as a read-only field.
  
  Function Mapping: functions are exported by declaring a single
  argument selector that starts with "_jsfunc_", eg:
  
    - (id)_jsfunc_doIt:(NSArray *)_args;
  
  declares a JavaScript function named "doIt()".
*/

@interface NGJavaScriptObjCClassInfo : NSObject
{
  Class          clazz;
  NSArray        *jsFuncNames;
  NSArray        *jsPropNames;
  NSArray        *jsReadOnlyPropNames;
  JSFunctionSpec *funcSpecs;
  unsigned char  tinyId;
  NSMapTable     *idToKey;
  JSPropertyOp   setter;
  JSPropertyOp   getter;
  JSNative       caller;
}

- (id)initWithClass:(Class)_clazz
  setter:(JSPropertyOp)_setter
  getter:(JSPropertyOp)_getter
  caller:(JSNative)_caller;

- (NSArray *)jsFuncNames;
- (NSArray *)jsPropNames;
- (NSArray *)jsReadOnlyPropNames;

- (JSFunctionSpec *)functionSpecs;

- (BOOL)isStaticProperty:(NSString *)_prop;

/* resolving IDs */

- (SEL)getSelectorForPropertyId:(void *)_idval inJSContext:(void *)_cx;
- (SEL)setSelectorForPropertyId:(void *)_idval inJSContext:(void *)_cx;

/* apply on JSObject */

- (BOOL)applyOnJSObject:(void *)_jso inJSContext:(void *)_cx;

@end

#endif /* __NGJavaScriptObjCClassInfo_H__ */
