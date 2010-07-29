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

  < scriptName   (obligatory !!!)
  > identifier
  > prefix

  Generates an ShiftClick JavaScript for CheckBoxes.

  Example:

  // wod:
  ShiftClickScript: JSShiftClick {
    scriptName = scriptName;
  }

  Repetition: WORepetition {
    list = (1, 2, 3, 4, 5, 6, 7, 8, 9);
    item = index;
  }
  CheckBox: WOCheckBox {
    checked = checked;
    value   = index;      // = index"              this must be done !!!
    onClick = scriptCall; // = "scriptName(index)" this must be done !!!
  }

  // html:

  <FORM....>
  
    <#ShiftClickScript />
    <#Repetition>
      <#CheckBox />
    </#Repetition>

  </FORM>
  
*/

@interface JSShiftClick : WODynamicElement
{
  WOAssociation *identifier;
  WOAssociation *prefix;
  WOAssociation *scriptName;
}
@end

#include "common.h"
#include <NGObjWeb/WEClientCapabilities.h>

static NSString *JSShiftClick_Script =
      @"<script language=\"JavaScript\">\n"
      @"<!--\n"
      @"var ns = (document.layers) ? true : false;\n"
      @"var ie = (document.all) ? true : false;\n"
      @"var last = -1;\n"
      @"function shiftClick%@SearchElement(el) { \n"
      @"  for (i = 0; i < document.forms.length; i++) { \n"
      @"    for (j = 0; j < document.forms[i].elements.length; j++) { \n"
      @"      if (document.forms[i].elements[j].value == el) { \n"
      @"        return document.forms[i].elements[j]; \n"
      @"      } \n"
      @"    } \n"
      @"  } \n"
      @"  return false; \n"
      @"} \n\n"
      @"function shiftClick%@(z) {\n"
      @"  if (ie) {\n"
      @"    var plusShift = window.event.shiftKey;\n"
      @"    if (plusShift && last >= 0) {\n"
      @"      var actEl    = shiftClick%@SearchElement('%@'+last); \n"
      @"      if (actEl) { \n "
      @"        var actState = actEl.checked;\n"
      @"        if (z<last) { var e1 = z; var e2 = last; }\n"
      @"        else { var e1 = last; var e2 = z; }\n"
      @"        for (idx = e1; idx<= e2; idx++) {\n"
      @"          actEl = shiftClick%@SearchElement('%@' + idx); \n"
      @"          actEl.checked = actState;\n"
      @"        }\n"
      @"      } \n"
      @"    }\n"
      @"    last = z;\n"
      @"  }\n"
      @"}\n"
      @"//-->\n"
      @"</script>";

@implementation JSShiftClick

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmp
{
  if ((self = [super initWithName:_name associations:_config template:_tmp])) {
    self->identifier = WOExtGetProperty(_config, @"identifier");
    self->prefix     = WOExtGetProperty(_config, @"prefix");
    self->scriptName = WOExtGetProperty(_config, @"scriptName");
  }
  return self;
}

- (void)dealloc {
  [self->identifier release];
  [self->prefix     release];
  [self->scriptName release];
  [super dealloc];
}

/* response generation */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WEClientCapabilities *ccaps = nil;
  NSString *eid  = nil;
  NSString *prfx = nil;

  if ([_ctx isRenderingDisabled]) return;

  ccaps = [[_ctx request] clientCapabilities];

  eid = [self->identifier stringValueInComponent:[_ctx component]];
  eid = (eid) ? eid : [_ctx elementID];
  eid = [[eid componentsSeparatedByString:@"."]
              componentsJoinedByString:@"_"];
  
  prfx = [self->prefix stringValueInComponent:[_ctx component]];
  prfx = (prfx != nil) ? prfx : (NSString *)@"";

  if ([ccaps isJavaScriptBrowser]) {
    NSString *s;
    
    s = [[NSString alloc] initWithFormat:JSShiftClick_Script,
                          eid, eid, eid, prfx, eid, prfx];
    [_response appendContentString:s];
    [s release];
  }
  if ([self->scriptName isValueSettable]) {
    NSString *sName = nil;

    sName = [@"shiftClick" stringByAppendingString:eid];
    [self->scriptName setValue:sName inComponent:[_ctx component]];
  }
#if DEBUG
  else {
    NSLog(@"Warning: JSShiftClick: 'scriptName' is not settable!!!");
  }
#endif
}

@end /* JSShiftClick */
