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

#ifndef __NGObjWeb_WOTemplate_H__
#define __NGObjWeb_WOTemplate_H__

#import <Foundation/NSObject.h>
#include <NGObjWeb/WOElement.h>

@class NSURL, NSDate, NSString, NSDictionary, NSMutableDictionary;
@class NSEnumerator;
@class WOTemplate, WOSubcomponentInfo, WOComponentScript;

@interface WOTemplate : WOElement
{
  /* should add some info about the logic of the component ... */
  NSURL               *url;
  WOElement           *rootElement;
  NSDate              *loadDate;
  NSMutableDictionary *subcomponentInfos;
  WOComponentScript   *componentScript;
  NSDictionary        *kvcTemplateVars;
}

- (id)initWithURL:(NSURL *)_url rootElement:(WOElement *)_element;

/* component info */

- (void)setComponentScript:(WOComponentScript *)_script;
- (WOComponentScript *)componentScript;

- (void)setKeyValueArchivedTemplateVariables:(NSDictionary *)_vars;
- (NSDictionary *)keyValueArchivedTemplateVariables;

/* subcomponent info */

- (void)addSubcomponentWithKey:(NSString *)_key
  name:(NSString *)_name
  bindings:(NSDictionary *)_bindings;

- (BOOL)hasSubcomponentInfos;
- (NSEnumerator *)infoKeyEnumerator;
- (WOSubcomponentInfo *)subcomponentInfoForKey:(NSString *)_key;

/* accessors */

- (void)setRootElement:(WOElement *)_element;
- (WOElement *)rootElement;

- (NSURL *)url;

@end

@interface WOSubcomponentInfo : NSObject
{
  NSString     *componentName;
  NSDictionary *bindings;
}

- (id)initWithName:(NSString *)_name bindings:(NSDictionary *)_bindings;

/* accessors */

- (NSString *)componentName;
- (NSDictionary *)bindings;

@end

#endif /* __NGObjWeb_WOTemplate_H__ */
