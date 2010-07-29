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

#include "JSMenu.h"
#include "JSMenuItem.h"
#include <NGObjWeb/NGObjWeb.h>
#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

@implementation JSMenu

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if((self = [super initWithName:_name associations:_config template:_subs])) {
    self->fgColor     = OWGetProperty(_config,@"fgColor");
    self->bgColor     = OWGetProperty(_config,@"bgColor");
    self->fgColorHigh = OWGetProperty(_config,@"fgColorHigh");
    self->bgColorHigh = OWGetProperty(_config,@"bgColorHigh");
    self->borderColor = OWGetProperty(_config,@"borderColor");
    self->borderWidth = OWGetProperty(_config,@"borderWidth");
    self->fontSize    = OWGetProperty(_config,@"fontSize");
    self->width       = OWGetProperty(_config,@"width");
    self->leftPadding = OWGetProperty(_config,@"leftPadding");
    self->string      = OWGetProperty(_config,@"string");
    self->bindAtId    = OWGetProperty(_config,@"bindAtId");
    self->align       = OWGetProperty(_config,@"align");
    self->tag         = OWGetProperty(_config,@"tag");

    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->fgColor     release];
  [self->bgColor     release];
  [self->fgColorHigh release];
  [self->bgColorHigh release];
  [self->borderWidth release];
  [self->fontSize    release];
  [self->width       release];
  [self->leftPadding release];
  [self->string      release];
  [self->bindAtId    release];
  [self->align       release];
  [self->tag         release];
  [self->template    release];
  [super dealloc];
}

/* handling requests */

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_req inContext:_ctx];
}

/* generate response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent          *comp;
  NSString             *tmp;
  NSString             *eid; // [_ctx elementID]
  WEClientCapabilities *ccaps;
  BOOL                 ie, ns;

  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  eid   = [[[_ctx elementID] componentsSeparatedByString:@"."]
                  componentsJoinedByString:@"_"];
  comp  = [_ctx component];
  ccaps = [[_ctx request] clientCapabilities];
  ie    = [ccaps isJavaScriptBrowser] && [ccaps isInternetExplorer];
  ns    = [ccaps isJavaScriptBrowser] && [ccaps isNetscape];

  [_ctx setObject:eid forKey:@"eid"];

  if (!ie) {
    return;

    [_response appendContentString:@"<font size=\"-1\">["];
    [self->template appendToResponse:_response inContext:_ctx];
    [_response appendContentString:@"]</font>"];
    return;
  }

  if (ie) {
    if ([_ctx objectForKey:@"jsmenu_included"] == nil) {
      [_ctx setObject:@"done" forKey:@"jsmenu_included"];
      tmp = [[NSString alloc] initWithFormat:
                      @"<style>\n"
                      @".menuItem {\n"
                      @"  font:%@pt sans-serif;\n"
                      @"  width:%@;\n"
                      @"  padding-left:%@;\n"
                      @"  background-Color:%@;\n"
                      @"  color:%@;\n"
                      @"  text-align:%@\n"
                      @"}\n"
                      @".highlightItem {\n"
                      @"  font:%@pt sans-serif;\n"
                      @"  width:%@;\n"
                      @"  padding-left:%@;\n"
                      @"  background-Color:%@;\n"
                      @"  color:%@\n"
                      @"  text-align:%@\n"
                      @"}\n"
                      @"</style>\n",
                      [self->fontSize stringValueInComponent:comp],
                      [self->width stringValueInComponent:comp],
                      [self->leftPadding stringValueInComponent:comp],
                      [self->bgColor stringValueInComponent:comp],
                      [self->fgColor stringValueInComponent:comp],
                      [self->align stringValueInComponent:comp],
                      [self->fontSize stringValueInComponent:comp],
                      [self->width stringValueInComponent:comp],
                      [self->leftPadding stringValueInComponent:comp],
                      [self->bgColorHigh stringValueInComponent:comp],
                      [self->fgColorHigh stringValueInComponent:comp],
                      [self->align stringValueInComponent:comp]];
      [_response appendContentString:tmp];
      [tmp release];

      tmp = [[NSString alloc] initWithFormat:
                      @"<script language=\"javascript\">\n"
                      @"var menuOpened;\n"
                      @"function displayMenu(m) {\n"
                      @"  closeMenu();\n"
                      @"  if(m.parentNode != event.srcElement)\n"
                      @"    return false;\n"
                      @"  menuOpened=m;\n"
                      @"  m.style.posLeft=event.clientX+document.body.scrollLeft;\n"
                      @"  m.style.posTop=event.clientY+document.body.scrollTop;\n"
                      @"  if(document.body.clientWidth<event.clientX+%@+5)\n"
                      @"    m.style.posLeft-=%@;\n"
                      @"  m.style.display=\"\";\n"
                      @"  m.setCapture();\n"
                      @"  return false;\n"
                      @"}\n"
                      @"function switchMenu() {\n"
                      @"  el=event.srcElement;\n"
                      @"  if(el.className==\"menuItem\")\n"
                      @"    el.className=\"highlightItem\";\n"
                      @"  else if(el.className==\"highlightItem\")\n"
                      @"    el.className=\"menuItem\";\n"
                      @"}\n"
                      @"function clickMenu(m) {\n"
                      @"  m.releaseCapture();\n"
                      @"  m.style.display=\"none\";\n"
                      @"  el=event.srcElement;\n"
                      @"  if(m==el.parentNode)window.location=el.url;\n"
                      @"  return false;\n"
                      @"}\n"
                      @"function closeMenu() {\n"
                      @"  if(menuOpened==null)"
                      @"    return;\n"
                      @"  menuOpened.releaseCapture();\n"
                      @"  menuOpened.style.display=\"none\";\n"
                      @"  menuOpened=null;\n"
                      @"}\n"
                      @"</script>\n",
                      [self->width stringValueInComponent:comp],
                      [self->width stringValueInComponent:comp]];
      [_response appendContentString:tmp];
      [tmp release];
    }
    tmp = [[NSString alloc] initWithFormat:
                    @"<div id=\"m%@\" onclick=\"return clickMenu(m%@);\" "
                    @"onmouseover=\"switchMenu();\" "
                    @"onmouseout=\"switchMenu();\" "
                    @"style=\"position:absolute;display:none;width:%@;"
                    @"background-Color:%@;border:outset %@px %@;"
                    @"text-decoration:none\">",
                    eid, eid,
                    [self->width       stringValueInComponent:comp],
                    [self->bgColor     stringValueInComponent:comp],
                    [self->borderWidth stringValueInComponent:comp],
                    [self->borderColor stringValueInComponent:comp]];
    [_response appendContentString:tmp];
    [tmp release];

    [self->template appendToResponse:_response inContext:_ctx];

    [_response appendContentString:@"</div>"];
#if 0
    if ([self->tag stringValueInComponent:comp] != nil)
      tmp = [[NSString alloc] initWithFormat:
                      @"<script id=\"s%@\" language=\"javascript\">"
                      @"function c%@(){return displayMenu(m%@);}"
                      @"tmp=document.getElementById(\"s%@\");"
                      @"i=5;"
                      @"while((tmp.tagName!=\"%@\")&&i--)"
                      @"tmp=tmp.parentNode;"
                      @"tmp.oncontextmenu=c%@;"
                      @"</script>",
                      eid, eid, eid, eid,
                      [self->tag stringValueInComponent:comp], eid];
    else
#endif
      tmp = [[NSString alloc] initWithFormat:
                      @"<script id=\"s%@\" language=\"javascript\">"
                      @"function c%@() { return displayMenu(m%@); }"
                      @"s%@.parentNode.oncontextmenu=c%@;"
                      @"</script>",
                      eid, eid, eid, eid, eid];
    [_response appendContentString:tmp];
    [tmp release];
  }
#if 0
  if (ns) {
    if ([_ctx objectForKey:@"jsmenu_included"] == nil) {
      tmp = [[NSString alloc] initWithFormat:
                      @"<script language=\"javascript1.2\" "
                      @"src=\"http://inster:9000/sascha/menu07.js\">"
                      @"</script>\n"
                      @"<script language=\"javascript1.2\">"
                      @"function onLoad(){m%@.writeMenus();}</script>\n",
                      eid];
      [_response appendContentString:tmp];
      [tmp release];
    }

    tmp = [[NSString alloc] initWithFormat:
                    @"<script language=\"javascript1.2\">\n"
                    @"m%@=new Menu();",eid];
    [_response appendContentString:tmp];
    [tmp release];

    [self->template appendToResponse:_response inContext:_ctx];

    tmp = [[NSString alloc] initWithFormat:
                    @"</script>\n"
                    @"<a href=\"#\" onclick=\"showMenu(m%@);return false;\">"
                    @"M</a>", eid];
    [_response appendContentString:tmp];
    [tmp release];

    [_ctx setObject:@"done" forKey:@"jsmenu_included"];
  }
#endif
}

@end /* JSMenu */
