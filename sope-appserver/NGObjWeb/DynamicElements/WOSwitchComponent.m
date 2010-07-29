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

#include <NGObjWeb/WOHTMLDynamicElement.h>

@class NSDictionary;
@class WOAssociation;

@interface WOSwitchComponent : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *componentName; // WOComponentName attribute
  NSDictionary  *bindings;
  WOElement     *template;
}

@end

#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOContext.h>
#include "WOElement+private.h"
#include "WOContext+private.h"
#include "WOComponent+private.h"
#include "decommon.h"

@implementation WOSwitchComponent

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->containsForm  = YES;
    self->componentName = OWGetProperty(_config, @"WOComponentName");
    self->bindings      = [_config copy];
    [(NSMutableDictionary *)_config removeAllObjects];

    self->template = [_c retain];
  }
  return self;
}

- (void)dealloc {
  [self->template      release];
  [self->componentName release];
  [self->bindings      release];
  [super dealloc];
}

/* component lookup */

- (WOComponent *)lookupComponent:(NSString *)cname
  inContext:(WOContext *)_ctx
{
  WOComponent *component;
  
  if (cname == nil)
    return nil;

  if ((component = [[_ctx component] pageWithName:cname]) == nil) {
    [[_ctx component] debugWithFormat:@"couldn't find component '%@'", cname];
    return nil;
  }
  
  [component setParent:[_ctx component]];
  [component setBindings:self->bindings];
  
  return component;
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *c;
  NSString    *cname;
  
  cname = [self->componentName stringValueInComponent:[_ctx component]];
  
  if ((c = [self lookupComponent:cname inContext:_ctx]) == nil)
    return;
  
  [_ctx appendElementIDComponent:cname];
  [_ctx enterComponent:c content:self->template];
  [c takeValuesFromRequest:_req inContext:_ctx];
  [_ctx leaveComponent:c];
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *c;
  id       result;
  NSString *cname, *reqname;

  if ((reqname = [_ctx currentElementID]) == nil)
    /* missing id in request */
    return nil;
  
  cname = [self->componentName stringValueInComponent:[_ctx component]];
  
  if (![cname isEqualToString:reqname]) {
    /* component mismatch */
    [[_ctx component] logWithFormat:
                        @"WOSwitchComponent: component name mismatch"
                        @" (%@ vs %@), ignoring action.",
                        cname, reqname];
    return nil;
  }
  
  if ((c = [self lookupComponent:cname inContext:_ctx]) == nil)
    return nil;
  [_ctx consumeElementID];
  
  [_ctx appendElementIDComponent:cname];
  [_ctx enterComponent:c content:self->template];
  result = [c invokeActionForRequest:_req inContext:_ctx];
  [_ctx leaveComponent:c];
  [_ctx deleteLastElementIDComponent];
  
  return result;
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *c;
  NSString    *cname;
  
  cname = [self->componentName stringValueInComponent:[_ctx component]];
  
  if ((c = [self lookupComponent:cname inContext:_ctx]) == nil)
    return;
  
  [_ctx appendElementIDComponent:cname];
  [_ctx enterComponent:c content:self->template];
  [c appendToResponse:_response inContext:_ctx];
  [_ctx leaveComponent:c];
  [_ctx deleteLastElementIDComponent];
}

@end /* WOSwitchComponent */
