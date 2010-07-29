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

@interface WOHiddenField : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // WOInput:    name
  // WOInput:    value
  // WOInput:    disabled
}

@end /* WOHiddenField */

#include "decommon.h"

@implementation WOHiddenField

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *v;
  BOOL isDisabled;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  isDisabled = [self->disabled boolValueInComponent:[_ctx component]];
    
  if (isDisabled) {
    // TODO: this is correct for a _hidden_?
    v = [self->value stringValueInComponent:[_ctx component]];
    [_response appendContentHTMLString:v];
    return;
  }
  
  v = [self->value stringValueInComponent:[_ctx component]];
  
  WOResponse_AddCString(_response, "<input type=\"hidden\" name=\"");
  [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
  WOResponse_AddCString(_response, "\" value=\"");
  [_response appendContentHTMLAttributeValue:v];
  WOResponse_AddChar(_response, '"');
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString != nil) {
        WOResponse_AddChar(_response, ' ');
        WOResponse_AddString(_response,
                             [self->otherTagString stringValueInComponent:
                                  [_ctx component]]);
  }
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

@end /* WOHiddenField */
