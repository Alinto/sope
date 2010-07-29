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

#include <NGObjWeb/NGObjWeb.h>
#include "common.h"

@interface WOCollapsibleComponentContent : WODynamicElement
{
@protected
  WOAssociation *condition;
  WOAssociation *visibility;
  WOAssociation *openedImageFileName;
  WOAssociation *closedImageFileName;
  WOAssociation *framework;
  WOAssociation *openedLabel;
  WOAssociation *closedLabel;
  WOAssociation *submitActionName;

  WOElement *template;
}
@end

@interface WOContext(WOExtensionsPrivate)
- (void)addActiveFormElement:(WOElement *)_element;
@end

@implementation WOCollapsibleComponentContent

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_temp
{
  if ((self = [super initWithName:_name associations:_config template:_temp])) {
    self->condition           = WOExtGetProperty(_config, @"condition");
    self->visibility          = WOExtGetProperty(_config, @"visibility");
    self->openedImageFileName = 
      WOExtGetProperty(_config, @"openedImageFileName");
    self->closedImageFileName = 
      WOExtGetProperty(_config, @"closedImageFileName");
    self->framework           = WOExtGetProperty(_config, @"framework");
    self->openedLabel         = WOExtGetProperty(_config, @"openedLabel");
    self->closedLabel         = WOExtGetProperty(_config, @"closedLabel");
    self->submitActionName    = WOExtGetProperty(_config, @"submitActionName");

    if (WOExtGetProperty(_config, @"condition"))
      NSLog(@"WARNING: WOCollapsibleComponent does not support 'condition'");

    if (self->visibility == nil)
      NSLog(@"WARNING: WOCollapsibleComponent 'visibility' not set");

    if (self->visibility && ![self->visibility isValueSettable])
      NSLog(@"WARNING: WOCollapsibleComponent 'visibility' is not settable");

    ASSIGN(self->template, _temp);
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->condition);
  RELEASE(self->visibility);
  RELEASE(self->openedImageFileName);
  RELEASE(self->closedImageFileName);
  RELEASE(self->framework);
  RELEASE(self->openedLabel);
  RELEASE(self->closedLabel);
  RELEASE(self->submitActionName);

  RELEASE(self->template);
  
  [super dealloc];
}

// responder

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *eid;

  eid = [_ctx elementID];

  if ([self->visibility boolValueInComponent:[_ctx component]]) {
    [_ctx appendZeroElementIDComponent];
    [self->template takeValuesFromRequest:_request inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  
  if ([_request formValueForKey:[eid stringByAppendingString:@".c.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:[[_ctx senderID] stringByAppendingString:@".c"]];
  }
  else if ([_request formValueForKey:[eid stringByAppendingString:@".e.x"]]) {
    [_ctx addActiveFormElement:self];
    [_ctx setRequestSenderID:[[_ctx senderID] stringByAppendingString:@".e"]];
  }
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  NSString *state;
  NSString *eid;

  state = [[_ctx currentElementID] stringValue];

  eid = [_ctx elementID];

  if (state) {
    BOOL doForm;
    
    [_ctx consumeElementID]; // consume state-id (on or off)

    doForm = ([_ctx isInForm] && self->submitActionName);
    
    if ([state isEqualToString:@"e"]) {
      if ([self->visibility isValueSettable])
        [self->visibility setBoolValue:NO inComponent:[_ctx component]];
      if (doForm)
        [self->submitActionName valueInComponent:[_ctx component]];
    }
    else if ([state isEqualToString:@"c"]) {
      if ([self->visibility isValueSettable])
        [self->visibility setBoolValue:YES inComponent:[_ctx component]];
      if (doForm)
        [self->submitActionName valueInComponent:[_ctx component]];
    }
    else {
      id result;
      
      [_ctx appendElementIDComponent:state];
      result = [self->template invokeActionForRequest:_request inContext:_ctx];
      [_ctx deleteLastElementIDComponent];

      return result;
    }
  }
  return nil;
}

- (void)appendToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  BOOL        isCollapsed;
  BOOL        doForm;
  WOComponent *comp;
  NSString    *img;
  NSString    *label;
  
  comp = [_ctx component];

  if ([self->visibility valueInComponent:comp] == nil) {
    isCollapsed = ![self->condition boolValueInComponent:comp];
    if ([self->visibility isValueSettable])
      [self->visibility setBoolValue:!isCollapsed inComponent:comp];
  }
  else
    isCollapsed = ![self->visibility boolValueInComponent:comp];

  if ([_ctx isRenderingDisabled] && !isCollapsed) {
    [_ctx appendZeroElementIDComponent];
    [self->template appendToResponse:_resp inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
    return;
  }
  
  img = (isCollapsed)
    ? [self->closedImageFileName stringValueInComponent:comp]
    : [self->openedImageFileName stringValueInComponent:comp];

  label = (isCollapsed)
    ? [self->closedLabel stringValueInComponent:comp]
    : [self->openedLabel stringValueInComponent:comp];

  img = WOUriOfResource(img, _ctx);
  
  if (isCollapsed)
    [_resp appendContentString:@"&nbsp;"];

  doForm = ([_ctx isInForm] && self->submitActionName && img);

  [_ctx appendElementIDComponent:(isCollapsed) ? @"c" : @"e"];
  if (doForm) {
    [_resp appendContentString:@"<INPUT TYPE=\"image\" BORDER=\"0\" NAME=\""];
    [_resp appendContentString:[_ctx elementID]];
    [_resp appendContentString:@"\" SRC=\""];
    [_resp appendContentString:img];
    [_resp appendContentString:@"\">"];
  }
  else {
    [_resp appendContentString:@"<A HREF=\""];
    [_resp appendContentString:[_ctx componentActionURL]];
    [_resp appendContentString:@"\">"];

    if (img) {
      [_resp appendContentString:@"<IMG BORDER=0 SRC=\""];
      [_resp appendContentString:img];
      [_resp appendContentString:@"\""];
      if (label) {
        [_resp appendContentString:@" NAME=\""];
        [_resp appendContentString:label];
        [_resp appendContentString:@"\""];
      }
      [_resp appendContentString:@">"];
    }
    else
      [_resp appendContentString:(isCollapsed) ? @"[+]" : @"[-]"];
    [_resp appendContentString:@"</A>&nbsp;"];
  }
  
  if (label) {
    if (!doForm) {
      [_resp appendContentString:@"<A HREF=\""];
      [_resp appendContentString:[_ctx componentActionURL]];
      [_resp appendContentString:@"\">"];
    }
    
    [_resp appendContentString:label];

    if (!doForm)
      [_resp appendContentString:@"</A>"];
  }
  [_ctx deleteLastElementIDComponent];
  
  [_resp appendContentString:@"<BR>"];
  
  if (!isCollapsed) {
    [_ctx appendZeroElementIDComponent];
    [self->template appendToResponse:_resp inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
}

@end /* WOComponentContent */
