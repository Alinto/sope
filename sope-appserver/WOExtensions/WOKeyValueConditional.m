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

@interface WOKeyValueConditional : WODynamicElement
{
@protected
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  
  WOAssociation *key;
  WOAssociation *value;
  WOElement     *template;

  // non-WO
  WOAssociation *negate;
}

@end /* WOKeyValueConditional */

#include "common.h"

@implementation WOKeyValueConditional

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->key      = WOExtGetProperty(_config, @"key");
    self->value    = WOExtGetProperty(_config, @"value");
    self->negate   = WOExtGetProperty(_config, @"negate");
    self->template = [_c retain];
  }
  return self;
}

- (void)dealloc {
  [self->template release];
  [self->value    release];
  [self->key      release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* state */

static inline BOOL _doShow(WOKeyValueConditional *self, WOContext *_ctx) {
  WOComponent *c       = [_ctx component];
  BOOL        doShow   = NO;
  BOOL        doNegate = [self->negate boolValueInComponent:c];
  id          v, kv;
  NSString    *k;

  k  = [self->key   stringValueInComponent:c];
  v  = [self->value valueInComponent:c];
  kv = [c valueForKey:k];
  
  doShow = [kv isEqual:v];
  
  return doNegate ? !doShow : doShow;
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (_doShow(self, _ctx)) {
    [_ctx appendElementIDComponent:@"1"];
    [self->template takeValuesFromRequest:_rq inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
#if 0
  else {
    NSLog(@"didn't take value from request: %@\n  doShow=%@\n  doNegate=%@",
          [self elementID],
          self->condition, self->negate);
  }
#endif
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSString *state;

  state = [[_ctx currentElementID] stringValue];
  
  if (state) {
    [_ctx consumeElementID]; // consume state-id (on or off)

    if ([state isEqualToString:@"1"]) {
      id result;
      
      [_ctx appendElementIDComponent:state];
      result = [self->template invokeActionForRequest:_rq inContext:_ctx];
      [_ctx deleteLastElementIDComponent];

      return result;
    }
  }
  return nil;
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (_doShow(self, _ctx)) {
    [_ctx appendElementIDComponent:@"1"];
    [self->template appendToResponse:_response inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:64];
  if (self->key)      [str appendFormat:@" key=%@",      self->key];
  if (self->value)    [str appendFormat:@" value=%@",    self->value];
  if (self->negate)   [str appendFormat:@" negate=%@",   self->negate];
  if (self->template) [str appendFormat:@" template=%@", self->template];
  return str;
}

@end /* WOKeyValueConditional */
