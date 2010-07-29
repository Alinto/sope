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

/*
  WETreeHeader

  Take a look at WETreeView for more information.

  WETreeHeader associations:
    isTreeElement
    icon
    cornerIcon
    title
    string

  Example:
      TreeHeaderCell: WETreeHeader {
        isTreeElement = YES;
      }
      HeaderCell: WETreeHeader {
        isTreeElement = NO;
      }
*/

#include <NGObjWeb/WODynamicElement.h>

@interface WETreeHeader : WODynamicElement
{
@protected
  WOAssociation  *isTreeElement;
  WOElement      *template;
  WOAssociation  *string;
}
@end

#include "WETreeContextKeys.h"
#include "common.h"

@implementation WETreeHeader

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self=[super initWithName:_name associations:_config template:_subs])) {
    self->isTreeElement = WOExtGetProperty(_config, @"isTreeElement");
    self->string        = WOExtGetProperty(_config, @"string");
    
    self->template      = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->string        release];
  [self->isTreeElement release];
  [self->template      release];
  [super dealloc];
}

/* request processing */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_rq inContext:_ctx];
}

/* response generation */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *content;
  BOOL isTree;
  BOOL doTable;

  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  if (![_ctx objectForKey:WETreeView_HEADER_MODE])
    return;
    
  isTree  = [self->isTreeElement boolValueInComponent:[_ctx component]];
  doTable = ([_ctx objectForKey:WETreeView_RenderNoTable] == nil);
  content = [self->string        stringValueInComponent:[_ctx component]];
    
  if (doTable) {
    [_response appendContentString:@"<td"];
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    if (self->otherTagString) {
      [_response appendContentCharacter:' '];
      [_response appendContentString:
                 [self->otherTagString stringValueInComponent:
                      [_ctx component]]];
    }
    if (isTree) {
      [_response appendContentString:@" colspan=\""];
      [_response appendContentString:
                 [[_ctx objectForKey:WETreeView_HEADER_MODE] stringValue]];
      [_response appendContentString:@"\"><nobr>"];
    }
    else
      [_response appendContentString:@"><nobr>"];
  }
    
  /* add cell content */
  [self->template appendToResponse:_response inContext:_ctx];
  if (content)
    [_response appendContentHTMLString:content];

  if (doTable)
    [_response appendContentString:@"</nobr></td>"];
}

@end /* WETreeHeader */
