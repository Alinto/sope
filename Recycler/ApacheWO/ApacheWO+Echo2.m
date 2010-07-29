// $Id: ApacheWO+Echo2.m,v 1.1 2004/06/14 15:02:00 helge Exp $

#include "ApacheWO.h"
#include "AWODirectoryConfig.h"
#include "ApacheResourceManager.h"
#include "WORequest+Apache.h"
#include "WOResponse+Apache.h"
#include <ApacheAPI/ApacheRequest.h>
#include "common.h"

@implementation ApacheWO(Echo2Handler)

- (WOResponse *)echoResponseForRequest:(WORequest *)woRequest
  apacheRequest:(ApacheRequest *)_rq
  config:(id)cfg
{
  WOResponse *woResponse;
  
  [self logWithFormat:@"generated response was <nil> .."];
  woResponse = [[[WOResponse alloc] initWithRequest:woRequest] autorelease];
  
  /* construct response */
  
  [woResponse setHeader:@"text/html" forKey:@"content-type"];
  [woResponse appendContentString:@"<h3>WOResponse Content</h3>"];
  
  [woResponse appendContentHTMLString:[cfg stringValue]];
  [woResponse appendContentString:@"<br />\n\n"];
  
  [woResponse appendContentString:@"<b>URI:</b><pre>"];
  [woResponse appendContentHTMLString:[woRequest uri]];
  [woResponse appendContentString:@"</pre>\n"];
  
  [woResponse appendContentString:@"<b>Description:</b><pre>"];
  [woResponse appendContentHTMLString:[woRequest description]];
  [woResponse appendContentString:@"</pre>\n"];
  
  [woResponse appendContentString:@"<b>Request Headers:</b><pre>"];
  [woResponse appendContentHTMLString:[[woRequest headers] description]];
  [woResponse appendContentString:@"</pre>\n"];

  [woResponse appendApacheResponseInfo:
                [_rq subRequestLookupURI:@"/docs/subdir/test.wox"]];
  [woResponse appendContentString:@"<br />"];
  
  [woResponse appendApacheResponseInfo:
                [_rq subRequestLookupFile:@"test.wox"]];
  [woResponse appendContentString:@"<br />"];
  
  [woResponse appendApacheResponseInfo:
                [_rq subRequestLookupURI:@"/docs/subdir/non_existent.wox"]];
  [woResponse appendContentString:@"<br />"];

  [woResponse appendApacheResponseInfo:
                [_rq subRequestLookupURI:@"/docs/subdir/"]];
  [woResponse appendContentString:@"<br />"];
  
  [woResponse appendApacheResponseInfo:
                [_rq subRequestLookupURI:@"/docs/bigimg.gif"]];
  [woResponse appendContentString:@"<br />"];

  return woResponse;
}

@end /* ApacheWO(Echo2Handler) */
