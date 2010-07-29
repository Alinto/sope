// $Id: ApacheWO+Echo.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "ApacheWO.h"
#include "common.h"
#include <ApacheAPI/ApacheAPI.h>

@implementation ApacheWO(EchoHandler)

- (int)performObjcEchoRequest:(ApacheRequest *)_rq {
  NSAutoreleasePool *pool;
  id cfg;
  NSString *s;
  
  pool = [[NSAutoreleasePool alloc] init];
  
  /* get directory specific info ! */
  cfg = [self configForDirectory:_rq];
  
  [self performWoxPageRequest:_rq];
  
  NSLog(@"CFG: %@", cfg);
  
  /* setup header */
  [_rq setContentType:@"text/html"];

  /* send header to client */
  [_rq sendHttpHeader];
  
  /* send body to client */
  [_rq rputs:"<h3>\n"];
  [_rq rputs:"echo !"];
  [_rq rputs:"</h3>\n"];
  
  s = [cfg stringValue];
  if ([s length] > 0)
    [_rq rputs:[s cString]];
  [_rq rputs:"<br />\n\n"];
  
  [_rq rputs:"<b>URI:</b><pre>"];
  [_rq rputs:[[_rq uri] cString]];
  [_rq rputs:"</pre>\n"];
  
  [_rq rputs:"<b>description:</b><pre>"];
  [_rq rputs:[[_rq description] cString]];
  [_rq rputs:"</pre>\n"];

  [_rq rputs:"<b>headers-in:</b><pre>"];
  [_rq rputs:[[[_rq headersIn] description] cString]];
  [_rq rputs:"</pre>\n"];

  [_rq rputs:"<b>headers-in-dict:</b><pre>"];
  [_rq rputs:[[[[_rq headersIn] asDictionary] description] cString]];
  [_rq rputs:"</pre>\n"];

  RELEASE(pool);
  
  /* say we are done ... */
  return ApacheHandledRequest;
}

@end /* ApacheWO(EchoHandler) */
