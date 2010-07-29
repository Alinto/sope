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

@interface WOCheckBox : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // inherited: name
  // inherited: value
  // inherited: disabled
@protected
  WOAssociation *selection;
  WOAssociation *checked;
}

@end /* WOCheckBox */

@implementation WOCheckBox

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->selection = OWGetProperty(_config, @"selection");
    self->checked   = OWGetProperty(_config, @"checked");
  }
  return self;
}

- (void)dealloc {
  [self->selection release];
  [self->checked   release];
  [super dealloc];
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  /*
    Checkboxes are special in their form-value handling. If the form is
    submitted and the checkbox is checked, a 'YES' value is transferred in the
    request. If the checkbox is not-checked, no value is transferred at all !
  */
  id formValue;
  
  if ([self->disabled boolValueInComponent:[_ctx component]])
    return;

  formValue = [_rq formValueForKey:OWFormElementName(self, _ctx)];
    
  if ([self->checked isValueSettable]) {
      [self->checked setBoolValue:formValue ? YES : NO
                     inComponent:[_ctx component]];
  }
  
  if ([self->value isValueSettable] && (formValue != nil))
    [self->value setStringValue:formValue inComponent:[_ctx component]];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *v;
  BOOL     isChecked;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  v         = [self->value   stringValueInComponent:[_ctx component]];
  isChecked = [self->checked boolValueInComponent:[_ctx component]];
    
  WOResponse_AddCString(_response, "<input type=\"checkbox\" name=\"");
  [_response appendContentHTMLAttributeValue:
	       OWFormElementName(self, _ctx)];
  WOResponse_AddCString(_response, "\" value=\"");
  [_response appendContentHTMLAttributeValue:
	       ([v isNotEmpty] ? v : (NSString *)@"1")];
  WOResponse_AddCString(_response, "\"");
  
  if ([self->disabled boolValueInComponent:[_ctx component]]) {
    WOResponse_AddCString(_response,
			  (_ctx->wcFlags.allowEmptyAttributes
			   ? " disabled" : " disabled=\"disabled\""));
  }
  
  if (isChecked) {
    WOResponse_AddCString(_response,
			  (_ctx->wcFlags.allowEmptyAttributes 
			   ? " checked" : " checked=\"checked\""));
  }
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  
  if (self->otherTagString != nil) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
			 [self->otherTagString stringValueInComponent:
				[_ctx component]]);
  }
  
  if (_ctx->wcFlags.xmlStyleEmptyElements) {
    WOResponse_AddCString(_response, " />");
  }
  else {
    WOResponse_AddCString(_response, ">");
  }
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = nil;
  str = [[NSMutableString alloc]
                          initWithString:[super associationDescription]];

  if (self->selection) [str appendFormat:@" selection=%@", self->selection];
  if (self->checked)   [str appendFormat:@" checked=%@", self->checked];

  return [str autorelease];
}

@end /* WOCheckBox */
