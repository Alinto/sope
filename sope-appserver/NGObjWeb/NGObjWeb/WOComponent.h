/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#ifndef __NGObjWeb_WOComponent_H__
#define __NGObjWeb_WOComponent_H__

#import <Foundation/NSMapTable.h>
#import <NGObjWeb/WOElement.h>
#include <NGObjWeb/WOActionResults.h>

@class NSString, NSDictionary, NSMutableDictionary, NSURL, NSException, NSURL;
@class WOElement, WOContext, WOSession, WOApplication, WOResourceManager;

@interface WOComponent : WOElement < WOActionResults, NSCoding >
{
@private
  NSDictionary        *wocBindings;     // bindings to parent component
  NSString            *wocName;         // name of component
  
  WOComponent         *parentComponent; // non-retained;
  NSDictionary        *subcomponents;   // subcomponents
  NSMutableDictionary *wocVariables;    // user variables

  struct {
    BOOL reloadTemplates:1; // component definition caching
    BOOL isAwake:1;
  } componentFlags;

@protected // transient (non-retained)
  WOContext     *context;
  WOApplication *application;
  WOSession     *session;
  
  NSURL *wocBaseURL;
  id    cycleContext; // was: _ODCycleCtx
  id    wocClientObject;
}

- (id)initWithContext:(WOContext *)_ctx;

- (void)awake;
- (void)sleep;

/*
  This method needs to be called before using a component cached by yourself.
*/
- (void)ensureAwakeInContext:(WOContext *)_ctx;

/* accessors */

- (NSString *)name;
- (NSString *)path;
- (NSURL *)baseURL;

- (id)application;
- (id)session;
- (WOContext *)context;
- (BOOL)hasSession; // new in WO4

/* component definition caching */

- (void)setCachingEnabled:(BOOL)_flag;
- (BOOL)isCachingEnabled;

/* resources */

- (NSString *)pathForResourceNamed:(NSString *)_name ofType:(NSString *)_ext;
- (NSString *)frameworkName;

/* templates */

- (WOElement *)templateWithName:(NSString *)_name;

+ (WOElement *)templateWithHTMLString:(NSString *)_html
  declarationString:(NSString *)_wod
  languages:(NSArray *)_languages;
  
- (id)pageWithName:(NSString *)_name; // new in WO4

- (void)setTemplate:(id)_template;

/* child components */

- (BOOL)synchronizesVariablesWithBindings;                // new in WO4
- (void)setValue:(id)_value forBinding:(NSString *)_name; // new in WO4
- (id)valueForBinding:(NSString *)_name;                  // new in WO4
- (BOOL)hasBinding:(NSString *)_name;                     // new in WO4
- (BOOL)canSetValueForBinding:(NSString *)_name;          // new in WO4
- (BOOL)canGetValueForBinding:(NSString *)_name;          // new in WO4

- (id)performParentAction:(NSString *)_attributeName;
- (id)parent;

/* variables */

- (BOOL)isStateless; // new in WO4.5
- (void)reset;       // new in WO4.5

- (void)setObject:(id)_object forKey:(NSString *)_key;
- (id)objectForKey:(NSString *)_key;

- (void)validationFailedWithException:(NSException *)_exception
  value:(id)_value
  keyPath:(NSString *)_keyPath; // new in WO4

/* logging */

- (BOOL)isEventLoggingEnabled;

@end /* WOComponent */

@interface WOComponent(Logging)
/* implemented in NGExtensions */

- (void)logWithFormat:(NSString *)_fmt arguments:(va_list)_arguments;
- (void)logWithFormat:(NSString *)_fmt, ...;
- (void)debugWithFormat:(NSString *)_fmt, ...;

@end

@interface WOComponent(SkyrixExtensions)

- (WOResourceManager *)resourceManager;
- (id)existingSession;

- (id<WOActionResults>)redirectToLocation:(id)_loc;
- (BOOL)shouldTakeValuesFromRequest:(WORequest *)_rq inContext:(WOContext*)_c;

@end

@interface WOComponent(DeprecatedMethodsInWO4)

- (WOElement *)templateWithHTMLString:(NSString *)_html
  declarationString:(NSString *)_wod;

- (NSString *)stringForKey:(NSString *)_key
  inTableNamed:(NSString *)_tableName
  withDefaultValue:(NSString *)_default;

@end /* WOComponent(DeprecatedMethodsInWO4) */

@interface WOComponent(AdvancedBindingAccessors)

- (void)setUnsignedIntValue:(unsigned)_value forBinding:(NSString *)_name;
- (unsigned)unsignedIntValueForBinding:(NSString *)_name;
- (void)setIntValue:(int)_value forBinding:(NSString *)_name;
- (int)intValueForBinding:(NSString *)_name;

@end /* WOComponent(AdvancedBindingAccessors) */

@interface WOComponent(Statistics)

- (NSString *)descriptionForResponse:(WOResponse *)_response
  inContext:(WOContext *)_context;

@end /* WOComponent(Statistics) */

@interface WOComponent(DirectActionExtensions)

- (void)takeFormValuesForKeyArray:(NSArray *)_keys;
- (void)takeFormValuesForKeys:(NSString *)_key1,...;
- (id<WOActionResults>)defaultAction;
- (id<WOActionResults>)performActionNamed:(NSString *)_actionName;

@end /* WOComponent(DirectActionExtensions) */

#endif /* __NGObjWeb_WOComponent_H__ */
