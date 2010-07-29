// $Id: ApacheWOTransaction.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "ApacheWOTransaction.h"
#include "common.h"

#include "AWODirectoryConfig.h"
#include "AWOServerConfig.h"
#include "ApacheResourceManager.h"
#include "WORequest+Apache.h"
#include "WOResponse+Apache.h"
#include <ApacheAPI/ApacheRequest.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOApplication.h>

@implementation ApacheWOTransaction

- (id)initWithApacheRequest:(ApacheRequest *)_rq
  config:(AWODirectoryConfig *)_cfg 
  serverConfig:(AWOServerConfig *)_srvcfg
{
  if (_rq == nil) {
    RELEASE(self);
    return nil;
  }
  self->config       = RETAIN(_cfg);
  self->serverConfig = RETAIN(_srvcfg);
  self->request      = RETAIN(_rq);
  
  if ((self->woRequest = [[WORequest alloc] initWithApacheRequest:_rq])==nil) {
    NSLog(@"%s: could not create WO request ...", __PRETTY_FUNCTION__);
    RELEASE(self);
    return nil;
  }
  
  if ((self->application = [[_cfg application] retain]) == nil) {
    NSLog(@"%s: no app is configured ...", __PRETTY_FUNCTION__);
    RELEASE(self);
    return nil;
  }
  
  self->resourceManager =
    [[ApacheResourceManager alloc] initWithApacheRequest:_rq config:_cfg];
  
  if (self->resourceManager == nil) {
    NSLog(@"%s: could not create resource manager ...", __PRETTY_FUNCTION__);
    RELEASE(self);
    return nil;
  }
  
  return self;
}

- (void)dealloc {
  RELEASE(self->resourceManager);
  RELEASE(self->woRequest);
  RELEASE(self->woResponse);
  RELEASE(self->application);
  RELEASE(self->serverConfig);
  RELEASE(self->config);
  RELEASE(self->request);
  [super dealloc];
}

/* accessors */

- (WOApplication *)application {
  return [self->config application];
}
- (WORequest *)request {
  return self->woRequest;
}
- (WOResponse *)response {
  return self->woResponse;
}

- (ApacheRequest *)apacheRequest {
  return self->request;
}

/* activation */

- (void)activate {
  [self->application activateApplication];
  // should use stack ??
  [self->application setResourceManager:self->resourceManager];
}
- (void)deactivate {
  [self->application setResourceManager:nil];
  [self->application deactivateApplication];
}

/* dispatch */

- (int)dispatchUsingHandler:(WORequestHandler *)_handler {
  WOResponse *response;
  
  response = [self->application
		  dispatchRequest:self->woRequest
		  usingHandler:_handler];
  return [response sendResponseUsingApacheRequest:self->request];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:64];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" uri=%@", [[self request] uri]];
  [ms appendString:@">"];
  return ms;
}

@end /* ApacheWOTransaction */
