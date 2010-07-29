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

#include <NGObjWeb/WOTemplateBuilder.h>
#include "common.h"

@implementation WOTemplate

+ (int)version {
  return [super version] + 1 /* v3 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithURL:(NSURL *)_url rootElement:(WOElement *)_element {
  if ((self = [super init])) {
    self->url         = [_url     copy];
    self->rootElement = [_element retain];
    self->loadDate    = [[NSDate alloc] init];
  }
  return self;
}

- (void)dealloc {
  [self->kvcTemplateVars   release];
  [self->componentScript   release];
  [self->subcomponentInfos release];
  [self->loadDate          release];
  [self->rootElement       release];
  [self->url               release];
  [super dealloc];
}

/* component info */

- (void)setComponentScript:(WOComponentScript *)_script {
  ASSIGN(self->componentScript, _script);
}
- (WOComponentScript *)componentScript {
  return self->componentScript;
}

- (void)setKeyValueArchivedTemplateVariables:(NSDictionary *)_vars {
  ASSIGN(self->kvcTemplateVars, _vars);
}
- (NSDictionary *)keyValueArchivedTemplateVariables {
  return self->kvcTemplateVars;
}

/* component info */

/* subcomponent info */

- (BOOL)hasSubcomponentInfos {
  return [self->subcomponentInfos count] > 0 ? YES : NO;
}

- (NSEnumerator *)infoKeyEnumerator {
  return [self->subcomponentInfos keyEnumerator];
}
- (WOSubcomponentInfo *)subcomponentInfoForKey:(NSString *)_key {
  if (_key == nil) return nil;
  return [self->subcomponentInfos objectForKey:_key];
}

- (void)addSubcomponentWithKey:(NSString *)_key
  name:(NSString *)_name
  bindings:(NSDictionary *)_bindings
{
  WOSubcomponentInfo *info;
  
  info = [[WOSubcomponentInfo alloc] initWithName:_name bindings:_bindings];
  if (info == nil)
    return;

  if (self->subcomponentInfos == nil)
    self->subcomponentInfos = [[NSMutableDictionary alloc] initWithCapacity:4];
    
  [self->subcomponentInfos setObject:info forKey:_key];
  [info release];
}

/* accessors */

- (void)setRootElement:(WOElement *)_element {
  ASSIGN(self->rootElement, _element);
}
- (WOElement *)rootElement {
  return self->rootElement;
}

- (NSURL *)url {
    return self->url;
}

/* WOElement methods */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  [self->rootElement takeValuesFromRequest:_req inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  return [self->rootElement invokeActionForRequest:_req inContext:_ctx];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  [self->rootElement appendToResponse:_response inContext:_ctx];
}

/* description */

- (NSString *)description {
  NSMutableString *ms = [NSMutableString stringWithCapacity:128];
  
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->url) {
    if ([self->url isFileURL])
      [ms appendFormat:@" path=%@", [self->url path]];
    else
      [ms appendFormat:@" url=%@", [self->url absoluteString]];
  }
  if (self->subcomponentInfos)
    [ms appendFormat:@" #subcomponents=%i", [self->subcomponentInfos count]];
  
  [ms appendString:@">"];
  return ms;
}

@end /* WOTemplate */
