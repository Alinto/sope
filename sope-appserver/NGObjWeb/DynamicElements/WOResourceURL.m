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

@interface WOResourceURL : WODynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *filename;  // path relative to WebServerResources
  WOAssociation *framework;
  WOAssociation *data;      // data (eg from a database)
  WOAssociation *mimeType;  // the type of data
  WOAssociation *key;       // the cache key
  WOElement     *template;  // subelements
}

@end

#include "WOElement+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include "decommon.h"

@implementation WOResourceURL

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmpl
{
  if ((self = [super initWithName:_name associations:_config template:_tmpl])) {
    self->template  = [_tmpl retain];
    self->filename  = OWGetProperty(_config, @"filename");
    self->framework = OWGetProperty(_config, @"framework");
    self->data      = OWGetProperty(_config, @"data");
    self->mimeType  = OWGetProperty(_config, @"mimeType");
    self->key       = OWGetProperty(_config, @"key");
  }
  return self;
}

- (void)dealloc {
  RELEASE(self->template);
  RELEASE(self->framework);
  RELEASE(self->filename);
  RELEASE(self->data);
  RELEASE(self->key);
  RELEASE(self->mimeType);
  [super dealloc];
}

/* responder */

#define StrVal(__x__) [self->__x__ stringValueInComponent:sComponent]

/* request handling */

- (void)takeValuesFromRequest:(WORequest *)_req inContext:(WOContext *)_ctx {
  [self->template takeValuesFromRequest:_req inContext:_ctx];
}

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  WOComponent *sComponent = [_ctx component];
  NSData     *adata;
  NSString   *atype;
  WOResponse *response;

  if (self->data == nil)
    return [self->template invokeActionForRequest:_request inContext:_ctx];
  
  adata = [self->data     valueInComponent:sComponent];
  atype = [self->mimeType stringValueInComponent:sComponent];

  response = [_ctx response];
    
  [response setContent:adata];
  [response setHeader:
	      (atype != nil ? atype : (NSString *)@"application/octet-stream")
            forKey:@"content-type"];
    
  return response;
}

/* response generation */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString    *uFi;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }

  sComponent = [_ctx component];
  uFi        = [self->filename stringValueInComponent:sComponent];
  
  if (uFi) {
    WOResourceManager *rm;
    NSString          *frameworkName;
    NSArray           *languages;
    
    if ((rm = [[_ctx component] resourceManager]) == nil)
      rm = [[_ctx application] resourceManager];
    
    /* If 'framework' binding is not set, use parent component's framework */
    if (self->framework){
      frameworkName = [self->framework stringValueInComponent:sComponent];
      if (frameworkName != nil && [frameworkName isEqualToString:@"app"])
        frameworkName = nil;
    }
    else
      frameworkName = [sComponent frameworkName];
    
    languages = [_ctx resourceLookupLanguages];
    uFi       = [rm urlForResourceNamed:uFi
                    inFramework:frameworkName
                    languages:languages
                     request:[_ctx request]];
    if (uFi == nil) {
      NSLog(@"%@: did not find resource '%@'", sComponent,
            [self->filename stringValueInComponent:sComponent]);
    }
    else
      [_response appendContentHTMLAttributeValue:uFi];
  }
  else if (self->data != nil) {
    NSString *kk;
    
    if ((kk = [self->key stringValueInComponent:sComponent])) {
      NSString          *url;
      WOResourceManager *rm;
      
      if ((rm = [[_ctx component] resourceManager]) == nil)
        rm = [[_ctx application] resourceManager];
    
      [rm setData:[self->data valueInComponent:sComponent]
          forKey:kk
          mimeType:[self->mimeType stringValueInComponent:sComponent]
          session:[_ctx hasSession] ? [_ctx session] : nil];
      
      url = [_ctx urlWithRequestHandlerKey:
                    [WOApplication resourceRequestHandlerKey]
                  path:[@"/" stringByAppendingString:kk]
                  queryString:nil];
      
      WOResponse_AddString(_response, url);
    }
    else {
      /* a component action link */
      uFi = [_ctx componentActionURL];
      WOResponse_AddString(_response, uFi);
    }
  }
  else {
    [sComponent logWithFormat:@"missing resource URL for element %@", self];
  }
  
  /* content */
  [self->template appendToResponse:_response inContext:_ctx];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [[NSMutableString alloc] init];

  if (self->filename)  [str appendFormat:@" filename=%@",  self->filename];
  if (self->framework) [str appendFormat:@" framework=%@", self->framework];
  if (self->data)      [str appendFormat:@" data=%@",      self->data];
  if (self->mimeType)  [str appendFormat:@" mimeType=%@",  self->mimeType];
  if (self->key)       [str appendFormat:@" key=%@",       self->key];
  
  return AUTORELEASE(str);
}

@end /* WOResourceURL */
