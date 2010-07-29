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
#include "WOElement+private.h"

@interface WOSetCursor : WODynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOElement     *template;
  WOAssociation *object;
}

@end

#include "decommon.h"

@implementation WOSetCursor

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->object   = OWGetProperty(_config, @"object");
    self->template = RETAIN(_c);
    
    /* support 'value' ?, support 'expr' (string evaluated as script ?) */
  }
  return self;
}
- (void)dealloc {
  [self->template release];
  [self->object   release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id obj;
  
  obj = [[self->object valueInContext:_ctx] retain];
  [_ctx pushCursor:obj];
  
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
  
  [_ctx popCursor];
  [obj autorelease];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id result;
  id obj;
  
  obj = [[self->object valueInContext:_ctx] retain];
  [_ctx pushCursor:obj];
  
  result = [[self->template invokeActionForRequest:_rq inContext:_ctx] retain];
  
  [_ctx popCursor];
  [obj autorelease];
  return [result autorelease];
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  id obj;
  
  obj = [[self->object valueInContext:_ctx] retain];
  [_ctx pushCursor:obj];
  NSLog(@"pushed cursor: %@", obj);
  
  [self->template appendToResponse:_response inContext:_ctx];
  
  [_ctx popCursor];
  [obj autorelease];
}

@end /* WOSetCursor */
