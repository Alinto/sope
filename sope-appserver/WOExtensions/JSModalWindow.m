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

@interface JSModalWindow : WODynamicElement
{
  WOAssociation *action;
  WOAssociation *pageName;
  WOAssociation *href;      /* non - WO API */
  
  WOAssociation *height;
  WOAssociation *width;
  WOAssociation *windowName;
  WOAssociation *isResizable;
  WOAssociation *showLocation;
  WOAssociation *showMenuBar;
  WOAssociation *showScrollbars;
  WOAssociation *showStatus;
  WOAssociation *showToolbar;

  /* non - WO API */
  WOAssociation *top;
  WOAssociation *left;
  WOAssociation *isCenter;
  WOAssociation *filename;
  WOAssociation *string;
  WOAssociation *framework;
  
  WOElement     *template;
}

@end

#include "common.h"

@implementation JSModalWindow

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
    int funcCount;

    self->action             = WOExtGetProperty(_config, @"action");
    self->pageName           = WOExtGetProperty(_config, @"pageName");
    self->href               = WOExtGetProperty(_config, @"href");
    
    self->height             = WOExtGetProperty(_config, @"height");
    self->width              = WOExtGetProperty(_config, @"width");
    self->windowName         = WOExtGetProperty(_config, @"windowName");
    self->isResizable        = WOExtGetProperty(_config, @"isResizable");
    self->showLocation       = WOExtGetProperty(_config, @"showLocation");
    self->showMenuBar        = WOExtGetProperty(_config, @"showMenuBar");
    self->showScrollbars     = WOExtGetProperty(_config, @"showScrollbars");
    self->showStatus         = WOExtGetProperty(_config, @"showStatus");
    self->showToolbar        = WOExtGetProperty(_config, @"showToolbar");

    self->top                = WOExtGetProperty(_config, @"top");
    self->left               = WOExtGetProperty(_config, @"left");
    self->isCenter           = WOExtGetProperty(_config, @"isCenter");
    self->filename           = WOExtGetProperty(_config, @"filename");
    self->string             = WOExtGetProperty(_config, @"string");
    self->framework          = WOExtGetProperty(_config, @"framework");

    funcCount = 0;
    if (self->action)   funcCount++;
    if (self->pageName) funcCount++;
    if (self->href)     funcCount++;

    if (funcCount > 1)
      NSLog(@"WARNING: JSModalWindow: choose only one of "
            @"action | pageName | href");
    if (funcCount < 1)
      NSLog(@"WARNING: JSModalWindow: no function declared - choose one of"
            @"action | pageName | href");

#define SetAssociationValue(_assoc_, _value_)                               \
             if (_assoc_ == nil) {                                          \
               _assoc_ = [WOAssociation associationWithValue:_value_];      \
               [_assoc_ retain];                                            \
             }                                                              \

    SetAssociationValue(self->height,         @"300");
    SetAssociationValue(self->width,          @"300");
    SetAssociationValue(self->isResizable,    @"Yes");
    SetAssociationValue(self->showLocation,   @"Yes");
    SetAssociationValue(self->showMenuBar,    @"Yes");
    SetAssociationValue(self->showScrollbars, @"Yes");
    SetAssociationValue(self->showStatus,     @"Yes");
    SetAssociationValue(self->showToolbar,    @"Yes");
    SetAssociationValue(self->top,            @"500");
    SetAssociationValue(self->left,           @"500");

#undef SetAssociationValue

    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->action   release];
  [self->pageName release];
  [self->href     release];
  
  [self->height         release];
  [self->width          release];
  [self->windowName     release];
  [self->isResizable    release];
  [self->showLocation   release];
  [self->showMenuBar    release];
  [self->showScrollbars release];
  [self->showStatus     release];
  [self->showToolbar    release];

  [self->top       release];
  [self->left      release];
  [self->isCenter  release];
  [self->filename  release];
  [self->string    release];
  [self->framework release];
  
  [self->template release];
  [super dealloc];
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (self->pageName != nil) {
    NSString *name;
    
    name = [self->pageName stringValueInComponent: [_ctx component]];
    return [[_ctx application] pageWithName:name inContext:_ctx];
  }
  
  if (self->action != nil)
    return [self->action valueInComponent:[_ctx component]];

  return [self->template invokeActionForRequest:_rq inContext:_ctx];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOComponent *comp;
  NSString    *tmp;
  NSArray     *languages;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_resp inContext:_ctx];
    return;
  }
  
  comp = [_ctx component];
  
  // link
  [_resp appendContentString:
             @"<a onclick=\"window.showModalDialog('"];
  if (self->href != nil)
    [_resp appendContentString:[self->href stringValueInComponent:comp]];
  else
    [_resp appendContentString:@"http://sope.opengroupware.org/"];
  
  [_resp appendContentString:@"', 'a short text', '"];

  /* configure modal panel */
  if (self->height != nil) {
    [_resp appendContentString:@" dialogHeight: "];
    [_resp appendContentString:[self->height stringValueInComponent:comp]];
    [_resp appendContentString:@"px;"];
  }
  if (self->width != nil) {
    [_resp appendContentString:@" dialogWidth: "];
    [_resp appendContentString:[self->width stringValueInComponent:comp]];
    [_resp appendContentString:@"px;"];
  }
  if (self->top != nil) {
    [_resp appendContentString:@" dialogTop: "];
    [_resp appendContentString:[self->top stringValueInComponent:comp]];
    [_resp appendContentString:@"px;"];
  }
  if (self->left != nil) {
    [_resp appendContentString:@" dialogLeft: "];
    [_resp appendContentString:[self->left stringValueInComponent:comp]];
    [_resp appendContentString:@"px;"];
  }
  if (self->isResizable != nil) {
    [_resp appendContentString:@" resizable: "];
    [_resp appendContentString:
	     [self->isResizable stringValueInComponent:comp]];
    [_resp appendContentCharacter:';'];
  }
  if (self->showStatus != nil) {
    [_resp appendContentString:@" status: "];
    [_resp appendContentString:[self->showStatus stringValueInComponent:comp]];
    [_resp appendContentCharacter:';'];
  }
  if (self->isCenter != nil) {
    [_resp appendContentString:@" center: "];
    [_resp appendContentString:[self->isCenter stringValueInComponent:comp]];
    [_resp appendContentCharacter:';'];
  }

  [_resp appendContentString:@"')\""];
  
  [_resp appendContentString:@" href=\""];
  [_resp appendContentString:[_ctx componentActionURL]];
  [_resp appendContentString:@"\" "];
  
  [self appendExtraAttributesToResponse:_resp inContext:_ctx];
  [_resp appendContentString:@" >"];

  /* link content */
  if (self->filename != nil) {
    WOResourceManager *rm;
    NSString          *frameworkName;
      
    rm        = [[_ctx application] resourceManager];
    languages = [_ctx resourceLookupLanguages];
    frameworkName = (self->framework != nil)
      ? [self->framework stringValueInComponent:comp] 
      : [comp frameworkName];
    
    tmp = [rm urlForResourceNamed:[self->filename stringValueInComponent:comp]
              inFramework:frameworkName
              languages:languages
              request:[_ctx request]];
    
    [_resp appendContentString:@"<img border=\"0\" src=\""];
    [_resp appendContentString:tmp];
    [_resp appendContentString:@"\" "];
    
    [_resp appendContentString:
	     (_ctx->wcFlags.xmlStyleEmptyElements ? @" />" : @">")];
  }
  
  [self->template appendToResponse:_resp inContext:_ctx];
  
  if (self->string != nil)
    [_resp appendContentString:[self->string stringValueInComponent:comp]];
  
  /* close link */
  [_resp appendContentString:@"</a>"];
}

@end /* JSModalWindow */
