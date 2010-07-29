// $Id: ApacheConnection.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "ApacheConnection.h"
#import <Foundation/NSString.h>
#include "httpd.h"

@implementation ApacheConnection
#define AP_HANDLE ((conn_rec *)self->handle)

/* accessors */

- (ApacheResourcePool *)connectionPool {
  return [ApacheResourcePool objectWithHandle:AP_HANDLE->pool];
}
- (ApacheServer *)server {
  return [ApacheServer objectWithHandle:AP_HANDLE->server];
}
- (ApacheServer *)baseServer {
  return [ApacheServer objectWithHandle:AP_HANDLE->base_server];
}

/* Information about the connection itself */

- (int)childNumber {
  return AP_HANDLE->child_num;
}

/* Who is the client? */

// struct sockaddr_in local_addr;
// struct sockaddr_in remote_addr;
- (NSString *)remoteIP {
  return [NSString stringWithCString:AP_HANDLE->remote_ip];
}
- (NSString *)remoteHost {
  return [NSString stringWithCString:AP_HANDLE->remote_host];
}
- (NSString *)remoteLogName {
  return [NSString stringWithCString:AP_HANDLE->remote_logname];
}
- (NSString *)user {
  return [NSString stringWithCString:AP_HANDLE->user];
}
- (NSString *)authorizationType {
  return [NSString stringWithCString:AP_HANDLE->ap_auth_type];
}

- (NSString *)localIP {
  return [NSString stringWithCString:AP_HANDLE->local_ip];
}
- (NSString *)localHost {
  return [NSString stringWithCString:AP_HANDLE->local_host];
}

- (BOOL)isAborted {
  return AP_HANDLE->aborted ? YES : NO;
}
- (BOOL)usesKeepAlive {
  return AP_HANDLE->keepalive == 1 ? YES : NO;
}
- (BOOL)doesNotUseKeepAlive {
  return AP_HANDLE->keepalive == -1 ? YES : NO;
}
- (BOOL)didUseKeepAlive {
  return AP_HANDLE->keptalive ? YES : NO;
}

- (int)numberOfKeepAlives {
  return AP_HANDLE->keepalives;
}

- (BOOL)isValidDoubleReverseDNS {
  return AP_HANDLE->double_reverse == 1 ? YES : NO;
}
- (BOOL)isInvalidDoubleReverseDNS {
  return AP_HANDLE->double_reverse == -1 ? YES : NO;
}

#undef AP_HANDLE


- (NSString *)description {
  NSMutableString *ms;
  id tmp;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" 0x%p", self->handle];

  if ([self isAborted])       [ms appendString:@" aborted"];
  if ([self usesKeepAlive])   [ms appendString:@" keepalive"];
  if ([self didUseKeepAlive]) [ms appendString:@" did-keepalive"];

  if ([self numberOfKeepAlives] > 0)
    [ms appendFormat:@" #keepalives=%i", [self numberOfKeepAlives]];
  
  tmp = [self remoteIP];
  if ([tmp length] > 0) [ms appendFormat:@" remoteIP=%@", tmp];
  
  tmp = [self user];
  if ([tmp length] > 0) [ms appendFormat:@" user=%@", tmp];

  tmp = [self authorizationType];
  if ([tmp length] > 0) [ms appendFormat:@" auth=%@", tmp];
  
  [ms appendString:@">"];
  return ms;
}

@end /* ApacheConnection */
