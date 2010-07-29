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

#include <NGObjWeb/OWViewRequestHandler.h>
#include "WORequestHandler+private.h"
#include "WOContext+private.h"
#include "WOComponent+private.h"
#include "WOApplication+private.h"
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSessionStore.h>
#include <NGObjWeb/WOSession.h>
#include "common.h"

NSString *OWAppDidRefuseSessionName = @"OWAppDidRefuseSession";
static BOOL perflog = NO;

//#define USE_POOLS 1

#if USE_POOLS
#  warning extensive pools are enabled ...
#endif

@implementation OWViewRequestHandler

+ (int)version {
  return [super version] + 0 /* 2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
  
  perflog = [[NSUserDefaults standardUserDefaults]
                             boolForKey:@"OWViewRequestHandlerProfile"];
}

- (NSString *)loggingPrefix {
  return @"[ow-handler]";
}

- (id)init {
  //NSLog(@"DEPRECATED: OWViewRequestHandler is being allocated ...");
  return [super init];
}

- (WOResponse *)runTransactionWithContext:(WOContext *)_ctx {
  WOApplication *app      = nil;
  WOSession     *sn       = nil;
  WOResponse    *response = nil;
  id<NSObject,WOActionResults> result;
  
  app = [_ctx application];
  sn  = [_ctx session];
  NSAssert(_ctx != nil, @"no context available");
  NSAssert(sn   != nil, @"no session available");
  NSAssert(app  != nil, @"no application available in context");

  /* take request values */

  [app takeValuesFromRequest:[_ctx request] inContext:_ctx];

  /* invoke action */
    
  result = [app invokeActionForRequest:[_ctx request] inContext:_ctx];
    
  /* check whether there is an page set at all ! */

  if ([_ctx page] == nil) {
    /* no page is set yet, load Main .. */
    WOComponent *mainPage;

    if ((mainPage = [app pageWithName:nil inContext:_ctx])) {
      [_ctx setPage:mainPage];
      [mainPage _awakeWithContext:_ctx];
    }
  }
  
  /* make response */
  
  if ((result == nil) || [result isKindOfClass:[WOComponent class]]) {
    /* determine the response page */
      
    if (result == nil) {
      /* make the request page the response page */
      if ((result = [_ctx page]) == nil) {
        /* no request page (probably the first request) */
        result = [app pageWithName:nil inContext:_ctx];
        [(id)result _awakeWithContext:_ctx];
        [_ctx setPage:(WOComponent *)result];
      }
    }

    response = [self generateResponseForComponent:(WOComponent *)result
                     inContext:_ctx
                     application:app];
      
    /* save page in session */
      
    if ([_ctx savePageRequired]) {
      [sn savePage:[_ctx page]];
#if DEBUG && 0
      [self logWithFormat:@"saved page ..."];
#endif
    }
#if DEBUG && 0
    else {
      [self logWithFormat:@"no save page required ..."];
    }
#endif
  }
  else {
    /* generate response from WOActionResult */
    if ([result respondsToSelector:@selector(generateResponse)]) {
      [app debugWithFormat:@"generating response for result .."];
      response = [result generateResponse];
    }
    else {
      [app logWithFormat:
             @"action result (class=%@) doesn't conform to "
             @"WOActionResult protocol !",
             NSStringFromClass([result class])];
        
      response = [[WOResponse alloc] init];
      [response setStatus:200];
      [response appendContentString:@"<pre>"];
      [response appendContentHTMLString:
                  @"ERROR:\n"
                  @"Result of action doesn't conform to WOActionResult "
                  @"protocol:\n---\n"
                  @"Content-Class: "];
      [response appendContentHTMLString:
                   [NSStringFromClass([result class]) description]];
      [response appendContentHTMLString:@"\nContent:\n"];
      [response appendContentHTMLString:[result description]];
      [response appendContentString:@"</pre>\n"];
      AUTORELEASE(response);
    }
  }
    
  [_ctx sleepComponents];
    
  return response;
}

- (NSString *)sessionIDFromRequest:(WORequest *)_request
  application:(WOApplication *)_app
{
  NSString *sessionId = nil;
  id tmp;
  
  if ((tmp = [_request formValueForKey:WORequestValueSenderID]) == nil) {
    if ([[_request requestHandlerPath] length] > 0) {
      /* traditional style URLs */
      NSArray *spath;
      
      spath = [_request requestHandlerPathArray];
      if ([spath count] > 0)
        sessionId = [spath objectAtIndex:0];
    }
  }
  
  if ([sessionId length] == 0)
    sessionId = [_app sessionIDFromRequest:_request];
  
  return sessionId;
}

- (BOOL)autocreateSessionForRequest:(WORequest *)_request {
  /* autocreate a session if none was restored */
  return YES;
}
- (BOOL)requiresSessionForRequest:(WORequest *)_request {
  /* _ensure_ that a session is available */
  return YES;
}

- (WOResponse *)handleRequest:(WORequest *)_request
  inContext:(WOContext *)context
  session:(WOSession *)session
  application:(WOApplication *)app
{
  NSString       *requestContextID;
  WOResponse     *response;
  WOComponent    *requestComponent;
  NSString       *cid;
  NSTimeInterval startRunTx = 0.0;
  id tmp;

  *(&requestContextID) = nil;
  *(&response)         = nil;
  *(&requestComponent) = nil;
  
  NSAssert(session, @"no session given !");

  /*
    parse handler path (URL)
      
    The format is:
      session/context-id.element-id
      
    or
      pageName?_i=context-id.element-id&wosid=session&_c=context-id
  */
  
  if ((tmp = [_request formValueForKey:WORequestValueSenderID])) {
    /* new query-para style URL */
    [context setRequestSenderID:tmp];
    
    if ((tmp = [_request formValueForKey:WORequestValueContextID]))
      requestContextID = tmp;
    else
      requestContextID = [context currentElementID];
  }
  else if ([[_request requestHandlerPath] length] > 0) {
    /* traditional style URLs */
    NSArray *spath;
    
    spath = [_request requestHandlerPathArray];
      
    if ([spath count] > 1) {
      [context setRequestSenderID:[spath objectAtIndex:1]];
      requestContextID = [context currentElementID];
    }
    // at idx 0 => sessionId
  }
  
  /* determine request component */

  if ([[self sessionIDFromRequest:_request application:app]
             isEqualToString:[session sessionID]])
    cid = [context currentElementID];
  else
    /* the session is different, was autocreated ... */
    cid = nil;
  
  if ((session != nil) && ([cid length] > 0)) {
    requestComponent = [session restorePageForContextID:cid];
    
    if (requestComponent == nil) {
      /* could not restore page ... */
      response = [app handlePageRestorationErrorInContext:context];
      if (response != nil) {
        [self logWithFormat:
                @"returning because of page restoration error ..."];
        return response;
      }
    }
  }
  if (requestComponent) {
    [context setPage:requestComponent];
    [requestComponent _awakeWithContext:context];
  }
  
  /* run transaction */

  if (perflog)
    startRunTx = [[NSDate date] timeIntervalSince1970];
  
  response = [self runTransactionWithContext:context];
  
  if (perflog) {
    NSTimeInterval rt;
    rt = [[NSDate date] timeIntervalSince1970] - startRunTx;
    [self logWithFormat:@"running tx took %4.3fs.", rt < 0.0 ? -1.0 : rt];
  }
  
  return response;
}

@end /* OWViewRequestHandler */
