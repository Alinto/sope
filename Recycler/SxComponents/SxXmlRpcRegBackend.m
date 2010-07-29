/*
  Copyright (C) 2000-2004 SKYRIX Software AG

  This file is part of OpenGroupware.org.

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

#include <SxComponents/SxComponentRegistry.h>
#include <SxComponents/SxComponentMethodSignature.h>
#include "common.h"

@class NGXmlRpcClient;

@interface SxXmlRpcRegBackend : NSObject < SxComponentRegistryBackend >
{
  NGXmlRpcClient *registryServer;
}

@end

#include "SxXmlRpcComponent.h"
#import <NGXmlRpc/NGXmlRpcClient.h>

@interface NSObject(AsUrl)
- (NSURL *)asNSURL;
@end

@implementation SxXmlRpcRegBackend

+ (void)initialize {
  static BOOL didInit = NO;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  NSDictionary   *defs;
  
  if (didInit) return;
  didInit = YES;
    
  defs = [NSDictionary dictionaryWithObjectsAndKeys:
			 @"http://127.0.0.1:14042/RPC2", 
			 @"SxComponentRegistryURL",
		       nil];
  [ud registerDefaults:defs];
}

+ (NSURL *)defaultRegistryURL {
  NSString *s;
  
  s = [[NSUserDefaults standardUserDefaults]
                       stringForKey:@"SxComponentRegistryURL"];
  if ([s length] == 0)
    return nil;
  return [NSURL URLWithString:s];
}

- (id)initWithURL:(NSURL *)_url {
  _url = [_url asNSURL];
  if (_url == nil) {
    [self release];
    return nil;
  }
  self->registryServer = [[NGXmlRpcClient alloc] initWithURL:_url];
  if (self->registryServer == nil) {
    [self release];
    return nil;
  }
  return self;
}
- (id)init {
  return [self initWithURL:[[self class] defaultRegistryURL]];
}

- (void)dealloc {
  [self->registryServer release];
  [super dealloc];
}

/* operations */

- (BOOL)registry:(id)_registry canHandleNamespace:(NSString *)_prefix {
  NSArray *supportedComponents = nil;
  
  supportedComponents = [self registry:_registry listComponents:@""];
#if 0
  [self logWithFormat:@"supported components : %@", supportedComponents];
#endif
  return [supportedComponents containsObject:_prefix];
}

- (BOOL)canHandleComponent:(SxComponent *)_component {
  if (_component == nil) return NO;
  if (![_component isKindOfClass:[SxXmlRpcComponent class]]) return NO;
  return YES;
}

- (NSArray *)registry:(id)_registry listComponents:(NSString *)_prefix {
  NSArray *result;
  
  result = [self->registryServer
                invokeMethodNamed:@"active.registry.getComponents"];
  if (result == nil)
    return nil;
  if ([result isKindOfClass:[NSException class]]) {
    /* call failed */
    [self logWithFormat:@"%s: component list failed: %@",
            __PRETTY_FUNCTION__, result];
    return nil;
  }
  else if ([result isKindOfClass:[NSDictionary class]]) {
    /* call failed */
    [self logWithFormat:@"%s: component list failed (got a dict?): %@",
            __PRETTY_FUNCTION__, result];
    return nil;
  }
  if (![result respondsToSelector:@selector(objectEnumerator)]) {
    [self logWithFormat:@"%s: got invalid result: %@", __PRETTY_FUNCTION__,
            result];
    return nil;
  }
  
  if ([_prefix length] == 0)
    return result;
  
  /* limit search ... */
  {
    NSEnumerator *e;
    NSString *k;
    NSMutableArray *ma;

    ma = nil;
    e = [result objectEnumerator];
    while ((k = [e nextObject])) {
      if ([k hasPrefix:_prefix]) {
        if (ma == nil)
          ma = [NSMutableArray arrayWithCapacity:32];
        [ma addObject:k];
      }
    }
    result = ma;
  }
  
  return result;
}

- (id)processInvalidResultType:(id)_result method:(NSString *)_name {
  NSException  *exc;
  NSDictionary *ui;
  
  ui = [NSDictionary dictionaryWithObjectsAndKeys:
                       _result,                            @"resultObject",
                       NSStringFromClass([_result class]), @"resultClassName",
                       nil];
  
  exc = [NSException exceptionWithName:@"SxRegistryIntrospectionError"
                     reason:[_name stringByAppendingString:@" failed ..."]
                     userInfo:ui];
  
  [self logWithFormat:@"WARNING(%@): got invalid result type !", _name];
  return exc;
}

- (BOOL)isXmlRpcFault:(id)_object {
  if ([_object isKindOfClass:[NSException class]])
    return YES;
  return NO;
}

- (NSArray *)registry:(id)_registry listMethods:(NSString *)_cname {
  NSArray *res;
  
  res = [self->registryServer
             invokeMethodNamed:@"active.registry.listComponentMethods"
             parameters:[NSArray arrayWithObject:_cname]];
  
  if (res == nil) return nil;

  if ([self isXmlRpcFault:res])
    return res;
  else if (![res isKindOfClass:[NSArray class]])
    res = [self processInvalidResultType:res method:@"listMethods"];
  
  return res;
}

- (NSArray *)registry:(id)_registry methodSignature:(NSString *)_cname
  method:(NSString *)_methods
{
  NSArray *sigs;
  NSMutableArray *result;
  NSEnumerator *sigEnum;
  NSArray      *sigElem;

  sigs =  [self->registryServer
               invokeMethodNamed:@"active.registry.componentMethodSignatures"
               parameters:[NSArray arrayWithObjects:_cname,_methods,nil]];
  
  if ([sigs isKindOfClass:[NSException class]])
    return sigs;
  else if (![sigs isKindOfClass:[NSArray class]])
    return [self processInvalidResultType:sigs method:
                 @"componentMethodSignatures"];
  
  sigEnum = [sigs objectEnumerator];
  result = [NSMutableArray arrayWithCapacity:[sigs count]];
  
  while((sigElem = [sigEnum nextObject])) {
    SxComponentMethodSignature *sig;

    sig = [SxComponentMethodSignature signatureWithXmlRpcTypes:sigElem];
    [result addObject:sig];
  }
  return result;
}

- (NSString *)registry:(id)_registry
  methodHelp:(NSString *)_cname
  method:(NSString *)_methods
{
  return [self->registryServer
              invokeMethodNamed:@"active.registry.componentMethodHelp"
              parameters:[NSArray arrayWithObjects:_cname,_methods,nil]];
}

- (SxComponent *)registry:(id)_registry getComponent:(NSString *)_cname {
  NSDictionary      *res;
  SxXmlRpcComponent *xc;
  NSURL    *url;
  NSString *s;
  
  res = [self->registryServer
             invokeMethodNamed:@"active.registry.getComponentAndNamespace"
             parameters:[NSArray arrayWithObject:_cname]];
  
  if (res == nil) return nil;
  
  if ([self isXmlRpcFault:res]) {
    /* call failed */
    NSLog(@"%s: component lookup failed: %@", __PRETTY_FUNCTION__, res);
    return nil;
  }
  
  if (![res isKindOfClass:[NSDictionary class]]) {
    NSLog(@"%s: got invalid result: %@", __PRETTY_FUNCTION__, res);
    return nil;
  }

  s = [NSString stringWithFormat:@"http://%@:%d%@",
                  [res  objectForKey:@"host"],
                  [[res objectForKey:@"port"] intValue],
                  [res  objectForKey:@"uri"]];

  if ((url = [NSURL URLWithString:s]) == nil) {
    [self logWithFormat:@"didn't get a valid URL: '%@'", s];
    return nil;
  }
  
  xc =
    [[SxXmlRpcComponent alloc] initWithName:_cname
                               namespace:[res objectForKey:@"namespace"]
                               registry:_registry
                               url:url];
  return AUTORELEASE(xc);
}



- (BOOL)removeComponent:(NSString *)_component {
  id res;
  
  res = [self->registryServer
             call:@"active.registry.removeComponent", _component, nil];
  return [res boolValue];
}

- (BOOL)addComponent:(NSString *)_component url:(id)_url {
  NSURL *url;

  url = [_url asNSURL];
  
  return [[self->registryServer
               call:@"active.registry.setComponent",
                 _component, [url path], [url host], [url port], nil]
               boolValue];
}

- (BOOL)registerComponent:(SxComponent *)_component {
  SxXmlRpcComponent *xc;
  
  NSAssert([_component isKindOfClass:[SxXmlRpcComponent class]],
           @"passed invalid component ...");
  xc = (SxXmlRpcComponent *)_component;

  return NO;
}

- (BOOL)unregisterComponent:(SxComponent *)_component {
  SxXmlRpcComponent *xc;
  
  NSAssert([_component isKindOfClass:[SxXmlRpcComponent class]],
           @"passed invalid component ...");
  xc = (SxXmlRpcComponent *)_component;

  return NO;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<0x%p[%@]: server=%@>",
                     self, NSStringFromClass([self class]),
                     self->registryServer];
}

@end /* SxXmlRpcRegBackend */

@implementation NSURL(AsUrl)

- (NSURL *)asNSURL {
  return self;
}

@end /* NSURL(AsUrl) */

@implementation NSObject(AsUrl)

- (NSURL *)asNSURL {
  NSString *s;
  s = [self stringValue];
  if ([s length] == 0) return nil;
  return [NSURL URLWithString:s];
}

@end /* NSURL(AsUrl) */
