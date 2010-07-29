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

#include "SxXmlRpcComponent.h"
#include "SxComponentRegistry.h"
#include "SxComponentMethodSignature.h"
#include "SxXmlRpcInvocation.h"
#include "SxComponentException.h"
#include <XmlRpc/NSObject+XmlRpc.h>
#include <NGXmlRpc/NGXmlRpcClient.h>
#include <NGObjWeb/WOHTTPConnection.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WORequest.h>
#include <NGStreams/NGSocketExceptions.h>
#include "common.h"

#include <unistd.h>

@interface SxComponentRegistry(RemoveComponentFromCache)
- (void)_removeComponentFromLookupCache:(NSString *)_cname;
@end /* SxComponentRegistry(RemoveComponentFromCache) */

@interface SxXmlRpcComponent(Privates)

/* this method doesn't prepend component name ... */
- (id)_call:(NSString *)_methodName arguments:(NSArray *)_params;

@end

@implementation SxXmlRpcComponent

+ (int)version {
  return [super version] + 0 /* v1 */;
}
+ (void)initialize {
  NSAssert2([super version] == 1,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithName:(NSString *)_name
  registry:(SxComponentRegistry *)_registry
  url:(NSURL *)_url
{
  return [self initWithName:_name
               namespace:[[_name componentsSeparatedByString:@"."] lastObject]
               registry:_registry
               url:_url];
}

- (id)initWithName:(NSString *)_name
  namespace:(NSString *)_namespace
  registry:(SxComponentRegistry *)_registry
  url:(NSURL *)_url
{
  if ((self = [self initWithName:_name namespace:_namespace
                    registry:_registry])) {
    self->url = [_url copy];
    self->httpConnection =
      [[WOHTTPConnection alloc] initWithHost:[_url host]
                                onPort:[[_url port] intValue]];

    self->retryCnt = 0;
  }
  return self;
}

- (void)dealloc {
  [self->lastCredentials release];
  [self->signatureCache  release];
  [self->httpConnection  release];
  [self->url             release];
  [super dealloc];
}

/* accessors */

- (NSString *)uri {
  return [self->url path];
}

- (WOHTTPConnection *)httpConnection {
  return self->httpConnection;
}

- (NSURL *)url {
  return self->url;
}

- (void)addSuccessfulCredentials:(id)_creds {
  ASSIGN(self->lastCredentials, _creds);
}

- (NSString *)fqMethodNameForMethod:(NSString *)_method {
  NSString *ns;

  if (![_method hasPrefix:@"system."]) {
    if ((ns = [self namespace]) != nil) {
      return [[ns stringByAppendingString:@"."]
                  stringByAppendingString:_method];
    }
  }
  return _method;
}

/* operations */

- (Class)invocationClass {
  static Class CompInv = Nil;
  if (CompInv == Nil) CompInv = [SxXmlRpcInvocation class];
  return CompInv;
}

- (SxComponentInvocation *)invocationForMethodNamed:(NSString *)_method
  methodSignature:(SxComponentMethodSignature *)_signature
{
  /*
    Overridden to add the last successful credentials to newly created
    invocation objects.
  */
  SxComponentInvocation *inv;
  
  inv = [super invocationForMethodNamed:_method
               methodSignature:_signature];
  [inv setCredentials:self->lastCredentials];
  return inv;
}

- (NSArray *)signaturesForMethodNamed:(NSString *)_method {
  NSMutableArray *result;
  NSArray        *signatures;
  NSString       *fqMethodName;
  int i;
  
  [self resetLastException];
  
  if ([_method length] == 0)
    return nil;
  
  if ((signatures = [self->signatureCache objectForKey:_method]))
    return [signatures isNotNull] ? signatures : (NSArray *)nil;

  fqMethodName = [self fqMethodNameForMethod:_method];

  signatures = [self _call:@"system.methodSignature"
                     arguments:[NSArray arrayWithObject:fqMethodName]];
  
  if ([self lastCallFailed]) {
    NSException *e;
    
    e = [self lastException];
    [self logWithFormat:@"%s: couldn't get method signature:\n"
            @"  method: %@\n"
            @"  name:   %@ (class=%@)\n"
            @"  reason: %@",
            __PRETTY_FUNCTION__, _method,
            NSStringFromClass([e class]), [e name], [e reason]];
    return nil;
  }
  
  if (![signatures isKindOfClass:[NSArray class]]) {
    NSException *e;
    
    e = [NSException exceptionWithName:@"InvalidXmlRpcResult"
                     reason:@"system.methodSignature did not return an array"
                     userInfo:nil];
    
    [self logWithFormat:
            @"system.methodSignature didn't return an array: '%@'<%@>",
            signatures, NSStringFromClass([signatures class])];
    
    if (e) [self setLastException:e];
    signatures = nil;
    return nil;
  }
  
  result = [NSMutableArray arrayWithCapacity:[signatures count]];
  
  for (i = 0; i < [signatures count]; i++) {
    SxComponentMethodSignature *signature;
    NSArray *bsig;
    
    bsig = [signatures objectAtIndex:i];
    signature = [SxComponentMethodSignature signatureWithXmlRpcTypes:bsig];
    [result addObject:signature];
  }
  
  if (self->signatureCache == nil)
    self->signatureCache = [[NSMutableDictionary alloc] initWithCapacity:32];
  
  [self->signatureCache
       setObject:(result ? result : (NSMutableArray *)[NSNull null])
       forKey:_method];
  
  return result;
}

- (SxComponentInvocation *)invocationForMethodNamed:(NSString *)_method
  arguments:(NSArray *)_args
{
  static NSArray *retType = nil;
  SxComponentMethodSignature *sig;
  SxXmlRpcInvocation *inv;
  NSArray *xsig;
  
  if (retType == nil)
    retType = [[NSArray alloc] initWithObjects:@"string", nil];
  
  xsig = [retType arrayByAddingObjectsFromArray:
                    [_args xmlRpcElementSignature]];
  sig = [[SxComponentMethodSignature alloc] initWithXmlRpcTypes:xsig];
  
  inv = (id)[self invocationForMethodNamed:_method
                  methodSignature:sig];
  [inv setArguments:_args];
  
  RELEASE(sig);
  
  return inv;
}

- (id)_call:(NSString *)_methodName arguments:(NSArray *)_params {
  SxComponentInvocation *inv;
  NSAutoreleasePool *pool;
  NSException *e;
  id result;
  
  pool = [[NSAutoreleasePool alloc] init];
  [self resetLastException];

  inv = [self invocationForMethodNamed:_methodName
              arguments:_params];
  
  /* TODO: hh: invoke does not work yet fully, returns true on fail ... */
  [inv invoke];
  
  if ((e = [inv lastException])) {
    int retries;

    retries = [[self componentRegistry] componentRetryCountOnError];

    if (self->retryCnt < retries) {
      if ([e isKindOfClass:[NGCouldNotConnectException class]]) {
        SxXmlRpcComponent *tmpComp;
        id compRegistry;

        compRegistry = [self componentRegistry];
        
        [compRegistry _removeComponentFromLookupCache:[self componentName]];
        tmpComp = (SxXmlRpcComponent *)
          [compRegistry getComponent:[self componentName]];
        
        if (tmpComp) {
          NSURL *tmpUrl;
        
          tmpUrl = [tmpComp url];
        
          [self->url            release]; self->url            = nil;
          [self->httpConnection release]; self->httpConnection = nil;

          self->url = RETAIN(tmpUrl);

          self->httpConnection =
            [[WOHTTPConnection alloc] initWithHost:[tmpUrl host]
                                      onPort:[[tmpUrl port] intValue]];

          NSLog(@"%s: trying once again (%d)....", __PRETTY_FUNCTION__,
                self->retryCnt);

          sleep(self->retryCnt*[[self componentRegistry] componentRetryTime]);
          self->retryCnt++;
          [self _call:_methodName arguments:_params];
        }
      }
    }
    else {
      NSLog(@"%s: giving up....", __PRETTY_FUNCTION__);
    }
    
    [self setLastException:e];
    [inv resetLastException]; /* do this to avoid retain cycles ! */
    
    if ([e respondsToSelector:@selector(setInvocation:)])
      [(id)e setInvocation:inv];
  }

  result = [inv returnValue];
  self->retryCnt = 0;
  
  result = [result retain];
  [pool release];
  
  return [result autorelease];
}

- (id)call:(NSString *)_methodName arguments:(NSArray *)_params {
  return [self _call:_methodName arguments:_params];
}

- (id)asyncCall:(NSString *)_methodName arguments:(NSArray *)_args {
  NSLog(@"%s: asyncCall(%@)", __PRETTY_FUNCTION__, _methodName);
  return [self call:_methodName arguments:_args];
}

/* caching */

- (void)flush {
  [self->signatureCache removeAllObjects];
}

/* NSCoding */

- (void)encodeWithCoder:(NSCoder *)_coder {
  [super encodeWithCoder:_coder];
  [_coder encodeObject:self->httpConnection];
  [_coder encodeObject:self->url];
}
- (id)initWithCoder:(NSCoder *)_coder {
  if ((self = [super initWithCoder:_coder])) {
    self->httpConnection = [[_coder decodeObject] retain];
    self->url            = [[_coder decodeObject] retain];
  }
  return self;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;

  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]: name=%@",
        self, NSStringFromClass([self class]),
        [self componentName]];
  [ms appendFormat:@" url=%@", [self->url absoluteString]];
  [ms appendString:@">"];
  return ms;
}

@end /* SxXmlRpcComponent */
