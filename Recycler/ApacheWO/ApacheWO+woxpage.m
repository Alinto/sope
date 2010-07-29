// $Id: ApacheWO+woxpage.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "ApacheWO.h"
#include "AliasMap.h"
#include "WORequestHandler+Apache.h"
#include "AWODirectoryConfig.h"
#include "AWOServerConfig.h"
#include "ApacheWOTransaction.h"
#include "ApacheResourceManager.h"
#include "WORequest+Apache.h"
#include "WOResponse+Apache.h"
#include "common.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequestHandler.h>
#include <ApacheAPI/ApacheAPI.h>

@interface WORequest(UsedPrivatesApache)
- (void)setRequestHandlerPath:(NSString *)_path;
- (ApacheRequest *)apacheRequest;
@end

@interface ApacheWO(EchoResponseE)
- (WOResponse *)echoResponseForRequest:(WORequest *)woRequest
  apacheRequest:(ApacheRequest *)_rq
  config:(id)cfg;
@end

@implementation ApacheWO(WoxPageHandler)

- (int)performSxApplicationRequest:(ApacheRequest *)_rq {
  AWOServerConfig   *cfg;
  NSString          *uri = [_rq uri];
  NSString          *appKey;
  WOApplication     *app;
  WORequest         *woRequest;
  WOResponse        *woResponse;
  int result;
  
  if (uri == nil)
    return ApacheDeclineRequest;
  
  woRequest = [[[WORequest alloc] initWithApacheRequest:_rq] autorelease];
  
  cfg    = [self configForServer:_rq];
  appKey = [cfg->appAlias keyForURI:uri];
  app    = [ApacheWO applicationForKey:appKey className:nil];
  
  [self logWithFormat:@"performSxApplicationRequest on app %@ ...", app];
  woResponse = [app dispatchRequest:woRequest];
  
  /* send response */
  
  if (woResponse)
    result = [woResponse sendResponseUsingApacheRequest:_rq];
  else
    result = 500;
  
  return result;
}

- (int)performSxHandlerRequest:(ApacheRequest *)_rq
  config:(AWODirectoryConfig *)cfg 
{
  WORequestHandler *handler;
  
  if ((handler = [cfg requestHandler]) == nil) {
    handler = [[cfg application] defaultRequestHandler];
    [self logWithFormat:@"using default request handler ..."];
  }
  
  return [[self currentWOTransaction] dispatchUsingHandler:handler];
}

- (int)performSxAliasHandlerRequest:(ApacheRequest *)_rq {
  ApacheWOTransaction *tx;
  WORequestHandler *handler;
  NSString *key;
  
  tx      = [self currentWOTransaction];
  key     = [tx->serverConfig->handlerAlias keyForURI:[_rq uri]];
  handler = [[tx application] requestHandlerForKey:key];
  
  return [tx dispatchUsingHandler:handler];
}

- (int)performWoxPageRequest:(ApacheRequest *)_rq {
  WORequestHandler *rh;
  WORequest *woRq;
  
  rh = [[[NSClassFromString(@"WOPageRequestHandler") alloc] init] autorelease];
  if (rh == nil)
    [self logWithFormat:@"couldn't allocate page request handler  .."];
  
  /* fill request special vars */
  woRq = [[self currentWOTransaction] request];
  [woRq setHeader: [woRq uri] forKey:@"x-httpd-pagename"];
  [woRq setRequestHandlerPath:[[woRq uri] lastPathComponent]];
  
  return [[self currentWOTransaction] dispatchUsingHandler:rh];
}

- (int)handleApplicationXHttpdWoRequest:(ApacheRequest *)_rq config:_cfg {
  NSString *uri = [_rq uri];
  
  [self logWithFormat:@"handleApplicationXHttpdWoxRequest (uri=%@) ...",uri];
  
  /* remove the slash of .wo directories, deny access to contents .. */
  if ([uri hasSuffix:@".wo/"]) {
    uri = [uri substringToIndex:([uri length] - 1)];
    [self logWithFormat:@"redirect to %@...", uri];
    
    [[_rq headersOut] setObject:uri forKey:@"location"];
    [_rq setStatus:302];
    [_rq sendHttpHeader];
    return ApacheHandledRequest; /* redirect */
  }
  
  return [self performWoxPageRequest:_rq];
}

- (int)handleSkyrixRqHandler:(ApacheRequest *)_rq config:(id)_cfg {
  NSDictionary     *plist;
  WORequestHandler *rh;
  
  plist = [NSDictionary dictionaryWithContentsOfFile:[_rq filename]];
  [self logWithFormat:@"plist: %@", plist];
  
  if ((rh = [WORequestHandler requestHandlerForConfig:plist]) == nil)
    return ApacheDeclineRequest;
  
  return [[self currentWOTransaction] dispatchUsingHandler:rh];
}

- (int)handleDirectoryRequest:(ApacheRequest *)_rq config:(id)_cfg {
  [self logWithFormat:@"check directory: %@", [_rq filename]];
  return ApacheDeclineRequest;
}
- (int)handleGenericRequest:(ApacheRequest *)_rq config:(id)_cfg {
  [self logWithFormat:@"(generic) check file: %@ (%@)", 
	  [_rq filename], [_rq contentType]];
  return ApacheDeclineRequest;
}

@end /* ApacheWO(WoxPageHandler) */
