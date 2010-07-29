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
#include "decommon.h"

@interface WORadioButton : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // WOInput:    name
  // WOInput:    value
  // WOInput:    disabled
@protected
  WOAssociation *selection;
  WOAssociation *checked;
}

@end /* WORadioButton */

@implementation WORadioButton

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t 
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->selection = OWGetProperty(_config, @"selection");
    self->checked   = OWGetProperty(_config, @"checked");
    
    if ((self->checked != nil) && (self->value != nil)) {
      NSLog(@"WARNING: specified both, 'checked' and 'value', "
            @"associations for radio button!");
    }
  }
  return self;
}

- (void)dealloc {
  [self->selection release];
  [self->checked   release];
  [super dealloc];
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  id formValue;
  
  sComponent = [_ctx component];
  if ([self->disabled boolValueInComponent:sComponent])
    return;
  
  // TODO: this seems to have issues

  // TODO: when a page is called with GET, this overwrites the selection!
  //       - so we should probably only push the value for POST?
  
  formValue = [_req formValueForKey:OWFormElementName(self, _ctx)];
  
#warning FIXME, radio button form handling
  
  if (self->checked != nil) {
    // TODO: check needs element-ids?
    if ([self->checked isValueSettable]) {
      // TODO: this only checks element-IDs! In case a value is assigned, it
      //       must check the value
      [self->checked setBoolValue:[formValue isEqual:[_ctx elementID]]
                     inComponent:sComponent];
    }
  }
  
  /*
    TODO
    
    This needs to check the value and compare it with the value of the form,
    otherwise all radio elements will push the value, multiple times because
    radio buttons always have the same name!

    Note that the actual result is usually OK, because all elements push the
    _same_ value, the one from the form, not their own.
  */
  if ([self->selection isValueSettable])
    [self->selection setValue:formValue inComponent:sComponent];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString *lvalue;
  
  if ([_ctx isRenderingDisabled]) return;

  sComponent = [_ctx component];
  lvalue = self->checked
    ? [_ctx elementID]
    : [self->value stringValueInComponent:sComponent];
  
  WOResponse_AddCString(_response, "<input type=\"radio\" name=\"");
  [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
  WOResponse_AddCString(_response, "\" value=\"");
  [_response appendContentHTMLAttributeValue:lvalue];
  WOResponse_AddCString(_response, "\"");
  
  if (self->checked != nil) {
    if ([self->checked boolValueInComponent:sComponent]) {
      WOResponse_AddCString(_response, 
			    (_ctx->wcFlags.allowEmptyAttributes 
			     ? " checked" : " checked=\"checked\""));
    }
  }
  else {
    id v, sel;
    
    v   = [self->value     valueInComponent:sComponent];
    sel = [self->selection valueInComponent:sComponent];
    if ((v == sel) || [v isEqual:sel]) {
      WOResponse_AddCString(_response, 
			    (_ctx->wcFlags.allowEmptyAttributes 
			     ? " checked" : " checked=\"checked\""));
    }
  }
  
  if ([self->disabled boolValueInComponent:sComponent]) {
    WOResponse_AddCString(_response, 
			  (_ctx->wcFlags.allowEmptyAttributes
			   ? " disabled" : " disabled=\"disabled\""));
  }
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString != nil) {
    lvalue = [self->otherTagString stringValueInComponent:sComponent];
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response, lvalue);
  }
  
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = nil;
  
  str = [[[super associationDescription] mutableCopy] autorelease];
  if (self->selection) [str appendFormat:@" selection=%@", self->selection];
  if (self->checked)   [str appendFormat:@" checked=%@", self->checked];
  return str;
}

@end /* WORadioButton */
