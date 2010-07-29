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

#import <NGObjWeb/WODynamicElement.h>

@interface JSConfirmPanel : WODynamicElement
{
  WOAssociation *action;
  WOAssociation *javaScriptFunction;
  WOAssociation *pageName;
  WOAssociation *confirmMessage;
  WOAssociation *altTag;
  WOAssociation *filename;
  WOAssociation *targetWindow;
  WOAssociation *string;

  /* non WO */
  WOAssociation *showPanel;
  WOElement     *template;
  WOAssociation *escapeJS;
  WOAssociation *framework;
}

@end

#include "common.h"

@implementation JSConfirmPanel

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
  if ((self = [super initWithName:_name associations:_config template:_subs]))
  {
    int funcCount;

    self->action             = WOExtGetProperty(_config,@"action");
    self->javaScriptFunction = WOExtGetProperty(_config,@"javaScriptFunction");
    self->pageName           = WOExtGetProperty(_config,@"pageName");
    self->confirmMessage     = WOExtGetProperty(_config,@"confirmMessage");
    self->altTag             = WOExtGetProperty(_config,@"altTag");
    self->filename           = WOExtGetProperty(_config,@"filename");
    self->targetWindow       = WOExtGetProperty(_config,@"targetWindow");
    self->string             = WOExtGetProperty(_config,@"string");
    self->showPanel          = WOExtGetProperty(_config,@"showPanel");
    self->escapeJS           = WOExtGetProperty(_config,@"escapeJS");
    self->framework          = WOExtGetProperty(_config,@"framework");

    funcCount = 0;
    if (self->action) funcCount++;
    if (self->pageName) funcCount++;
    if (self->javaScriptFunction) funcCount++;

    if (funcCount > 1) {
      NSLog(@"WARNING: JSConfirmPanel: choose only one of "
            @"action | pageName | javaScriptFunction");
    }
    if (funcCount < 1) {
      NSLog(@"WARNING: JSConfirmPanel: no function declared - choose one of"
            @"action | pageName | javaScriptFunction");
    }
    if (!self->confirmMessage) {
      NSLog(@"WARNING: JSConfirmPanel: no value for 'confirmMessage'"
            @" - using default");
    }
    
    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->action             release];
  [self->javaScriptFunction release];
  [self->pageName           release];
  [self->confirmMessage     release];
  [self->altTag             release];
  [self->filename           release];
  [self->targetWindow       release];
  [self->string             release];
  [self->template           release];
  [self->showPanel          release];
  [self->escapeJS           release];
  [self->framework          release];
  [super dealloc];
}

/* request processing */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx{
  id       result;
  NSString *name;

  if (self->showPanel &&
      ![self->showPanel boolValueInComponent:[_ctx component]]) {
    return nil;
  }
  
  if (self->pageName != nil) {
    name   = [self->pageName stringValueInComponent: [_ctx component]];
    result = [[_ctx application] pageWithName:name inContext:_ctx];
  }
  else if (self->action != nil) {
    result = [self->action valueInComponent:[_ctx component]];
  }
  else {
    result = [self->template invokeActionForRequest:_request inContext:_ctx];
  }
  return result;
}

/* response generation */

- (void)_appendPanelToResponse:(WOResponse *)_response 
  message:(NSString *)_msg
  inContext:(WOContext *)_ctx 
{
  if (![self->showPanel boolValueInComponent:[_ctx component]])
    return;
  
  [_response appendContentString:
               @"<script type=\"text/javascript\">\nvar res = confirm(\""];
  [_response appendContentHTMLString:_msg];
  [_response appendContentString:@"\");\n if (res) {\n"];

  if (self->javaScriptFunction) {
    NSString *js;
    
    js = [self->javaScriptFunction stringValueInComponent:[_ctx component]];
    [_response appendContentString:js];
  }
  else if (self->action || self->pageName) {
    [_response appendContentString:@"document.location.href=\""];
    [_response appendContentString:[_ctx componentActionURL]];
    [_response appendContentString:@"\";"];
  }
    
  [_response appendContentString:@"}"];
  [_response appendContentString:@"</script>"];
}

- (void)_appendLinkToResponse:(WOResponse *)_response 
  message:(NSString *)_msg
  inContext:(WOContext *)_ctx 
{
  WOComponent *comp;
  NSString    *tmp;
  NSArray     *languages;
  
  comp = [_ctx component];
  
  [_response appendContentString:@"<a onclick=\"javascript:return confirm('"];
  [_response appendContentHTMLString:_msg];
  [_response appendContentString:@"');\""];
  [_response appendContentString:@" href=\""];
  
  if (self->javaScriptFunction) {
      [_response appendContentString:@"javascript:"];
      [_response appendContentHTMLAttributeValue:
                 [self->javaScriptFunction stringValueInComponent:comp]];
  }
  else {
      [_response appendContentString:[_ctx componentActionURL]];
  }
  [_response appendContentString:@"\" "];
  if (self->targetWindow) {
      [_response appendContentString:@" target=\""];
      [_response appendContentHTMLAttributeValue:
                 [self->targetWindow stringValueInComponent: comp]];
      [_response appendContentString:@"\" "];
  }
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  [_response appendContentString:@" >"];

  /* link content */
  if (self->filename != nil) { /* image */
    WOResourceManager *rm;
    NSString          *frameworkName;

    frameworkName = (self->framework != nil)
      ? [self->framework stringValueInComponent:comp] 
      : [comp frameworkName];

    rm        = [[_ctx application] resourceManager];
    languages = [_ctx resourceLookupLanguages];
      
    tmp = [rm urlForResourceNamed:[self->filename stringValueInComponent:comp]
	      inFramework:frameworkName
	      languages:languages
	      request:[_ctx request]];
    
    [_response appendContentString:@"<img border=\"0\" src=\""];
    [_response appendContentString:tmp];
    [_response appendContentString:@"\" "];
    
    if (self->altTag != nil) {
      [_response appendContentString:@"alt=\""];
      [_response appendContentString:
                   [self->altTag stringValueInComponent:comp]];
      [_response appendContentString:@"\" "];
    }

    [_response appendContentString:
		 (_ctx->wcFlags.xmlStyleEmptyElements ? @" />" : @">")];
  }
  
  [self->template appendToResponse:_response inContext:_ctx];
  
  if (self->string != nil) {
    [_response appendContentString:
                 [self->string stringValueInComponent:comp]];
  }
  
  /* close link */
  [_response appendContentString:@"</a>"];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString    *msg;
  WOComponent *comp;

  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  comp = [_ctx component];
  msg  = (self->confirmMessage)
    ? [self->confirmMessage stringValueInComponent:comp]
    : (NSString *)@"Really?";
  if (self->escapeJS != nil && [self->escapeJS boolValueInComponent:comp]) {
    msg = [msg stringByApplyingJavaScriptEscaping];
  }

  if (self->showPanel)
    [self _appendPanelToResponse:_response message:msg inContext:_ctx];
  else 
    [self _appendLinkToResponse:_response message:msg inContext:_ctx];
}

@end /* JSConfirmPanel */
