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

#include <NGXmlRpc/NGXmlRpcAction.h>
#include <NGXmlRpc/NGAsyncResultProxy.h>
#include <NGXmlRpc/NGXmlRpc.h>
#include <NGXmlRpc/XmlRpcMethodCall+WO.h>
#include <NGXmlRpc/XmlRpcMethodResponse+WO.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WOSession.h>
#include <NGObjWeb/WOResponse.h>
#include "common.h"


@interface NSException(UserInfoExt)
- (void)setUserInfo:(NSDictionary *)_ui;
@end

@implementation WOCoreApplication(XmlRpcActionClass)

- (Class)defaultActionClassForRequest:(WORequest *)_request {
  return NSClassFromString(@"DirectAction");
}

@end

@implementation NGXmlRpcAction

+ (int)version {
  return 1;
}

+ (BOOL)coreOnFault {
#if DEBUG
  return [[NSUserDefaults standardUserDefaults] 
	                  boolForKey:@"WOCoreOnXmlRpcFault"];
#else
  return NO;
#endif
}

/* initialization */

- (id)initWithContext:(WOContext *)_ctx {
  if ((self = [super init])) {
    self->context = RETAIN(_ctx);
  }
  return self;
}
- (id)init {
  return [self initWithContext:nil];
}

- (void)dealloc {
  RELEASE(self->context);
  [super dealloc];
}

/* sandstorm components */

- (NSString *)xmlrpcComponentNamespacePrefix {
  NSString *np;
  
  np = [[NSUserDefaults standardUserDefaults]
                        stringForKey:@"SxDefaultNamespacePrefix"];
  if ([np isNotEmpty])
    return np;

  [self logWithFormat:
          @"WARNING: SxDefaultNamespacePrefix default is not set !"];
  
  np = [(NSHost *)[NSHost currentHost] name];
  if ([np isNotEmpty]) {
    if (!isdigit([np characterAtIndex:0])) {
      NSArray *parts;

      parts = [np componentsSeparatedByString:@"."];
      if (![parts isNotEmpty]) {
      }
      else if ([parts count] == 1)
        return [parts objectAtIndex:0];
      else {
        NSEnumerator *e;
        BOOL     isFirst = YES;
        NSString *s;
        
        e = [parts reverseObjectEnumerator];
        while ((s = [e nextObject])) {
          if (isFirst) {
            isFirst = NO;
            np = s;
          }
          else {
            np = [[np stringByAppendingString:@"."] stringByAppendingString:s];
          }
        }
        return np;
      }
    }
  }
  
  return @"com.skyrix";
}
- (NSString *)xmlrpcComponentName {
  NSString *s;

  s = NSStringFromClass([self class]);
  if (![s isEqualToString:@"DirectAction"])
    return s;
  
  return [[NSProcessInfo processInfo] processName];
}

- (NSString *)xmlrpcComponentNamespace {
  NSString *ns, *n;
  
  ns = [self xmlrpcComponentNamespacePrefix];
  n  = [self xmlrpcComponentName];
  return [[ns stringByAppendingString:@"."] stringByAppendingString:n];
}

/* notifications */

- (void)awake {
}
- (void)sleep {
}

- (id)application {
  return [WOCoreApplication application];
}

- (NSNotificationCenter *)notificationCenter {
  return [NSNotificationCenter defaultCenter];
}

- (WOContext *)context {
  if (self->context == nil)
    self->context = RETAIN([[WOApplication application] context]);
  return self->context;
}

- (WORequest *)request {
  return [[self context] request];
}

- (id)session {
  return [[self context] session];
}

- (id)existingSession {
  WOContext *ctx = [self context];
  
  /* check whether the context has a session */
  
  return [ctx hasSession] ? [ctx session] : nil;
}

/* XML-RPC direct action dispatcher ... */

- (NSString *)authRealm {
  WOApplication *app = [self application];
  return [app name];
}

- (id<WOActionResults>)missingAuthAction {
  WOResponse *resp;
  NSString *auth;

  auth = [NSString stringWithFormat:@"basic realm=\"%@\"",[self authRealm]];
  
  resp = [(WOResponse *)[WOResponse alloc] initWithRequest:[self request]];
  [resp setStatus:401 /* unauthorized */];
  [resp setHeader:auth forKey:@"www-authenticate"];
  // TODO: should embed an XML-RPC fault representing the auth-problem
  return [resp autorelease];
}
- (id<WOActionResults>)accessDeniedAction {
  WOResponse *resp;
  NSString *auth;
  
  auth = [NSString stringWithFormat:@"basic realm=\"%@\"",[self authRealm]];
  
  [self logWithFormat:@"access was denied"];
  
  resp = [(WOResponse *)[WOResponse alloc] initWithRequest:[self request]];
  [resp setStatus:401 /* unauthorized */];
  [resp setHeader:auth forKey:@"www-authenticate"];
  // TODO: should embed an XML-RPC fault representing the auth-problem
  return [resp autorelease];
}

- (id<WOActionResults>)actionResponseForResult:(id)resValue {
  if ([resValue isKindOfClass:[NGAsyncResultProxy class]]) {
    /* async result ... */
    return [self responseForAsyncResult:resValue];
  }
  else if ([resValue conformsToProtocol:@protocol(WOActionResults)]) {
    /* a "HTTP" result ... */
    return resValue;
  }
  else {
    /* an XML-RPC result ... */
    XmlRpcMethodResponse *mResponse;
    
    mResponse = [[[XmlRpcMethodResponse alloc]
                                        initWithResult:resValue]
                                        autorelease];
    return mResponse;
  }
}

- (void)proxyReady:(NGAsyncResultProxy *)_sender {
  id<WOActionResults> ares;
  WOResponse *r;
  
  AUTORELEASE(RETAIN(self)); /* keep me around ;-) */
  
  //[self debugWithFormat:@"ready: %@", _sender];
  
  [_sender setTarget:nil];
  [_sender setAction:NULL];
  
  ares = [self actionResponseForResult:[_sender result]];
  //[self debugWithFormat:@"  result: %@", ares];

  r = [ares generateResponse];
  //[self debugWithFormat:@"  response: %@", r];

  [[self notificationCenter]
         postNotificationName:@"WOAsyncResponseReadyNotification"
         object:[_sender token]
         userInfo:[NSDictionary dictionaryWithObject:r
                                forKey:@"WOAsyncResponse"]];
}

- (WOResponse *)responseForAsyncResult:(NGAsyncResultProxy *)_proxy {
  static int cnt = 0;
  NSString   *token;
  WOResponse *r;
  NSDictionary *ui;

  //[self debugWithFormat:@"shall create async result for proxy:\n  %@", _proxy];
  
  token = [NSString stringWithFormat:@"0x%p-%i", _proxy, cnt++];
  //[self debugWithFormat:@"token: %@", token];
  ui = [NSDictionary dictionaryWithObject:token
                     forKey:@"WOAsyncResponseToken"];
  
  r = [WOResponse responseWithRequest:[self request]];
  [r setStatus:20001 /* async response */];
  [r setUserInfo:ui];
  
  /* map token to result proxy ... */
  [_proxy setTarget:self];
  [_proxy setAction:@selector(proxyReady:)];
  [_proxy setToken:token];
  
  return r;
}

- (id)faultFromException:(NSException *)_exception
  methodCall:(XmlRpcMethodCall *)_call
{
  /* add some more information to generic exceptions ... */
  if (_call) {
    NSMutableDictionary *ui;
    
    ui = [[_exception userInfo] mutableCopy];
    if (ui == nil) ui = [[NSMutableDictionary alloc] init];
    
    [ui setObject:[_call methodName] forKey:@"methodName"];
    [ui setObject:[_call parameters] forKey:@"methodParameters"];
    
    [_exception setUserInfo:ui];
    RELEASE(ui);
  }

  [self logWithFormat:@"%s: turning exception into fault %@\n",
          __PRETTY_FUNCTION__,
          [_exception description]];

  if ([[self class] coreOnFault])
    abort();
  
  return _exception;
}
- (id)faultFromException:(NSException *)_exception {
  return [self faultFromException:_exception methodCall:nil];
}

- (NSArray *)signatureForParameters:(NSArray *)_params {
  NSMutableArray *ma;
  unsigned count, i;
  
  if ((count = [_params count]) == 0)
    return [NSArray arrayWithObject:@"*"];
  
  ma = [NSMutableArray arrayWithCapacity:(count + 1)];
  [ma addObject:@"*"]; // return type, unknown from request ...
  for (i = 0; i < count; i++)
    [ma addObject:[[_params objectAtIndex:i] xmlRpcType]];
  return ma;
}
- (SEL)selectorForXmlRpcAction:(NSString *)_name
  parameters:(NSArray *)_params
{
  NSArray *sig = nil;

  if ((sig = [self signatureForParameters:_params]) == nil)
    [self logWithFormat:@"found not signature for params ..."];
  
  return [[self class] selectorForActionNamed:_name
                       signature:sig];
}

- (NSString *)_methodNameWithoutPrefix:(NSString *)_name {
  NSString *n;
  int len;

  if ((n = [self xmlrpcComponentNamespacePrefix]) == nil)
    return _name;
  if ((len = [n length]) == 0)
    return _name;
  if (![_name hasPrefix:n])
    return _name;
  
  n = _name;
  _name = [_name substringFromIndex:len];
  if ([_name hasPrefix:@"."])
    _name = [_name substringFromIndex:1];
  return _name;
}

- (id)performActionNamed:(NSString *)_name parameters:(NSArray *)_params {
  NSMethodSignature *sign;
  NSInvocation      *invo;
  id       result = nil;
  SEL      sel;
  int      i, cnt;
  NSString *n;
  
  n = _name;
  _name = [self _methodNameWithoutPrefix:_name];
  
  /* generate selector */
  if ((sel = [self selectorForXmlRpcAction:_name parameters:_params]) ==NULL) {
    /* return a fault .. */
    NSString     *r;
    NSDictionary *ui;
    
    [self debugWithFormat:@"found no selector for XML-RPC action %@", _name];
    
    ui = nil;
    r = [NSString stringWithFormat:
                    @"found no XML-RPC method named '%@' "
                    @"(%i parameters, component=%@)",
                    n, [_params count], [self xmlrpcComponentNamespace]];
    
    return [NSException exceptionWithName:@"NoSuchXmlRpcMethod"
                        reason:r
                        userInfo:ui];
  }
  
  sign = [[self class] instanceMethodSignatureForSelector:sel];
  invo = [NSInvocation invocationWithMethodSignature:sign];
  [invo setSelector:sel];
  [invo setTarget:self];
  
  /* more arguments may be passed than supported by the method .. */
  cnt = [sign numberOfArguments] - 2;
  cnt = (cnt > (int)[_params count]) ? (int)[_params count] : cnt;
  for (i = 0; i < cnt; i++) {
    id param = [_params objectAtIndex:i];
    /* 
       TODO: bjoern
       is this correct ? shouldnt that break, because the address of
       param is always the same (who says, that NSInvocation copies the
       values ???)
    */
    [invo setArgument:&param atIndex:(i + 2)];
  }
  
  /* fill additional selector values with nil ... */
  if (cnt < ((int)[sign numberOfArguments] - 2)) {
    static id nilValue = nil;
    unsigned int oldCnt = cnt;
    
    for (i = oldCnt, cnt = ([sign numberOfArguments] - 2); i < cnt; i++)
      [invo setArgument:&nilValue atIndex:(i + 2)];
  }
  
  [invo invoke];
  [invo getReturnValue:&result];
  
  return result;
}
- (id<WOActionResults>)performMethodCall:(XmlRpcMethodCall *)_call {
  id resValue;
  
  NS_DURING {
    resValue = [self performActionNamed:[_call methodName]
                     parameters:[_call parameters]];
    resValue = [resValue retain];
  }
  NS_HANDLER {
    resValue = [self faultFromException:localException
                     methodCall:_call];
    if ([[self class] coreOnFault])
      abort();
    resValue = [resValue retain];
  }
  NS_ENDHANDLER;
  
  resValue = [resValue autorelease];
  
  if ([[self class] coreOnFault]) {
    if ([resValue isKindOfClass:[NSException class]]) {
      abort();
    }
  }
  return [self actionResponseForResult:resValue];
}

/* command context */

- (BOOL)hasAuthorizationHeader {
  WORequest *rq;
  NSString  *cred;
  
  if ((rq = [self request]) == nil)
    return NO;

  if ((cred = [rq headerForKey:@"authorization"]) == nil)
    return NO;
  
  return YES;
}

- (NSString *)credentials {
  WORequest *rq;
  NSString  *cred;
  NSRange   r;
  
  if ((rq = [self request]) == nil)
    return nil;
  if ((cred = [rq headerForKey:@"authorization"]) == nil)
    return nil;
  
  r = [cred rangeOfString:@" " options:NSBackwardsSearch];
  if (r.length == 0) {
    [self logWithFormat:@"invalid 'authorization' header: '%@'", cred];
    return nil;
  }
  return [cred substringFromIndex:(r.location + r.length)];
}

/* logging */

- (NSString *)loggingPrefix {
  return [NSString stringWithFormat:@"RPC>%@>",
                     NSStringFromClass([self class])];
}

/* reflection (do not define as a category, as other may do this .. */

- (NSArray *)system_listMethodsAction {
  NSArray *names;
  
  names = [[self class] registeredMethodNames];
  names = [names sortedArrayUsingSelector:@selector(compare:)];
  
  return names;
}
- (NSArray *)system_methodSignatureAction:(NSString *)_method {
  return [[self class] signaturesForMethodNamed:_method];
}

@end /* NGXmlRpcAction */
