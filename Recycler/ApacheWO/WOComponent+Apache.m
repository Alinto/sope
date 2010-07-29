// $Id: WOComponent+Apache.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include <NGObjWeb/WOComponent.h>
#include <NGObjWeb/WOContext.h>
#include <NGObjWeb/WORequest.h>
#include <ApacheAPI/ApacheRequest.h>
#include "common.h"

@interface WOContext(Apache)
- (ApacheRequest *)apacheRequest;
@end

@implementation WOContext(Apache)

- (ApacheRequest *)apacheRequest {
  return [[[self  request] userInfo] objectForKey:@"ApacheRequest"];
}

- (id)_jsprop_apacheRequest {
  return [self apacheRequest];
}

@end /* WOContext(Apache) */

@implementation WOComponent(Apache)

- (ApacheRequest *)apacheRequest {
  return [[self context] apacheRequest];
}

- (id)_jsprop_apacheRequest {
  return [self apacheRequest];
}

@end /* WOComponent(Apache) */
