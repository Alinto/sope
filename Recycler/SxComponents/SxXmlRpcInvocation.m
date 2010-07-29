/*
  Copyright (C) 2000-2003 SKYRIX Software AG

  This file is part of OGo

  OGo is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  OGo is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with OGo; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/
// $Id$

#include "SxXmlRpcInvocation.h"
#include "SxXmlRpcComponent.h"
#include "SxComponentException.h"
#include "SxBasicAuthCredentials.h"
#include <NGXmlRpc/XmlRpcMethodCall+WO.h>
#include <NGXmlRpc/XmlRpcMethodResponse+WO.h>
#include <SxComponents/SxComponentMethodSignature.h>
#include <SxComponents/SxComponentRegistry.h>
#include <NGObjWeb/NGObjWeb.h>
#include <NGHttp/NGHttpHeaderFieldParser.h>
#include "common.h"

@interface NSObject(SxXmlRpcValue)
- (NSArray *)asXmlRpcValueOfType:(NSString *)_type;
@end

@interface NSObject(HttpCredentials)

- (BOOL)usableWithHttpResponse:(WOResponse *)_response;
- (void)applyOnRequest:(WORequest *)_request;

@end

@interface SxXmlRpcInvocation(ErrorHandling)

- (void)_setException:(NSString *)_name
  reason:(NSString *)_reason
  methodCall:(XmlRpcMethodCall *)_call;

- (id)sendFailedForMethodCall:(XmlRpcMethodCall *)_call
  exception:(NSException *)_exception;
- (id)receiveFailedForMethodCall:(XmlRpcMethodCall *)_call;
- (id)call:(XmlRpcMethodCall *)_call
  failedWithResponse:(WOResponse *)_response;
- (id)callFailedNoCredentials:(WOResponse *)_response;
- (id)callFailedNoUsableCredentials:(WOResponse *)_response;
- (id)handleCallExceptionResult:(NSException *)_exception;

- (id)call:(XmlRpcMethodCall *)_call
  invalidResultContentType:(WOResponse *)_response;
  
@end

@interface SxXmlRpcInvocation(AsyncResult)

- (void)resultReady:(id)_result;

@end

@interface SxXmlRpcInvocation(Creds)

- (NSMutableArray *)_makeUsableCredentialsArrayForTarget:(id)_target
  response:(WOResponse *)_response;
- (void)_processSuccessfulCredentials:(id)_creds
  forTarget:(SxXmlRpcComponent *)_target;

@end

@interface SxXmlRpcTransaction : NSObject
{
@public
  SxXmlRpcInvocation *invocation;   /* non-retained */
  id                 currentCreds;
  XmlRpcMethodCall   *methodCall;
  WORequest          *request;
  SxXmlRpcComponent  *currentTarget;
  NSMutableArray     *usableCreds;
  unsigned           credIdx;
  WOHTTPConnection   *httpConnection;
}

- (id)initWithMethod:(NSString *)_methodName
  target:(SxXmlRpcComponent *)_target
  arguments:(NSArray *)_params
  forInvocation:(SxXmlRpcInvocation *)_inv;
- (void)finish;

- (BOOL)isAsyncResultPending;

- (BOOL)sendFirstAsyncRequest;
- (BOOL)sendNextRequest;
- (WOResponse *)readResponse;

- (void)processResponse:(WOResponse *)_response;

@end

@interface WOResponse(XmlRpcResponseType)

- (BOOL)isXmlRpcResponse;

@end

@implementation WOResponse(XmlRpcResponseType)

- (BOOL)isXmlRpcResponse {
  NSString *ctype;
  
  ctype = [self headerForKey:@"content-type"];
  
  if ([ctype hasPrefix:@"text/xml"])
    /* this is the expected/valid XML-RPC response content type ... */
    return YES;

  if ([ctype hasPrefix:@"text/"] || [ctype length] == 0) {
    /* if the client send a text entity or no content-type, check the content */
    NSData *data;
    
    data = [self content];
    if ([data length] > 32) {
      const char *bytes = [data bytes];
      if (strncmp("<methodResponse>", bytes, 16) != 0)
        return YES;
    }
  }
  
  return NO;
}

@end /* WOResponse(XmlRpcResponseType) */

@implementation SxXmlRpcInvocation

static NSNull *null = nil;

+ (int)version {
  return [super version] + 0 /* v1 */;
}

- (void)dealloc {
  RELEASE(self->transaction);
  [super dealloc];
}

- (BOOL)isDebuggingEnabled {
  static int debugOn = -1;
  if (debugOn == -1) {
    debugOn = [[[NSUserDefaults standardUserDefaults]
                                objectForKey:@"SxXmlRpcInvocationDebug"]
                                boolValue];
  }
  return debugOn ? YES : NO;
}
- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:
                     @"XML-RPC Invocation[%@]", self->methodName];
}

- (NSArray *)argumentsForCall {
  SxComponentMethodSignature *sig;
  NSArray  *args;
  unsigned count;
  
  if (null == nil) null = [[NSNull null] retain];
  
  sig = [self methodSignature];
    
  /* collect arguments, coerce types ... */
  if ((count = [self->arguments count]) == 0) {
    args = self->arguments;
  }
  else if (sig) {
    unsigned i;
    id *aa;
      
    aa = calloc(count, sizeof(id));
    for (i = 0; i < count; i++) {
      NSString *xrtype;
      id value;
      
      xrtype = [sig argumentTypeAtIndex:i];
        
      value = [self->arguments objectAtIndex:i];
      value = [value asXmlRpcValueOfType:xrtype];
      aa[i] = value ? value : (id)null;
    }
    args = [NSArray arrayWithObjects:aa count:count];
    if (aa != NULL) free(aa);
  }
  else
    args = self->arguments;
  
  return args;
}

- (NSArray *)credentialsUsableForComponent:(SxXmlRpcComponent *)_target {
  /* select all credentials which respond to usableWithHttpResponse: ... */
  NSMutableArray *ma;
  NSArray        *creds;
  NSEnumerator   *e;
  id cred;
  
  creds = [[_target componentRegistry] credentials];
  if ([creds count] == 0) {
#if DEBUG
    [self debugWithFormat:@"no credentials in registry %@ ...",
            [_target componentRegistry]];
#endif
    return nil;
  }
  
  ma = [NSMutableArray arrayWithCapacity:[creds count]];
  e = [creds objectEnumerator];
  while ((cred = [e nextObject])) {
    if (![cred respondsToSelector:@selector(usableWithHttpResponse:)])
      continue;
    
    [ma addObject:cred];
  }
#if DEBUG
  [self debugWithFormat:@"found usable credentials in registry: %@ ...", ma];
#endif
  
  return ma;
}

- (NSMutableArray *)_makeUsableCredentialsArrayForTarget:(id)_target
  response:(WOResponse *)_response
{
  /*
    fill 'usable' credentials array (you can store multiple login/pwds
    for a single domain as a credential in the registry, and we will
    test each credential for success ...)
  */
  NSMutableArray *lUsableCreds;
  NSEnumerator   *e;
  id             cred;
  
  lUsableCreds = [NSMutableArray arrayWithCapacity:8];
  
#if 1
  /* check invocation credentials */
  if (self->credentials) {
    if ([self->credentials usableWithHttpResponse:_response])
      [lUsableCreds addObject:self->credentials];
    else
      [self debugWithFormat:@"inv creds are not usable with response !"];
  }
#endif
  
  /* check registry credentials */
  e = [[self credentialsUsableForComponent:_target] objectEnumerator];
  while ((cred = [e nextObject])) {
    if ([cred usableWithHttpResponse:_response])
      [lUsableCreds addObject:cred];
  }
  
  return lUsableCreds;
}

- (void)_processSuccessfulCredentials:(id)_creds
  forTarget:(SxXmlRpcComponent *)_target
{
  /* the invocation credentials were used for authentication */
  NSArray *regCreds;
  
  if (_creds == nil) return;
  
  [_target addSuccessfulCredentials:_creds];
  
  if (_creds == self->credentials) {
    regCreds = [self credentialsUsableForComponent:_target];
    
    if (![regCreds containsObject:_creds] || regCreds == nil) {
      /*
        invocation credentials are not part of the registry creds,
        automatically add them (should be configurable ?).
      */
      
#if DEBUG
      [self debugWithFormat:@"adding invocation credentials to registry .."];
#endif
      
      [[_target componentRegistry] addCredentials:_creds];
    }
#if DEBUG
    else {
      [self debugWithFormat:
              @"component credentials are already "
              @"contained in the registry ..."];
    }
#endif
  }
}

- (BOOL)beginTransactionForMethod:(NSString *)_methodName
  onTarget:(SxXmlRpcComponent *)_target
  arguments:(NSArray *)_params
{
  NSString *namespace;

  if (self->transaction) {
    NSLog(@"%s: transaction in progress ...", __PRETTY_FUNCTION__);
    return NO;
  }
  
  [self resetLastException];

  if (![_methodName hasPrefix:@"system."]) {
    if ((namespace = [_target namespace]) != nil) {
      _methodName = [[namespace stringByAppendingString:@"."]
                                stringByAppendingString:_methodName];
    }
  }
  
  self->transaction = [[SxXmlRpcTransaction alloc] initWithMethod:_methodName
						   target:_target
						   arguments:_params
						   forInvocation:self];
  return self->transaction ? YES : NO;
}
- (void)endTransaction {
  [self->transaction finish];
  ASSIGN(self->transaction, (id)nil);
}

- (id)_call:(NSString *)_methodName
  onTarget:(SxXmlRpcComponent *)_target
  arguments:(NSArray *)_params
{
#if DEBUG
  [self debugWithFormat:@"invoking ..."];
#endif

  [self beginTransactionForMethod:_methodName
	onTarget:_target
	arguments:_params];
  
  do {
    if ([self->transaction sendNextRequest]) {
      WOResponse *response;
  
      response = [self->transaction readResponse];
      [self->transaction processResponse:response];
    }
  }
  while (self->transaction);
  
  [self endTransaction];
  
  return [self returnValue];
}

- (BOOL)invokeWithTarget:(SxComponent *)_target {
  if ([self isAsyncResultPending]) {
    NSLog(@"ERROR(%s): tried to invoke while tx is in progress !",
	  __PRETTY_FUNCTION__);
    return NO;
  }
  
  return [super invokeWithTarget:_target];
}

/* async result proxy implementation (invocation is passed back as result) */

- (BOOL)isAsyncResultPending {
  if (self->transaction == nil)
    return NO;
  return [self->transaction isAsyncResultPending];
}
- (id)asyncResult {
  if ([self isAsyncResultPending])
    return nil;
  return [self returnValue];
}
- (BOOL)asyncCallFailed {
  if ([self isAsyncResultPending])
    return NO;
  return self->lastException ? YES : NO;
}

/* async invoke */

- (void)resultReady:(id)_result {
  if ([_result isKindOfClass:[NSException class]]) {
    [self setReturnValue:nil];
    [self setLastException:_result];
  }
  else
    [self setReturnValue:_result];
  
  [self endTransaction];
  
  [[self->target notificationCenter]
    postNotificationName:SxAsyncResultReadyNotificationName
    object:self];
}

- (BOOL)asyncInvoke {
  if ([self isAsyncResultPending]) {
    NSLog(@"ERROR(%s): tried to invoke while tx is in progress !",
	  __PRETTY_FUNCTION__);
    return NO;
  }
  
  [self beginTransactionForMethod:[self methodName]
	onTarget:(id)self->target
	arguments:[self argumentsForCall]];
  
  if ([self->transaction sendFirstAsyncRequest])
    return YES;
  
  [self endTransaction];
  return NO;
}

@end /* SxXmlRpcInvocation */

@implementation SxXmlRpcInvocation(ErrorHandling)

- (void)_setException:(NSString *)_name
  reason:(NSString *)_reason
  methodCall:(XmlRpcMethodCall *)_call
{
  NSException  *e;
  NSDictionary *ui;
  
  ui = [NSDictionary dictionaryWithObjectsAndKeys:
                       _call, @"methodCall",
                       nil];
  e = [NSException exceptionWithName:_name
                   reason:_reason
                   userInfo:ui];
  
  [self debugWithFormat:@"EXCEPTION: %@", e];
  [self setLastException:e];
}

- (id)sendFailedForMethodCall:(XmlRpcMethodCall *)_call
  exception:(NSException *)_exception
{
  NSLog(@"%s: couldn't send XML-RPC call %@ via HTTP: %@",
        __PRETTY_FUNCTION__, _call, _exception);
  if (_exception)
    [self setLastException:_exception];
  else {
    [self _setException:@"XmlRpcSendException"
          reason:@"couldn't send XML-RPC request via HTTP"
          methodCall:_call];
  }
  return nil;
}
- (id)receiveFailedForMethodCall:(XmlRpcMethodCall *)_call {
  [self _setException:@"XmlRpcReceiveException"
        reason:@"couldn't receive XML-RPC response via HTTP"
        methodCall:_call];
  return nil;
}
- (id)call:(XmlRpcMethodCall *)_call
  failedWithResponse:(WOResponse *)_response
{
  NSLog(@"%s: XML-RPC response status: %i", __PRETTY_FUNCTION__,
        [_response status]);
  
  if ([_response status] == 401) {
    SxAuthException *exception;
    
    exception = [[SxAuthException alloc] init];
    [self setLastException:exception];
    RELEASE(exception);
  }
  else {
    [self _setException:@"XmlRpcException"
          reason:[_response contentAsString]
          methodCall:_call];
  }
  return nil;
}

- (id)makeCredentialsTemplateUsableWithResponse:(WOResponse *)_response {
  SxBasicAuthCredentials  *creds;
  //NGMimeHeaderFieldParser *parser;
  id authHeader;
  
  if ((authHeader = [_response headerForKey:@"www-authenticate"]) == nil) {
    [self logWithFormat:@"missing www-authenticate header in 401 response !"];
    return nil;
  }
  
#warning detect realm ...
  creds = [[SxBasicAuthCredentials alloc] init];
  
  return [creds autorelease];
}
- (id)callFailedNoCredentials:(WOResponse *)_response {
  SxMissingCredentialsException *exception;
  id creds;
  
  creds = [self makeCredentialsTemplateUsableWithResponse:_response];
  
  exception = [[SxMissingCredentialsException alloc] init];
  [exception setCredentials:creds];
  [self setLastException:exception];
  [exception release];
  return nil;
}
- (id)callFailedNoUsableCredentials:(WOResponse *)_response {
  SxMissingCredentialsException *exception;
  id creds;
  
  creds = [self makeCredentialsTemplateUsableWithResponse:_response];
  
  exception = [[SxInvalidCredentialsException alloc] init];
  [exception setCredentials:creds];
  [self setLastException:exception];
  [exception release];
  return nil;
}

- (id)handleCallExceptionResult:(NSException *)_exception {
  [self setLastException:_exception];
  return nil;
}

- (id)call:(XmlRpcMethodCall *)_call
  invalidResultContentType:(WOResponse *)_response
{
  NSString *reason;
  NSString *ctype;

  ctype  = [_response headerForKey:@"content-type"];
  reason = [NSString stringWithFormat:
                       @"invalid content-type of XML-RPC response: "
                       @"'%@' (XML-RPC requires text/xml !)", ctype];
  [self _setException:@"XmlRpcException" reason:reason methodCall:_call];
  return nil;
}

@end /* SxXmlRpcInvocation(ErrorHandling) */

@implementation SxXmlRpcTransaction

- (id)initWithMethod:(NSString *)_methodName
  target:(SxXmlRpcComponent *)_target
  arguments:(NSArray *)_params
  forInvocation:(SxXmlRpcInvocation *)_inv
{
  self->invocation = _inv;
  
  self->currentTarget = RETAIN(_target);
  self->methodCall = [[XmlRpcMethodCall alloc] 
		       initWithMethodName:_methodName
		       parameters:_params];
  self->request = 
    [[self->methodCall generateRequestWithUri:[[_target url] path]] retain];
  
  if ((self->httpConnection = [[_target httpConnection] retain]) == nil) {
    RELEASE(self);
    return nil;
  }
  
  /* check first without credentials */
  self->usableCreds  = nil;
  self->currentCreds = [[self->invocation credentials] retain];
  
  return self;
}

- (void)finish {
  self->invocation = nil;
  ASSIGN(self->currentCreds,   (id)nil);
  ASSIGN(self->methodCall,     (id)nil);
  ASSIGN(self->request,        (id)nil);
  ASSIGN(self->currentTarget,  (id)nil);
  ASSIGN(self->httpConnection, (id)nil);
  ASSIGN(self->usableCreds,    (id)nil);
}
- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [self finish];
  [super dealloc];
}

- (BOOL)isDebuggingEnabled {
  return [self->invocation isDebuggingEnabled];
}

- (BOOL)isAsyncResultPending {
  return self->methodCall ? YES : NO;
}

- (void)resultReady:(id)_result {
  /* if async, post notification ... */
  ASSIGN(self->methodCall, (id)nil); // currently the marker ...
  
  [self->invocation resultReady:_result];
}

- (void)processOkResponse:(WOResponse *)_response {
  XmlRpcMethodResponse *methodResponse;
  id res;
  
  /* do post processing on successful credentials .. */
  [self->invocation
       _processSuccessfulCredentials:self->currentCreds 
       forTarget:self->currentTarget];
  
  /* check whether returned body is XML-RPC ... */
  if (![_response isXmlRpcResponse]) {
    res = [self->invocation call:self->methodCall
               invalidResultContentType:_response];
    goto done;
  }
  
  methodResponse = [[XmlRpcMethodResponse alloc] initWithResponse:_response];
  res            = [methodResponse result];
  
  /* process faults */
  if ([res isKindOfClass:[NSException class]])
    res = [self->invocation handleCallExceptionResult:res];
  
  res = RETAIN(res);
  RELEASE(methodResponse);
  res = AUTORELEASE(res);
  
 done:
  [self resultReady:res];
}

- (void)processAuthResponse:(WOResponse *)_response {
  if (self->usableCreds == nil) {
    self->credIdx = 0;
    [self->usableCreds autorelease];
    self->usableCreds =
      [[self->invocation
	    _makeUsableCredentialsArrayForTarget:self->currentTarget
	    response:_response] retain];
#if DEBUG
    [self debugWithFormat:@"  usable credentials %@ ...", self->usableCreds];
#endif
    if ([self->usableCreds count] == 0) {
      /* no credentials were found ... */
      [self resultReady:[self->invocation callFailedNoCredentials:_response]];
      return;
    }
  }
      
  /* go to next credentials */
  if (self->credIdx >= [self->usableCreds count]) {
    [self resultReady:[self->invocation callFailedNoUsableCredentials:_response]];
    return;
  }
  
  ASSIGN(self->currentCreds, [self->usableCreds objectAtIndex:self->credIdx]);
  self->credIdx++;
}

- (void)processFailResponse:(WOResponse *)_response {
  [self resultReady:[self->invocation call:self->methodCall
			 failedWithResponse:_response]];
}

- (void)processResponse:(WOResponse *)_response {
  if (_response == nil) {
    [self resultReady:
	    [self->invocation receiveFailedForMethodCall:self->methodCall]];
    return;
  }

#if DEBUG
  [self debugWithFormat:@"  response status %i ...", [_response status]];
#endif
  
  switch ([_response status]) {
  case 200:
    [self processOkResponse:_response];
    break;
  case 401:
    [self processAuthResponse:_response];
    break;
  default:
    [self processFailResponse:_response];
    break;
  }
}

- (void)_registerForNotification {
  [[NSNotificationCenter defaultCenter] 
    addObserver:self selector:@selector(responseAvailable:)
    name:WOHTTPConnectionCanReadResponse object:self->httpConnection];
}

- (BOOL)sendNextRequest {
  [self->currentCreds applyOnRequest:self->request];
    
  if (![self->httpConnection sendRequest:self->request]) {
    [self resultReady:
	    [self->invocation sendFailedForMethodCall:self->methodCall
			      exception:[self->httpConnection lastException]]];
    return NO;
  }
  
  return YES;
}

- (BOOL)sendFirstAsyncRequest {
  [self _registerForNotification];
  return [self sendNextRequest];
}

- (WOResponse *)readResponse {
  return [self->httpConnection readResponse];
}

- (void)responseAvailable:(NSNotification *)_notification {
  WOResponse *response;
  
#if DEBUG
  [self debugWithFormat:@"  response available ..."];
#endif

  response = [self->httpConnection readResponse];

#if DEBUG
  [self debugWithFormat:@"  read response ..."];
#endif
  
  AUTORELEASE(RETAIN(self));
  [self processResponse:response];
  
  if ([self isAsyncResultPending]) {
    /* send next request ... */
#if DEBUG
    [self debugWithFormat:@"  send next request ..."];
#endif
    [self sendNextRequest];
  }
  else {
#if DEBUG
    [self debugWithFormat:@"  result available ! ..."];
#endif
    //[self->invocation endTransaction];
  }
}

/* description */

- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:
                     @"XML-RPC Tx[%@] 0x%p", 
		     [self->invocation methodName], self];
}

@end /* SxXmlRpcTransaction */
