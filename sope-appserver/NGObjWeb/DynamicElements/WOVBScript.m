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
#include "WOElement+private.h"
#include <NGObjWeb/WOResourceManager.h>
#include <NGObjWeb/WOApplication.h>
#include "decommon.h"

@interface WOVBScript : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *scriptFile;
  WOAssociation *scriptString;
  WOAssociation *scriptSource;
  WOAssociation *hideInComment;
}

@end /* WOVBScript */

@implementation WOVBScript

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmpl
{
  if ((self = [super initWithName:_name associations:_config template:_tmpl])) {
    self->scriptFile    = OWGetProperty(_config, @"scriptFile");
    self->scriptString  = OWGetProperty(_config, @"scriptString");
    self->scriptSource  = OWGetProperty(_config, @"scriptSource");
    self->hideInComment = OWGetProperty(_config, @"hideInComment");
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->scriptFile);
  RELEASE(self->scriptString);
  RELEASE(self->scriptSource);
  RELEASE(self->hideInComment);
  [super dealloc];
}
#endif

// ******************** responder ********************

#define StrVal(__x__) [self->__x__ stringValueInComponent:sComponent]

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  BOOL        hide;

  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;

  sComponent = [_ctx component];
  hide       = [self->hideInComment boolValueInComponent:sComponent];
    
  WOResponse_AddCString(_response, "<script language=\"VBScript\" ");

  /* add URL to script */
  if (self->scriptSource) {
    WOResponse_AddCString(_response, " src=\"");
    [_response appendContentHTMLAttributeValue:
                 [self->scriptSource stringValueInComponent:sComponent]];
    WOResponse_AddCString(_response, "\"");
  }
  
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                                                 [_ctx component]]);
  }
  WOResponse_AddChar(_response, '>');
  if (hide) WOResponse_AddCString(_response, "<!--hide from older browsers");

  /* add a script string */
  if (self->scriptString) {
    NSString *s = [self->scriptString stringValueInComponent:sComponent];

    if (s) WOResponse_AddString(_response, s);
  }

  /* add a script file */
  if (self->scriptFile) {
    NSString *s;

    s = [NSString stringWithContentsOfFile:
                    [self->scriptFile stringValueInComponent:sComponent]];
    if (s) WOResponse_AddString(_response, s);
  }
  
  if (hide) WOResponse_AddCString(_response, "//hide from older browsers-->");
  WOResponse_AddCString(_response, "</script>");
}

// description

- (NSString *)associationDescription {
  NSMutableString *str = [[NSMutableString alloc] init];

  if (self->scriptFile)    [str appendFormat:@" file=%@",   self->scriptFile];
  if (self->scriptString)  [str appendFormat:@" string=%@", self->scriptString];
  if (self->scriptSource)  [str appendFormat:@" source=%@", self->scriptSource];
  if (self->hideInComment)
    [str appendFormat:@" hide=%@",   self->hideInComment];
  
  return AUTORELEASE(str);
}

@end /* WOVBScript */
