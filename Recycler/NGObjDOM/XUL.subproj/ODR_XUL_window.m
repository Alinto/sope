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

#include "ODR_XUL_box.h"

/*
  http://www.xulplanet.com/tutorials/xultu/elemref/ref_window.html
*/

@interface ODR_XUL_window : ODR_XUL_box
@end

#include <DOM/DOM.h>
#include "common.h"
#include "ODNamespaces.h"

@implementation ODR_XUL_window

- (void)appendNode:(id)_node
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *title;
  
  title = [self stringFor:@"title" node:_node ctx:_ctx];

  if ([title length] > 0) {
    [_response appendContentString:@"<table border='1' width='100%'>"];
    [_response appendContentString:@"<tr><th>"];
    [_response appendContentHTMLString:title];
    [_response appendContentString:@"</th></tr>"];
    [_response appendContentString:@"<tr><td width='100%'>"];
  }
  
  [super appendNode:_node
         toResponse:_response
         inContext:_ctx];

  if ([title length] > 0)
    [_response appendContentString:@"&nbsp;</td></tr></table>"];
}

@end /* ODR_XUL_window */
