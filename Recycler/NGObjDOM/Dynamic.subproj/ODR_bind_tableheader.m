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

#include "ODR_bind_tablecell.h"

@interface ODR_bind_th : ODR_bind_tablecell
{
}
@end /* ODR_bind_th */

#include "ODR_bind_tableview.h"
#include "common.h"

@implementation ODR_bind_th

- (void)appendNode:(id)_node
        toResponse:(WOResponse *)_response
        inContext:(WOContext *)_ctx
{
  if ([[_ctx objectForKey:ODRTableView_HeaderMode] boolValue]) {
    NSString *bg  = nil;

    bg  = [self stringFor:@"bgColor" node:_node ctx:_ctx];

    if (!bg)
      bg = [_ctx objectForKey:ODRTableView_headerColor];
  
    [_response appendContentString:@"<td"];
    if (bg) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:bg];
      [_response appendContentCharacter:'"'];
    }

    [_response appendContentString:@"><nobr>"];
    [self appendSortIcon:_node toResponse:_response inContext:_ctx];
    [self appendTitle:_node toResponse:_response inContext:_ctx];
    [self appendChildNodes:[_node childNodes]
          toResponse:_response
          inContext:_ctx];
  
    [_response appendContentString:@"</nobr>"];
    [_response appendContentString:@"</td>\n"];
  }
}

@end /* ODR_bind_th */


