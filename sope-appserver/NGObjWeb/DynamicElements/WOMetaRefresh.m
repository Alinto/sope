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
#include <NGObjWeb/WOAssociation.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include "decommon.h"

/*
  WOMetaRefresh associations:

    href | pageName | action | (directActionName & actionClass)
    fragmentIdentifier
    disabled
    timeout/seconds
*/

@interface WOMetaRefresh : WOHTMLDynamicElement
{
  // WODynamicElement: extraAttributes
  // WODynamicElement: otherTagString
@protected
  WOAssociation *action;
  WOAssociation *href;
  WOAssociation *pageName;
  WOAssociation *directActionName;
  WOAssociation *actionClass;
  WOAssociation *disabled;
  WOAssociation *fragmentIdentifier;
  WOAssociation *timeout;

  WOAssociation *queryDictionary;
  NSDictionary  *queryParameters;  /* associations beginning with ? */
  BOOL          sidInUrl;
}

@end

@implementation WOMetaRefresh

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_t
{
  if ((self = [super initWithName:_name associations:_config template:_t])) {
    WOAssociation *sidInUrlAssoc;
    
    sidInUrlAssoc            = OWGetProperty(_config, @"?wosid");
    self->action             = OWGetProperty(_config, @"action");
    self->href               = OWGetProperty(_config, @"href");
    self->pageName           = OWGetProperty(_config, @"pageName");
    self->fragmentIdentifier = OWGetProperty(_config, @"fragmentIdentifier");
    self->disabled           = OWGetProperty(_config, @"disabled"); 
    self->timeout            = OWGetProperty(_config, @"timeout"); 
    self->directActionName   = OWGetProperty(_config, @"directActionName"); 
    self->actionClass        = OWGetProperty(_config, @"actionClass"); 
    
    self->sidInUrl = (sidInUrlAssoc)
      ? [sidInUrlAssoc boolValueInComponent:nil]
      : YES;
    
    if (self->timeout == nil)
      self->timeout = OWGetProperty(_config, @"seconds");
    else if ([OWGetProperty(_config, @"seconds") autorelease] != nil) {
      [self logWithFormat:
	      @"WARNING: got both, 'timeout' and 'seconds' bindings!"];
    }
    
    self->queryDictionary = OWGetProperty(_config, @"queryDictionary");
    self->queryParameters = OWExtractQueryParameters(_config);
  }
  return self;
}

- (void)dealloc {
  [self->queryParameters    release];
  [self->queryDictionary    release];
  [self->directActionName   release];
  [self->actionClass        release];
  [self->action             release];
  [self->href               release];
  [self->pageName           release];
  [self->fragmentIdentifier release];
  [self->disabled           release];
  [self->timeout            release];
  [super dealloc];
}

/* handling requests */

- (id)invokeActionForRequest:(WORequest *)_request
  inContext:(WOContext *)_ctx
{
  if ([self->disabled boolValueInComponent:[_ctx component]])
    return nil;
  
  if (self->action)
    return [self executeAction:self->action inContext:_ctx];

  if (self->pageName) {
    NSString    *name;
    WOComponent *page;

    name = [self->pageName stringValueInComponent:[_ctx component]];
    page = [[_ctx application] pageWithName:name inContext:_ctx];
      
    if (page == nil) {
      [[_ctx component] logWithFormat:
                          @"%@[0x%p]: did not find page with name %@ !",
                          NSStringFromClass([self class]), self, name];
    }
    [self debugWithFormat:@"showing page %@", page];
    return page;
  }
  
  [[_ctx component] 
         logWithFormat:@"%@[0x%p]: no action/page set !",
           NSStringFromClass([self class]), self];
  return nil;
}

/* generating response */

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  int         to;
  NSString    *url;
  NSString    *queryString;
  BOOL        addSID;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent])
    return;
  
  sComponent  = [_ctx component];
  queryString = nil;
  to = [self->timeout intValueInComponent:sComponent];
  WOResponse_AddCString(_response, "<meta http-equiv=\"refresh\" content=\"");
  WOResponse_AddInt(_response, to);
  WOResponse_AddCString(_response, "; url=");

  if (self->href) {
    /* a href was explicitly assigned */
    url = [self->href stringValueInComponent:sComponent];
    addSID = self->sidInUrl;
  }
  else if (self->directActionName) {
    /* a direct action */
    NSString *daClass;
    NSString *daName;

    daClass = [self->actionClass      stringValueInComponent:sComponent];
    daName  = [self->directActionName stringValueInComponent:sComponent];
    
    if (daClass) {
      if (daName) {
        if (![daClass isEqualToString:@"DirectAction"])
          daName = [NSString stringWithFormat:@"%@/%@", daClass, daName];
      }
      else
        daName = daClass;
    }

    url = [_ctx directActionURLForActionNamed:daName queryDictionary:nil];
    addSID = self->sidInUrl;
  }
  else {
    url = [_ctx componentActionURL];
    addSID = NO;
  }
  WOResponse_AddString(_response, url);
  
  queryString = [self queryStringForQueryDictionary:
                        [self->queryDictionary valueInComponent:sComponent]
                      andQueryParameters:self->queryParameters
                      inContext:_ctx];
  if (addSID && [sComponent hasSession]) {
    WOSession *sn = [sComponent session];
    
    if ([queryString length] == 0) {
      queryString = [NSString stringWithFormat:@"%@=%@", 
			      WORequestValueSessionID, [sn sessionID]];
    }
    else {
      queryString = [queryString stringByAppendingFormat:@"&%@=%@", 
			      WORequestValueSessionID, [sn sessionID]];
    }
  }
  
  if (self->fragmentIdentifier) {
    [_response appendContentCharacter:'#'];
    WOResponse_AddString(_response,
                         [self->fragmentIdentifier stringValueInComponent:
                              sComponent]);
  }
  
  if (queryString) {
    [_response appendContentCharacter:'?'];
    WOResponse_AddString(_response, queryString);
  }
  
  [_response appendContentCharacter:'"']; // close CONTENT attribute
  
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  if (self->otherTagString) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                              [_ctx component]]);
  }
  WOResponse_AddEmptyCloseParens(_response, _ctx);
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:256];
  
  if (self->action)   [str appendFormat:@" action=%@",   self->action];
  if (self->href)     [str appendFormat:@" href=%@",     self->href];
  if (self->pageName) [str appendFormat:@" pageName=%@", self->pageName];
  if (self->fragmentIdentifier)
    [str appendFormat:@" fragment=%@", self->fragmentIdentifier];
  if (self->disabled) [str appendFormat:@" disabled=%@", self->disabled];
  
  return str;
}

@end /* WOMetaRefresh */
