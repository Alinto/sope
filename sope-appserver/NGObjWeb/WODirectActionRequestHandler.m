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

#include "WODirectActionRequestHandler.h"
#include "WORequestHandler+private.h"
#include "WOContext+private.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WODirectAction.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOSessionStore.h>
#include <NGObjWeb/WOStatisticsStore.h>
#include "common.h"

#if APPLE_RUNTIME || NeXT_RUNTIME
#  include <objc/objc-class.h>
#endif

static BOOL  usePool = NO;
static BOOL  perflog = NO;
static BOOL  debugOn = NO;
static Class NSDateClass = Nil;

@implementation WODirectActionRequestHandler

+ (int)version {
  return [super version] + 0 /* 2 */;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);

  NSDateClass = [NSDate class];
  perflog = [ud boolForKey:@"WOProfileDirectActionRequestHandler"];
}

- (NSString *)loggingPrefix {
  return @"[da-handler]";
}

/*
  The request handler part of a direct action URI looks like this:
  
    [actionClass/]actionName[?key=value&key=value&...]
*/

- (BOOL)isComponentClass:(Class)_clazz {
  if (_clazz == Nil) 
    return NO;
#if (defined(__GNU_LIBOBJC__) && (__GNU_LIBOBJC__ == 20100911)) || defined(APPLE_RUNTIME) || defined(__GNUSTEP_RUNTIME__)
  while ((_clazz = class_getSuperclass(_clazz)) != Nil) {
#else
  while ((_clazz = _clazz->super_class) != Nil) {
#endif
    if (_clazz == [WOComponent    class]) return YES;
    if (_clazz == [WODirectAction class]) return NO;
    if (_clazz == [NSObject       class]) return NO;
  }
  return NO;
}

- (id)instantiateObjectForActionClass:(Class)actionClass
  inContext:(WOContext *)context
  application:(WOApplication *)app
{
  WOComponent *component;
  
  if (actionClass == Nil)
    return nil;
  
  if (![self isComponentClass:actionClass]) {
    /* create direct action object */
    id actionObject;
    
    if (![actionClass instancesRespondToSelector:
			@selector(initWithContext:)]) {
      [self logWithFormat:@"tried to use class '%@' as a direct-action class",
	      NSStringFromClass(actionClass)];
      return nil;
    }
    
    actionObject =
      [(WODirectAction *)[actionClass alloc] initWithContext:context];
    actionObject = [actionObject autorelease];
    return actionObject;
  }
  
  /* special initialization for WOComponents used as direct actions */
    
  component = [app pageWithName:NSStringFromClass(actionClass)
		   inContext:context];
  [context setPage:(id)component];
  
  if ([component shouldTakeValuesFromRequest:[context request]
		 inContext:context])
    [app takeValuesFromRequest:[context request] inContext:context];
  
  return component;
}

- (WOResponse *)handleRequest:(WORequest *)_request
  inContext:(WOContext *)context
  session:(WOSession *)session
  application:(WOApplication *)app
{
  NSAutoreleasePool   *pool2;
  NSString            *actionClassName;
  NSString            *actionName;
  WOResponse          *response;
  NSArray             *handlerPath;
  Class               actionClass = Nil;
  WODirectAction      *actionObject = nil;
  id<WOActionResults> result = nil;

  pool2 = usePool ? [[NSAutoreleasePool alloc] init] : nil;
  
  *(&result) = nil;
  *(&response)        = nil;
  *(&actionClassName) = nil;
  *(&actionName)      = nil;
  *(&handlerPath)     = nil;
  
  /* process path */
  
  handlerPath = [_request requestHandlerPathArray];

  if (debugOn) {
    [self debugWithFormat:@"path=%@ array=%@",
          [_request requestHandlerPath], handlerPath];
  }
  
  // TODO: fix OGo bug #1028
  switch ([handlerPath count]) {
    case 0:
      actionClassName = @"DirectAction";
      actionName      = @"default";
      break;
    case 1:
      actionClassName = @"DirectAction";
      actionName      = [handlerPath objectAtIndex:0];
      break;
    case 2:
      actionClassName = [handlerPath objectAtIndex:0];
      actionName      = [handlerPath objectAtIndex:1];
      break;

    default:
      actionClassName = [handlerPath objectAtIndex:0];
      actionName      = [handlerPath objectAtIndex:1];
      // TODO: set path info in ctx?
      if (debugOn) {
	[self logWithFormat:@"invalid direction action URL: %@",
                [_request requestHandlerPath]];
      }
      break;
  }

  if ([actionName length] == 0)
    actionName = @"default";

  if ((*(&actionClass) = NSClassFromString(actionClassName)) == Nil) {
    [self errorWithFormat:@"did not find direct action class %@",
            actionClassName];
    actionClass = [WODirectAction class];
  }
  
  if (debugOn) {
    [self debugWithFormat:
	    @"[direct action request handler] class=%@ action=%@ ..",
            actionClassName, actionName];
  }
  
  /* process request */
  
  actionObject = [self instantiateObjectForActionClass:actionClass
		       inContext:context
		       application:app];
  
  if (actionObject == nil) {
    [self errorWithFormat:
            @"could not create direct action object of class %@",
            actionClassName];
    actionObject = nil;
  }
  else {
    static Class WOComponentClass = Nil;
    
    if (WOComponentClass == Nil)
      WOComponentClass = [WOComponent class];
    
    result = [(id)[actionObject performActionNamed:actionName] retain];
    
    if (result == nil) result = [[context page] retain];
    
    if ([(id)result isKindOfClass:WOComponentClass]) {
      [(id)result _awakeWithContext:context];
      [context setPage:(WOComponent *)result];
      
      response = [self generateResponseForComponent:(WOComponent *)result
                       inContext:context
                       application:app];
      
      if ([context hasSession]) {
        if ([context savePageRequired])
          [[context session] savePage:(WOComponent *)result];
      }
      
      response = [response retain];
    }
    else {
      /* generate response */
      response = [[result generateResponse] retain];
    }
              
    [context sleepComponents];
    
    [(id)result release]; result = nil;
    
    /* check whether a session was created */
    if ((session == nil) && [context hasSession]) {
      session = [[[context session] retain] autorelease];
      [session lock];
    }
    
    if (usePool) {
      session = [session retain];
      [pool2 release]; pool2 = nil;
      session = [session autorelease];
    }
    response = [response autorelease];
  }
  
  return response;
}

@end /* WODirectActionRequestHandler */
