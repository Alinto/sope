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

#include "WOGenericElement.h"

@interface WOGenericContainer : WOGenericElement
{
  // WODynamicElement:   extraAttributes
  // WODynamicElement:   otherTagString
  // WOGenericContainer: tagName
@protected
  WOElement *template;
}

@end

#include "WOElement+private.h"
#include "decommon.h"

// TODO(perf): ASCII Tags (appendContentCString)
// TODO(perf): constant tags

#define TagNameType_Assoc  0
#define TagNameType_String 1
#define TagNameType_ASCII  2

@implementation WOGenericContainer

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

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString    *tag;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  sComponent = [_ctx component];
  switch (self->tagNameType) {
    case TagNameType_Assoc:
      if ((tag = [(id)self->tagName stringValueInComponent:sComponent]) == nil)
        tag = @"p";
      break;
    case TagNameType_String:
      if ((tag = self->tagName) == nil) tag = @"p";
      break;
    case TagNameType_ASCII:
    default:
      tag = nil;
      break;
  }
  
  WOResponse_AddChar(_response, '<');
  if (tag) {
    WOResponse_AddString(_response, tag);
  }
  else if (self->tagNameType == TagNameType_ASCII) {
    WOResponse_AddCString(_response, self->tagName);
  }
  
  [self _appendAttributesToResponse:_response inContext:_ctx];
  
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                           sComponent]);
  }
  WOResponse_AddChar(_response, '>');
  
  [self->template appendToResponse:_response inContext:_ctx];
  
  WOResponse_AddCString(_response, "</");
  if (tag) {
    WOResponse_AddString(_response, tag);
  }
  else if (self->tagNameType == TagNameType_ASCII) {
    WOResponse_AddCString(_response, self->tagName);
  }
  WOResponse_AddChar(_response, '>');
}

@end /* WOGenericContainer */
