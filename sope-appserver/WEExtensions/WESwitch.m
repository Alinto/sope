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
  WESwitch      { selection | selections };
  WECase        { key | keys };
  WEDefaultCase {};
  
  Warning: The DefaultCase must appear at the last position!!!
*/

/*  
  example:
  
  // wod:
  Switch:      WESwitch { selection = selection;           };
  FirstCase:   WECase   { key       = "first";             };
  SecondCase:  WECase   { keys      = ("second", "third"); };
  DefaultCase: WEDefaultCase {};

  // html:
  <#Switch>
    <#FirstCase>content of first case</#FirstCase>
    <#SecondCase>content of second case</#SecondCase>
    <#DefaultCase>content of default case</#SecondCase>
  </#Switch>
  
*/
#include <NGObjWeb/WODynamicElement.h>

@class WOAssociation;

@interface WESwitch : WODynamicElement
{
@protected
  WOAssociation *selection;     // string -> single switch
  WOAssociation *selections;    // array  -> multi  switch
  WOElement     *template;
}
@end

@interface WECase : WODynamicElement
{
  WOAssociation *key;          // string -> unique identifier
  WOAssociation *keys;         // array of unique identifiers

  WOAssociation *defaultCase;  // emulates a WEDefaultCase DEPRECATED!!!
  
  WOElement     *template;
}
@end

@interface WEDefaultCase : WODynamicElement
{
  WOElement *template;
}
@end

#include "common.h"

#if DEBUG
static NSString *WESwitch_DefaultCaseFound = @"WESwitch_DefaultCaseFound";
#endif
static NSString *WESwitch_CaseDidMatch     = @"WESwitch_CaseDidMatch";
static NSString *WESwitchSelection         = @"WESwitchSelection";
static NSString *WESwitchSelections        = @"WESwitchSelections";
static NSString *WESwitchDict              = @"WESwitchDict";

@implementation WESwitch

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->selection  = WOExtGetProperty(_config, @"selection");
    self->selections = WOExtGetProperty(_config, @"selections");
    
    self->template   = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->template   release];
  [self->selection  release];
  [self->selections release];
  [super dealloc];
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *cmp   = nil;
  NSArray     *array = nil;
  NSString    *k     = nil;
  unsigned    i, cnt;
  BOOL        doLazy = YES;

  
  cmp   = [_ctx component];
  array = [self->selections valueInComponent:cmp];
  k     = [self->selection  valueInComponent:cmp];
  cnt   = [array count];

  if (_req == nil) {
    [self->template takeValuesFromRequest:_req inContext:_ctx];
  }
  else if (k) {
    [_ctx setObject:k forKey:WESwitchSelection];
    [self->template takeValuesFromRequest:_req inContext:_ctx];
    [_ctx removeObjectForKey:WESwitchSelection];
  }
  else if (doLazy) {
    for (i = 0; i < cnt; i++) {
      [_ctx setObject:[array objectAtIndex:i] forKey:WESwitchSelection];
      [self->template takeValuesFromRequest:_req inContext:_ctx];
    }
    if (cnt == 0) {
      [_ctx setObject:array forKey:WESwitchSelections];
      [self->template takeValuesFromRequest:_req inContext:_ctx];
      [_ctx removeObjectForKey:WESwitchSelections];
    }
    [_ctx removeObjectForKey:WESwitchSelection];
  }
  else if (cnt > 0) {
    NSLog(@"Warning(%s):This case is not implemented!!!", __PRETTY_FUNCTION__);
    [self->template takeValuesFromRequest:_req inContext:_ctx];
  }
  
#if DEBUG
  else {
    [cmp logWithFormat:
         @"Warning! WESwitch: Neither 'selection' nor 'selections' set!!!"];
  }
#endif

  [_ctx removeObjectForKey:WESwitch_CaseDidMatch];
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_request inContext:_ctx];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *cmp   = nil;
  NSArray     *array = nil;
  NSString    *k     = nil;
  unsigned    i, cnt;
  BOOL        doLazy = YES;

  
  cmp   = [_ctx component];
  array = [self->selections valueInComponent:cmp];
  k     = [self->selection  valueInComponent:cmp];
  cnt   = [array count];

  if (_response == nil) {
    [self->template appendToResponse:_response inContext:_ctx];
  }
  else if (k) {
    [_ctx setObject:k forKey:WESwitchSelection];
    [self->template appendToResponse:_response inContext:_ctx];
    [_ctx removeObjectForKey:WESwitchSelection];
  }
  else if (doLazy) {
    for (i=0; i<cnt; i++) {
      [_ctx setObject:[array objectAtIndex:i] forKey:WESwitchSelection];
      [self->template appendToResponse:_response inContext:_ctx];
    }
    if (cnt == 0) {
      [_ctx setObject:array forKey:WESwitchSelections];
      [self->template appendToResponse:_response inContext:_ctx];
      [_ctx removeObjectForKey:WESwitchSelections];
    } 
    [_ctx removeObjectForKey:WESwitchSelection];
  }
  else if (cnt > 0) {
    NSMutableDictionary *dict = nil;
    
    // get subcontent of WECases
    [_ctx setObject:array forKey:WESwitchSelections];
    [self->template appendToResponse:_response inContext:_ctx];
    
    dict = [_ctx objectForKey:WESwitchDict];

    // append subcontent
    if (dict) {
      for (i=0; i<cnt; i++) {
        NSString *k = [array objectAtIndex:i];
        NSData   *c = [dict objectForKey:k];   // subcontent of WECase

        if (c)
          [_response appendContentData:c];
      }
    }
    
    [_ctx removeObjectForKey:WESwitchDict];
    [_ctx removeObjectForKey:WESwitchSelections];
  }
  
#if DEBUG
  else {
    [cmp logWithFormat:
         @"Warning! WESwitch: Neither 'selection' nor 'selections' set!!!"];
  }
#endif

  [_ctx removeObjectForKey:WESwitch_CaseDidMatch];
}

@end /* WESwitch */

@implementation WECase

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->key  = WOExtGetProperty(_config, @"key");
    self->keys = WOExtGetProperty(_config, @"keys");

    // DEPRECATED!!!
    self->defaultCase  = WOExtGetProperty(_config, @"default");
    
    self->template = [_t retain];
  }
  return self;
}

- (void)dealloc {
  [self->template    release];
  [self->key         release];
  [self->keys        release];
  [self->defaultCase release];
  [super dealloc];
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  NSArray     *selections = nil;
  NSString    *selection  = nil;
  NSString    *k          = nil;
  NSArray     *ks         = nil;
  
  k   = [self->key  stringValueInComponent:[_ctx component]];
  ks  = [self->keys valueInComponent:[_ctx component]];
  
  selections = [_ctx objectForKey:WESwitchSelections];
  selection  = [_ctx objectForKey:WESwitchSelection];

  if ([self->defaultCase boolValueInComponent:[_ctx component]]) {
    if ([_ctx objectForKey:WESwitch_CaseDidMatch] == nil)
      [self->template takeValuesFromRequest:_req inContext:_ctx];
    return;
  }

  if ((k == nil) && (ks == nil)) {
#if DEBUG
    [[_ctx component] logWithFormat:
                      @"Warning! WECase: Neither 'key' nor 'keys' set!!!"];
#endif
    return;
  }
  if ((k != nil) && (ks != nil)) {
#if DEBUG
    [[_ctx component] logWithFormat:
                      @"Warning! WECase: Both, 'key' and 'keys' are set!!!"];
#endif
    return;
  }
  
  if (_req == nil) {
    [self->template takeValuesFromRequest:nil inContext:_ctx];
  }
  if (selection) {
    if (k && [k isEqualToString:selection]) {
       [self->template takeValuesFromRequest:_req inContext:_ctx];
       [_ctx setObject:@"YES" forKey:WESwitch_CaseDidMatch];
    }
    else if (ks && [ks containsObject:selection]) {
      [self->template takeValuesFromRequest:_req inContext:_ctx];
      [_ctx setObject:@"YES" forKey:WESwitch_CaseDidMatch];
    }
  }
  else if (selections && [selections count] > 0) {
    NSLog(@"Warning(%s): This case is not implemented!", __PRETTY_FUNCTION__);
    [self->template takeValuesFromRequest:_req inContext:_ctx];
  }
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_req inContext:_ctx];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSArray     *selections = nil;
  NSString    *selection  = nil;
  NSString    *k          = nil;
  NSArray     *ks         = nil;

  k   = [self->key  stringValueInComponent:[_ctx component]];
  ks  = [self->keys valueInComponent:[_ctx component]];

  selections = [_ctx objectForKey:WESwitchSelections];
  selection  = [_ctx objectForKey:WESwitchSelection];

  if ([self->defaultCase boolValueInComponent:[_ctx component]]) {
    if ([_ctx objectForKey:WESwitch_CaseDidMatch] == nil)
      [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  if ((k == nil) && (ks == nil)) {
#if DEBUG
    [[_ctx component] warnWithFormat:
                      @"WECase: Neither 'key' nor 'keys' set!!!"];
#endif
    return;
  }
  if ((k != nil) && (ks != nil)) {
#if DEBUG
    [[_ctx component] warnWithFormat:
                      @"WECase: Both, 'key' and 'keys' are set!!!"];
#endif
    return;
  }
  
  if (_response == nil) {
    [self->template appendToResponse:nil inContext:_ctx];
  }
  if (selection) {
    if (k && [k isEqualToString:selection]) {
       [self->template appendToResponse:_response inContext:_ctx];
       [_ctx setObject:@"YES" forKey:WESwitch_CaseDidMatch];
    }
    else if (ks && [ks containsObject:selection]) {
      [self->template appendToResponse:_response inContext:_ctx];
      [_ctx setObject:@"YES" forKey:WESwitch_CaseDidMatch];
    }
  }
  else if (selections && [selections count] > 0) {
    if ([selections containsObject:k]) {
      static NSData *emptyData = nil;
      NSMutableDictionary *dict       = nil;
      NSData              *oldContent = nil;

      if (emptyData == nil)
        emptyData = [[NSData alloc] init];

      // get subcontent dictionary
      dict = [_ctx objectForKey:WESwitchDict];
      if (dict == nil)
        dict = [NSMutableDictionary dictionaryWithCapacity:[selections count]];

      // set new content
      oldContent = [_response content];
      RETAIN(oldContent);
      [_response setContent:emptyData];
      
      // append template to new content
      [self->template appendToResponse:_response inContext:_ctx];

      // save new content in dict
      if ([_response content])
        [dict setObject:[_response content] forKey:k];
      [_ctx setObject:dict forKey:WESwitchDict];

      // restore old content
      [_response setContent:oldContent];
      [oldContent release]; oldContent = nil;

      // TODO: use NSNumber here?
      [_ctx setObject:@"YES" forKey:WESwitch_CaseDidMatch];
    }
  }
}

@end /* WECase */

@implementation WEDefaultCase

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->template = [_t retain];
  }
  return self;
}

- (void)dealloc {
  [self->template release];
  [super dealloc];
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  if (([_ctx objectForKey:WESwitch_CaseDidMatch] == nil))
    [self->template takeValuesFromRequest:_req inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_req inContext:_ctx];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (([_ctx objectForKey:WESwitch_CaseDidMatch] == nil))
    [self->template appendToResponse:_response inContext:_ctx];
  
#if DEBUG
  [_ctx setObject:@"Yes" forKey:WESwitch_DefaultCaseFound];
#endif
}

@end /* WEDefaultCase */
