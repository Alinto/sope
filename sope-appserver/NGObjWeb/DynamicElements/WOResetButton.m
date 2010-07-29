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
#include "WOElement+private.h"
#include "decommon.h"

@interface WOResetButton : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // WOInput:    name
  // WOInput:    value
  // WOInput:    disabled
}

@end /* WOResetButton */

@implementation WOResetButton

// ******************** responder ********************

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *v;

  if ([_ctx isRenderingDisabled]) return;

  v = [self->value stringValueInComponent:[_ctx component]];

  if ((self->name != nil) || (self->disabled != nil)) {
    [self warnWithFormat:@"'name' and 'disabled' properties are "
                         @"not supported in WOResetButton !"];
  }

  WOResponse_AddCString(_response, "<input type=\"reset\" value=\"");
  [_response appendContentHTMLAttributeValue:v];
  WOResponse_AddChar(_response, '"');
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                              [_ctx component]]);
  }
  
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

@end /* WOResetButton */
