// $Id: WOResponse+Apache.h,v 1.1 2004/06/08 11:06:00 helge Exp $

#ifndef __WOResponse_Apache_H__
#define __WOResponse_Apache_H__

#include <NGObjWeb/WOResponse.h>

@class ApacheRequest;

@interface WOResponse(Apache)

- (int)sendResponseUsingApacheRequest:(ApacheRequest *)_rq;

@end /* WOResponse(Apache) */

@interface WOResponse(ApacheInfo)
- (void)appendApacheResponseInfo:(ApacheRequest *)_request;
@end

#endif /* __WOResponse_Apache_H__ */
