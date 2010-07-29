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

#import "common.h"
#import "WEContextConditional.h"

@implementation WEContextConditional

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->negate     = WOExtGetProperty(_config, @"negate");
    self->contextKey = WOExtGetProperty(_config, @"contextKey");
    self->didMatch   = WOExtGetProperty(_config, @"didMatch");

    self->template  = RETAIN(_c);
  }
  return self;
}

- (void)dealloc {
  [self->template   release];
  [self->negate     release];
  [self->contextKey release];
  [self->didMatch   release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

- (NSString *)_contextKey {
  return nil;
}

- (NSString *)_didMatchKey {
  return nil;
}

/* state */

static inline BOOL _doShow(WEContextConditional *self, WOContext *_ctx) {
  BOOL doShow   = NO;
  BOOL doNegate = [self->negate boolValueInComponent:[_ctx component]];

  if ([self _contextKey])
    doShow = ([_ctx objectForKey:[self _contextKey]] != nil);
  else if (self->contextKey) {
    id cKey = [self->contextKey valueInComponent:[_ctx component]];

    doShow = ([_ctx objectForKey:cKey] != nil);
  }
  doShow = doNegate ? !doShow : doShow;
  
  if (doShow && [self->didMatch isValueSettable])
    [self->didMatch setBoolValue:YES inComponent:[_ctx component]];
  
  if (doShow && [self _didMatchKey] != nil)
    [_ctx setObject:@"YES" forKey:[self _didMatchKey]];
  
  return doShow;
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (_doShow(self, _ctx)) {
    [_ctx appendElementIDComponent:@"1"];
    [self->template takeValuesFromRequest:_rq inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSString *state;
  id result;

  if ((state = [[_ctx currentElementID] stringValue]) == nil)
    return nil;
  
  [_ctx consumeElementID]; // consume state-id (on or off)

  if (![state isEqualToString:@"1"])
    return nil;
      
  [_ctx appendElementIDComponent:state];
  result = [self->template invokeActionForRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  return result;
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (_doShow(self, _ctx)) {
    [_ctx appendElementIDComponent:@"1"];
    [self->template appendToResponse:_response inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
}

@end /* WEContextConditional */
