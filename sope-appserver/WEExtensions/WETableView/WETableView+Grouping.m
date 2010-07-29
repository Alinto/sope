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

#include "WETableView+Grouping.h"
#include "WETableView.h"
#include "common.h"

@implementation WETableView(Grouping)

- (id)invokeGrouping:(WORequest *)_request inContext:(WOContext *)_ctx {
  NSString *stateId;

  if ((stateId = [[_ctx currentElementID] stringValue]) == nil)
    return nil;
  
  if ([stateId isEqualToString:@"e"]) {
    if ([self->showGroup isValueSettable])
      [self->showGroup setBoolValue:NO inComponent:[_ctx component]];
    return nil;
  }
  else if ([stateId isEqualToString:@"c"]) {
    if ([self->showGroup isValueSettable])
      [self->showGroup setBoolValue:YES inComponent:[_ctx component]];
    return nil;
  }
  
  return [self->template invokeActionForRequest:_request inContext:_ctx];
}

- (void)_appendGroupTitle:(WOResponse *)_response
  inContext:(WOContext *)_ctx
  infos:(NSMutableArray *)_infos
  actionUrl:(NSString *)_actionUrl
  rowSpan:(unsigned)_rowSpan
  groupId:(NSString *)_groupId
{
  NSString    *bgcolor;
  BOOL        isCollapsed;
  WOComponent *comp;
  NSString    *img;
  int         colspan;
  unsigned char buf[16];
  
  comp = [_ctx component];

  [_ctx removeObjectForKey:WETableView_INFOS];
  colspan  = [_infos count] - 2;
  colspan += (self->state->doCheckBoxes) ? 1 : 0;

  isCollapsed = ![self->showGroup boolValueInComponent:comp];
  
  [_response appendContentString:@"<tr><td colspan=\""];
  sprintf((char *)buf, "%d", colspan);
  [_response appendContentCString:buf];
  [_response appendContentCharacter:'"'];
  
  if ((bgcolor = [self->groupColor stringValueInComponent:comp])) {
    [_response appendContentString:@" bgcolor=\""];
    [_response appendContentString:bgcolor];
    [_response appendContentCharacter:'"'];
  }
  [_response appendContentString:@"width=\"1%\">"];
      
  [_ctx setObject:@"Yes" forKey:WETableView_GroupMode];
  
  img = (!isCollapsed)
    ? [self->groupOpenedIcon stringValueInComponent:comp]
    : [self->groupClosedIcon stringValueInComponent:comp];

  img = WEUriOfResource(img, _ctx);
  
  [_ctx appendElementIDComponent:(isCollapsed) ? @"c" : @"e"];

  if (!self->state->doScriptCollapsing) {
    [_response appendContentString:@"<a href=\""];
    [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentString:@"\">"];
  }

  if (img) {
    [_response appendContentString:@"<img border=\"0\" src=\""];
    [_response appendContentString:img];
    [_response appendContentCharacter:'"'];
    if (self->state->doScriptCollapsing) {
      NSString *openImg;
      NSString *closeImg;

      openImg  = [self->groupOpenedIcon stringValueInComponent:comp];
      closeImg = [self->groupClosedIcon stringValueInComponent:comp];

      openImg  = WEUriOfResource(openImg, _ctx);
      closeImg = WEUriOfResource(closeImg, _ctx);

      openImg  = (openImg) ? openImg : closeImg;
      closeImg = (closeImg) ? closeImg : openImg;
      
      [_response appendContentString:@" onClick=\"toggleTableGroup();\""];
      [_response appendContentString:@" group=\""];
      [_response appendContentString:_groupId];
      [_response appendContentString:@"\" openImg=\""];
      [_response appendContentString:openImg];
      [_response appendContentString:@"\" closeImg=\""];
      [_response appendContentString:closeImg];
      [_response appendContentCharacter:'"'];
      if (isCollapsed)
        [_response appendContentString:@" isGroupVisible=\"none\""];
      else
        [_response appendContentString:@" isGroupVisible=\"\""];
    }
    [_response appendContentString:@">"];
  }
  else
    [_response appendContentString:(isCollapsed) ? @"[+]" : @"[-]"];
  if (!self->state->doScriptCollapsing)
    [_response appendContentString:@"</a>&nbsp;"];

  [_ctx deleteLastElementIDComponent];

  if ([self->groups isValueSettable]) {
    NSAssert(([_infos count] > 1), @"info count must be at least 2");
    [self->groups setValue:[_infos objectAtIndex:[_infos count]-1]
               inComponent:comp];
  }
  
  [_ctx setObject:@"YES" forKey:WETableView_GroupMode];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx removeObjectForKey:WETableView_GroupMode];

  [_response appendContentString:@"</td>"];

  if (_rowSpan) {
    [self _appendBatchResizeButtons:_response
                            rowSpan:_rowSpan
                          actionUrl:_actionUrl
                          inContext:_ctx];
  }
  [_response appendContentString:@"</tr>"];
  [_infos removeLastObject]; // groups
  [_infos removeLastObject]; // WETableView_GroupMode
}

@end /* WOComponentContent */
