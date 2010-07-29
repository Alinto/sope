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

/* 
   Q: Whats the difference to WORedirect?
   A: It is a dynamic element while WORedirect is a component.

   Note: you can also use the WOComponent -redirectToLocation: method.
*/

@interface WERedirect : WODynamicElement
{
  WOAssociation *setURL;
}
@end

#include "common.h"

@implementation WERedirect

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->setURL = WOExtGetProperty(_config, @"setURL");
  }
  return self;
}

- (void)dealloc {
  [self->setURL release];
  [super dealloc];
}

/* generating the response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  [_response setStatus:302];
  [_response setHeader:[self->setURL stringValueInComponent:[_ctx component]]
             forKey:@"location"];
}

@end /* WERedirect */
