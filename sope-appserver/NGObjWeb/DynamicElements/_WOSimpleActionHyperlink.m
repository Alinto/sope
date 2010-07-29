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

#include "WOHyperlink.h"

/*
  Class Hierachy
    [WOHTMLDynamicElement]
      [WOHyperlink]
        _WOSimpleActionHyperlink
          _WOSimpleStringActionHyperlink
*/

@interface _WOSimpleActionHyperlink : WOHyperlink
{
  WOAssociation *action;
  WOElement     *template;
}
@end /* _WOSimpleActionHyperlink */

@interface _WOSimpleStringActionHyperlink : _WOSimpleActionHyperlink
{
  WOAssociation *string;
}
@end /* _WOSimpleStringActionHyperlink */

#include "WOHyperlinkInfo.h"
#include "WOElement+private.h"
#include <NGObjWeb/WOAssociation.h>
#include "decommon.h"

@implementation _WOSimpleActionHyperlink

+ (int)version {
  return [super version] + 0 /* v4 */;
}
+ (void)initialize {
  NSAssert2([super version] == 4,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithName:(NSString *)_name
  hyperlinkInfo:(WOHyperlinkInfo *)_info
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name hyperlinkInfo:_info template:_t])) {
    self->template     = RETAIN(_t);
    self->containsForm = NO;
    self->action       = _info->action;
#if DEBUG
    NSAssert(self->action, @"missing action ?!");
#endif
  }
  return self;
}

- (void)dealloc {
  [self->template release];
  [self->action   release];
  [super dealloc];
}

/* dynamic invocation */

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if (![[_ctx elementID] isEqualToString:[_ctx senderID]]) {
    /* link is not the active element */
#if DEBUG
    NSLog(@"HYPERLINK is not active (%@ vs %@) !",
          [_ctx elementID], [_ctx senderID]);
#endif
    return [self->template invokeActionForRequest:_request inContext:_ctx];
  }
  
  //NSLog(@"%s: invoke called ...", __PRETTY_FUNCTION__);
  
  /* link is active */
  return [self executeAction:self->action inContext:_ctx];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if ([[_ctx request] isFromClientComponent])
    return;
  
  WOResponse_AddCString(_response, "<a href=\"");
  WOResponse_AddString(_response, [_ctx componentActionURL]);
  
  [_response appendContentCharacter:'"'];
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                              [_ctx component]]);
  }
  [_response appendContentCharacter:'>'];
  
  /* content */
  [self->template appendToResponse:_response inContext:_ctx];
  
  /* closing tag */
  WOResponse_AddCString(_response, "</a>");
}

/* description */

- (NSString *)associationDescription {
  return [NSString stringWithFormat:@"action=%@", self->action];
}

@end /* _WOSimpleActionHyperlink */

@implementation _WOSimpleStringActionHyperlink

- (id)initWithName:(NSString *)_name
  hyperlinkInfo:(WOHyperlinkInfo *)_info
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name hyperlinkInfo:_info template:_t])) {
    self->string = _info->string;
  }
  return self;
}

- (void)dealloc {
  [self->string release];
  [super dealloc];
}

/* HTML generation */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString *content;

  if ([[_ctx request] isFromClientComponent])
    return;
  
  sComponent = [_ctx component];
  content = [self->string stringValueInComponent:sComponent];
    
  WOResponse_AddCString(_response, "<a href=\"");
  WOResponse_AddString(_response, [_ctx componentActionURL]);
    
  [_response appendContentCharacter:'"'];
    
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                              sComponent]);
  }
  [_response appendContentCharacter:'>'];
    
  /* content */
  [self->template appendToResponse:_response inContext:_ctx];
  if (content) [_response appendContentHTMLString:content];

  /* closing tag */
  WOResponse_AddCString(_response, "</a>");
}

/* description */

- (NSString *)associationDescription {
  return [NSString stringWithFormat:@"action=%@, string=%@",
                     self->action, self->string];
}

@end /* _WOSimpleStringActionHyperlink */
