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

#include "WORequestHandler+private.h"
#include "WOApplication+private.h"
#include "WOContext+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOStatisticsStore.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOCookie.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include "common.h"

//#define USE_POOLS 1

#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
@interface NSObject(Miss)
- (id)subclassResponsibility:(SEL)cmd;
@end
#endif

@interface WOApplication(Privates)
- (void)_setCurrentContext:(WOContext *)_ctx;
@end

@implementation WORequestHandler

static BOOL     doNotSetCookiePath = NO;
static Class    NSDateClass        = Nil;
static NGLogger *logger            = nil;
static NGLogger *perfLogger        = nil;

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSUserDefaults  *ud;
  NGLoggerManager *lm;
  static BOOL didInit = NO;

  if (didInit)
    return;
  didInit = YES;

  NSDateClass = [NSDate class];
  
  lm         = [NGLoggerManager defaultLoggerManager];
  logger     = [lm loggerForDefaultKey:@"WODebuggingEnabled"];
  perfLogger = [lm loggerForDefaultKey:@"WOProfileRequestHandler"];
  
  ud                 = [NSUserDefaults standardUserDefaults];
  doNotSetCookiePath = [ud boolForKey:@"WOUseGlobalCookiePath"];
}

- (id)init {
  if ((self = [super init])) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    if ([ud boolForKey:@"WORunMultithreaded"])
      self->lock = [[NSRecursiveLock alloc] init];
  }
  return self;
}

- (void)dealloc {
  [self->lock release];
  [super dealloc];
}

/* request handling */

- (BOOL)restoreSessionUsingIDs {
  /* restore a session if an ID was given */
  return YES;
}
- (BOOL)autocreateSessionForRequest:(WORequest *)_request {
  /* autocreate a session if none was restored */
  return NO;
}
- (BOOL)requiresSessionForRequest:(WORequest *)_request {
  /* _ensure_ that a session is available */
  return NO;
}

- (NSString *)sessionIDFromRequest:(WORequest *)_request
  application:(WOApplication *)_app
{
  NSString *sid;
  
  if ((sid = [_app sessionIDFromRequest:_request]) == nil)
    return nil;
  
#if DEBUG
  NSAssert1([sid isKindOfClass:[NSString class]],
            @"invalid session ID: %@", sid);
#endif
  return sid;
}

- (WOResponse *)handleRequest:(WORequest *)_request
  inContext:(WOContext *)context
  session:(WOSession *)session
  application:(WOApplication *)app
{
  return [self subclassResponsibility:_cmd];
}

- (BOOL)doesRejectFavicon {
  return YES;
}

- (WOResponse *)handleRequest:(WORequest *)_request {
  NSTimeInterval    startHandling = 0.0;
#if USE_POOLS
  NSAutoreleasePool *pool = nil;
#endif
  WOApplication *app;
  WOResponse    *response   = nil;
  WOContext     *context    = nil;
  NSThread      *thread;
  NSString      *sessionId  = nil;
  WOSession     *session    = nil;
  NSString *uri;
  
  /* first check URI for favicon requests ... */
  uri = [_request uri];
  if ([self doesRejectFavicon] && uri != nil) {
    if ([@"/favicon.ico" isEqualToString:uri]) {
      response = [WOResponse responseWithRequest:_request];
      [response setStatus:404 /* not found */];
      [self debugWithFormat:@"rejected favicon request: %@", uri];
      return response;
    }
  }
  
  if (perfLogger)
    startHandling = [[NSDateClass date] timeIntervalSince1970];
  
  thread = [NSThread currentThread];
  NSAssert(thread, @"missing current thread ...");
  
  if (_request == nil) return nil;

  *(&app) = nil;
  app = [WOApplication application];
  
#if USE_POOLS
  *(&pool) = [[NSAutoreleasePool alloc] init];
#endif
  {
    /* setup context */
    context = [WOContext contextWithRequest:_request];
    NSAssert(context, @"no context assigned ..");
    [app _setCurrentContext:context];
    
    /* check session id */
    *(&session)   = nil;
    *(&sessionId) = [self sessionIDFromRequest:_request application:app];
    
    if ([sessionId length] == 0)
      sessionId = nil;
    else if ([sessionId isEqualToString:@"nil"])
      sessionId = nil;
    
    NS_DURING {
      [app awake];
      
      /* retrieve session */
      if ([self restoreSessionUsingIDs]) {
        SYNCHRONIZED(app) {
          if (sessionId) {
            session = [app restoreSessionWithID:sessionId
                           inContext:context];
            if (session == nil) {
              response  = [app handleSessionRestorationErrorInContext:context];
              sessionId = nil;
            }
          }
        }
        END_SYNCHRONIZED;
        
        [[session retain] autorelease];
        
        if (response != nil)
          /* some kind of error response from above ... */
          goto responseDone;
	
        if (session == nil) {
          /* session autocreation .. */
          if ([self autocreateSessionForRequest:_request]) {
            if (![app isRefusingNewSessions]) {
              session = [app _initializeSessionInContext:context];
	      
              [self debugWithFormat:@"autocreated session: %@", session];
              
              if (session == nil)
                response =[app handleSessionRestorationErrorInContext:context];
            }
            else { /* app refuses new sessions */
              // TODO: this already failed once, will it return null again?
              [self logWithFormat:@"app is refusing new sessions ..."];
              response = [app handleSessionRestorationErrorInContext:context];
            }
          }
          if (response)
            /* some kind of error response from above ... */
            goto responseDone;
          
          /* check whether session is required ... */
          if ([self requiresSessionForRequest:_request] && (session == nil)) {
            response = [app handleSessionCreationErrorInContext:context];
            goto responseDone;
          }
        }
      }
      
      [session lock];
      
      NS_DURING {
        response = [self handleRequest:_request
                         inContext:context
                         session:session
                         application:app];
        
        session = [context hasSession]
          ? [context session]
          : nil;
        
        if (session != nil) {
          if ([session storesIDsInCookies]) {
            if (logger != nil) /* Note: required! do not remove */
	      [self debugWithFormat:@"add cookie to session: %@", session];
            [self addCookiesForSession:session
                  toResponse:response
                  inContext:context];
          }
          
          [self saveSession:session
                inContext:context
                withResponse:response
                application:app];
        }
        else
          [self debugWithFormat:@"no session to store."];
      }
      NS_HANDLER {
        response = [app handleException:localException inContext:context];
      }
      NS_ENDHANDLER;
      
      [session unlock];
      
    responseDone:
      [session _sleepWithContext:context];
      response = [response retain];
      
      [app sleep];
    }  
    NS_HANDLER {
      response = [app handleException:localException inContext:context];
      response = [response retain];
    }
    NS_ENDHANDLER;
    
    [app _setCurrentContext:nil];
  }
#if USE_POOLS
  [pool release]; pool = nil;
#endif

  [app lock];
  if ([app isRefusingNewSessions] &&
      ([app activeSessionsCount] < [app minimumActiveSessionsCount])) {
    [self logWithFormat:
            @"application terminates because it refuses new sessions and "
            @"the active session count (%i) is below the minimum (%i).",
            [app activeSessionsCount], [app minimumActiveSessionsCount]];
    [app terminate];
  }
  [app unlock];
  
  if (perfLogger) {
    NSTimeInterval rt;
    rt = [[NSDateClass date] timeIntervalSince1970] - startHandling;
    [perfLogger logWithFormat:@"handleRequest took %4.3fs.",
                  rt < 0.0 ? -1.0 : rt];
  }
  
  return [response autorelease];
}

/* locking */

- (void)lock {
  [self->lock lock];
}
- (void)unlock {
  [self->lock unlock];
}

/* KVC */

- (id)valueForUndefinedKey:(NSString *)_key {
  [self debugWithFormat:@"queried undefined KVC key (returning nil): '%@'",
	  _key];
  return nil;
}

/* logging */

- (id)debugLogger {
  return logger;
}

/* Cookies */

- (void)addCookiesForSession:(WOSession *)_sn
  toResponse:(WOResponse *)_response
  inContext:(WOContext *)_ctx
{
  WOApplication *app;
  WOCookie *cookie     = nil;
  NSString *uri;
  NSString *value;
  
  if (![_sn storesIDsInCookies])
    return;
  
  app = [WOApplication application];
  
  // TODO: there is a DUP of this section in OpenGroupware.m to set an
  //       expiration cookie
  if (!doNotSetCookiePath) {
    NSString *tmp;
      
    if ((uri = [[_ctx request] applicationName]) == nil)
      uri = [app name];
    uri = [@"/" stringByAppendingString:uri];
    if ((tmp = [[_ctx request] adaptorPrefix]))
      uri = [tmp stringByAppendingString:uri];
  }
  else
    uri = @"/";
  
#if 0 // TODO: explain!
  uri = [_ctx urlSessionPrefix];
  uri = [_ctx urlWithRequestHandlerKey:
		[WOApplication componentRequestHandlerKey]
	      path:@"/"
	      queryString:nil];
#endif
    
  value = [_sn isTerminating]
    ? (NSString *)@"nil"
    : [_sn sessionID];
    
  cookie = [WOCookie cookieWithName:[app name]
		     value:value
		     path:uri
		     domain:[_sn domainForIDCookies]
		     expires:[_sn expirationDateForIDCookies]
		     isSecure:NO];
  if (cookie != nil)
    [_response addCookie:cookie];
}

@end /* WORequestHandler */


@implementation WORequest(DblClickBrowser)

- (BOOL)isDoubleClickBrowser {
  return NO;
}

@end /* WORequest(DblClickBrowser) */

@implementation WORequestHandler(Support)

- (WOResponse *)doubleClickResponseForContext:(WOContext *)_ctx {
  // DEPRECATED
  return nil;
}

- (void)saveSession:(WOSession *)_session
  inContext:(WOContext *)_ctx
  withResponse:(WOResponse *)_response
  application:(WOApplication *)_app
{
  static BOOL perflog = NO;
  NSTimeInterval startSaveSn = 0.0;
  
  if (_session == nil) return;

  if (perflog)
    startSaveSn = [[NSDate date] timeIntervalSince1970];
  
  [_app saveSessionForContext:_ctx];
  
  if (perflog) {
    NSTimeInterval rt;
    rt = [[NSDate date] timeIntervalSince1970] - startSaveSn;
    NSLog(@"[rq]: saving of session took %4.3fs.",
          rt < 0.0 ? -1.0 : rt);
  }
}

- (void)_fixupResponse:(WOResponse *)_response {
  NSString *ctype;
  NSString *cntype = nil;
  
  if ((ctype = [_response headerForKey:@"content-type"]) == nil) {
    NSData *body;
    
    ctype = @"text/html";
    
    body = [_response content];
    if ([body length] > 6) {
      const unsigned char *bytes;

      if ((bytes = [body bytes])) {
        if ((bytes[0] == '<') && (bytes[1] == '?')) {
          if ((bytes[2] == 'x') && (bytes[3] == 'm') && (bytes[4] == 'l'))
            ctype = @"text/xml";
        }
      }
    }
    
    [_response setHeader:ctype forKey:@"content-type"];
  }

  if ([ctype isEqualToString:@"text/html"]) {
    switch ([_response contentEncoding]) {
      case NSISOLatin1StringEncoding:
        cntype = [ctype stringByAppendingString:@"; charset=iso-8859-1"];
        break;
      case NSUTF8StringEncoding:
        cntype = [ctype stringByAppendingString:@"; charset=utf-8"];
        break;
	
      default:
        break;
    }
  }
  if (cntype)
    [_response setHeader:cntype forKey:@"content-type"];
}

- (WOResponse *)generateResponseForComponent:(WOComponent *)_component
  inContext:(WOContext *)_ctx
  application:(WOApplication *)_app
{
  WOResponse *response;
  
  if (_component == nil) return nil;
  
  /* make the component the "response page" */
  [_ctx setPage:_component];
  
  if ([_ctx hasSession]) {
    response = [_ctx response];
    [_app appendToResponse:response inContext:_ctx];
  }
  else {
    //[self logWithFormat:@"generating component using -generateResponse"];
    response = [_component generateResponse];
    
    /* generate statistics */
    [[_app statisticsStore]
           recordStatisticsForResponse:response
           inContext:_ctx];
  }
  
  [self _fixupResponse:response];
  return response;
}

@end /* WORequestHandler(Support) */
