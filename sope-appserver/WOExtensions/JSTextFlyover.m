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

@interface JSTextFlyover : WODynamicElement
{
  WOAssociation *action;
  WOAssociation *pageName;
  WOAssociation *selectedColor;
  WOAssociation *unselectedColor;
  WOAssociation *targetWindow;
  /* additional, not in api */
  WOAssociation *string;
  
  WOElement     *template;
}

@end

#include "common.h"

@implementation JSTextFlyover

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])){
    self->action             = WOExtGetProperty(_config,@"action");
    self->pageName           = WOExtGetProperty(_config,@"pageName");
    self->selectedColor      = WOExtGetProperty(_config,@"selectedColor");
    self->unselectedColor    = WOExtGetProperty(_config,@"unselectedColor");
    self->targetWindow       = WOExtGetProperty(_config,@"targetWindow");
    self->string             = WOExtGetProperty(_config,@"string");
    
    if ((self->action) && (self->pageName)) 
      NSLog(@"WARNING: JSTextFlyover: choose only one of "
            @"action | pageName ");
    if (!((self->action) || (self->pageName)))
      NSLog(@"WARNING: JSTextFlyover: no function declared - choose one of"
            @"action | pageName | javaScriptFunction");
    if (!self->selectedColor)
      NSLog(@"WARNING: JSTextFlyover: no value for 'selectedColor'");
    if (!self->unselectedColor)
      NSLog(@"WARNING: JSTextFlyover: no value for 'unselectedColor'");

    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->action          release];
  [self->pageName        release];
  [self->selectedColor   release];
  [self->unselectedColor release];
  [self->targetWindow    release];
  [self->string          release];
  [self->template        release];
  [super dealloc];
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if (self->pageName) {
    NSString *name;
    
    name = [self->pageName stringValueInComponent: [_ctx component]];
    return [[_ctx application] pageWithName:name inContext:_ctx];
  }
  if (self->action)
    return [self->action valueInComponent:[_ctx component]];

  return [self->template invokeActionForRequest:_request inContext:_ctx];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *comp;
  NSString    *tmp;
  NSString    *userAgent;
  NSString    *normalColor;
  NSString    *rollColor;
  NSString    *obj;
  NSRange     r;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  comp        = [_ctx component];
  userAgent   = [[_ctx request] headerForKey:@"user-agent"];
  normalColor = [self->unselectedColor stringValueInComponent:comp];
  rollColor   = [self->selectedColor   stringValueInComponent:comp];
  
  /* link containing onMouseOver, onMouseOut, STYLE and HREF */
  r = [userAgent rangeOfString: @"MSIE"];
  obj = (r.length == 0)
    ? @"this.textcolor"
    : @"this.style.color";
  [_response appendContentString:@"<a onmouseover=\""];
  tmp = [[NSString alloc] initWithFormat:@"%@='%@'",obj,rollColor];
  [_response appendContentString:tmp];
  [tmp release];
  [_response appendContentString:@"\" onmouseout=\""];
  tmp = [[NSString alloc] initWithFormat:@"%@='%@'",obj,normalColor];
  [_response appendContentString:tmp];
  [tmp release];

  [_response appendContentString:@"\" style=\"color: "];
  [_response appendContentString:normalColor];
  [_response appendContentString:@"\" "];

  [_response appendContentString:@" href=\""];
  [_response appendContentString:[_ctx componentActionURL]];
  [_response appendContentString:@"\" "];

  if (self->targetWindow) {
    [_response appendContentString:@" target=\""];
    [_response appendContentHTMLAttributeValue:
                 [self->targetWindow stringValueInComponent: comp]];
    [_response appendContentString:@"\" "];
  }
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  [_response appendContentString:@" >"];

  /* text itself */
  [self->template appendToResponse:_response inContext:_ctx];
  if (self->string)
    [_response appendContentString:[self->string stringValueInComponent:comp]];

  /* close link */
  [_response appendContentString:@"</a>"];
}

@end /* JSTextFlyover */
