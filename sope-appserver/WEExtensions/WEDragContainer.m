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

/*
  renders this:

  <...small script...>
  <SPAN onDragStart="fnSetInfo($tag,$effectsAllowed)">
  $content
  </SPAN>

*/

@interface WEDragContainer : WODynamicElement
{
  WOElement     *template;
  WOAssociation *tag;
  WOAssociation *effectsAllowed;
  WOAssociation *elementName;
  WOAssociation *isDraggable;
  
  WOAssociation *object;
  WOAssociation *droppedObject;
}
@end

@interface WEDragScript : WODynamicElement
+ (void)appendDragScriptToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx;
@end

#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

//#define DEBUG_TAKEVALUES 1

@implementation WEDragContainer

static BOOL debugTakeValues = NO;

+ (int)version {
  return 0 + [super version];
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->tag            = WOExtGetProperty(_config, @"tag");
    self->effectsAllowed = WOExtGetProperty(_config, @"effectsAllowed");
    self->elementName    = WOExtGetProperty(_config, @"elementName");
    self->isDraggable    = WOExtGetProperty(_config, @"isDraggable");
    
    self->object         = WOExtGetProperty(_config, @"object");
    self->droppedObject  = WOExtGetProperty(_config, @"droppedObject");
    
    self->template = [_t retain];
  }
  return self;
}

- (void)dealloc {
  [self->isDraggable    release];
  [self->object         release];
  [self->droppedObject  release];
  [self->tag            release];
  [self->elementName    release];
  [self->effectsAllowed release];
  [self->template       release];
  [super dealloc];
}

/* processing request values */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id formValue;
  
  if ((formValue = [_rq formValueForKey:[_ctx elementID]]) != nil) {
    id obj;

    if (debugTakeValues) {
      [[_ctx component]
	     debugWithFormat:@"WEDragContainer: got value '%@' for id '%@'",
               formValue, [_ctx elementID]];
    }

    obj = [self->object valueInComponent:[_ctx component]];
    
    if (debugTakeValues)
      NSLog(@"DRAG MATCH => ok, obj is %@",obj);
    
    if ([self->droppedObject isValueSettable])
      [self->droppedObject setValue:obj inComponent:[_ctx component]];
    
    if (obj) {
      [_ctx takeValue:obj forKey:@"WEDragContainer_DropObject"];
    }
  }
  else if (debugTakeValues) {
    [[_ctx component]
           debugWithFormat:@"WEDragContainer: got no value for id '%@'",
             [_ctx elementID]];
  }
  
  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_rq inContext:_ctx];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *tmp = nil;
  NSString *ttag;
  BOOL     doDnD;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  doDnD = [[[_ctx request] clientCapabilities] doesSupportDHTMLDragAndDrop];
    
  if (doDnD) {
    if (self->isDraggable)
      doDnD = [self->isDraggable boolValueInComponent:[_ctx component]];
  }
  
  [WEDragScript appendDragScriptToResponse:_response inContext:_ctx];
  
  ttag = [self->tag stringValueInComponent:[_ctx component]];

  if (doDnD) {
    NSString *teffect, *tdragContent;

    teffect = self->effectsAllowed
      ? [self->effectsAllowed stringValueInComponent:[_ctx component]]
      : (NSString *)@"all";
    
    tdragContent = @"this.innerHTML";
    
    tmp = @"fnSetInfo('%@?%@','%@', %@)";
    tmp = [NSString stringWithFormat:tmp,
                      [_ctx elementID], ttag,
                      teffect,
                      tdragContent];
  }

  if (self->elementName || doDnD) {
    /* Note: not using lowercase names since this might break JS? */
    [_response appendContentString:@"<SPAN "];
    [_response appendContentString:@"ID=\"span_"];
    [_response appendContentString:[_ctx elementID]];
    [_response appendContentString:@"\" "];
  }
  
  if (doDnD) {
    [_response appendContentString:@" onDragStart=\""];
    [_response appendContentString:tmp];
    [_response appendContentString: @"\""];
    [_response appendContentString:@" onDrag=\"fnDrag()\""];
    [_response appendContentString:@" onDragEnd=\"fnDragEnd()\""];
  }
  
  if (self->elementName || doDnD) {
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    [_response appendContentString:@">"];
  }
  
  /* add template */
  [self->template appendToResponse:_response inContext:_ctx];
  
  /* close container */
  if (self->elementName || doDnD)
    [_response appendContentString:@"</SPAN>"];
}

/* accessors */

- (id)template {
  return self->template;
}

@end /* WEDragContainer */


@implementation WEDragScript

+ (void)appendDragScriptToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString *dragScript;
  BOOL     doDnD;
  
  doDnD = [[[_ctx request] clientCapabilities] doesSupportDHTMLDragAndDrop];
  
  if (![[_ctx valueForKey: @"WEDragContainerScriptDone"] boolValue] && doDnD) {
    dragScript =
      @"<DIV ID=\"DragDIV\" STYLE=\"position: absolute; visibility: hidden; width: 150;\"></DIV>"
      @"<SCRIPT LANGUAGE=\"JScript\">\n"
      @"<!--\n"
      @"function fnSetInfo(objData, effects, dragContent) {\n"
      @"  event.dataTransfer.clearData(\"Text\");\n"
      @"  event.dataTransfer.setData(\"Text\", objData);\n"
      @"  event.dataTransfer.effectAllowed = effects;\n "
      @"  DragDIV.innerHTML = dragContent;\n"
      @"  DragDIV.style.visibility = \"visible\";\n "
      @"  DragDIV.style.top  =window.event.clientY+document.body.scrollTop;\n"
      @"  DragDIV.style.left =window.event.clientX+document.body.scrollLeft;\n"
      @"  DragDIV.style.zIndex += 20; \n"
      @"}\n"
      @"function fnDrag() {\n"
      @"  DragDIV.style.top  =window.event.clientY+document.body.scrollTop;\n"
      @"  DragDIV.style.left =window.event.clientX+document.body.scrollLeft;\n"
      @"}\n"
      @"function fnDragEnd() {\n"
      @"  DragDIV.innerHTML = \"\";\n"
      @"  DragDIV.style.visibility = \"hidden\";\n"
      @"}\n"
      @"// -->\n"
      @"</SCRIPT>";

    [_response appendContentString: dragScript];
    
    [_ctx takeValue: [NSNumber numberWithBool: YES] forKey:
          @"WEDragContainerScriptDone"];
  }
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  [[self class] appendDragScriptToResponse:_response inContext:_ctx];
}

@end /* WEDragScript */
