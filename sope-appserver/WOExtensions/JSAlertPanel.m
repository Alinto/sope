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

@interface JSAlertPanel : WODynamicElement
{
  WOAssociation *action;
  WOAssociation *javaScriptFunction;
  WOAssociation *pageName;
  WOAssociation *alertMessage;
  WOAssociation *altTag;
  WOAssociation *filename;
  WOAssociation *targetWindow;
  WOAssociation *string;
  
  /* non WO */
  WOElement     *template;
  WOAssociation *escapeJS;
  WOAssociation *framework;
}

@end

#include "common.h"

@implementation JSAlertPanel

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
    self->alertMessage       = WOExtGetProperty(_config,@"alertMessage");
    self->altTag             = WOExtGetProperty(_config,@"altTag");
    self->filename           = WOExtGetProperty(_config,@"filename");
    self->targetWindow       = WOExtGetProperty(_config,@"targetWindow");
    self->string             = WOExtGetProperty(_config,@"string");
    self->escapeJS           = WOExtGetProperty(_config,@"escapeJS");
    self->framework          = WOExtGetProperty(_config,@"framework");
    
    funcCount = 0;
    if (self->action) funcCount++;
    if (self->pageName) funcCount++;
    if (self->javaScriptFunction) funcCount++;

    if (funcCount > 1) {
      NSLog(@"WARNING: JSAlertPanel: choose only one of "
            @"action | pageName | javaScriptFunction");
    }
    if (funcCount < 1) {
      NSLog(@"WARNING: JSAlertPanel: no function declared - choose one of"
            @"action | pageName | javaScriptFunction");
    }
    if (!self->alertMessage) {
      NSLog(@"WARNING: JSAlertPanel: no value for 'alertMessage'"
            @" - using default");
    }
    
    self->template = RETAIN(_subs);
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->action);
  RELEASE(self->javaScriptFunction);
  RELEASE(self->pageName);
  RELEASE(self->alertMessage);
  RELEASE(self->altTag);
  RELEASE(self->filename);
  RELEASE(self->targetWindow);
  RELEASE(self->string);
  RELEASE(self->template);
  RELEASE(self->escapeJS);
  RELEASE(self->framework);
  [super dealloc];
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (self->pageName) {
    NSString *name;
    
    name = [self->pageName stringValueInComponent: [_ctx component]];
    return [[_ctx application] pageWithName:name inContext:_ctx];
  }
  if (self->action)
    return [self->action valueInComponent:[_ctx component]];
  
  return [self->template invokeActionForRequest:_rq inContext:_ctx];
}


- (void)appendToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent *comp;
  NSString    *tmp;
  NSArray     *languages;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  comp = [_ctx component];
  
  // link
  [_response appendContentString:@"<a onclick=\"javascript:alert('"];
  tmp = (self->alertMessage)
    ? [self->alertMessage stringValueInComponent: comp]
    : (NSString *)@"Press OK.";
  if (self->escapeJS != nil && [self->escapeJS boolValueInComponent: comp]) {
    tmp = [tmp stringByApplyingJavaScriptEscaping];
  }
  [_response appendContentHTMLString:tmp];
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

  // link content  
  if (self->filename != nil) {
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
    [_response appendContentString:@"\""];
    
    if (self->altTag != nil) {
      [_response appendContentString:@" alt=\""];
      [_response appendContentString:
        [self->altTag stringValueInComponent:comp]];
      [_response appendContentString:@"\" "];
    }
    
    [_response appendContentString:
		 (_ctx->wcFlags.xmlStyleEmptyElements ? @" />" : @">")];
  }

  [self->template appendToResponse:_response inContext:_ctx];
  
  if (self->string != nil) 
    [_response appendContentString:[self->string stringValueInComponent:comp]];

  /* close link */
  [_response appendContentString:@"</a>"];
}

@end /* JSAlertPanel */
