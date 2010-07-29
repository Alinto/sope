// $Id: ApacheServer.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "ApacheServer.h"
#include <httpd.h>
#import <Foundation/Foundation.h>

static NSString *mkString(const char *str) {
  static Class NSStringClass = Nil;
  unsigned len;

  if (str == NULL) return nil;
  if (NSStringClass == Nil) NSStringClass = [NSString class];
  if ((len = strlen(str)) == 0) return nil;

  return [[[NSStringClass alloc] initWithCString:str] autorelease];
}

@implementation ApacheServer
#define AP_HANDLE ((server_rec *)self->handle)

/* accessors */

- (ApacheServer *)nextServer {
  return [[[ApacheServer alloc] initWithHandle:AP_HANDLE->next] autorelease];
}

/* description of where the definition came from */

- (NSString *)definitionName {
  return mkString(AP_HANDLE->defn_name);
}
- (unsigned int)definitionLineNumber {
  return AP_HANDLE->defn_line_number;
}

/* Full locations of server config info */

- (NSString *)srmConfigName {
  return mkString(AP_HANDLE->srm_confname);
}
- (NSString *)accessConfigName {
  return mkString(AP_HANDLE->access_confname);
}

- (NSString *)serverAdmin {
  return mkString(AP_HANDLE->server_admin);
}
- (NSString *)serverHostName {
  return mkString(AP_HANDLE->server_hostname);
}
- (unsigned short)port {
  return AP_HANDLE->port;
}

/* log files */

- (NSString *)errorFileName {
  return mkString(AP_HANDLE->error_fname);
}
- (FILE *)errorLogFile {
  return AP_HANDLE->error_log;
}
- (int)logLevel {
  return AP_HANDLE->loglevel;
}

/* module-specific configuration for server, and defaults... */

- (BOOL)isVirtual {
  return AP_HANDLE->is_virtual ? YES : NO;
}

/* transaction handling */

- (NSTimeInterval)timeout {
  return AP_HANDLE->timeout;
}
- (NSTimeInterval)keepAliveTimeout {
  return AP_HANDLE->keep_alive_timeout;
}
- (int)keepAliveMax {
  return AP_HANDLE->keep_alive_max;
}
- (BOOL)keepAlive {
  return AP_HANDLE->keep_alive ? YES : NO;
}
- (int)sendBufferSize {
  return AP_HANDLE->send_buffer_size;
}

- (NSString *)serverPath {
  return [NSString stringWithCString:AP_HANDLE->path
                   length:AP_HANDLE->pathlen];
}

#warning names, wild_names

- (id)serverUserId {
  return [NSNumber numberWithInt:AP_HANDLE->server_uid];
}
- (id)serverGroupId {
  return [NSNumber numberWithInt:AP_HANDLE->server_gid];
}

- (int)requestLineLimit {
  return AP_HANDLE->limit_req_line;
}
- (int)requestFieldSizeLimit {
  return AP_HANDLE->limit_req_fieldsize;
}
- (int)requestFieldCountLimit {
  return AP_HANDLE->limit_req_fields;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  id tmp;

  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" 0x%p", self->handle];
  
  if ([self isVirtual])
    [ms appendString:@" virtual"];
  
  [ms appendFormat:@" uid=%@ gid=%@",
        [self serverUserId], [self serverGroupId]];
  
  if ([(tmp = [self definitionName]) length] > 0)
    [ms appendFormat:@" def=%@:%i", tmp, [self definitionLineNumber]];

  if ((tmp = [self serverHostName]))
    [ms appendFormat:@" host=%@:%i", tmp, [self port]];

#if 0
  if ((tmp = [self serverAdmin]))
    [ms appendFormat:@" admin=%@", tmp];
#endif
  
  [ms appendFormat:@" loglevel=%i", [self logLevel]];
  
  if ((tmp = [self nextServer]))
    [ms appendFormat:@" next=%@", tmp];
  
  [ms appendString:@">"];
  return ms;
}

@end /* ApacheServer */
