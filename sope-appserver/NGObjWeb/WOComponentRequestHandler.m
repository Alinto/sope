/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Pulic License as published by the
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

#include "WOComponentRequestHandler.h"
#include "WORequestHandler+private.h"
#include "WOContext+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOComponent.h>
#include "common.h"

@interface WOApplication(Privates)
- (WOSession *)_initializeSessionInContext:(WOContext *)_ctx;
- (void)_setCurrentContext:(WOContext *)_ctx;
@end

@interface WORequestHandler(URI)
- (BOOL)doesRejectFavicon;
@end

@implementation WOComponentRequestHandler

+ (int)version {
  return [super version] + 0 /* 2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (WOResponse *)restoreSessionWithID:(NSString *)_sid
  inContext:(WOContext *)_ctx
{
  WOApplication *app;
  WOSession *session;
  
  app = [WOApplication application];
  if (_sid == nil) {
    // invalid session ID (or no session-ID ?!, which is no error ?) */
    return [app handleSessionRestorationErrorInContext:_ctx];
  }
  
  if ((session = [app restoreSessionWithID:_sid inContext:_ctx]) != nil) {
    /* awake restored session */
    [_ctx setSession:session];
    [session _awakeWithContext:_ctx];
    
    [session awake];
    return nil;
  }
  
  return [app handleSessionRestorationErrorInContext:_ctx];
}

/*
  The request handler path of a component URI looks like this:

    sessionID/componentName/contextID/elementID/instance/server
*/

- (WOResponse *)handleRequest:(WORequest *)_request {
  // TODO: this should be integrated into the WORequestHandler default
  //       mechanism
  NSString      *sessionID        = nil;
  WOApplication *application      = nil;
  WOContext     *context;
  WOResponse    *response         = nil;
  WOSession     *session          = nil;
  WOComponent   *component        = nil;
  BOOL          isLocked          = NO;
  NSString      *handlerPath      = nil;

  if (_request == nil) return nil;
  
  if ([self doesRejectFavicon] && [[_request uri] isNotNull]) {
    // TODO: code copied from WORequestHandler ...
    if ([@"/favicon.ico" isEqualToString:[_request uri]]) {
      response = [WOResponse responseWithRequest:_request];
      [response setStatus:404 /* not found */];
      [self debugWithFormat:@"rejected favicon request: %@", [_request uri]];
      return response;
    }
  }
  
  application = [WOApplication application];
  handlerPath = [_request requestHandlerPath];
  
#if 0
  [self logWithFormat:@"[component request handler] path: '%@'", handlerPath];
#endif

  if (![application allowsConcurrentRequestHandling]) {
    [application lockRequestHandling];
    isLocked = YES;
  }
  
  context = [WOContext contextWithRequest:_request];
  [application _setCurrentContext:context];
  
  /*
    parse handler path (URL)

    The format is:

      session/context.element-id
  */
  if ([handlerPath isNotEmpty]) {
    NSArray *spath = [_request requestHandlerPathArray];
    
    if ([spath count] > 1)
      [context setRequestSenderID:[spath objectAtIndex:1]];
    if ([spath isNotEmpty])
      sessionID = [spath objectAtIndex:0];
  }
  
  if (![sessionID isNotEmpty])
    sessionID = [application sessionIDFromRequest:_request];
  
#if 1
  [self logWithFormat:@"%s: made context %@ (cid=%@, sn=%@) ..",
	  __PRETTY_FUNCTION__, context, [context contextID], sessionID];
#endif
  
  [application awake];
  
  /* restore or create session */
  if ([sessionID isNotEmpty]) {
    if ((response = [self restoreSessionWithID:sessionID inContext:context]))
      session = nil;
    else {
      /* 
	 Note: this creates a _new_ session if the restoration handler did not
	       return a response! We check that below by comparing the session
	       IDs.
      */
      session = [context session];
    }
    
    [self debugWithFormat:@"restored session (id=%@): %@", sessionID, session];
    
    if (session && (![sessionID isEqualToString:[session sessionID]])) {
      [self errorWithFormat:@"session-ids do not match (%@ vs %@)",
	      sessionID, [session sessionID]];
    }
    
    if ([session isNotNull]) {
      NSString *eid;
      
      /*
	 only try to restore a page if we still have the same session and if
	 the request contains an element-id (eg if we reconnect to the main
	 URL we do not have an element-id
      */
      eid = [context currentElementID];
      if ([sessionID isEqualToString:[session sessionID]] && eid != nil) {
	/* awake stored page from "old" session */
	component = [session restorePageForContextID:eid];
	
	if (component == nil) {
	  [self logWithFormat:@"could not restore component from session: %@",
	        session];
	  response = [application handlePageRestorationErrorInContext:context];
	}
      }
      else /* a new session was created (but no restore-error response ret.) */
	component = [application pageWithName:nil inContext:context];
    }
    else if (response == nil) {
      [[WOApplication application] warnWithFormat:
                                     @"got no session restoration error, "
                                     @"but missing session!"];
    }
  }
  else {
    /* create new session */
    session = [application _initializeSessionInContext:context];
    if ([session isNotNull]) {
      /* awake created session */
      [session awake];
      component = [application pageWithName:nil inContext:context];
    }
    else
      response = [application handleSessionCreationErrorInContext:context];
  }
  
  if ((session != nil) && (component != nil) && (response == nil)) {
    WOComponent *newPage = nil;

    [[session retain] autorelease];
    
#if DEBUG
    NSAssert(application, @"missing application object ..");
    NSAssert(session,     @"missing session object ..");
#endif
    
    /* set request page in context */
    [context setPage:component];
    
    /* run take-values phase */
    [application takeValuesFromRequest:_request inContext:context];
    
    /* run invoke-action phase */
    newPage = [application invokeActionForRequest:_request inContext:context];
    
    /* process resulting page */
    if (newPage == nil) {
      if ((newPage = [context page]) == nil) {
        newPage = [application pageWithName:nil inContext:context];
        [context setPage:newPage];
      }
    }
    else if ([newPage isKindOfClass:[WOComponent class]])
      [context setPage:newPage];

    [self debugWithFormat:@"%s: new page: %@", __PRETTY_FUNCTION__, newPage];
    
    /* generate response */
    
    response = [self generateResponseForComponent:[context page]
		     inContext:context
		     application:application];
  }
  else {
    [self warnWithFormat:@"%s: did not enter request/response transaction ...",
            __PRETTY_FUNCTION__];
  }
  
  /* tear down */

  /* sleep objects */
  [context sleepComponents];
  [session sleep];
  
  /* save objects */
  
  if (session != nil) {
    if ([context savePageRequired])
      [session savePage:[context page]];
    
    [self debugWithFormat:@"saving session %@", [session sessionID]];
    
    if ([session storesIDsInCookies]) {
      [self debugWithFormat:@"add cookie to session: %@", session];
      [self addCookiesForSession:session
	    toResponse:response
	    inContext:context];
    }
    
#if 1 // TODO: explain that
    [application saveSessionForContext:context];
#else
    [self saveSession:session
	  inContext:context
	  withResponse:response
	  application:application];
#endif
  }
  
  [application sleep];
  
  /* locking */
  
  if (isLocked) {
    [application unlockRequestHandling];
    isLocked = NO;
  }
  
  [application _setCurrentContext:nil];
  return response;
}

@end /* WOComponentRequestHandler */
