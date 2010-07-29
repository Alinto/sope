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

#include "WOElement+private.h"
#include <NGObjWeb/WOHTMLDynamicElement.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include "decommon.h"

@class WOAssociation;

@interface WOBody : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *filename;  // path relative to WebServerResources
  WOAssociation *framework;
  WOAssociation *src;       // absolute URL
  WOAssociation *value;     // image data (eg from a database)

  WOElement *template;
}

@end

@implementation WOBody

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    self->filename  = OWGetProperty(_config, @"filename");
    self->framework = OWGetProperty(_config, @"framework");
    self->src       = OWGetProperty(_config, @"src");
    self->value     = OWGetProperty(_config, @"value");
    
    self->template  = [_c retain];
    
    if (self->value) NSLog(@"WARNING: value not yet supported !");
  }
  return self;
}

- (void)dealloc {
  [self->template  release];
  [self->framework release];
  [self->filename  release];
  [self->src       release];
  [self->value     release];
  [super dealloc];
}

/* accessors */

- (id)template {
  return self->template;
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_req inContext:_ctx];
}
- (id)invokeActionForRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  return [self->template invokeActionForRequest:_req inContext:_ctx];
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  NSString *uUri;
  NSString *uFi;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  uUri = [self->src      stringValueInComponent:[_ctx component]];
  uFi  = [self->filename stringValueInComponent:[_ctx component]];
  
  WOResponse_AddCString(_response, "<body");
  
  if ([uFi length] > 0) {
    NSArray *languages;
    WOResourceManager *rm;
    NSString  *frameworkName;

    WOResponse_AddCString(_response, " background=\"");
      
    languages = [_ctx resourceLookupLanguages];
      
    if ((rm = [[_ctx component] resourceManager]) == nil)
      rm = [[_ctx application] resourceManager];
      
    /* If 'framework' binding is not set, use parent component's framework */
    if (self->framework){
      frameworkName = [self->framework stringValueInComponent:[_ctx component]];
      if (frameworkName != nil && [frameworkName isEqualToString:@"app"])
        frameworkName = nil;
    }
    else
      frameworkName = [[_ctx component] frameworkName];
    
    uFi = [rm urlForResourceNamed:uFi
              inFramework:frameworkName
              languages:languages
              request:[_ctx request]];
    if (uFi == nil) {
      NSLog(@"%@: did not find resource '%@' (languages=%@)",
            [_ctx component],
            [self->filename stringValueInComponent:[_ctx component]],
            [languages componentsJoinedByString:@","]);
      uFi = uUri;
    }
    [_response appendContentHTMLAttributeValue:uFi];
    WOResponse_AddChar(_response, '"');
  }
  else if ([uUri length] > 0) {
    WOResponse_AddCString(_response, " background=\"");
    [_response appendContentHTMLAttributeValue:uUri];
    WOResponse_AddChar(_response, '"');
  }
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                              [_ctx component]]);
  }
  WOResponse_AddChar(_response, '>');
  
  [self->template appendToResponse:_response inContext:_ctx];
  
  WOResponse_AddCString(_response, "</body>");
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:128];
  if (self->filename)  [str appendFormat:@" filename=%@",  self->filename];
  if (self->framework) [str appendFormat:@" framework=%@", self->framework];
  if (self->src)       [str appendFormat:@" src=%@",       self->src];
  if (self->value)     [str appendFormat:@" value=%@",     self->value];
  if (self->template)  [str appendFormat:@" template=%@",  self->template];
  
  return str;
}

@end /* WOBody */
