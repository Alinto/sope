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

#include <NGObjWeb/WOHTMLDynamicElement.h>

@class WOAssociation;

@interface WOHtml : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOElement *template;
}
@end

#include "WOElement+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include "decommon.h"

@implementation WOHtml

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->template = [_c retain];
  }
  return self;
}

- (void)dealloc {
  [self->template release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_req inContext:_ctx];
}
- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_req inContext:_ctx];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  BOOL doRender = !([_ctx isRenderingDisabled] ||
                    [[_ctx request] isFromClientComponent]);
  
  if (doRender)
    WOResponse_AddCString(_response, "<html>");
  [self->template appendToResponse:_response inContext:_ctx];
  if (doRender)
    WOResponse_AddCString(_response, "</html>");
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:128];
  if (self->template)  [str appendFormat:@" template=%@",  self->template];
  return str;
}

@end /* WOHtml */
