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

/*
  WEQualifierConditional

    IfPerson: WEQualifierConditional {
      condition = "isPerson=YES AND isCategory like '*customer*'";
      object    = currentPerson;
      negate    = NO;
      bindings  = nil; // optional qualifier bindings
      requiresAllVariables = YES; // whether all bindings must be resolved
    }
  
  If no object is given, the qualifier is evaluated against the component.
*/

#include <NGObjWeb/WODynamicElement.h>

@class WOAssociation;

@interface WEQualifierConditional : WODynamicElement
{
@protected
  WOAssociation *condition;
  WOAssociation *object;
  WOAssociation *negate;
  WOElement     *template;
  WOAssociation *bindings;
  WOAssociation *requiresAllVariables;
}
@end

#include "common.h"

// TODO: add support for qualifier arguments?

@implementation WEQualifierConditional

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->condition = WOExtGetProperty(_config, @"condition");
    self->object    = WOExtGetProperty(_config, @"object");
    self->negate    = WOExtGetProperty(_config, @"negate");
    self->bindings  = WOExtGetProperty(_config, @"bindings");
    self->requiresAllVariables = 
      WOExtGetProperty(_config, @"requiresAllVariables");
    self->template  = [_t retain];
    
    if (self->condition == nil) {
      [self logWithFormat:
              @"WARNING: missing 'condition' association in element: '%@'",
              _name];
    }
    else if ([self->condition isValueConstant]) {
      /* optimization, replace constant associations with a parsed qualifier */
      NSString *value;
      
      if ((value = [self->condition stringValueInComponent:nil])) {
        EOQualifier   *q;
        
        q = [EOQualifier qualifierWithQualifierFormat:value];
        if (q) {
          WOAssociation *tmp;
          
          tmp = [[WOAssociation associationWithValue:q] retain];
          [self->condition release];
          self->condition = tmp;
        }
      }
    }
  }
  return self;
}

- (void)dealloc {
  [self->template  release];
  [self->condition release];
  [self->object    release];
  [self->negate    release];
  [self->bindings  release];
  [self->requiresAllVariables release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* state */

- (BOOL)_doShowInContext:(WOContext *)_ctx {
  WOComponent  *cmp;
  NSDictionary *vars;
  NSArray      *args;
  id   qualifier, context;
  BOOL doShow, doNegate, needAllVars;
  
  cmp         = [_ctx component];
  doNegate    = self->negate ? [self->negate boolValueInComponent:cmp] : NO;
  doShow      = NO;
  vars        = [self->bindings valueInComponent:cmp];
  args        = nil;
  needAllVars = self->requiresAllVariables 
    ? [self->requiresAllVariables boolValueInComponent:cmp]
    : NO;
  
  /* determine qualifier */
  
  if ((qualifier = [self->condition valueInComponent:cmp])) {
    if ([qualifier isKindOfClass:[NSString class]]) {
      qualifier = [EOQualifier qualifierWithQualifierFormat:qualifier
                               arguments:args];
    }
  }
  
  /* apply qualifier bindings */
  
  if (vars != nil && qualifier != nil) {
    qualifier = [qualifier qualifierWithBindings:vars 
                           requiresAllVariables:needAllVars];
  }
  
  /* find context object */
  
  context = (self->object != nil)
    ? [self->object valueInComponent:cmp]
    : (id)cmp;
  
  /* evaluate */
  
  if (![qualifier respondsToSelector:@selector(evaluateWithObject:)]) {
    [self errorWithFormat:@"got a qualifier which does not respond to "
                          @"evaluateWithObject: %@", qualifier];
    doShow = NO;
  }
  else
    doShow = [qualifier evaluateWithObject:context];
  
  return doNegate ? !doShow : doShow;
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (![self _doShowInContext:_ctx])
    return;

  [_ctx appendElementIDComponent:@"1"];
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSString *state;
  id result;

  state = [[_ctx currentElementID] stringValue];
  
  if (!state) 
    return nil;
  [_ctx consumeElementID]; // consume state-id (on or off)
  
  if (![state isEqualToString:@"1"])
    return nil;
  
  [_ctx appendElementIDComponent:state];
  result = [self->template invokeActionForRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  return result;
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (![self _doShowInContext:_ctx])
    return;

  [_ctx appendElementIDComponent:@"1"];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:64];
  if (self->condition) [str appendFormat:@" condition=%@", self->condition];
  if (self->object)    [str appendFormat:@" object=%@",    self->object];
  if (self->negate)    [str appendFormat:@" negate=%@",    self->negate];
  if (self->template)  [str appendFormat:@" template=%@",  self->template];
  return str;
}

@end /* WEQualifierConditional */
