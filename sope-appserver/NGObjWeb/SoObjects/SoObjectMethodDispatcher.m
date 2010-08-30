/*
  Copyright (C) 2002-2005 SKYRIX Software AG

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

#include "SoObjectMethodDispatcher.h"
#include "SoObject.h"
#include "SoClass.h"
#include "SoObjectRequestHandler.h"
#include "WOContext+SoObjects.h"
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOElement.h>
#include "common.h"

@implementation SoObjectMethodDispatcher

static BOOL debugOn = NO;
static BOOL useRedirectsForDefaultMethods = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  debugOn = [ud boolForKey:@"SoObjectMethodDispatcherDebugEnabled"];
  useRedirectsForDefaultMethods = 
    [ud boolForKey:@"SoRedirectToDefaultMethods"];
}

- (id)initWithObject:(id)_object {
  if ((self = [super init])) {
    self->object = [_object retain];
  }
  return self;
}
- (void)dealloc {
  [self->object release];
  [super dealloc];
}

/* perform dispatch */

- (id)dispatchInContext:(WOContext *)_ctx {
  NSAutoreleasePool *pool;
  WORequest *rq;
  NSString  *httpMethod;
  id clientObject;
  id methodObject;
  id resultObject;
  
  pool = [[NSAutoreleasePool alloc] init];
  rq   = [_ctx request];
  
  /* find client object */
  
  if ((clientObject = [_ctx clientObject]) != nil) {
    if (debugOn)
      [self debugWithFormat:@"client object set in ctx: %@", clientObject];
  }
  else if ((clientObject = [self->object clientObject]) != nil) {
    if (debugOn)
      [self debugWithFormat:@"setting client object: %@", clientObject];
    [_ctx setClientObject:clientObject];
  }

  /* check whether client object is a response ... */
  
  if ([clientObject isKindOfClass:[WOResponse class]]) {
    [self debugWithFormat:@"clientObject is a WOResponse, returning that: %@",
	    clientObject];
    resultObject = [clientObject retain];
    [pool release];
    return [resultObject autorelease];
  }
  
  // TODO: should check XML-RPC !!! 
  //       (hm, why? XML-RPC is handled by other dispatcher?)
  
  /* 
     This X- field is used by Google which uses POST to trigger REST methods,
     don't ask me why ... ;-/
  */
  if (![(httpMethod = [rq headerForKey:@"x-http-method-override"]) isNotEmpty])
    httpMethod = [rq method];
  
  /* find callable (method) object */
  
  if ([self->object isCallable]) {
    if (debugOn)
      [self debugWithFormat:@"traversed object is callable: %@", self->object];
    methodObject = self->object;
  }
  else if ([[self->object soClass] hasKey:httpMethod inContext:_ctx]) {
    // TODO: I'm not sure whether this step is correct
    /* the class has a GET/PUT/xxx method */
    methodObject = [self->object lookupName:[rq method] 
				 inContext:_ctx
				 acquire:NO];
  }
  else if (useRedirectsForDefaultMethods) {
    /*
      Redirect to a default method if available.
    */
    NSString *defaultName;
    
    methodObject = nil;
    defaultName = [self->object defaultMethodNameInContext:_ctx];
    if ([defaultName isNotEmpty]) {
      WOResponse *r;
      NSString   *url;
	
      url = [self->object baseURLInContext:_ctx];
      if (![url hasSuffix:@"/"]) url = [url stringByAppendingString:@"/"];
      url = [url stringByAppendingString:defaultName];
	
      [self debugWithFormat:@"redirect to default method %@ of %@: %@", 
	      defaultName, self->object, url];
	
      r = [[_ctx response] retain];
      [r setStatus:302 /* moved */];
      [r setHeader:url forKey:@"location"];
      [pool release];
      return [r autorelease];
    }
  }
  else {
    /* 
       Note: this can lead to incorrect URLs if the base URL of the method is
             not set (the method will run in the client URL).
    */
    methodObject = [self->object lookupDefaultMethod];
    if (debugOn)
      [self debugWithFormat:@"using default method: %@", methodObject];
  }
  
  /* apply arguments */
    
  if ([methodObject respondsToSelector:
  		      @selector(takeValuesFromRequest:inContext:)]) {
    if (debugOn)
      [self debugWithFormat:@"applying values from request ..."];
    [methodObject takeValuesFromRequest:rq inContext:_ctx];
  }

  /* perform call */
  
  if (methodObject == nil || ![methodObject isCallable]) {
    /*
      The object is neither callable nor does it have a default method,
      so we just pass it through.
      
      Note: you can run into situations where there is a methodObject, but
            it isn't callable. Eg this situation can occur if the default
	    method name leads to an object which isn't a method (occured in
	    the OFS context if 'index' maps to an OFSFile which itself isn't
	    callable).
    */
    resultObject = self->object;
    if (debugOn) {
      if (methodObject == nil) {
	[self debugWithFormat:@"got no method, using object as result: %@", 
	        resultObject];
      }
      else {
	[self debugWithFormat:
		@"method is not callable %@, using object as result: %@", 
	        methodObject, resultObject];
      }
    }
  }
  else {
    resultObject = [methodObject callOnObject:[_ctx clientObject]
				 inContext:_ctx];
    if (debugOn) {
      if ([resultObject isKindOfClass:[WOResponse class]]) {
	[self debugWithFormat:@"call produced response: 0x%p (code=%i)", 
	        resultObject, [(WOResponse *)resultObject status]];
      }
      else
	[self debugWithFormat:@"call produced result: %@", resultObject];
    }
  }
  
  resultObject = [resultObject retain];
  [pool release];
  
  /* deliver result */
  return [resultObject autorelease];
}

/* logging */

- (NSString *)loggingPrefix {
  return @"[obj-mth-dispatch]";
}
- (BOOL)isDebuggingEnabled {
  return debugOn ? YES : NO;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self,
        NSStringFromClass((Class)*(void**)self)];
  
  if (self->object)
    [ms appendFormat:@" object=%@", self->object];
  else
    [ms appendString:@" <no object>"];
  
  [ms appendString:@">"];
  return ms;
}

@end /* SoObjectMethodDispatcher */
