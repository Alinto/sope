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

#import <NGObjWeb/NGObjWeb.h>
#import <Foundation/Foundation.h>
#ifdef __APPLE__
#  import <NGObjWeb/WEClientCapabilities.h>
#else
#  import <WEExtensions/WEClientCapabilities.h>
#endif
#import "JSMenuItem.h"

@implementation JSMenuItem

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if ((self = [super initWithName:_name associations:_config template:_subs]))
  {
    self->action = OWGetProperty(_config,@"action");
    self->href   = OWGetProperty(_config,@"href");
    self->string = OWGetProperty(_config,@"string");

    self->template = [_subs retain];
  }
  return self;
}

- (void)dealloc {
  [self->action   release];
  [self->href     release];
  [self->string   release];
  [self->template release];
  [super dealloc];
}

- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  if (![[_ctx elementID] isEqualToString:[_ctx senderID]]) {
    NSLog(@"ERROR: elementID %@ and senderID %@ do not match.",
          [_ctx elementID], [_ctx senderID]);
    return nil;
  }
  return [self->action valueInComponent:[_ctx component]];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent          *comp;
  NSString             *tmp;
  NSString             *url;
  WEClientCapabilities *ccaps;
  BOOL                 ie, ns;
  NSString             *eid;
  
  if ([_ctx isRenderingDisabled]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  comp  = [_ctx component];
  ccaps = [[_ctx request] clientCapabilities];
  ie    = [ccaps isJavaScriptBrowser] && [ccaps isInternetExplorer];
  ns    = [ccaps isJavaScriptBrowser] && [ccaps isNetscape];
  eid   = [_ctx objectForKey:@"eid"];

  NSAssert(self->action != nil || self->href != nil,
           @"ERROR: no action or href defined...");
  if (self->action != nil)
    url = [_ctx componentActionURL];
  else if (self->href != nil)
    url = [self->href stringValueInComponent:comp];
  else
    url = nil;

  if (ie) {
    tmp  = [[NSString alloc] initWithFormat:
                     @"<div align=\"left\" class=\"menuItem\" url=\"%@\">"
                     @"%@</div>",
                     url, [self->string stringValueInComponent:comp]];
  }
#if 0
  else if (ns)
    tmp = [[NSString alloc] initWithFormat:
                    @"m%@.addMenuItem(\"%@\",\"top.window.location='%@'\");",
                    //@"m%@.addMenuItem(\"%@\",\"alert('%@')\");",
                    eid, [self->string stringValueInComponent:comp], url];
#endif
  else {
    return;
#if 0
    tmp = [[NSString alloc] initWithFormat:
                    @"<a href=\"%@\">%@</a>", url,
                    [self->string stringValueInComponent:[_ctx component]]];
#endif
  }
  
  [_response appendContentString:tmp];
  [tmp release];
}

@end /* JSMenuItem */
