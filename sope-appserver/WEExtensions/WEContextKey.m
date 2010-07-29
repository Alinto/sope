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

#include <NGObjWeb/WODynamicElement.h>

@interface WEContextKey : WODynamicElement
{
  WOAssociation *key;
  WOAssociation *value;
  WOElement     *template;
}
@end

#include "common.h"

@implementation WEContextKey

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmp
{
  if ((self = [super initWithName:_name associations:_config template:_tmp])) {
    self->key   = WOExtGetProperty(_config, @"key");
    self->value = WOExtGetProperty(_config, @"value");

    if (self->key == nil)
      NSLog(@"Warning! WEContextKey no key set");
    
    if (self->value == nil) {
      self->value = [WOAssociation associationWithValue:@"YES"];
      RETAIN(self->value);
    }
    
    ASSIGN(self->template, _tmp);
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->key);
  RELEASE(self->value);
  RELEASE(self->template);
  
  [super dealloc];
}
#endif

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSString *k  = nil;
  id       v   = nil;
  id       tmp = nil;

  k = [self->key   stringValueInComponent:[_ctx component]];
  v = [self->value valueInComponent:[_ctx component]];

  if (k && v) {
    tmp = [_ctx objectForKey:k]; // save old context value
    [_ctx setObject:v forKey:k];
  }
  
  [self->template takeValuesFromRequest:_req inContext:_ctx];

  if (k && v)   [_ctx removeObjectForKey:k];
  if (tmp && k) [_ctx setObject:tmp forKey:k]; // restore old context value
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSString *k     = nil;
  id       v      = nil;
  id       tmp    = nil;
  id       result = nil;

  k = [self->key   stringValueInComponent:[_ctx component]];
  v = [self->value valueInComponent:[_ctx component]];

  if (k && v) {
    tmp = [_ctx objectForKey:k]; // save old context value
    [_ctx setObject:v forKey:k];
  }
  
  result = [self->template invokeActionForRequest:_req inContext:_ctx];
  
  if (k && v)   [_ctx removeObjectForKey:k];
  if (tmp && k) [_ctx setObject:tmp forKey:k]; // restore old context value
  
  return result;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *k  = nil;
  id       v   = nil;
  id       tmp = nil;
  
  k = [self->key   stringValueInComponent:[_ctx component]];
  v = [self->value valueInComponent:[_ctx component]];

  if (k && v) {
    tmp = [_ctx objectForKey:k]; // save old context value
    [_ctx setObject:v forKey:k];
  }

  [self->template appendToResponse:_response inContext:_ctx];
  
  if (k && v)   [_ctx removeObjectForKey:k];
  if (tmp && k) [_ctx setObject:tmp forKey:k]; // restore old context value
}

@end /* WEContextKey */
