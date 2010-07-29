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

#include "WOInput.h"

@interface WOImageButton : WOInput
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
  // WOInput:    name
  // WOInput:    value
  // WOInput:    disabled
@protected
  WOAssociation *filename;  // image path relative to WebServerResources
  WOAssociation *framework;
  WOAssociation *src;       // absolute URL
  WOAssociation *action;
  WOAssociation *pageName;
  WOAssociation *x;
  WOAssociation *y;
  
  // new in WO4:
  WOAssociation *queryDictionary;
  NSDictionary  *queryParameters;  // associations beginning with ?
  WOAssociation *actionClass;
  WOAssociation *directActionName;
  BOOL          sidInUrl;
  
  // non-WO
  WOAssociation *disabledFilename; // image path to icon for 'disabled' state
}

@end /* WOImageButton */

#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOResourceManager.h>
#include "decommon.h"

@implementation WOImageButton

+ (int)version {
  return 2;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    WOAssociation *sidInUrlAssoc;
    
    sidInUrlAssoc   = OWGetProperty(_config, @"?wosid");
    self->action    = OWGetProperty(_config, @"action");
    self->filename  = OWGetProperty(_config, @"filename");
    self->framework = OWGetProperty(_config, @"framework");
    self->pageName  = OWGetProperty(_config, @"pageName");
    self->x         = OWGetProperty(_config, @"x");
    self->y         = OWGetProperty(_config, @"y");

    self->queryDictionary  = OWGetProperty(_config, @"queryDictionary");
    self->queryParameters  = OWExtractQueryParameters(_config);
    self->actionClass      = OWGetProperty(_config, @"actionClass");
    self->directActionName = OWGetProperty(_config, @"directActionName");
    
    self->disabledFilename = OWGetProperty(_config, @"disabledFilename");
    
    self->sidInUrl = (sidInUrlAssoc)
      ? [sidInUrlAssoc boolValueInComponent:nil]
      : YES;
  }
  return self;
}

- (void)dealloc {
  [self->actionClass      release];
  [self->directActionName release];
  [self->queryDictionary  release];
  [self->queryParameters  release];
  [self->action           release];
  [self->disabledFilename release];
  [self->framework        release];
  [self->filename         release];
  [self->src              release];
  [self->pageName         release];
  [self->x                release];
  [self->y                release];
  [super dealloc];
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  WOComponent *sComponent = [_ctx component];
  NSString *baseId = nil;
  id       xVal    = nil;
  id       yVal    = nil;

  //NSLog(@"%s: take values ...", __PRETTY_FUNCTION__);
  
  if (self->disabled != nil) {
    if ([self->disabled boolValueInComponent:sComponent])
      return;
  }
  
  baseId = OWFormElementName(self, _ctx);
  
  xVal = [_rq formValueForKey:[baseId stringByAppendingString:@".x"]];
  yVal = [_rq formValueForKey:[baseId stringByAppendingString:@".y"]];

  if (xVal) {
    if ([self->x isValueSettable]) {
      [self->x setUnsignedIntValue:[xVal unsignedIntValue]
           inComponent:sComponent];
    }
  }
  if (yVal) {
    if ([self->y isValueSettable]) {
      [self->y setUnsignedIntValue:[yVal unsignedIntValue]
           inComponent:sComponent];
    }
  }
  
  if (((xVal != nil) || (yVal != nil)) &&
      ((self->action != nil) || (self->pageName != nil))) {
    /* should perform action */
    [_ctx addActiveFormElement:self];
  }
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  if (self->disabled != nil) {
    if ([self->disabled boolValueInComponent:[_ctx component]])
      return nil;
  }
  
  /* check whether this is the active form element (determined above) */
  if (![[_ctx elementID] isEqualToString:[_ctx senderID]]) {
    NSLog(@"WOImageButton is not active (%@ vs %@) !",
          [_ctx elementID], [_ctx senderID]);
    return nil;
  }
  
  if (self->action)
    return [self executeAction:self->action inContext:_ctx];
    
  if (self->pageName) {
    NSString    *pname = nil;
    WOComponent *page = nil;

    pname = [self->pageName stringValueInComponent:[_ctx component]];
    page = [[_ctx application] pageWithName:pname inContext:_ctx];

    if (page == nil) {
      [[_ctx session] logWithFormat:
                      @"%@[0x%p]: did not find page with name %@ !",
                      NSStringFromClass([self class]), self, pname];
    }
    NSLog(@"%@: showing page %@", self, page);
    return page;
  }
  return nil;
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString *uUri = nil;
  NSString *uFi  = nil;
  BOOL isDisabled;

  if ([_ctx isRenderingDisabled]) return;

  sComponent = [_ctx component];
  uUri       = [self->src stringValueInComponent:sComponent];

  if ((isDisabled = [self->disabled boolValueInComponent:sComponent])) {
    uFi =  [self->disabledFilename stringValueInComponent:sComponent];
    if (uFi == nil)
      uFi = [self->filename stringValueInComponent:sComponent];
  }
  else
    uFi = [self->filename stringValueInComponent:sComponent];

  if (isDisabled) {
    WOResponse_AddCString(_response, "<img");
  }
  else {
    WOResponse_AddCString(_response, "<input type=\"image\" name=\"");
    [_response appendContentHTMLAttributeValue:OWFormElementName(self, _ctx)];
    WOResponse_AddChar(_response, '"');
  }
  
  WOResponse_AddCString(_response, " src=\"");
  if (uFi != nil) {
    WOResourceManager *rm;
    NSArray *langs;
    NSString  *frameworkName;

    if ((rm = [[_ctx component] resourceManager]) == nil)
      rm = [[_ctx application] resourceManager];

    langs = [_ctx resourceLookupLanguages];
    
    /* If 'framework' binding is not set, use parent component's framework */
    if (self->framework){
      frameworkName = [self->framework stringValueInComponent:sComponent];
      if (frameworkName != nil && [frameworkName isEqualToString:@"app"])
        frameworkName = nil;
    }
    else
      frameworkName = [sComponent frameworkName];
    
    uFi = [rm urlForResourceNamed:uFi
               inFramework:frameworkName
               languages:langs
               request:[_ctx request]];
    if (uFi == nil) {
      NSLog(@"%@: did not find resource '%@'", sComponent,
            [self->filename stringValueInComponent:sComponent]);
      uFi = uUri;
    }
    [_response appendContentHTMLAttributeValue:uFi];
  }
  else
    [_response appendContentHTMLAttributeValue:uUri];
  WOResponse_AddChar(_response, '"');
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString != nil) {
    NSString *s;
    
    s = [self->otherTagString stringValueInComponent:sComponent];
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response, s);
  }
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:128];
  [str appendString:[super associationDescription]];
  if (self->action)   [str appendFormat:@" action=%@", self->action];
  if (self->pageName) [str appendFormat:@" page=%@", self->pageName];
  if (self->filename) [str appendFormat:@" file=%@", self->filename];
  if (self->src)      [str appendFormat:@" src=%@",  self->src];
  if (self->x)        [str appendFormat:@" x=%@",    self->x];
  if (self->y)        [str appendFormat:@" y=%@",    self->y];

  if (self->actionClass)
    [str appendFormat:@" actionClass=%@", self->actionClass];
  if (self->directActionName)
    [str appendFormat:@" directAction=%@", self->directActionName];
  
  return str;
}

@end /* WOImageButton */
