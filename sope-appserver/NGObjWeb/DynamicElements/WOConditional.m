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

@interface WOConditional : WODynamicElement
{
@protected
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  
  WOAssociation *condition;
  WOAssociation *negate;
  WOElement     *template;

  // non-WO
  WOAssociation *value; // compare the condition with value

#if DEBUG
  NSString *condName;
#endif
}

@end /* WOConditional */

#include <DOM/EDOM.h>
#include <NGObjWeb/WOxElemBuilder.h>
#include "decommon.h"
#include "WOElement+private.h"

// TODO: make that a class cluster for improved performance

@implementation WOConditional

static int descriptiveIDs = -1;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  descriptiveIDs = [ud boolForKey:@"WODescriptiveElementIDs"] ? 1 : 0;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
#if DEBUG
  self->condName = _name ? [_name copy] : (id)@"condYES";
#endif
  
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->condition = OWGetProperty(_config, @"condition");
    self->negate    = OWGetProperty(_config, @"negate");
    self->value     = OWGetProperty(_config, @"value");
    self->template  = [_c retain];
    
    if (self->condition == nil) {
      [self warnWithFormat:
              @"missing 'condition' association in element: '%@'", _name];
    }
  }
  return self;
}

- (id)initWithNegateElement:(id<DOMElement>)_element
  templateBuilder:(WOxElemBuilder *)_builder
{
  /* need an own -init so that we can patch the 'negate' association */
  NSString            *name;
  NSMutableDictionary *assocs;
  NSArray             *children;
  id<NSObject,DOMNamedNodeMap> attrs;
  unsigned count;
  
  name = [_element tagName];
  
  /* construct associations */
  
  assocs = nil;
  attrs = [_element attributes];
  if ((count = [attrs length]) > 0)
    assocs = [_builder associationsForAttributes:attrs];

  if ([assocs objectForKey:@"negate"] != nil) {
    // TODO: implement
    [self logWithFormat:@"TODO: if-not with 'negate' binding not supported!"];
    [self release];
    return nil;
  }
  else {
    static WOAssociation *yesAssoc = nil;
    if (yesAssoc == nil) {
      yesAssoc = [[WOAssociation associationWithValue:
				   [NSNumber numberWithBool:YES]] retain];
    }
    [assocs setObject:yesAssoc forKey:@"negate"];
  }
  
  /* construct child elements */
  
  if ([_element hasChildNodes]) {
    /* look for var:binding tags ... */
    
    children = [_builder buildNodes:[_element childNodes]
                         templateBuilder:_builder];
    [children autorelease];
  }
  else
    children = nil;
  
  /* construct self ... */
  return [self initWithName:name associations:assocs contentElements:children];
}

- (id)initWithElement:(id<DOMElement>)_element
  templateBuilder:(WOxElemBuilder *)_builder
{
  NSString *tag;
  
  tag = [_element tagName];
  if ([tag isEqualToString:@"if-not"] || [tag isEqualToString:@"ifnot"])
    return [self initWithNegateElement:_element templateBuilder:_builder];
  
  return [super initWithElement:_element templateBuilder:_builder];
}

- (void)dealloc {
  [self->template  release];
  [self->value     release];
  [self->condition release];
  [self->negate    release];
#if DEBUG
  [self->condName release];
#endif
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* state */

static inline BOOL _doShow(WOConditional *self, WOContext *_ctx) {
  WOComponent *cmp = [_ctx component];
  BOOL doShow   = NO;
  BOOL doNegate = [self->negate boolValueInComponent:cmp];

  if (self->value) {
    id v  = [self->value     valueInComponent:cmp];
    id cv = [self->condition valueInComponent:cmp];
    
    doShow = [cv isEqual:v];
  }
  else
    doShow = [self->condition boolValueInComponent:cmp];
  
  return doNegate ? !doShow : doShow;
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (!_doShow(self, _ctx)) {
#if 0
    NSLog(@"didn't take value from request: %@\n  doShow=%@\n  doNegate=%@",
          [self elementID],
          self->condition, self->negate);
#endif
    return;
  }
  
#if DEBUG
  [_ctx appendElementIDComponent:
	  descriptiveIDs ? self->condName : (NSString *)@"1"];
#else
  [_ctx appendElementIDComponent:@"1"];
#endif
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  NSString *state;
  NSString *key;
  id result;

  state = [[_ctx currentElementID] stringValue];
  
  if (!state) 
    return nil;
    
  [_ctx consumeElementID]; // consume state-id (on or off)
    
#if DEBUG
  key = descriptiveIDs ? self->condName : (NSString *)@"1";
#else
  key = @"1";
#endif
    
  if (![state isEqualToString:key])
    return nil;
      
  [_ctx appendElementIDComponent:state];
  result = [self->template invokeActionForRequest:_rq inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  return result;
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (!_doShow(self, _ctx))
    return;
#if DEBUG
  [_ctx appendElementIDComponent:
	  descriptiveIDs ? self->condName : (NSString *)@"1"];
#else
  [_ctx appendElementIDComponent:@"1"];
#endif
    
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:64];
  if (self->condition) [str appendFormat:@" condition=%@", self->condition];
  if (self->negate)    [str appendFormat:@" negate=%@",    self->negate];
  if (self->template)  [str appendFormat:@" template=%@",  self->template];
  return str;
}

@end /* WOConditional */
