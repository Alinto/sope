// $Id: WORequest+Apache.h,v 1.1 2004/06/08 11:06:00 helge Exp $

#ifndef __WORequest_Apache_H__
#define __WORequest_Apache_H__

#include <NGObjWeb/WORequest.h>

@class ApacheRequest;

@interface WORequest(Apache)

- (id)initWithApacheRequest:(ApacheRequest *)_rq;

@end /* WORequest(Apache) */

#endif /* __WORequest_Apache_H__ */
