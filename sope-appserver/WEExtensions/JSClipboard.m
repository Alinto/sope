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

#include <NGObjWeb/NGObjWeb.h>
#include <NGObjWeb/WEClientCapabilities.h>
#include "common.h"

@interface JSClipboard : WODynamicElement
{
  WOAssociation *filename;
  WOAssociation *imgURL;
  WOAssociation *string;
  WOAssociation *toolTip;
  WOAssociation *value;
}
@end

@implementation JSClipboard

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_subs
{
  if((self = [super initWithName:_name associations:_config template:_subs])) {
    self->filename = OWGetProperty(_config,@"filename");
    self->imgURL   = OWGetProperty(_config,@"imgURL");
    self->string   = OWGetProperty(_config,@"string");
    self->toolTip  = OWGetProperty(_config,@"toolTip");
    self->value    = OWGetProperty(_config,@"value");
  }
  return self;
}

- (void)dealloc {
  [self->imgURL  release];
  [self->string  release];
  [self->toolTip release];
  [self->value   release];
  [super dealloc];
}

/* operations */

- (NSString *)imageByFilename:(NSString *)_name
  inContext:(WOContext *)_ctx
  framework:(NSString *)_framework
{
  WOResourceManager *rm;
  NSString          *tmp;
  NSArray           *languages;

  rm        = [[_ctx application] resourceManager];
  languages = [_ctx resourceLookupLanguages];
  tmp       = [rm urlForResourceNamed:_name
                  inFramework:_framework
                  languages:languages
                  request:[_ctx request]];
  return tmp;
}

- (void)appendToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOComponent          *comp;
  NSString             *tmp;
  NSString             *tt;    // toolTip
  WEClientCapabilities *ccaps;

  if ([_ctx isRenderingDisabled]) return;

  comp    = [_ctx component];
  ccaps   = [[_ctx request] clientCapabilities];
  tt      = [self->toolTip stringValueInComponent:comp];
  tt      = tt != nil ? tt : (NSString *)@"";

  if (![ccaps isInternetExplorer]) return;
  if ([ccaps isMacBrowser]) return;

  tmp = [[NSString alloc] initWithFormat:
                  @"<a href=\"#\" onclick=\"javascript:clipboardData."
                  @"setData('text', '%@');return false;\" title=\"%@\">",
                  [self->value stringValueInComponent:comp], tt];
  [_response appendContentString:tmp];
  [tmp release]; tmp = nil;
  
  NSAssert(self->imgURL != nil || self->string != nil || self->filename != nil,
           @"ERROR: no imageURL or string defined...");

  if (self->filename) {
    NSString *imageFilename;

    imageFilename =
      [self imageByFilename:[self->filename stringValueInComponent:comp]
            inContext:_ctx
            framework:[comp frameworkName]];

    tmp = [[NSString alloc] initWithFormat:
                    @"<img border=\"0\"src=\"%@\" /></a>",
                    imageFilename];
  }
  else if (self->imgURL) {
    tmp = [[NSString alloc] initWithFormat:
                    @"<img border=\"0\"src=\"%@\" /></a>",
                    [self->imgURL stringValueInComponent:comp]];
  }
  else {
    tmp = [[NSString alloc] initWithFormat:
                    @"%@</a>",
                    [self->string stringValueInComponent:comp]];
  }
  [_response appendContentString:tmp];
  [tmp release];
}

@end /* JSClipboard */
