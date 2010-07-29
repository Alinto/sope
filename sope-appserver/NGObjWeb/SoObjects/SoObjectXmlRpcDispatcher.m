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

#include "SoObjectXmlRpcDispatcher.h"
#include "SoObject.h"
#include "SoClass.h"
#include "NSException+HTTP.h"
#include <NGXmlRpc/XmlRpcMethodCall+WO.h>
#include <NGXmlRpc/XmlRpcMethodResponse+WO.h>
#include <NGObjWeb/WOActionResults.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"

@interface NSObject(XmlRpcCall)

- (id)callOnObject:(id)_client 
  withPositionalParameters:(NSArray *)_args
  inContext:(id)_ctx;

@end

@implementation SoObjectXmlRpcDispatcher

static BOOL debugOn = NO;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn = [ud boolForKey:@"SoObjectXmlRpcDispatcherDebugEnabled"];
  if (debugOn) NSLog(@"Note: SOPE XML-RPC Dispatcher Debugging turned on.");
}

/* error handling */

- (NSException *)missingMethodFault:(NSString *)_method 
  inContext:(WOContext *)_ctx
{
  NSString *r;
  
  r = [@"Could not locate requested XML-RPC method: " 
	stringByAppendingString:_method];
  return [NSException exceptionWithHTTPStatus:404 /* not found */
		      reason:r];
}

/* perform call on object */

- (BOOL)isPackagePathMethodName:(NSString *)_name inContext:(WOContext *)_ctx {
  /*
    If the XML-RPC method name contains a dot (eg system.listmethods), we need
    to check whether the namespace is to be treated as a path or whether we
    should lookup the fully qualified name.
    
    So we first check whether it contains a dot, then we check whether the
    object implements the fully qualified name. Otherwise we treat the
    namespace as a path.
  */
  NSRange r;

  /* check whether the name contains a dot ... */
  
  r = [_name rangeOfString:@"." options:(NSLiteralSearch|NSBackwardsSearch)];
  if (r.length == 0)
    return NO; /* no dot ... */
  
  /* check whether the object implements the fully qualified name */
  
  if ([self->object hasName:_name inContext:_ctx])
    return NO;
  
  [self debugWithFormat:
	  @"Note: did not find pkg name '%@' in %@", _name, self->object];
  
  /* otherwise, perform a path lookup ... */
  return YES;
}

- (NSException *)getClientObject:(id *)_object andMethodName:(NSString **)_mn
  forPackageMethodPath:(NSString *)_path inContext:(WOContext *)_ctx
{
  /* has a prefix, eg "folder.folder.a()" => traverse */
  NSArray     *nsParts;
  NSException *error = nil;
  unsigned    count;
    
  nsParts = [_path componentsSeparatedByString:@"."];
  count   = [nsParts count];
  *_mn    = [[[nsParts objectAtIndex:(count - 1)] copy] autorelease];
  nsParts = [nsParts subarrayWithRange:NSMakeRange(0, count - 1)];
  
  [self debugWithFormat:@"XML-RPC traversal: %@",
	    [nsParts componentsJoinedByString:@" => "]];
  
  /*
    TODO: we might not want to use -traverse.. so that the clientObject
          stays the same (the one bound to the URL)?
  */
  *_object = [self->object 
		  traversePathArray:nsParts inContext:_ctx error:&error
		  acquire:YES];
  return error;
}

- (id)performActionNamed:(NSString *)_name parameters:(NSArray *)_params 
  inContext:(WOContext *)_ctx
{
  NSString *methodName;
  id       clientObject;
  id       method;

  // TODO: check whether _name is set
  
  [self debugWithFormat:@"should perform: %@", _name];
  methodName = nil;
  
  if ([self isPackagePathMethodName:_name inContext:_ctx]) {
    /* has a prefix, eg "folder.folder.a()" => traverse */
    NSException *error = nil;

    [self debugWithFormat:@"Note: traversing path to XML-RPC method: %@",
	    _name];
    
    error = [self getClientObject:&clientObject andMethodName:&methodName
		  forPackageMethodPath:_name inContext:_ctx];
    if (error) {
      [self debugWithFormat:@"  XML-RPC traversal error: %@", error];
      return error;
    }
  }
  else {
    clientObject = self->object;
    methodName   = _name;
  }
  
  method = [clientObject lookupName:methodName inContext:_ctx acquire:YES];
  if (method == nil) {
    // TODO: return proper fault!
    [self logWithFormat:@"did not find requested XML-RPC method: '%@'",
	    methodName];
    return [self missingMethodFault:methodName inContext:_ctx];
  }
  if (![method isCallable]) {
    // TODO: return proper fault!
    [self logWithFormat:
	    @"located object (%@) is not callable (class=%@):\n  %@", 
	    methodName, NSStringFromClass([method class]), method];
    return nil;
  }
  
  /* TODO: do we need to bind or is this automatic? */
  
  if ([method respondsToSelector:
		@selector(callOnObject:withPositionalParameters:inContext:)]) {
    [self debugWithFormat:
	    @"calling XML-RPC method with %i positional parameters.",
	    [_params count]];
    return [method callOnObject:clientObject 
		   withPositionalParameters:_params 
		   inContext:_ctx];
  }
  
  if ([_params count] > 0) {
    [self warnWithFormat:
            @"invoking SOPE method via XML-RPC without "
            @"positional paramters (%i parameters defined): %@",
            [_params count], method];
  }
  return [method callOnObject:clientObject inContext:_ctx];
}

- (id)faultFromException:(NSException *)_exception
  methodCall:(XmlRpcMethodCall *)_call
{
#if !APPLE_FOUNDATION_LIBRARY && !NeXT_Foundation_LIBRARY
  /* add some more information to generic exceptions ... */
  if (_call != nil) {
    NSMutableDictionary *ui;
    
    ui = [[_exception userInfo] mutableCopy];
    if (ui == nil) ui = [[NSMutableDictionary alloc] init];
    
    [ui setObject:[_call methodName] forKey:@"methodName"];
    [ui setObject:[_call parameters] forKey:@"methodParameters"];
    
    [_exception setUserInfo:ui];
    [ui release];
  }
#endif
  
  [self logWithFormat:@"%s: turning exception into fault %@\n",
          __PRETTY_FUNCTION__,
          [_exception description]];
  
  return _exception;
}

- (id<WOActionResults>)actionResponseForResult:(id)resValue {
  if ([resValue conformsToProtocol:@protocol(WOActionResults)]) {
    /* a "HTTP" result ... */
    return resValue;
  }
  else {
    /* an XML-RPC result ... */
    XmlRpcMethodResponse *mResponse;
    
    mResponse = [[XmlRpcMethodResponse alloc] initWithResult:resValue];
    return [mResponse autorelease];
  }
}

- (id)performMethodCall:(XmlRpcMethodCall *)_call inContext:(WOContext *)_ctx{
  id resValue;
  
  NS_DURING {
    resValue = [self performActionNamed:[_call methodName]
                     parameters:[_call parameters]
		     inContext:_ctx];
    resValue = [resValue retain];
  }
  NS_HANDLER {
    resValue = [self faultFromException:localException
                     methodCall:_call];
    resValue = [resValue retain];
  }
  NS_ENDHANDLER;
  
  resValue = [resValue autorelease];
  
  return [self actionResponseForResult:resValue];
}

- (id)couldNotDecodeXmlRpcRequestInContext:(WOContext *)_ctx {
  WOResponse *r = [_ctx response];
  
  [r setStatus:400 /* bad request */];
  [r appendContentString:@"malformed XML-RPC request !"];
  return r;
}

- (id)handleXmlRpcEncodingException:(NSException *)_exception object:(id)_obj {
  [self logWithFormat:@"could not encode object: %@ (%@): %@",
	  _obj, NSStringFromClass([_obj class]), _exception];
  return nil;
}

- (id)dispatchInContext:(WOContext *)_ctx {
  XmlRpcMethodResponse *r;
  XmlRpcMethodCall *call;
  id result;
  
  if (![XmlRpcMethodCall
	 instancesRespondToSelector:@selector(initWithRequest:)]) {
    [self errorWithFormat:
	    @"XmlRpcMethodCall does not respond to -initWithRequest:, "
	    @"this method is part of libNGXmlRpc which you might want to link "
	    @"against to get XML-RPC support."];
    return [NSException exceptionWithHTTPStatus:501 /* Not Implemented */
			reason:@"server does not support XML-RPC"];
  }
  
  /* decode XML-RPC call */
  
  call = [XmlRpcMethodCall alloc];
  call = [call initWithRequest:[_ctx request]];
  call = [call autorelease];
  
  if (call == nil)
    return [self couldNotDecodeXmlRpcRequestInContext:_ctx];

  /* perform call */
  
  if ((result = [self performMethodCall:call inContext:_ctx]) == nil)
    /* TODO: should we return a fault instead? */
    return nil;
  
  if ([result isKindOfClass:[WOResponse class]])
    /* pass WOResponse objects through ... */
    return result;
  
  /* encode result as XML-RPC */
  
  NS_DURING {
    if ([result isKindOfClass:[XmlRpcMethodResponse class]])
      r = result;
    else
      r = [[[XmlRpcMethodResponse alloc] initWithResult:result] autorelease];
    
    result = [[[r generateResponse] retain] autorelease];
  }
  NS_HANDLER {
    result = [self handleXmlRpcEncodingException:localException
		   object:result];
  }
  NS_ENDHANDLER;
  
  return result;
}

/* debugging */

- (NSString *)loggingPrefix {
  return @"[obj-xmlrpc-dispatch]";
}
- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* SoObjectXmlRpcDispatcher */
