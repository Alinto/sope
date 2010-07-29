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

@interface WOPasswordField : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // WOInput:    name
  // WOInput:    value
  // WOInput:    disabled
@protected
  // non WO:
  WOAssociation *size;
}

@end /* WOPasswordField */

@implementation WOPasswordField

- (id)initWithName:(NSString *)_name associations:(NSDictionary *)_a
  template:(WOElement *)_root
{
  if ((self = [super initWithName:_name associations:_a template:_root])) {
    self->size = OWGetProperty(_a, @"size");
  }
  return self;
}

- (void)dealloc {
  [self->size release];
  [super dealloc];
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString     *v;
  unsigned int s;
  
  if ([_ctx isRenderingDisabled]) return;

  v = [self->value stringValueInComponent:[_ctx component]];
  s = [self->size  unsignedIntValueInComponent:[_ctx component]];
  
  WOResponse_AddCString(_response, "<input type=\"password\" name=\"");
  [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
  WOResponse_AddCString(_response, "\" value=\"");
  [_response appendContentHTMLAttributeValue:v];
  [_response appendContentCharacter:'"'];
  
  if (s > 0) {
    WOResponse_AddCString(_response, " size=\"");
    WOResponse_AddUInt(_response, s);
    [_response appendContentCharacter:'"'];
  }
  
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
  NSMutableString *str = nil;
  
  str = [NSMutableString stringWithCapacity:128];
  [str appendString:[super associationDescription]];
  
  if (self->size) [str appendFormat:@" size=%@", self->size];
  
  return str;
}

@end /* WOPasswordField */
