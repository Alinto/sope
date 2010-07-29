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

@class WOAssociation;

@interface WECollapsibleComponentContent : WODynamicElement
{
@protected
  WOAssociation *condition;
  WOAssociation *visibility;
  
  WOAssociation *allowScript; /* perform clicks on browser (use javaScript) */
  
  WOElement     *template;
}
@end

@interface WECollapsibleAction : WODynamicElement
{
@protected
  WOAssociation *openedImageFileName;
  WOAssociation *closedImageFileName;
  WOAssociation *framework;
  WOAssociation *openedLabel;
  WOAssociation *closedLabel;
  WOAssociation *submitActionName;
  WOAssociation *action; // if submit button, use submitActionName instead
  WOAssociation *fragmentIdentifier;
  WOAssociation *isClicked;

  WOElement *template;
}
@end

#include "WEContextConditional.h"
#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

static NSString *WECollapsible_TitleMode   = @"WECollapsible_TitleMode";
static NSString *WECollapsible_ContentMode = @"WECollapsible_ContentMode";
static NSString *WECollapsible_IsCollapsed = @"WECollapsible_IsCollapsed";
static NSString *WECollapsible_ScriptId    = @"WECollapsible_ScriptId";
static NSString *WECollapsible_HasScript   = @"WECollapsible_HasScript";
static NSString *Yes                       = @"YES";
static NSString *No                        = @"NO";

@implementation WECollapsibleComponentContent

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmp
{
  if ((self = [super initWithName:_name associations:_config template:_tmp])) {
    self->condition   = WOExtGetProperty(_config, @"condition");
    self->visibility  = WOExtGetProperty(_config, @"visibility");
    self->allowScript = WOExtGetProperty(_config, @"allowScript");

    if (self->visibility == nil)
      NSLog(@"WARNING: WECollapsibleComponent 'visibility' not set");

    if (self->visibility && ![self->visibility isValueSettable])
      NSLog(@"WARNING: WECollapsibleComponent 'visibility' is not settable");
    
    self->template = [_tmp retain];
  }
  return self;
}

- (void)dealloc {
  [self->condition   release];
  [self->visibility  release];
  [self->allowScript release];
  [self->template    release];
  [super dealloc];
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  BOOL isCollapsed;

  isCollapsed = ![self->visibility boolValueInComponent:[_ctx component]];

  // content
  if (!isCollapsed) {
    [_ctx setObject:Yes forKey:WECollapsible_ContentMode];
    [self->template takeValuesFromRequest:_req inContext:_ctx];
    [_ctx removeObjectForKey:WECollapsible_ContentMode];
  }

  // title
  [_ctx setObject:Yes forKey:WECollapsible_TitleMode];

  [self->template takeValuesFromRequest:_req inContext:_ctx];

  [_ctx removeObjectForKey:WECollapsible_TitleMode];
}

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  id   result = nil;
  BOOL isCollapsed;

  isCollapsed = ![self->visibility boolValueInComponent:[_ctx component]];
  
  // title
  [_ctx setObject:Yes forKey:WECollapsible_TitleMode];
  [_ctx setObject:Yes forKey:WECollapsible_ContentMode];
  [_ctx setObject:(isCollapsed) ? Yes : No forKey:WECollapsible_IsCollapsed];

  result = [self->template invokeActionForRequest:_request inContext:_ctx];
  isCollapsed = [[_ctx objectForKey:WECollapsible_IsCollapsed] boolValue];

  if ([self->visibility isValueSettable])
    [self->visibility setBoolValue:!isCollapsed inComponent:[_ctx component]];

  [_ctx removeObjectForKey:WECollapsible_IsCollapsed];
  [_ctx removeObjectForKey:WECollapsible_ContentMode];
  [_ctx removeObjectForKey:WECollapsible_TitleMode];
  
  return result;
}

- (void)appendToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  WOComponent *comp;
  BOOL        isCollapsed;
  BOOL        doScript;
  NSString    *scriptId;

  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_resp inContext:_ctx];
    return;
  }
  
  comp     = [_ctx component];
  doScript = [self->allowScript boolValueInComponent:comp];
  scriptId = [[[_ctx elementID] componentsSeparatedByString:@"."]
                     componentsJoinedByString:@"_"];

  if (doScript) {
    WEClientCapabilities *ccaps;
    
    ccaps    = [[_ctx request] clientCapabilities];
    doScript = [ccaps isInternetExplorer];
  }

  if (doScript)
    [_ctx setObject:scriptId forKey:WECollapsible_ScriptId];
  
  if ([self->visibility valueInComponent:comp] == nil) {
    isCollapsed = ![self->condition boolValueInComponent:comp];
    if ([self->visibility isValueSettable])
      [self->visibility setBoolValue:!isCollapsed inComponent:comp];
  }
  else
    isCollapsed = ![self->visibility boolValueInComponent:comp];

  // append title
  [_ctx setObject:Yes forKey:WECollapsible_TitleMode];
  [_ctx setObject:(isCollapsed) ? Yes : No forKey:WECollapsible_IsCollapsed];

  [self->template appendToResponse:_resp inContext:_ctx];
  
  [_ctx removeObjectForKey:WECollapsible_IsCollapsed];
  [_ctx removeObjectForKey:WECollapsible_TitleMode];
  
  // append content
  if (!isCollapsed || doScript) {
    [_ctx setObject:Yes forKey:WECollapsible_ContentMode];
    if (doScript) {
      [_resp appendContentString:@"<div class=\"collapsible\" "];
      [_resp appendContentString:@"id=\"collapsible"];
      [_resp appendContentString:scriptId];
      [_resp appendContentString:@"\" style=\"display:"];
      [_resp appendContentString:(isCollapsed) ? @"none" : @"block"];
      [_resp appendContentString:@";\">"];
    }
    
    [self->template appendToResponse:_resp inContext:_ctx];
    
    if (doScript)
      [_resp appendContentString:@"</div>"];
    [_ctx removeObjectForKey:WECollapsible_ContentMode];
  }
  [_ctx removeObjectForKey:WECollapsible_ScriptId];
}
@end /* WECollapsibleComponentContent */

@implementation WECollapsibleAction

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_temp
{
  if ((self = [super initWithName:_name associations:_config template:_temp])) {
    self->openedImageFileName = WOExtGetProperty(_config, @"openedImageFileName");
    self->closedImageFileName = WOExtGetProperty(_config, @"closedImageFileName");
    self->framework           = WOExtGetProperty(_config, @"framework");
    self->openedLabel         = WOExtGetProperty(_config, @"openedLabel");
    self->closedLabel         = WOExtGetProperty(_config, @"closedLabel");
    self->submitActionName    = WOExtGetProperty(_config, @"submitActionName");
    self->action              = WOExtGetProperty(_config, @"action");
    self->fragmentIdentifier  = WOExtGetProperty(_config, @"fragmentIdentifier");
    self->isClicked           = WOExtGetProperty(_config, @"isClicked");

    self->template = [_temp retain];
  }
  return self;
}

- (void)dealloc {
  [self->openedImageFileName release];
  [self->closedImageFileName release];
  [self->framework           release];
  [self->openedLabel         release];
  [self->closedLabel         release];
  [self->submitActionName    release];
  [self->action              release];
  [self->fragmentIdentifier  release];
  [self->isClicked           release];
  [self->template            release];
  [super dealloc];
}

/* requests */

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *eid;

  eid = [_ctx elementID];

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
  NSString    *state;
  BOOL        doForm;
  
  state = [[_ctx currentElementID] stringValue];
  
  doForm = ([_ctx isInForm] && self->submitActionName &&
            ([self->submitActionName valueInComponent:[_ctx component]]));
  
  [_ctx consumeElementID]; // consume state-id
    
  if ([state isEqualToString:@"e"]) {
    [_ctx setObject:[NSNumber numberWithBool:YES]
          forKey:WECollapsible_IsCollapsed];
    
    if (doForm)
      [self->submitActionName valueInComponent:[_ctx component]];
    else if ([self->action valueInComponent:[_ctx component]] != nil)
      [self->action valueInComponent:[_ctx component]];
  }
  else if ([state isEqualToString:@"c"]) {
    [_ctx setObject:[NSNumber numberWithBool:NO]
          forKey:WECollapsible_IsCollapsed];
    
    if (doForm)
      [self->submitActionName valueInComponent:[_ctx component]];
    else if ([self->action valueInComponent:[_ctx component]] != nil)
      [self->action valueInComponent:[_ctx component]];
  }
  if ([self->isClicked isValueSettable])
    [self->isClicked setBoolValue:YES inComponent:[_ctx component]];
    
  return nil; 
}

- (void)_appendScriptWithID:(NSString *)scriptId 
  label:(NSString *)label imageURL:(NSString *)img
  toResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx 
{
  WOComponent *comp;
    NSString *openedImg  = nil;
    NSString *closedImg  = nil;
    NSString *openLabel  = nil;
    NSString *closeLabel = nil;

    comp       = [_ctx component];
    closedImg  = [self->closedImageFileName stringValueInComponent:comp];
    openedImg  = [self->openedImageFileName stringValueInComponent:comp];
    openLabel  = [self->openedLabel         stringValueInComponent:comp];
    closeLabel = [self->closedLabel         stringValueInComponent:comp];

    closedImg = WEUriOfResource(closedImg, _ctx);
    openedImg = WEUriOfResource(openedImg, _ctx);

    if (![_ctx objectForKey:WECollapsible_HasScript]) {
      [_resp appendContentString:
           @"\n<script language=\"JavaScript\">\n"
           @"<!--\n"
           @"function toggleColl(el, img1, img2, alt1, alt2)\n"
           @"{\n"
           @"	whichEl = eval(\"collapsible\" + el);\n"
           @"	whichIm = event.srcElement;\n"
           @"	if (whichEl.style.display == \"none\") {\n"
           @"		whichEl.style.display = \"block\";\n"
           @"		whichIm.src = img1;\n"
           @"       whichIm.alt = alt1;\n"
           @"	}\n"
           @"	else {\n"
           @"		whichEl.style.display = \"none\";\n"
           @"	    whichIm.src = img2;\n"
           @"       whichIm.alt = alt2;\n"
           @"   }\n"
           @"}\n"
           @"//-->\n"
           @"</script>\n"];
      [_ctx setObject:Yes forKey:WECollapsible_HasScript];
    }
    
    [_resp appendContentString:@"<a href=\"#\" onclick=\"toggleColl('"];
    [_resp appendContentString:scriptId];
    [_resp appendContentString:@"','"];
    [_resp appendContentHTMLString:openedImg];
    [_resp appendContentString:@"','"];
    [_resp appendContentHTMLString:closedImg];
    [_resp appendContentString:@"','"];
    [_resp appendContentHTMLString:openLabel];
    [_resp appendContentString:@"','"];
    [_resp appendContentHTMLString:closeLabel];
    [_resp appendContentString:@"'); return false\"><img "];
    if (label) {
      [_resp appendContentString:@"alt=\""];
      [_resp appendContentString:label];
      [_resp appendContentString:@"\" title=\""];
      [_resp appendContentString:label];
      [_resp appendContentString:@"\" "];
    }
    [_resp appendContentString:@"border=\"0\" name=\"imEx\" src=\""];
    [_resp appendContentString:img];
    [_resp appendContentString:@"\" /></a>"];
}

- (void)_appendLinkWithFragmentID:(NSString *)fragId
  label:(NSString *)label imageURL:(NSString *)img
  isCollapsed:(BOOL)isCollapsed
  toResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx 
{
  [_resp appendContentString:@"<a href=\""];
  [_resp appendContentString:[_ctx componentActionURL]];
  if ([fragId isNotEmpty]) {
    [_resp appendContentString:@"#"];
    [_resp appendContentString:fragId];
  }
  [_resp appendContentString:@"\">"];
  
  if (img != nil) {
    [_resp appendContentString:@"<img border=\"0\" src=\""];
    [_resp appendContentString:img];
    [_resp appendContentString:@"\""];
    if (label) {
      [_resp appendContentString:@" alt=\""];
      [_resp appendContentString:label];
      [_resp appendContentString:@"\" title=\""];
      [_resp appendContentString:label];
      [_resp appendContentString:@"\""];
    }
    [_resp appendContentString:@" />"];
  }
  else
    [_resp appendContentString:(isCollapsed) ? @"[+]" : @"[-]"];
    
  [_resp appendContentString:@"</a>"];
}

- (void)appendToResponse:(WOResponse *)_resp inContext:(WOContext *)_ctx {
  /* TODO: split up this huge method */
  BOOL        isCollapsed;
  BOOL        doForm;
  BOOL        doScript;
  WOComponent *comp;
  NSString    *img      = nil;
  NSString    *label    = nil;
  NSString    *fragId   = nil;
  NSString    *scriptId = nil;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_resp inContext:_ctx];
    return;
  }
  
  comp   = [_ctx component];
  fragId = [self->fragmentIdentifier stringValueInComponent:comp];

  isCollapsed = [[_ctx objectForKey:WECollapsible_IsCollapsed] boolValue];
  scriptId    = [_ctx objectForKey:WECollapsible_ScriptId];
  doScript    = [scriptId isNotEmpty] ? YES : NO;
  
  img = (isCollapsed)
    ? [self->closedImageFileName stringValueInComponent:comp]
    : [self->openedImageFileName stringValueInComponent:comp];

  label = (isCollapsed)
    ? [self->closedLabel stringValueInComponent:comp]
    : [self->openedLabel stringValueInComponent:comp];

  img = WEUriOfResource(img, _ctx);

  /*
  if (isCollapsed)
    [_resp appendContentString:@"&nbsp;"];
  */

  doForm = ([_ctx isInForm] && self->submitActionName && img);

  [_ctx appendElementIDComponent:(isCollapsed) ? @"c" : @"e"];
  if (doScript) {
    [self _appendScriptWithID:scriptId label:label imageURL:img
          toResponse:_resp inContext:_ctx];
  }
  else if (doForm) {
    [_resp appendContentString:@"<input type=\"image\" border=\"0\" name=\""];
    [_resp appendContentString:[_ctx elementID]];
    [_resp appendContentString:@"\" src=\""];
    [_resp appendContentString:img];
    [_resp appendContentString:@"\" />"];
  }
  else {
    [self _appendLinkWithFragmentID:fragId label:label imageURL:img
          isCollapsed:isCollapsed
          toResponse:_resp inContext:_ctx];
  }
  
  if (fragId) {
    WEClientCapabilities *ccaps;
    
    ccaps    = [[_ctx request] clientCapabilities];
    
    [_resp appendContentString:@"<a name=\""];
    [_resp appendContentString:fragId];
    [_resp appendContentString:@"\">&nbsp;</a>"];
    if ([self->isClicked boolValueInComponent:comp] &&
        ([ccaps isInternetExplorer] || [ccaps isMozilla] || [ccaps isNetscape6])) {
      if ([self->isClicked isValueSettable])
        [self->isClicked setBoolValue:NO inComponent:comp];
      
      [_resp appendContentString:
             [NSString stringWithFormat:
             @"\n<script language=\"JavaScript\">\n"
             @"<!--\n"
             @"  window.location.hash=\"#%@\";\n"
             @"//-->\n"
             @"</script>\n",
             fragId]];
    }
  }
  else
    [_resp appendContentString:@"&nbsp;"];
  
  if (label && !doScript) {
    if (!doForm) {
      [_resp appendContentString:@"<a href=\""];
      [_resp appendContentString:[_ctx componentActionURL]];
      if (fragId) {
        [_resp appendContentString:@"#"];
        [_resp appendContentString:fragId];
      }
      [_resp appendContentString:@"\">"];
    }
    
    [_resp appendContentString:label];

    if (!doForm)
      [_resp appendContentString:@"</a>"];
  }
  [_ctx deleteLastElementIDComponent];
}

@end /* WECollapsibleAction */

@interface WECollapsibleTitleMode: WEContextConditional
@end

@implementation WECollapsibleTitleMode

- (NSString *)_contextKey {
  return WECollapsible_TitleMode;
}

@end /* WECollapsibleTitleMode */

@interface WECollapsibleContentMode: WEContextConditional
@end

@implementation WECollapsibleContentMode

- (NSString *)_contextKey {
  return WECollapsible_ContentMode;
}

@end /* WECollapsibleContentMode */
