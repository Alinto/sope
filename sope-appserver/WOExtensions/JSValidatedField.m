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

@interface JSValidatedField : WODynamicElement
{
  WOAssociation *inputText;
  WOAssociation *errorMessage;
  WOAssociation *formName;
  WOAssociation *fieldSize;
  WOAssociation *inputIsRequired;
  WOAssociation *requiredText;

  /* non WO */
  WOElement     *template;
  WOAssociation *escapeJS;
}
@end

#include <NGObjWeb/NSString+JavaScriptEscaping.h>
#include <NGExtensions/NSString+Ext.h>
#include "common.h"

@implementation JSValidatedField

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
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    self->inputText       = WOExtGetProperty(_config,@"inputText");
    self->errorMessage    = WOExtGetProperty(_config,@"errorMessage");
    self->formName        = WOExtGetProperty(_config,@"formName");
    self->fieldSize       = WOExtGetProperty(_config,@"fieldSize");
    self->inputIsRequired = WOExtGetProperty(_config,@"inputIsRequired");
    self->requiredText    = WOExtGetProperty(_config,@"requiredText");
    self->escapeJS        = WOExtGetProperty(_config,@"escapeJS");

    if (!self->inputText)
      NSLog(@"WARNING: JSValidatedField: 'inputText' not bound.");
    if (!self->errorMessage)
      NSLog(@"WARNING: JSValidatedField: 'errorMessage' not bound, "
            @"using default.");
    if (!self->formName)
      NSLog(@"ERROR: JSValidatedField: 'formName' not bound.");

    self->template = [_t retain];
  }
  return self;
}

- (void)dealloc {
  [self->inputText       release];
  [self->errorMessage    release];
  [self->fieldSize       release];
  [self->inputIsRequired release];
  [self->requiredText    release];
  [self->template        release];
  [self->escapeJS        release];
  [super dealloc];
}

/* operations */

- (NSString *)buildJSSaveID:(NSString *)_id {
  return [_id stringByReplacingString:@"." withString:@"x"];
}

/* processing requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id       formValue;
  NSString *elID;

  elID = [self buildJSSaveID:[_ctx elementID]];
  
  if ((formValue = [_rq formValueForKey:elID])) {
    if ([self->inputText isValueSettable])
      [self->inputText setValue: formValue inComponent:[_ctx component]];
  }

  [self->template takeValuesFromRequest:_rq inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_rq inContext:_ctx];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  NSString    *elID;
  WOComponent *comp;
  NSString    *tmp;
  int         objectsCount;
  NSString    *terrMesg, *tformName, *tinput, *ttext;
  NSString    *s;

  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  comp = [_ctx component];
  elID = [self buildJSSaveID:[_ctx elementID]];

  terrMesg = (self->errorMessage)
    ? [self->errorMessage stringValueInComponent:comp]
    : (NSString *)@"Invalid values.";
  if (self->escapeJS != nil && [self->escapeJS boolValueInComponent:comp])
      terrMesg = [terrMesg stringByApplyingJavaScriptEscaping];
  tformName = [self->formName stringValueInComponent:comp];
  tinput = ([self->inputIsRequired boolValueInComponent:comp])
    ? @"true"
    : @"false";
  if (self->requiredText) {
    ttext = [self->requiredText stringValueInComponent:comp];
    if (self->escapeJS != nil && [self->escapeJS boolValueInComponent:comp])
      ttext = [ttext stringByApplyingJavaScriptEscaping];
    ttext = [NSString stringWithFormat:@"\"%@\"", ttext];
  }
  else
      ttext = @"false";
  
  /* script */
  [_response appendContentString:@"<script type=\"text/javascript\">\n<!--\n"];

  if (!((objectsCount =
         [[_ctx valueForKey:@"JSValidatedFieldCounter"] intValue]))) {
    objectsCount = 0;

    tmp = @"var JSVFtestedObjects = new Array();\n"
          @"function JSValidatedFieldCheckValues() {\n"
          @"  for (var i = 0; i < JSVFtestedObjects.length; i++) {\n"
          @"    tform  = JSVFtestedObjects[i][\"form\"];\n"
          @"    tname  = JSVFtestedObjects[i][\"name\"];\n"
          @"    tinput = JSVFtestedObjects[i][\"inputIsRequired\"];\n"
          @"    ttext  = JSVFtestedObjects[i][\"requiredText\"];\n"
          @"    tmesg  = JSVFtestedObjects[i][\"errorMessage\"];\n"
          @"    obj = document.forms[tform].elements[tname];\n"
          @"    if (((tinput) && (obj.value == \"\")) || \n"
          @"        ((ttext)  && (obj.value.indexOf(ttext) == -1))) {\n"
          @"      alert(tmesg);\n"
          @"      obj.focus();\n"
          @"      return false;\n"
          @"    }\n"
          @"  }\n"
          @"  return true;\n"
          @"}\n";

    [_response appendContentString:tmp];
  }
  
  tmp = @"JSVFtestedObjects[%i] = new Array();\n"
        @"JSVFtestedObjects[%i][\"name\"]            = \"%@\";\n"
        @"JSVFtestedObjects[%i][\"form\"]            = \"%@\";\n"
        @"JSVFtestedObjects[%i][\"inputIsRequired\"] = %@;\n"
        @"JSVFtestedObjects[%i][\"requiredText\"]    = %@;\n"
        @"JSVFtestedObjects[%i][\"errorMessage\"]    = \"%@\";\n"
        @"document.%@.onsubmit = JSValidatedFieldCheckValues;\n";
  
  s = [[NSString alloc] initWithFormat:tmp,
                                              objectsCount,
                                              objectsCount, elID,
                                              objectsCount, tformName,
                                              objectsCount, tinput,
                                              objectsCount, ttext,
                                              objectsCount, terrMesg,
                tformName];
  [_response appendContentString:s];
  [s release];
  
  [_ctx takeValue:[NSNumber numberWithInt:(objectsCount + 1)]
        forKey:@"JSValidatedFieldCounter"];
  [_response appendContentString:@"\n//-->\n</script>"];

  /* input element */
  
  [_response appendContentString:@"<input type=\"text\" name=\""];
  [_response appendContentString:elID];
  [_response appendContentString:@"\" value=\""];
  [_response appendContentHTMLAttributeValue:
               [self->inputText stringValueInComponent:comp]];
  [_response appendContentString:@"\""];
  if (self->fieldSize) {
    [_response appendContentString:@" size=\""];
    [_response appendContentString:
                 [self->fieldSize stringValueInComponent:comp]];
    [_response appendContentString:@"\""];
  }

  [_response appendContentString:
	       (_ctx->wcFlags.xmlStyleEmptyElements ? @" />" : @">")];
}

@end /* JSValidatedField */
