/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "WOForm.h"
#include "WOElement+private.h"
#include "WOInput.h"
#include "WOContext+private.h"
#include <NGObjWeb/WOApplication.h>
#include "decommon.h"

@implementation WOForm

static int debugTakeValues = -1;

+ (int)version {
  return 5;
}

- (id)initWithName:(NSString *)_name
  associations:(NSDictionary *)_config
  template:(WOElement *)_c
{
  if (debugTakeValues == -1) {
    debugTakeValues = 
      [[NSUserDefaults standardUserDefaults] boolForKey:@"WODebugTakeValues"]
      ? 1 : 0;
    if (debugTakeValues) NSLog(@"WOForm: WODebugTakeValues on.");
  }
  
  if ((self = [super initWithName:_name associations:_config template:_c])) {
    WOAssociation *sidInUrlAssoc;
    id tmp;

    self->containsForm = YES;
    
    sidInUrlAssoc            = OWGetProperty(_config, @"?wosid");
    self->action             = OWGetProperty(_config, @"action");
    self->href               = OWGetProperty(_config, @"href");
    self->pageName           = OWGetProperty(_config, @"pageName");
    self->queryDictionary    = OWGetProperty(_config, @"queryDictionary");
    self->queryParameters    = OWExtractQueryParameters(_config);
    self->actionClass        = OWGetProperty(_config, @"actionClass");
    self->directActionName   = OWGetProperty(_config, @"directActionName");
    self->method             = OWGetProperty(_config, @"method");
    self->fragmentIdentifier = OWGetProperty(_config, @"fragmentIdentifier");
    
    self->sidInUrl = (sidInUrlAssoc != nil)
      ? [sidInUrlAssoc boolValueInComponent:nil]
      : YES;
    
    if ((tmp = OWGetProperty(_config, @"multipleSubmit")) != nil) {
      /* not required with SOPE, for WO compatibility */
      [tmp release];
    }
    
    self->template = [_c retain];
  }
  return self;
}

- (void)dealloc {
  [self->fragmentIdentifier release];
  [self->method             release];
  [self->template           release];
  [self->actionClass        release];
  [self->directActionName   release];
  [self->queryDictionary    release];
  [self->queryParameters    release];
  [self->action             release];
  [self->pageName           release];
  [self->href               release];
  [super dealloc];  
}

/* handle active form elements */

- (id)template {
  return self->template;
}

/* handling requests */

- (void)takeValuesFromRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  static int alwaysPassIn = -1;

  if (alwaysPassIn == -1) {
    alwaysPassIn = [[[NSUserDefaults standardUserDefaults]
                                     objectForKey:@"WOFormAlwaysPassDown"]
                                     boolValue] ? 1 : 0;
  }
  
  if ([_ctx isInForm]) {
    [self errorWithFormat:@"(%s): another form is already active in context !",
            __PRETTY_FUNCTION__];
  }
  
  [_ctx setInForm:YES];
  {
    WOComponent *sComponent = [_ctx component];
    BOOL doTakeValues = NO;
    
    if (self->queryParameters != nil) {
      /* apply values to ?style parameters */
      NSEnumerator *keys;
      NSString     *key;

      keys = [self->queryParameters keyEnumerator];
      while ((key = [keys nextObject])) {
        WOAssociation *assoc;
        id value;
        
        assoc = [self->queryParameters objectForKey:key];
        value = [_rq formValueForKey:key];

        [assoc setValue:value inComponent:sComponent];
      }
    }
    
    // TODO: explain this href comparison
    if ([[self->href stringValueInComponent:sComponent] 
	  isEqualToString:[_rq uri]]) {
      if (debugTakeValues) {
	NSArray *formValues = [_rq formValueKeys];
	NSLog(@"%s: we are uri active (uri=%@): %@ ..", __PRETTY_FUNCTION__,
	      [_rq uri], formValues);
      }
      doTakeValues = YES;
    }
    else if ([[_ctx elementID] isEqualToString:[_ctx senderID]]) {
      if (debugTakeValues) {
	NSArray *formValues = [_rq formValueKeys];
	NSLog(@"%s: we are elem active (eid=%@): %@ ..", __PRETTY_FUNCTION__,
	      [_ctx elementID], formValues);
      }
      doTakeValues = YES;
    }
    else if (alwaysPassIn) {
      // Note: this does not call the component! Bug? (see 'else' below)
      if (debugTakeValues)
	NSLog(@"%s: taking values from foreign request ",__PRETTY_FUNCTION__);
      doTakeValues = YES;
    }
    else {
      /* finally, let the component decide */
      doTakeValues = [sComponent shouldTakeValuesFromRequest:_rq 
				 inContext:_ctx];
      if (debugTakeValues) {
	NSLog(@"%s: component should take values: %s ", __PRETTY_FUNCTION__,
	      doTakeValues ? "yes" : "no");
      }
    }
    
    if (doTakeValues) {
      if (debugTakeValues) 
	NSLog(@"%s: taking values ...", __PRETTY_FUNCTION__);
      
      [self->template takeValuesFromRequest:_rq inContext:_ctx];

      if (debugTakeValues) 
	NSLog(@"%s: did take values.", __PRETTY_FUNCTION__);
    }
    else if (debugTakeValues) {
      [sComponent
             debugWithFormat:
               @"WOForm: *not* taking values from foreign request "
               @"(id='%@' vs sid='%@') ...",
               [_ctx elementID], [_ctx senderID]];
    }
  }
  
  if (![_ctx isInForm]) {
    [[_ctx component]
           errorWithFormat:@"(%s:%d): -isInForm is NO !!!",
             __PRETTY_FUNCTION__, __LINE__];
  }
  else
    [_ctx setInForm:NO];
}

- (id)invokeActionForRequest:(WORequest *)_rq inContext:(WOContext *)_ctx {
  id result = nil;
  
  [_ctx setInForm:YES];

  if ([_ctx currentElementID] == nil) {
    WOElement *element;
    
    if ((element = [_ctx activeFormElement])) {
#if 1
      result = [self->template invokeActionForRequest:_rq inContext:_ctx];
      RETAIN(result);
#else
      /* wrong - need to setup correct component stack */
      result = [[element invokeActionForRequest:_rq
                         inContext:_ctx]
                         retain];
#endif
    }
    else if (self->action) {
      result = [self executeAction:self->action inContext:_ctx];
    }
    else if (self->pageName) {
      NSString    *pname = nil;
      WOComponent *page = nil;

      pname = [self->pageName stringValueInComponent:[_ctx component]];
      page  = [[_ctx application] pageWithName:pname inContext:_ctx];

      if (page == nil) {
        [[_ctx session] logWithFormat:
                          @"%@[0x%p]: did not find page with name %@ !",
                          NSStringFromClass([self class]), self, pname];
      }
      NSLog(@"showing page %@", page);
      result = page;
    }
  }
  else
    result = [self->template invokeActionForRequest:_rq inContext:_ctx];

  [_ctx setInForm:NO];

  return result;
}

/* generate response */

- (NSString *)_addHrefToResponse:(WOResponse *)_r inContext:(WOContext *)_ctx {
  /* post to a fixed hyperlink */
  WOComponent *sComponent = [_ctx component];
  NSString     *s;
  NSDictionary *d;
  
  s = [self->href stringValueInComponent:sComponent];
  d = [self->queryDictionary valueInComponent:sComponent];
  
  WOResponse_AddString(_r, s);
  
  return [self queryStringForQueryDictionary:d
	       andQueryParameters:self->queryParameters
	       inContext:_ctx];
}

- (NSString *)_addActionToResponse:(WOResponse *)_r inContext:(WOContext *)_c {
  /* post to a component action */
  NSDictionary *d;
        
  WOResponse_AddString(_r, [_c componentActionURL]);

  d = [self->queryDictionary valueInComponent:[_c component]];
  return [self queryStringForQueryDictionary:d
	       andQueryParameters:self->queryParameters
	       inContext:_c];
}

- (void)_addDirectActionToResponse:(WOResponse *)_r inContext:(WOContext *)_c {
  /* a direct action link */
  WOComponent *sComponent;
  NSString            *daClass = nil;
  NSString            *daName  = nil;
  NSMutableDictionary *qd;
  NSDictionary        *tmp;
  NSString            *uri;
          
  sComponent = [_c component];
  daClass = [self->actionClass      stringValueInComponent:sComponent];
  daName  = [self->directActionName stringValueInComponent:sComponent];
  
  if (daClass != nil) {
    if (daName != nil) {
      if (![daClass isEqualToString:@"DirectAction"])
	daName = [NSString stringWithFormat:@"%@/%@", daClass, daName];
    }
    else
      daName = daClass;
  }
  
  qd = [NSMutableDictionary dictionaryWithCapacity:16];
  
  /* add query dictionary */
        
  if (self->queryDictionary) {
    if ((tmp = [self->queryDictionary valueInComponent:sComponent]))
      [qd addEntriesFromDictionary:tmp];
  }
        
  /* add ?style parameters */
  
  if (self->queryParameters) {
    NSEnumerator *keys;
    NSString     *key;
  
    keys = [self->queryParameters keyEnumerator];
    while ((key = [keys nextObject])) {
      id assoc, value;
  
      assoc = [self->queryParameters objectForKey:key];
      value = [assoc stringValueInComponent:sComponent];
      
      [qd setObject:(value != nil ? value : (id)@"") forKey:key];
    }
  }
        
  /* add session ID */
  if (self->sidInUrl && [_c hasSession]) {
    WOSession *sn;

    sn = [_c session];
    [qd setObject:[sn sessionID] forKey:WORequestValueSessionID];
            
    if (![sn isDistributionEnabled]) {
      [qd setObject:[[WOApplication application] number]
	  forKey:WORequestValueInstance];
    }
  }
  else if (self->sidInUrl) {
    /* Note: this is not a problem! Eg this occurs on the OGo Main component */
    [self debugWithFormat:
	    @"Note: session-id is requested, but no session is active?"];
  }
  
  uri = [_c directActionURLForActionNamed:daName queryDictionary:qd];
  WOResponse_AddString(_r, uri);
}

- (void)appendToResponse:(WOResponse *)_response inContext:(WOContext *)_ctx {
  WOComponent *sComponent;
  NSString    *queryString = nil;
  
  if ([_ctx isRenderingDisabled] || [[_ctx request] isFromClientComponent]) {
    [self->template appendToResponse:_response inContext:_ctx];
    return;
  }
  
  sComponent = [_ctx component];

  if ([_ctx isInForm])
    [self warnWithFormat:@"detected nested WOForm, component: %@", sComponent];
  else
    [_ctx setInForm:YES];

  WOResponse_AddCString(_response, "<form action=\"");

  /* add URL to response and return the query string */
  
  if (self->href != nil)
    queryString = [self _addHrefToResponse:_response inContext:_ctx];
  else if (self->directActionName != nil || self->actionClass != nil)
    [self _addDirectActionToResponse:_response inContext:_ctx];
  else
    queryString = [self _addActionToResponse:_response inContext:_ctx];

  if (self->fragmentIdentifier != nil) {
    NSString *f = [self->fragmentIdentifier stringValueInComponent:sComponent];
    if ([f isNotEmpty]) {
      [_response appendContentCharacter:'#'];
      WOResponse_AddString(_response, f);
    }
  }

  /* append the query string */
  
  if (queryString != nil) {
    [_response appendContentCharacter:'?'];
    WOResponse_AddString(_response, queryString);
  }
  if (self->method != nil) {
    WOResponse_AddCString(_response, "\" method=\"");
    WOResponse_AddString(_response, 
			 [self->method stringValueInComponent:sComponent]);
    WOResponse_AddCString(_response, "\"");
  }
  else
    WOResponse_AddCString(_response, "\" method=\"post\"");
      
  [self appendExtraAttributesToResponse:_response inContext:_ctx];
  
  if (self->otherTagString != nil) {
    WOResponse_AddChar(_response, ' ');
    WOResponse_AddString(_response,
                         [self->otherTagString stringValueInComponent:
                           sComponent]);
  }
  WOResponse_AddChar(_response, '>');

  /* render form content */
    
  [self->template appendToResponse:_response inContext:_ctx];

  /* close form */
  
  WOResponse_AddCString(_response, "</form>");
  [_ctx setInForm:NO];
}

/* description */

- (NSString *)associationDescription {
  NSMutableString *str = [NSMutableString stringWithCapacity:64];
  //[str appendString:[super associationDescription]];

  if (self->action)   [str appendFormat:@" action=%@", self->action];
  if (self->href)     [str appendFormat:@" href=%@", self->href];
  if (self->pageName) [str appendFormat:@" page=%@", self->pageName];

  if (self->actionClass)
    [str appendFormat:@" actionClass=%@", self->actionClass];
  if (self->directActionName)
    [str appendFormat:@" directAction=%@", self->directActionName];
  if (self->template)
    [str appendFormat:@" template=%@", self->template];
  
  return str;
}

@end /* WOForm */
