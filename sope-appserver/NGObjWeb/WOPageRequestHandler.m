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

#include <NGObjWeb/WORequestHandler.h>

@interface WOPageRequestHandler : WORequestHandler
@end

//#include "WOPageRequestHandler.h"
#include "WORequestHandler+private.h"
#include "WOContext+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WODirectAction.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOSessionStore.h>
#include <NGObjWeb/WOStatisticsStore.h>
#include "common.h"

static BOOL  perflog             = NO;
static Class NSDateClass         = Nil;
static BOOL  debugUnknownActions = NO;
static BOOL  debugOn             = NO;

@interface WOComponent(Privates)
- (void)_awakeWithContext:(WOContext *)_ctx;
- (id<WOActionResults>)performActionNamed:(NSString *)_actionName;
@end

@implementation WOPageRequestHandler

+ (int)version {
  return [super version] + 0 /* 2 */;
}
+ (void)initialize {
  NSUserDefaults *ud;
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  NSDateClass = [NSDate class];
  ud = [NSUserDefaults standardUserDefaults];
  perflog = [ud boolForKey:@"WOProfilePageRequestHandler"];
  debugOn = [ud boolForKey:@"WOPageRequestHandlerDebugEnabled"];
}

/* debugging */

- (NSString *)loggingPrefix {
  return @"[pg-handler]";
}
- (BOOL)isDebuggingEnabled {
  return debugOn;
}

/*
  The request handler part of a direct action URI looks like this:

    [actionClass/]actionName[?key=value&key=value&...]
*/

- (WOResponse *)handleRequest:(WORequest *)_request
  inContext:(WOContext *)context
  session:(WOSession *)session
  application:(WOApplication *)app
{
  NSString      *actionName;
  WOResponse    *response;
  id<WOActionResults> result = nil;
  NSString      *pageName;
  WOComponent   *page;
  
  *(&result) = nil;
  *(&response)        = nil;
  *(&actionName)      = nil;
  
  /* process path */
  if ((pageName = [_request headerForKey:@"x-httpd-pagename"]) == nil) {
    NSArray *handlerPath;
    
    handlerPath = [_request requestHandlerPathArray];
    switch ([handlerPath count]) {
      case 0:
        pageName   = @"Main";
        actionName = @"default";
        break;
      case 1:
        pageName   = [handlerPath objectAtIndex:0];
        actionName = @"default";
        break;
      default:
        pageName   = [handlerPath objectAtIndex:0];
        actionName = [handlerPath objectAtIndex:1];
        break;
    }
    
    if (debugOn) {
      [self debugWithFormat:@"path:   %@",   handlerPath];
      [self debugWithFormat:@"page:   %@",   pageName];
      [self debugWithFormat:@"action: %@", actionName];
    }
  }
  else {
    if (debugOn)
      [self debugWithFormat:@"using httpd provided pagename: %@", pageName];
  }
  
  if (pageName == nil)
    pageName = @"Main";
  
  if ((page = [app pageWithName:pageName inContext:context]) == nil) {
    [self errorWithFormat:
            @"could not create page object with name %@", pageName];
    return nil;
  }
  
  [self debugWithFormat:@"created page: %@", page];
  
  /* setup page context */
  [page _awakeWithContext:context];
  [context setPage:page];
  
  /* take values phase */
  
  [app takeValuesFromRequest:_request inContext:context];
  
  /* perform a direct action like action */
  
  result = [page performActionNamed:actionName];

  /* generate response */
  
  if (result != page && result != nil) {
    if ([(id)result isKindOfClass:[WOComponent class]]) {
      [(WOComponent *)result _awakeWithContext:context];
      [context setPage:(WOComponent *)result];
      
      response = [self generateResponseForComponent:(WOComponent *)result
                       inContext:context
                       application:app];
    }
    else
      response = [result generateResponse];
  }
  else {
    result = page;
    response = [self generateResponseForComponent:page
                     inContext:context
                     application:app];
  }
  
  if ([context hasSession]) {
    if ([context savePageRequired])
      [[context session] savePage:(WOComponent *)result];
  }
  
  /* check whether a session was created */
  if ((session == nil) && [context hasSession]) {
    session = [[[context session] retain] autorelease];
    [session lock];
  }
  
  /* add session cookies to response */
  [self addCookiesForSession:session
        toResponse:response
        inContext:context];
    
  /* store session if one was active */
  [self saveSession:session
        inContext:context
        withResponse:response
        application:app];
  
  return response;
}

@end /* WOPageRequestHandler */

@implementation WOComponent(DirectActionExtensions)

/* taking form values */

- (void)takeFormValuesForKeyArray:(NSArray *)_keys {
  NSEnumerator *keys;
  NSString     *key;
  WORequest    *rq;

  rq   = [[self context] request];
  keys = [_keys objectEnumerator];

  while ((key = [keys nextObject]))
    [self takeValue:[rq formValueForKey:key] forKey:key];
}
- (void)takeFormValuesForKeys:(NSString *)_key1,... {
  va_list   va;
  NSString  *key;
  WORequest *rq;
  
  rq = [[self context] request];
  va_start(va, _key1);
  for (key = _key1; key != nil; key = va_arg(va, NSString *))
    [self takeValue:[rq formValueForKey:key] forKey:key];
  va_end(va);
}

/* perform actions */

- (id<WOActionResults>)defaultAction {
  return self;
}

- (id<WOActionResults>)performActionNamed:(NSString *)_actionName {
  SEL actionSel;
  NSRange rng;
  
  /* discard everything after a point in the URL */
  rng = [_actionName rangeOfString:@"."];
  if (rng.length > 0)
    _actionName = [_actionName substringToIndex:rng.location];
  
  _actionName = [_actionName stringByAppendingString:@"Action"];
  
  if ((actionSel = NSSelectorFromString(_actionName)) == NULL) {
    [self debugWithFormat:@"did not find selector for action: %@", 
	    _actionName];
    return [self defaultAction];
  }
  
  if ([self respondsToSelector:actionSel]) 
    return [self performSelector:actionSel];

  if (debugUnknownActions) {
    [self logWithFormat:@"Page class %@ cannot handle action %@",
            NSStringFromClass([self class]), _actionName];
  }
  return [self defaultAction];
}

@end /* WOComponent(DirectActionExtensions) */
