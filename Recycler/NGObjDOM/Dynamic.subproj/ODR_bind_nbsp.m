/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include <NGObjDOM/ODNodeRenderer.h>

/*
   attributes:
     -

   usage:
     <nbsp/>
*/

@interface ODR_bind_nbsp : ODNodeRenderer
@end

#include <DOM/DOM.h>
#include "common.h"

@implementation ODR_bind_nbsp

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  [_response appendContentString:@"&nbsp;"];
  [super appendNode:_node toResponse:_response inContext:_ctx];
}

@end /* ODR_bind_nsbp */
