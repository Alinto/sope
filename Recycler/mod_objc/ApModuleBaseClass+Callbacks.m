// $Id: ApModuleBaseClass+Callbacks.m,v 1.1 2004/06/08 11:15:58 helge Exp $

#include "ApModuleBaseClass.h"
#include <httpd.h>
#include "http_config.h"
#import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>
#import <Foundation/NSAutoreleasePool.h>
#include "ApacheServer.h"
#include "ApacheResourcePool.h"
#include "ApacheModule.h"
#include "ApacheRequest.h"

@implementation ApModuleBaseClass(BasicModuleCallbacks)

+ (void)_moduleInit:(void *)s pool:(void *)p {
  NSAutoreleasePool *pool;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheServer       *os;
    ApacheResourcePool *op;
    
    os = [[ApacheServer alloc] initWithHandle:s];
    op = [[ApacheResourcePool alloc] initWithHandle:p];
    [bundleHandler initializeModuleForServer:os inPool:op];
    RELEASE(op); op = nil;
    RELEASE(os); os = nil;
  }
  RELEASE(pool);
}

+ (void *)_perDirConfCreate:(void *)dirspec pool:(void *)p {
  NSAutoreleasePool *pool;
  id result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return NULL;
  }
  
  result = nil;
  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheResourcePool *op;
    
    op = [[ApacheResourcePool alloc] initWithHandle:p];

    result = [bundleHandler createPerDirectoryConfigInPool:op];
    if (result) {
      /* let apache release config ... */
      RETAIN(result);
      [op releaseObject:result];
    }
    
    RELEASE(op); op = nil;
  }
  RELEASE(pool);
  return result;
}

+ (void *)_perDirConfMerge:(void *)baseCconf with:(void *)newCconf
  pool:(void *)p
{
  NSAutoreleasePool *pool;
  id result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return NULL;
  }

  result = nil;
  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheResourcePool *op;
    
    op = [[ApacheResourcePool alloc] initWithHandle:p];

    result = [bundleHandler mergePerDirectoryBaseConfig:baseCconf
                            withNewConfig:newCconf
                            inPool:op];
    if (result) {
      /* let apache release config ... */
      RETAIN(result);
      [op releaseObject:result];
    }
    
    RELEASE(op); op = nil;
  }
  RELEASE(pool);
  return result;
}

+ (void *)_perServerConfCreate:(void *)s pool:(void *)p {
  NSAutoreleasePool *pool;
  id result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return NULL;
  }
  
  result = nil;
  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheServer       *os;
    ApacheResourcePool *op;
    
    os = [[ApacheServer       alloc] initWithHandle:s];
    op = [[ApacheResourcePool alloc] initWithHandle:p];

    result = [bundleHandler createPerServerConfig:os inPool:op];
    if (result) {
      /* let apache release config ... */
      RETAIN(result);
      [op releaseObject:result];
    }
    
    RELEASE(op); op = nil;
    RELEASE(os); os = nil;
  }
  RELEASE(pool);
  return result;
}
+ (void *)_perServerConfMerge:(void *)baseConf with:(void *)newConf
  pool:(void *)p
{
  NSAutoreleasePool *pool;
  id result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return NULL;
  }

  result = nil;
  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheResourcePool *op;
    
    op = [[ApacheResourcePool alloc] initWithHandle:p];
    
    result = [bundleHandler mergePerServerBaseConfig:baseConf
                            withNewConfig:newConf
                            inPool:op];
    if (result) {
      /* let apache release config ... */
      RETAIN(result);
      [op releaseObject:result];
    }
    
    RELEASE(op); op = nil;
  }
  RELEASE(pool);
  return result;
}

+ (int)_translateHandler:(void *)_request {
  NSAutoreleasePool *pool;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return DECLINED;
  }

  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheRequest *or;
    or = [[ApacheRequest alloc] initWithHandle:_request];
    result = [bundleHandler handleTranslationForRequest:or];
    RELEASE(or);
  }
  RELEASE(pool);
  return result;
}
+ (int)_apCheckUserId:(void *)_request {
  NSAutoreleasePool *pool;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return DECLINED;
  }

  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheRequest *or;
    or = [[ApacheRequest alloc] initWithHandle:_request];
    result = [bundleHandler checkUserIdFromRequest:or];
    RELEASE(or);
  }
  RELEASE(pool);
  return result;
}
+ (int)_authChecker:(void *)_request {
  NSAutoreleasePool *pool;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return DECLINED;
  }

  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheRequest *or;
    or = [[ApacheRequest alloc] initWithHandle:_request];
    result = [bundleHandler checkAuthForRequest:or];
    RELEASE(or);
  }
  RELEASE(pool);
  return result;
}
+ (int)_accessChecker:(void *)_request {
  NSAutoreleasePool *pool;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return DECLINED;
  }

  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheRequest *or;
    or = [[ApacheRequest alloc] initWithHandle:_request];
    result = [bundleHandler checkAccessForRequest:or];
    RELEASE(or);
  }
  RELEASE(pool);
  return result;
}
+ (int)_typeChecker:(void *)_request {
  NSAutoreleasePool *pool;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return DECLINED;
  }

  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheRequest *or;
    or = [[ApacheRequest alloc] initWithHandle:_request];
    result = [bundleHandler checkTypeForRequest:or];
    RELEASE(or);
  }
  RELEASE(pool);
  return result;
}
+ (int)_fixerUpper:(void *)_request {
  NSAutoreleasePool *pool;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return DECLINED;
  }

  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheRequest *or;
    or = [[ApacheRequest alloc] initWithHandle:_request];
    result = [bundleHandler fixupRequest:or];
    RELEASE(or);
  }
  RELEASE(pool);
  return result;
}
+ (int)_logger:(void *)_request {
  NSAutoreleasePool *pool;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return DECLINED;
  }

  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheRequest *or;
    or = [[ApacheRequest alloc] initWithHandle:_request];
    result = [bundleHandler logRequest:or];
    RELEASE(or);
  }
  RELEASE(pool);
  return result;
}
+ (int)_headerParser:(void *)_request {
  NSAutoreleasePool *pool;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return DECLINED;
  }

  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheRequest *or;
    or = [[ApacheRequest alloc] initWithHandle:_request];
    result = [bundleHandler parseHeadersOfRequest:or];
    RELEASE(or);
  }
  RELEASE(pool);
  return result;
}

+ (void)_childInit:(void *)_server pool:(void *)_pool {
  NSAutoreleasePool *pool;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheResourcePool *op;
    ApacheServer       *sr;
    
    op = [[ApacheResourcePool alloc] initWithHandle:_pool];
    sr = [[ApacheServer       alloc] initWithHandle:_server];
    [bundleHandler initializeChildProcessWithServer:sr inPool:op];
    RELEASE(sr);
    RELEASE(op);
  }
  RELEASE(pool);
}
+ (void)_childExit:(void *)_server pool:(void *)_pool {
  NSAutoreleasePool *pool;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheResourcePool *op;
    ApacheServer       *sr;
    
    op = [[ApacheResourcePool alloc] initWithHandle:_pool];
    sr = [[ApacheServer       alloc] initWithHandle:_server];
    [bundleHandler exitChildProcessWithServer:sr inPool:op];
    RELEASE(sr);
    RELEASE(op);
  }
  RELEASE(pool);
}

+ (int)_postReadRequest:(void *)_request {
  NSAutoreleasePool *pool;
  int result;
  ApacheModule *bundleHandler = [self bundleHandler];
  
  if (bundleHandler == nil) {
    printf("%s: missing bundle handler !!!\n", __PRETTY_FUNCTION__);
    return DECLINED;
  }
  
  pool = [[NSAutoreleasePool alloc] init];
  {
    ApacheRequest *or;
    or = [[ApacheRequest alloc] initWithHandle:_request];
    result = [bundleHandler postProcessRequest:or];
    RELEASE(or);
  }
  RELEASE(pool);
  return result;
}

@end /* ApModuleBaseClass(BasicModuleCallbacks) */
