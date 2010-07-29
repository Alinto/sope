/*
  Copyright (C) 2005 Helge Hess

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

/*
  WELiveLink

  Inspired by the link_to_remote() RoR function.
 
  position := { Before, Top, Bottom, After }
*/

@interface WELiveLink : WODynamicElement
{
  WOAssociation *string;
  WOAssociation *updateID;
  WOAssociation *position;
  
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  WOAssociation *href;
  
  WOAssociation *confirmText;
  
  WOElement *template;
}

@end

#include "WEPrototypeScript.h"
#include "common.h"

@implementation WELiveLink

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmp
{
  if ((self = [super initWithName:_name associations:_config template:_tmp])) {
    self->template = [_tmp retain];
    
    self->string           = WEPExtGetProperty(_config, @"string");
    self->updateID         = WEPExtGetProperty(_config, @"updateID");
    self->position         = WEPExtGetProperty(_config, @"position");
    self->actionClass      = WEPExtGetProperty(_config, @"actionClass");
    self->directActionName = WEPExtGetProperty(_config, @"directActionName");
    self->href             = WEPExtGetProperty(_config, @"href");
    self->confirmText      = WEPExtGetProperty(_config, @"confirmText");
  }
  return self;
}

- (void)dealloc {
  [self->updateID         release];
  [self->position         release];
  [self->actionClass      release];
  [self->directActionName release];
  [self->href             release];
  [self->confirmText      release];
  [self->string           release];
  [self->template         release];
  [super dealloc];
}

/* generating response */

- (NSString *)linkInContext:(WOContext *)_ctx {
  if (self->directActionName != nil) {
    NSString *ac, *da;
    
    ac = [self->actionClass      stringValueInComponent:[_ctx component]];
    da = [self->directActionName stringValueInComponent:[_ctx component]];

    if ([ac length] > 0)
      da = [[ac stringByAppendingString:@"/"] stringByAppendingString:da];
    
    return [_ctx directActionURLForActionNamed:da queryDictionary:nil];
  }
  
  if (self->href != nil)
    return [self->href stringValueInComponent:[_ctx component]];
  
  [self logWithFormat:@"ERROR: no binding for link!"];
  return nil;
}

- (void)appendJavaScriptToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  /*
    new Ajax.Updater('time_div', 
                     '/hello_world/say_when', 
                     {insertion:Insertion.After, asynchronous:true}); 
    return false;
  */
  WOComponent *sComponent;
  NSString *s;
  BOOL     closeBracket = NO, isDOM = NO;
  
  sComponent = [_ctx component];
  
  /* check for confirm panel */
  
  s = [self->confirmText stringValueInComponent:sComponent];
  if ([s length] > 0) {
    [_response appendContentString:@"if (confirm('"];
    [_response appendContentHTMLAttributeValue:s];
    [_response appendContentString:@"')) { "];
    closeBracket = YES;
  }
  
  /* whether to update an element */
  
  s = [self->updateID stringValueInComponent:sComponent];
  if ([s length] > 0) {
    [_response appendContentString:@"new Ajax.Updater('"];
    [_response appendContentHTMLAttributeValue:s];
    [_response appendContentString:@"', '"];
    isDOM = YES;
  }
  else {
    [_response appendContentString:@"new Ajax.Request('"];
  }
  
  /* Link */
  
  if ((s = [self linkInContext:_ctx]) != nil)
    [_response appendContentHTMLAttributeValue:s];
  [_response appendContentString:@"'"];
  
  /* parameters */

  [_response appendContentString:@", {"];
  
  if (isDOM) {
    s = [self->position stringValueInComponent:sComponent];
    if ([s length] > 0) {
      [_response appendContentString:@"insertion: Insertion."];
      [_response appendContentString:[s capitalizedString]];
      [_response appendContentString:@", "];
    }
  }
  
  [_response appendContentString:@"asynchronous: true }"];
  
  /* close function */
  
  [_response appendContentString:@");"];
  
  /* close confirm panel if */
  
  if (closeBracket) [_response appendContentString:@"}"];
  
  /* always: do not follow link target */
  [_response appendContentString:@" return false;"];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *s;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  /* first ensure that prototype is loaded */
  [WEPrototypeScript appendToResponse:_response inContext:_ctx];
  
  /* start link tag */
  
  [_response appendContentString:@"<a href=\"#\" onclick=\""];
  
  /* generate JavaScript */

  [self appendJavaScriptToResponse:_response inContext:_ctx];
  
  /* finish link start tag */
  
  [_response appendContentString:@"\""];
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString != nil) {
    [_response appendContentString:@" "];
    s = [self->otherTagString stringValueInComponent:[_ctx component]];
    [_response appendContentString:s];
  }
  [_response appendContentString:@">"];
  
  /* generate content */
  
  if ((s = [self->string stringValueInComponent:[_ctx component]]) != nil)
    [_response appendContentHTMLString:s];
  
  [self->template appendToResponse:_response inContext:_ctx];
  
  /* close anker */
  [_response appendContentString:@"</a>"];
}

@end /* WELiveLink */
