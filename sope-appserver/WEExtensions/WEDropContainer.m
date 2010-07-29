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

/*
  usage:

     DropContainer: WEDropContainer {
       elementName   = "tr";
       isAttached    = YES;
       tags          = ( * );
       action        = dropAction;
       droppedObject = droppedObject;
       
       swapColor     = YES;
       activeColor   = "lightblue";
       bgColor       = bgColor;
     }
     
  renders this:

    <$area BGCOLOR=white 
        onDragEnter="fnCancelDefault()"
        onDragOver="fnCancelDefault()"
        onDrop="fnGetInfo()">
       $content
    </$area>
*/

@interface WEDropContainer : WODynamicElement
{
  NSDictionary  *dExtraAttrs;
  WOAssociation *tags;
  WOAssociation *elementName;
  WOAssociation *isAttached;  /* bool */
  WOAssociation *effect;
  WOAssociation *swapColor; /* swap bgcolor if drag object is over container */
  WOAssociation *action;
  WOAssociation *droppedObject;
  
  WOElement     *template;
}
@end

@interface WEDropScript : WODynamicElement
+ (void)appendDropScriptToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx;
@end

#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

@implementation WEDropContainer

+ (int)version {
  return 0 + [super version];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs])) {
    self->tags            = WOExtGetProperty(_config, @"tags");
    self->elementName     = WOExtGetProperty(_config, @"elementName");
    self->effect          = WOExtGetProperty(_config, @"effect");
    self->action          = WOExtGetProperty(_config, @"action");
    self->droppedObject   = WOExtGetProperty(_config, @"droppedObject");
    self->swapColor       = WOExtGetProperty(_config, @"swapColor");
    self->isAttached      = WOExtGetProperty(_config, @"isAttached");
    
    self->template = RETAIN(_subs);
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->dExtraAttrs);
  
  RELEASE(self->swapColor);
  RELEASE(self->droppedObject);
  RELEASE(self->action);
  RELEASE(self->template);
  RELEASE(self->effect);
  RELEASE(self->tags);
  RELEASE(self->elementName);
  RELEASE(self->isAttached);
  
  [super dealloc];
}

- (void)setExtraAttributes:(NSDictionary *)_extras {
  ASSIGNCOPY(self->dExtraAttrs, _extras);
}

- (void)appendExtraAttributesToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if (self->dExtraAttrs) {
    WOComponent  *sComponent;
    NSEnumerator *keys;
    NSString     *key;
    
    sComponent = [_ctx component];

    keys = [self->dExtraAttrs keyEnumerator];
    
    while ((key = [keys nextObject])) {
      id value;
      
      value = [self->dExtraAttrs objectForKey:key];
      
      if (value == nil)
        continue;
      
      //key   = [key lowercaseString];
      value = [value stringValueInComponent:sComponent];

      [_response appendContentCharacter:' '];
      [_response appendContentString:key];
      [_response appendContentString:@"=\""];
      [_response appendContentHTMLAttributeValue:value];
      [_response appendContentCharacter:'"'];
    }
  }
}

/* responder */

- (void)takeValuesFromRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  [_ctx appendElementIDComponent:@"p"];
  [self->template takeValuesFromRequest:_request inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
}

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  NSString *op;
  id result;
  
  op = [[_ctx currentElementID] stringValue];
#if 0
    NSLog(@"check DROP ACTION %@ ..", op);
#endif
  
  if ([op isEqualToString:@"p"]) {
    /* an action inside of the component */
    [_ctx consumeElementID]; // consume id
    [_ctx appendElementIDComponent:@"p"];
    result = [self->template invokeActionForRequest:_request inContext:_ctx];
    [_ctx deleteLastElementIDComponent];
  }
  else if ([op isEqualToString:@"drop"]) {
    /* an action of *this* component */
    [_ctx consumeElementID]; // consume id
    [_ctx appendElementIDComponent:@"drop"];

#if 0
    NSLog(@"WILL RUN DROP ACTION ..");
#endif
    
    if ([self->droppedObject isValueSettable]) {
      [self->droppedObject setValue:
                             [_ctx valueForKey:@"WEDragContainer_DropObject"]
                           inComponent:[_ctx component]];
    }
    
    result = [self->action valueInComponent:[_ctx component]];
    
    [_ctx deleteLastElementIDComponent];
  }
  else {
    NSLog(@"invalid element-id: did not expect '%@' id", op);
    result = nil;
  }
  return result;
}

- (void)appendExtraAttributesAsJavaScriptToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  if (self->dExtraAttrs) {
    WOComponent     *sComponent = [_ctx component];
    NSEnumerator    *keyEnum;
    NSString        *key;

    [_response appendContentString:
               @"\n"
               @"<script language=\"JavaScript\">\n"
               @"<!--\n"];

    keyEnum = [self->dExtraAttrs keyEnumerator];
    while ((key = [keyEnum nextObject])) {
      id value;
      
      value = [self->dExtraAttrs objectForKey:key];
      
      if (value == nil)
        continue;

      if ([[key lowercaseString] isEqualToString:@"width"])
        key = @"width";
      else if ([[key lowercaseString] isEqualToString:@"height"])
        key = @"height";
      else if ([[key lowercaseString] isEqualToString:@"bgcolor"])
        key = @"bgColor";
      else if ([[key lowercaseString] isEqualToString:@"activecolor"])
        key = @"activeColor";
      else if ([[key lowercaseString] isEqualToString:@"align"])
        key = @"align";
      else if ([[key lowercaseString] isEqualToString:@"valign"])
        key = @"vAlign";
      else if ([[key lowercaseString] isEqualToString:@"colspan"])
        key = @"colSpan";
      else if ([[key lowercaseString] isEqualToString:@"rowspan"])
        key = @"rowSpan";
      else if ([[key lowercaseString] isEqualToString:@"nowrap"])
        key = @"noWrap";
      
      value = [value stringValueInComponent:sComponent];
      [_response appendContentString:
                 [NSString stringWithFormat:@"tmp.%@ = \"%@\";\n", key, value]];
    }
    [_response appendContentString:
               @"// -->\n"
               @"</script>\n"];
  }
}

- (void)appendToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *htmlEl;
  NSString *ttag;
  NSString *teffect;
  NSString *containerID = nil;
  BOOL     doDnD, doSwap, doAttach;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  doDnD = [[[_ctx request] clientCapabilities] doesSupportDHTMLDragAndDrop];

  //doDnD = YES;
  
  ttag = [[self->tags valueInComponent:[_ctx component]]
                      componentsJoinedByString:@","];
  
  teffect = [self->effect stringValueInComponent:[_ctx component]];
  if (teffect == nil) teffect = @"move";
  
  [WEDropScript appendDropScriptToResponse:_response inContext:_ctx];
  
  [_ctx appendElementIDComponent:@"drop"];
  
  htmlEl   = [self->elementName stringValueInComponent:[_ctx component]];
  doAttach = ([self->isAttached boolValueInComponent:[_ctx component]] &&
             (self->elementName != nil));
  
  if (htmlEl == nil || doAttach) htmlEl = @"span";
  
  if ((self->elementName != nil) || doDnD) {
    int containerIDc;
    
    [_response appendContentString: @"<"];
    [_response appendContentString:htmlEl];

    if (doDnD) {
      /* gen unique container id */
      
      if ((containerID = [_ctx valueForKey:@"WEDropContainerSequence"])) {
        containerID = AUTORELEASE([containerID copy]);
        containerIDc = [containerID intValue];
      }
      else {
        containerID  = @"0";
        containerIDc = 0;
      }
      
      [_response appendContentString:@" id=\"skydrop"];
      if (doAttach) [_response appendContentString:@"dummy"];
      [_response appendContentString:containerID];
      [_response appendContentString:@"\""];
      
      containerIDc++;
    
      [_ctx takeValue:[NSString stringWithFormat:@"%i", containerIDc]
            forKey:@"WEDropContainerSequence"];
    }
  }
  
  if (doDnD) {
    NSString *swapOnAction  = @"";
    NSString *swapOffAction = @"";
    NSString *cancelAction;
    NSString *infoAction;
      

    doSwap = self->swapColor
      ? [self->swapColor boolValueInComponent:[_ctx component]]
      : YES;

    cancelAction = [NSString stringWithFormat:@"fnCancelDefault('%@','%@');",
                             ttag, teffect];
    if (doSwap) {
      swapOnAction  = [NSString stringWithFormat:
                                @"dropFieldSwapColor(skydrop%@,true);",
                                containerID];
      swapOffAction = [NSString stringWithFormat:
                                @"dropFieldSwapColor(skydrop%@,false);",
                                containerID];
    }
    
    infoAction = [NSString stringWithFormat:@"fnGetInfo(this, '%@');",
                           [_ctx componentActionURL]];

    if (doAttach) {
      NSString *tagName = nil;

      // doAttach==YES -> self->elementName != nil
      tagName = [self->elementName stringValueInComponent:[_ctx component]];
      tagName = [tagName uppercaseString];
      
      [_response appendContentCharacter:'>'];
      
      [_response appendContentString:[NSString stringWithFormat:
           @"\n"
           @"<script language=\"JavaScript\">\n"
           @"<!--\n"
           @"  function onDragEnterFunc%@() {\n    %@\n     %@\n}\n"
           @"  function onDragOverFunc%@()  {\n    %@\n     %@\n}\n"
           @"  function onDragLeaveFunc%@() {\n %@\n     }\n"
           @"  function onDropFunc%@()      {\n %@\n     }\n"
           @"\n"
           @"  tmp = document.getElementById(\"%@\");\n"
           @"  i = 5;\n"
           @"  while ((tmp.tagName != \"%@\") && (i >= 0)) {\n"
           @"    tmp = tmp.parentNode;\n"
           @"    i--;\n"
           @"  }\n"
           @"  tmp.ondragover    = onDragOverFunc%@;\n"
           @"  tmp.ondragleave   = onDragLeaveFunc%@;\n"
           @"  tmp.ondrop        = onDropFunc%@;\n"
           @"  tmp.ondragenter   = onDragEnterFunc%@;\n"
           @"  tmp.id            = \"%@\";\n"
           @"// -->\n"
           @"</script>\n",
           containerID, cancelAction, swapOnAction,
           containerID, cancelAction, swapOnAction,
           containerID, swapOffAction,
           containerID, infoAction,
           [@"skydropdummy" stringByAppendingString:containerID],
           tagName,
           containerID,
           containerID,
           containerID,
           containerID,
           [@"skydrop" stringByAppendingString:containerID]]];

      // remove bgColors of TR's sub TD:
      if ([tagName isEqualToString:@"TR"]) {
        [_response appendContentString:
           @"\n"
           @"<script language=\"JavaScript\">\n"
           @"<!--\n"
           @"list = tmp.getElementsByTagName(\"TD\");\n"
           @"cnt  = list.length;\n"
           @"for (i=0; i<cnt; i++) {\n"
           @"  list[i].removeAttribute(\"bgColor\");\n"
           @"}\n"
           @"// -->\n"
           @"</script>\n"];
      }

      /* append extra attributes by script */
      [self appendExtraAttributesAsJavaScriptToResponse:_response
                                              inContext:_ctx];
    }
    else {
      [_response appendContentString:@" onDragEnter=\""];
      [_response appendContentString:cancelAction];
      [_response appendContentString:swapOnAction];

      [_response appendContentString:@"\" onDragOver=\""];
      [_response appendContentString:cancelAction];
      [_response appendContentString:swapOnAction];

      [_response appendContentString:@"\" onDragLeave=\""];
      [_response appendContentString:swapOffAction];
     
      [_response appendContentString:@"\" onDrop=\""];
      [_response appendContentString:infoAction];
      [_response appendContentCharacter:'"'];
      
      [self appendExtraAttributesToResponse:_response inContext:_ctx];
      [_response appendContentCharacter:'>'];
    }
  }
  else if (self->elementName != nil) {
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    [_response appendContentCharacter:'>'];
  }
  
  [_ctx deleteLastElementIDComponent];
  
  /* add template */
  [_ctx appendElementIDComponent:@"p"];
  [self->template appendToResponse:_response inContext:_ctx];
  [_ctx deleteLastElementIDComponent];
  
  /* close container */
  if ((self->elementName != nil) || doDnD) {
    [_response appendContentString:@"</"];
    [_response appendContentString:htmlEl];
    [_response appendContentCharacter:'>'];
  }
}

/* accessors */

- (id)template {
  return self->template;
}

@end /* WEDropContainer */


@implementation WEDropScript

static NSString *dropScript = 
#include "WEDropScript.jsm"
;

+ (void)appendDropScriptToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  BOOL doDnD;
  
  doDnD = [[[_ctx request] clientCapabilities] doesSupportDHTMLDragAndDrop];
  
  if (![[_ctx valueForKey:@"WEDropContainerScriptDone"] boolValue] && doDnD) {
    [_response appendContentString:dropScript];
    
    [_ctx takeValue:[NSNumber numberWithBool:YES]
          forKey:@"WEDropContainerScriptDone"];
  }
}

- (void)appendToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  [[self class] appendDropScriptToResponse:_response inContext:_ctx];
}

@end /* WEDropScript */
