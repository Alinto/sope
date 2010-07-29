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

#include "WOInput.h"
#include <NGObjWeb/WOApplication.h>
#include "decommon.h"

@interface WOSubmitButton : WOInput
{
  // WOInput: name
  // WOInput: value
  // WOInput: disabled
@protected
  WOAssociation *action;
  WOAssociation *pageName;

  // new in WO4:
  WOAssociation *queryDictionary;
  NSDictionary  *queryParameters;  // associations beginning with ?
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  BOOL          sidInUrl;
}

@end /* WOSubmitButton */

@implementation WOSubmitButton

static BOOL WOSubmitButtonEnableValueSync = NO;

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  WOSubmitButtonEnableValueSync = 
    [ud boolForKey:@"WOSubmitButtonEnableValueSync"];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    WOAssociation *sidInUrlAssoc;

    sidInUrlAssoc  = OWGetProperty(_config, @"?wosid");
    self->action   = OWGetProperty(_config, @"action");
    self->pageName = OWGetProperty(_config, @"pageName");

    self->queryDictionary    = OWGetProperty(_config, @"queryDictionary");
    self->queryParameters    = OWExtractQueryParameters(_config);
    self->actionClass        = OWGetProperty(_config, @"actionClass");
    self->directActionName   = OWGetProperty(_config, @"directActionName");
    
    self->sidInUrl = (sidInUrlAssoc)
      ? [sidInUrlAssoc boolValueInComponent:nil]
      : YES;
  }
  return self;
}

- (void)dealloc {
  [self->actionClass      release];
  [self->directActionName release];
  [self->queryDictionary  release];
  [self->queryParameters  release];
  [self->action           release];
  [self->pageName         release];
  [super dealloc];
}

/* handle request */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id formValue;
  
  if (self->disabled != nil) {
    if ([self->disabled boolValueInComponent:[_ctx component]])
      return;
  }
  
  if ((formValue = [_rq formValueForKey:OWFormElementName(self, _ctx)])!=nil) {
    // [self debugWithFormat:@"%@: value=%@ ..", [self elementID], formValue];
    
    if (WOSubmitButtonEnableValueSync) {
      /*
        We need this because some associations (eg
        WOKeyPathAssociationSystemKVC) report "isValueSettable" as YES,
        but raise an exception afterwards.

        This section is disabled per default since its usually not required.
        
        See OGo bug #1568 for details.
      */
      if ([self->value isValueSettable])
        [self->value setStringValue:formValue inComponent:[_ctx component]];
    }
    
    if ((self->action != nil) || (self->pageName != nil))
      [_ctx addActiveFormElement:self];
  }
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (self->disabled != nil) {
    if ([self->disabled boolValueInComponent:[_ctx component]])
      return nil;
  }
  
  /* 
     check whether this is the active form element (determined in take-values) 
  */
  if (![[_ctx elementID] isEqualToString:[_ctx senderID]]) {
    NSLog(@"SUBMITBUTTON is not active (%@ vs %@) !",
          [_ctx elementID], [_ctx senderID]);
    return nil;
  }
  
  if (self->action != nil)
    return [self executeAction:self->action inContext:_ctx];

  if (self->pageName) {
    NSString    *pname = nil;
    WOComponent *page = nil;

    pname = [self->pageName stringValueInComponent:[_ctx component]];
    page = [[_ctx application] pageWithName:pname inContext:_ctx];

    if (page == nil) {
      [[_ctx session] logWithFormat:
                      @"%@[0x%p]: did not find page with name %@ !",
                      NSStringFromClass([self class]), self, pname];
    }
    [self logWithFormat:@"showing page %@", page];
    return page;
  }

  return nil;
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *v;
  
  if ([_ctx isRenderingDisabled]) return;

  v = [self->value stringValueInComponent:[_ctx component]];
  WOResponse_AddCString(_response, "<input type=\"submit\" name=\"");
  [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
  WOResponse_AddCString(_response, "\" value=\"");
  [_response appendContentHTMLAttributeValue:v];
  WOResponse_AddChar(_response, '"');
  
  if ([self->disabled boolValueInComponent:[_ctx component]])
    WOResponse_AddCString(_response, " disabled=\"disabled\"");
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString != nil) {
    v = [self->otherTagString stringValueInComponent:[_ctx component]];
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response, v);
  }
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;

  str = [NSMutableString stringWithCapacity:128];
  [str appendString:[super associationDescription]];
  
  if (self->action)   [str appendFormat:@" action=%@", self->action];
  if (self->pageName) [str appendFormat:@" page=%@",   self->pageName];
  
  if (self->actionClass)
    [str appendFormat:@" actionClass=%@", self->actionClass];
  if (self->directActionName)
    [str appendFormat:@" directAction=%@", self->directActionName];
  return str;
}

@end /* WOSubmitButton */
