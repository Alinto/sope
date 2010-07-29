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

@interface WOEmbeddedObject : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *filename;  // path relative to WebServerResources
  WOAssociation *framework;
  WOAssociation *src;       // absolute URL
  WOAssociation *value;     // data (eg from a database)

  /* new in WO4 */
  WOAssociation *data;
  WOAssociation *mimeType;
  WOAssociation *key;
}

@end /* WOEmbeddedObject */

@implementation WOEmbeddedObject

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_tmpl
{
  if ((self = [super initWithName:_name associations:_config template:_tmpl])) {
    self->filename  = OWGetProperty(_config, @"filename");
    self->framework = OWGetProperty(_config, @"framework");
    self->src       = OWGetProperty(_config, @"src");
    self->value     = OWGetProperty(_config, @"value");

    self->data      = OWGetProperty(_config, @"data");
    self->mimeType  = OWGetProperty(_config, @"mimeType");
    self->key       = OWGetProperty(_config, @"key");

    if (self->key)
      NSLog(@"WARNING: 'key' association in WOEmbeddedObject not supported !");
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->key);
  RELEASE(self->data);
  RELEASE(self->mimeType);
  RELEASE(self->framework);
  RELEASE(self->filename);
  RELEASE(self->src);
  RELEASE(self->value);
  [super dealloc];
}
#endif

// ******************** responder ********************

- (id)invokeActionForRequest:(WORequest *)_request inContext:(WOContext *)_ctx {
  if (self->value) {
    WOElement *element;

    if ((element = [self->value valueInComponent:[_ctx component]]) == nil) {
      [[_ctx session] debugWithFormat:
          @"WARNING: missing element value for WOEmbeddedObject %@", self];
      return nil;
    }

    [element appendToResponse:[_ctx response] inContext:_ctx];
    return [_ctx response];
  }
  else if (self->data) {
    WOComponent *sComponent;
    NSData     *adata;
    NSString   *atype;
    WOResponse *response;
    
    sComponent = [_ctx component];
    adata = [self->data     valueInComponent:sComponent];
    atype = [self->mimeType stringValueInComponent:sComponent];
    
    response = [_ctx response];
    
    [response setContent:adata];
    [response setHeader:
		(atype != nil ? atype :(NSString *)@"application/octet-stream")
              forKey:@"content-type"];
    
    return response;
  }
  else {
    [[_ctx session] debugWithFormat:
                      @"no value configured for WOEmbeddedObject %@", self];
    return nil;
  }
}

#define StrVal(__x__) [self->__x__ stringValueInComponent:sComponent]

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  if (!([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])) {
    WOComponent *sComponent = [_ctx component];
    NSString *uUri = [self->src      stringValueInComponent:sComponent];
    NSString *uFi  = [self->filename stringValueInComponent:sComponent];
    NSArray  *languages;

    sComponent = [_ctx component];
    uUri = [self->src      stringValueInComponent:sComponent];
    uFi  = [self->filename stringValueInComponent:sComponent];
    
    WOResponse_AddCString(_response, "<embed src=\"");
    
    if ((self->data != nil) || (self->value != nil)) {
      /* a component action link */
      uUri = [_ctx componentActionURL];
      if (uFi) {
        uUri = [uUri stringByAppendingString:@"/"];
        uUri = [uUri stringByAppendingString:uFi];
      }
      WOResponse_AddString(_response, uUri);
    }
    else if (uFi) {
      WOResourceManager *rm;
      NSString  *frameworkName;
      
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
      
      languages = [_ctx resourceLookupLanguages];
      uFi       = [rm urlForResourceNamed:uFi
                      inFramework:frameworkName
                      languages:languages
                      request:[_ctx request]];
      if (uFi == nil) {
        NSLog(@"%@: did not find resource '%@'", sComponent,
              [self->filename stringValueInComponent:sComponent]);
        uFi = uUri;
      }
      [_response appendContentHTMLAttributeValue:uFi];
    }
    else if (uUri) {
      [_response appendContentHTMLAttributeValue:uUri];
    }
    else {
      [sComponent logWithFormat:@"missing resource URL for element %@", self];
    }
    
    WOResponse_AddChar(_response, '"');
  
    [self appendExtraAttributesToResponse:_response inContext:_ctx];
    if (self->otherTagString) {
      WOResponse_AddChar(_response, ' ');
      WOResponse_AddString(_response,
                           [self->otherTagString stringValueInComponent:
                                                   [_ctx component]]);
    }
    WOResponse_AddEmptyCloseParens(_response, _ctx);
  }
}

// description

- (NSString *)associationDescription {
  NSMutableString *str = [[NSMutableString alloc] init];

  if (self->filename)  [str appendFormat:@" filename=%@",  self->filename];
  if (self->framework) [str appendFormat:@" framework=%@", self->framework];
  if (self->src)       [str appendFormat:@" src=%@",       self->src];
  if (self->value)     [str appendFormat:@" value=%@",     self->value];
  
  return AUTORELEASE(str);
}

@end /* WOEmbeddedObject */
