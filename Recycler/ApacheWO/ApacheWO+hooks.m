// $Id: ApacheWO+hooks.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "ApacheWO.h"
#include "AliasMap.h"
#include "AWOServerConfig.h"
#include <ApacheAPI/ApacheRequest.h>
#include <ApacheAPI/ApacheTable.h>
#include "common.h"

@implementation ApacheWO(Hooks)

- (int)handleTranslationForRequest:(ApacheRequest *)_rq {
  AWOServerConfig *cfg;
  NSString *uri = [_rq uri];
  NSString *app, *rqh;
  
  cfg = [self configForServer:_rq];
  
  //[self logWithFormat:@"translate URI '%@' (cfg=%@) ...", uri, cfg];
  
  /* check handler aliases */
  
  if ((rqh = [cfg->handlerAlias keyForURI:uri])) {
    NSString *prefix;
    
    prefix = [cfg->handlerAlias uriForKey:rqh baseURI:uri];
    //[self logWithFormat:@"found handler: %@ (prefix=%@)", rqh, prefix];
    
    [_rq setFilename:prefix];
    [_rq setPathInfo:[uri substringFromIndex:[prefix length]]];
    [_rq setHandler:@"sx-alias-handler"];
    return ApacheHandledRequest;
  }
  
  /* check app aliases */
  
  if ((app = [cfg->appAlias keyForURI:uri])) {
    NSString *prefix;
    
    prefix = [cfg->appAlias uriForKey:app baseURI:uri];
    [self logWithFormat:@"found app: %@ (prefix=%@)", app, prefix];
    
    [_rq setFilename:prefix];
    [_rq setPathInfo:[uri substringFromIndex:[prefix length]]];
    [_rq setHandler:@"sx-application"];
    return ApacheHandledRequest;
  }
  
  return ApacheDeclineRequest;
}

#if 0
- (int)checkUserIdFromRequest:(ApacheRequest *)_req {
  [self logWithFormat:@"check uid for URI '%@' ...", [_req uri]];
  return ApacheDeclineRequest;
}
#endif

- (int)checkTypeForRequest:(ApacheRequest *)_req {
  /* do not process .wo directories as simple directories .. */
  
  //[self logWithFormat:@"check type for URI '%@' ...", [_req uri]];
  
  if ([_req isDirectory]) {
    NSString *fext;
    
    fext = [[[_req filename] lastPathComponent] pathExtension];
    if ([fext isEqualToString:@"wo"]) {
      [_req setContentType:@"application/x-httpd-wo"];
      return ApacheHandledRequest;
    }
  }
  return ApacheDeclineRequest;
}

@end /* ApacheWO(Hooks) */
