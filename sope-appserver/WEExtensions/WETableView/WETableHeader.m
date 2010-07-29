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

#include "WETableCell.h"

@interface WETableHeader : WETableCell
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
}

@end /* WETableHeader */

#include "WETableView.h"
#include "common.h"

@implementation WETableHeader

/* responder */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  if ([[_ctx objectForKey:WETableView_HeaderMode] boolValue]) {
    WOComponent *cmp = nil;
    NSString    *bg  = nil;

    cmp = [_ctx component];
    bg  = [self->bgColor stringValueInComponent:cmp];

    if (!bg)
      bg = [_ctx objectForKey:WETableView_headerColor];
  
    [_response appendContentString:@"<td"];
    if (bg) {
      [_response appendContentString:@" bgcolor=\""];
      [_response appendContentString:bg];
      [_response appendContentCharacter:'"'];
    }
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    if (self->otherTagString) {
      [_response appendContentCharacter:' '];
      [_response appendContentString:
            [self->otherTagString stringValueInComponent:[_ctx component]]];
    }
    [_response appendContentString:@"><nobr>"];
    [self appendSortIcon:_response inContext:_ctx];
    [self->template appendToResponse:_response inContext:_ctx];
  
    [_response appendContentString:@"</nobr>"];
    [_response appendContentString:@"</td>\n"];
  }
}

@end /* WETableHeader */
