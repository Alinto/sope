// $Id: ApacheWO+RequestHandler.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "ApacheWO.h"
#include "AWODirectoryConfig.h"
#include "ApacheResourceManager.h"
#include "WORequest+Apache.h"
#include "WOResponse+Apache.h"
#include "common.h"
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequestHandler.h>
#include <ApacheAPI/ApacheAPI.h>

/*
  implements a WORequestHandler "dispatcher"
  
  All WORequestHandler classes are registered in the ApacheHandlers.plist
  with the single dispatchRequest: selector. This method creates an object
  of the request handler class and let it dispatch the request.
*/

@implementation ApacheWO(RequestHandler)

- (int)dispatchRequest:(ApacheRequest *)_rq
  usingHandlerNamed:(NSString *)_hname
  inApplication:(WOApplication *)_app
{
  WORequestHandler *handler;
  WORequest  *woRequest;
  WOResponse *woResponse;
  int        result;
  
  if ((handler = [_app requestHandlerForKey:_hname]) == nil) {
    [self logWithFormat:@"did not find request handler for key '%@'", 
	    _hname];
    return ApacheDeclineRequest;
  }
  
  woRequest = [[[WORequest alloc] initWithApacheRequest:_rq] autorelease];
  
  woResponse = [_app dispatchRequest:woRequest usingHandler:handler];
  
  /* send response */
  
  if (woResponse)
    result = [woResponse sendResponseUsingApacheRequest:_rq];
  else
    result = 500;

  return result;
}

- (int)dispatchRequestHandler:(ApacheRequest *)_rq {
  NSAutoreleasePool  *pool;
  AWODirectoryConfig *cfg;
  WOApplication    *app;
  int result;
  
  if (_rq == NULL)
    return ApacheDeclineRequest;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  /* get directory specific info (app, request-handler) ! */
  
  cfg = [self configForDirectory:_rq];
  
  if ((app = [cfg application]) == nil) {
    [self logWithFormat:@"missing app .."];
    goto done;
  }
  
  result = [self dispatchRequest:_rq
		 usingHandlerNamed:[_rq handler]
		 inApplication:app];
  
 done:
  RELEASE(pool);
  
  /* say we are done ... */
  return result;
}

@end /* ApacheWO(WoxPageHandler) */
