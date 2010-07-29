// $Id: WOResponse+Apache.m,v 1.1 2004/06/08 11:06:00 helge Exp $

#include "WOResponse+Apache.h"
#include <ApacheAPI/ApacheRequest.h>
#include <ApacheAPI/ApacheModule.h>
#include <ApacheAPI/ApacheTable.h>
#include "common.h"

@implementation WOResponse(Apache)

- (BOOL)applyHeadersOnApacheRequest:(ApacheRequest *)_rq {
  static NSMutableSet *ignoredHeaders = nil;
  ApacheTable  *apHeaders;
  NSString     *ctype;
  NSEnumerator *keys;
  NSString     *key;
  
  if (_rq == nil)
    return NO;
  
  if (ignoredHeaders == nil) {
    ignoredHeaders = [[NSMutableSet alloc] initWithObjects:
					     @"content-type",
					     nil];
  }
  
  if ((ctype = [self headerForKey:@"content-type"]))
    [_rq setContentType:ctype];
  
  /* apply all headers ... */
  
  apHeaders = [_rq headersOut];
  
  keys = [[self headerKeys] objectEnumerator];
  while ((key = [keys nextObject])) {
    NSString *svalue;
    
    if ([ignoredHeaders containsObject:key])
      continue;
    
    svalue = [[self headersForKey:key] componentsJoinedByString:@", "];
    [apHeaders setObject:svalue forKey:key];
  }
  return YES;
}

- (int)sendContentUsingApacheRequest:(ApacheRequest *)_rq {
  return [_rq rwriteData:[self content]];
}

- (int)sendResponseUsingApacheRequest:(ApacheRequest *)_rq {
  NSAutoreleasePool *pool;
  int result;
  
  result = [self status];
  
  pool = [[NSAutoreleasePool alloc] init];

  [_rq setStatus:[self status]];
  
  if (![self applyHeadersOnApacheRequest:_rq])
    result = 500;
  else {
#if DONT_SEND_CONTENT_IN_SUBREQUESTS
    if ([_rq mainRequest]) {
      [self logWithFormat:@"is subrequest (no content is send) ..."];
    }
    else {
#endif
      [_rq sendHttpHeader];
      
      if (![_rq isHeadRequest])
	result = [self sendContentUsingApacheRequest:_rq];
#if DONT_SEND_CONTENT_IN_SUBREQUESTS
    }
#endif
  }
  
  RELEASE(pool);
  return ApacheHandledRequest;
}

@end /* WOResponse(Apache) */

@implementation WOResponse(ApacheAppend)

- (void)appendApacheResponseInfo:(ApacheRequest *)_request {
  [self appendContentString:@"<table border='1' width=\"100%\">"];

#if 0
  [self appendContentString:
          @"<tr><td valign='top' align='right'>Description:</td><td><pre>"];
  [self appendContentHTMLString:[_request description]];
  [self appendContentString:@"</pre></td></tr>"];
#endif

  [self appendContentString:
          @"<tr><td width='25%' valign='top' align='right'>Status:</td><td>"];
  [self appendContentHTMLString:[NSString stringWithFormat:@"%i",[_request status]]];
  [self appendContentString:@"</td></tr>"];
  
  [self appendContentString:
          @"<tr><td width='25%' valign='top' align='right'>unparsed URI:</td><td>"];
  [self appendContentHTMLString:[_request unparsedURI]];
  [self appendContentString:@"</td></tr>"];
  
  [self appendContentString:
          @"<tr><td valign='top' align='right'>URI:</td><td>"];
  [self appendContentHTMLString:[_request uri]];
  [self appendContentString:@"</td></tr>"];
  
  [self appendContentString:
          @"<tr><td valign='top' align='right'>filename:</td><td>"];
  [self appendContentHTMLString:[_request filename]];
  [self appendContentString:@"</td></tr>"];

  [self appendContentString:
          @"<tr><td valign='top' align='right'>filetype:</td><td>"];
  [self appendContentHTMLString:[_request fileType]];
  [self appendContentString:@"</td></tr>"];

  [self appendContentString:
          @"<tr><td valign='top' align='right'>content-type:</td><td>"];
  [self appendContentHTMLString:[_request contentType]];
  [self appendContentString:@"</td></tr>"];
  
  [self appendContentString:
          @"<tr><td valign='top' align='right'>queryargs:</td><td>"];
  [self appendContentHTMLString:[_request queryArgs]];
  [self appendContentString:@"</td></tr>"];
  
  [self appendContentString:
          @"<tr><td valign='top' align='right'>pathinfo:</td><td>"];
  [self appendContentHTMLString:[_request pathInfo]];
  [self appendContentString:@"</td></tr>"];

  [self appendContentString:
          @"<tr><td valign='top' align='right'>Headers:</td><td><pre>"];
  [self appendContentHTMLString:
          [[[_request headersOut] asDictionary] description]];
  [self appendContentString:@"</pre></td></tr>"];
  
  [self appendContentString:@"</table>"];
}

@end /* WOResponse(ApacheAppend) */
