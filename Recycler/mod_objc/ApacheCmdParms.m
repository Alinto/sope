// $Id: ApacheCmdParms.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "ApacheCmdParms.h"
#include "ApacheResourcePool.h"
#include "httpd.h"
#include "http_config.h"
#import <Foundation/Foundation.h>

@implementation ApacheCmdParms

#define AP_HANDLE ((cmd_parms *)self->handle)

- (void *)userInfo {
  /* Argument to command from cmd_table */
  return AP_HANDLE->info;
}

- (ApacheResourcePool *)pool {
  ApacheResourcePool *pool;
  
  pool = [[ApacheResourcePool alloc]
                              initWithHandle:AP_HANDLE->pool freeWhenDone:NO];
  return AUTORELEASE(pool);
}
- (ApacheResourcePool *)temporaryPool {
  ApacheResourcePool *pool;
  
  pool = [[ApacheResourcePool alloc]
                              initWithHandle:AP_HANDLE->temp_pool
                              freeWhenDone:NO];
  return AUTORELEASE(pool);
}

- (ApacheServer *)server {
  return [[[ApacheServer alloc] initWithHandle:AP_HANDLE->server] autorelease];
}

- (NSString *)path {
  const unsigned char *c;
  
  if ((c = AP_HANDLE->path) == NULL)
    return nil;
  return [[[NSString alloc] initWithCString:c] autorelease];
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  id tmp;

  ms = [NSMutableString stringWithCapacity:256];
  [ms appendFormat:@"<0x%p[%@]: ", self, NSStringFromClass([self class])];

  [ms appendFormat:@" 0x%p ui=0x%p", self->handle, [self userInfo]];
  
  if ((tmp = [self path]))
    [ms appendFormat:@" path=%@", tmp];
  if ((tmp = [self server]))
    [ms appendFormat:@" server=%@", tmp];
  
  [ms appendString:@">"];
  return ms;
}

@end /* ApacheCmdParms */
