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

#include <NGObjWeb/WOHTMLDynamicElement.h>

@interface WOJavaScript : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *scriptFile;
  WOAssociation *scriptString;
  WOAssociation *scriptSource;
  WOAssociation *hideInComment;
  
  WOAssociation *type;
}

@end /* WOJavaScript */

#include "WOElement+private.h"
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOApplication.h>
#include "decommon.h"

@implementation WOJavaScript

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmp
{
  if ((self = [super initWithName:_name associations:_config template:_tmp])) {
    self->scriptFile    = OWGetProperty(_config, @"scriptFile");
    self->scriptString  = OWGetProperty(_config, @"scriptString");
    self->scriptSource  = OWGetProperty(_config, @"scriptSource");
    self->hideInComment = OWGetProperty(_config, @"hideInComment");
    self->type          = OWGetProperty(_config, @"type");
  }
  return self;
}

- (void)dealloc {
  [self->type          release];
  [self->scriptFile    release];
  [self->scriptString  release];
  [self->scriptSource  release];
  [self->hideInComment release];
  [super dealloc];
}

/* response generation */

- (void)appendScriptFileToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx 
{
  NSString *s;

  if (self->scriptFile == nil)
    return;
  if ((s = [self->scriptFile stringValueInComponent:[_ctx component]]) == nil)
    return;

  /* load file */

  if ([s isAbsolutePath]) {
    s = [[NSString alloc] initWithContentsOfFile:s];
  }
  else {
    WOResourceManager *rm;
    NSArray           *languages;
          
    if ((rm = [[_ctx component] resourceManager]) == nil)
      rm = [[_ctx application] resourceManager];
    
    languages = [_ctx resourceLookupLanguages];
    s         = [rm pathForResourceNamed:s inFramework:nil languages:languages];
    if (s)  s = [[NSString alloc] initWithContentsOfFile:s];
  }

  /* append to response */
  
  if (s) WOResponse_AddString(_response, s);
  [s release];
}

- (void)appendScriptContentToResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx 
{
  if (self->scriptString) {
    NSString *s;

    if ((s = [self->scriptString stringValueInComponent:[_ctx component]]))
      WOResponse_AddString(_response, s);
  }
  
  if (self->scriptFile)
    [self appendScriptFileToResponse:_response inContext:_ctx];
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString    *st;
  BOOL        hide;

  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  sComponent = [_ctx component];
  hide       = [self->hideInComment boolValueInComponent:sComponent];

  WOResponse_AddCString(_response, "<script");

  if ((st = [self->type stringValueInComponent:sComponent]) != nil) {
    WOResponse_AddCString(_response, " type=\"");
    [_response appendContentHTMLAttributeValue:st];
    WOResponse_AddCString(_response, "\"");
  }
  else {
    WOResponse_AddCString(_response, " type=\"text/javascript\"");
  }

  /* add URL to script */
  if (self->scriptSource != nil) {
    st = [self->scriptSource stringValueInComponent:sComponent];
    WOResponse_AddCString(_response, " src=\"");
    [_response appendContentHTMLAttributeValue:st];
    WOResponse_AddCString(_response, "\"");
  }
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString != nil) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                           sComponent]);
  }
  WOResponse_AddChar(_response, '>');
  if (hide) 
    WOResponse_AddCString(_response, "<!-- hide from older browsers\n");
  
  [self appendScriptContentToResponse:_response inContext:_ctx];
  
  if (hide) 
    WOResponse_AddCString(_response, "// hide from older browsers -->");
  WOResponse_AddCString(_response, "</script>");
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [[NSMutableString alloc] init];
  
  str = [NSMutableString stringWithCapacity:64];
  if (self->scriptFile)   [str appendFormat:@" file=%@",   self->scriptFile];
  if (self->scriptString) [str appendFormat:@" string=%@", self->scriptString];
  if (self->scriptSource) [str appendFormat:@" source=%@", self->scriptSource];
  if (self->hideInComment)
    [str appendFormat:@" hide=%@",   self->hideInComment];
  
  return str;
}

@end /* WOJavaScript */
