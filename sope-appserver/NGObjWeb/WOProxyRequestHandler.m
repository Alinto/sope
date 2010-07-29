/*
  Copyright (C) 2000-2005 SKYRIX Software AG

  This file is part of SOPE.

  SOPE is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the
  Free Software Foundation; either version 2, or (at your option) any
  later version.

  SOPE is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or
  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Lesser General Public
  License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with SOPE; see the file COPYING.  If not, write to the
  Free Software Foundation, 59 Temple Place - Suite 330, Boston, MA
  02111-1307, USA.
*/

#include <NGObjWeb/WOProxyRequestHandler.h>
#include <NGObjWeb/WOApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOHTTPConnection.h>
#include "common.h"

@implementation WOProxyRequestHandler

+ (int)version {
  return [super version] + 0 /* v2 */;
}
+ (void)initialize {
  NSAssert2([super version] == 2,
            @"invalid superclass (%@) version %i !",
            NSStringFromClass([self superclass]), [super version]);
}

- (id)initWithHost:(NSString *)_hostName onPort:(unsigned int)_port {
  if ((self = [super init])) {
    self->client = 
      [[WOHTTPConnection alloc] initWithHost:_hostName onPort:_port];
    
    self->rewriteHost = YES;
  }
  return self;
}

- (id)init {
  return [self initWithHost:nil onPort:0];
}

- (void)dealloc {
  [self->logFilePrefix release];
  [self->client release];
  [super dealloc];
}

/* settings */

- (void)enableRawLogging {
  [self logWithFormat:@"enabling raw logging ..."];
  self->rawLogRequest  = YES;
  self->rawLogResponse = YES;
}

- (void)setLogFilePrefix:(NSString *)_p {
  ASSIGNCOPY(self->logFilePrefix, _p);
}

/* logging */

- (void)logMessage:(WOMessage *)_msg prefix:(NSString *)_p 
  ext:(NSString *)_ext
{
  NSEnumerator *keys;
  NSString     *key;
  FILE *fh = NULL;
  const unsigned char *s;
  
  if (self->logFilePrefix) {
    NSString *fn;
    
    fn = [self->logFilePrefix stringByAppendingFormat:@"%04i.%@",
	      self->rqcount, _ext];
    if ((fh = fopen([fn cString], "w")) == NULL)
      [self logWithFormat:@"could not open: %@", fn];
  }
  
  if (_p) {
    printf("%s", [_p cString]);
    if (fh != NULL) fprintf(fh, "%s", [_p cString]);
  }
  
  /* headers */
  keys = [[_msg headerKeys] objectEnumerator];
  while ((key = [keys nextObject])) {
    NSEnumerator *vals;
    id val;
    
    vals = [[_msg headersForKey:key] objectEnumerator];
    while ((val = [vals nextObject]) != NULL) {
      s = (unsigned char *)[[val stringValue] cString];
      printf("%s: %s\n", [key cString], s);
      if (fh != NULL) fprintf(fh, "%s: %s\r\n", [key cString], s);
    }
  }
  
  /* content */
  if ((s = (unsigned char *)[[_msg contentAsString] cString])) {
    printf("\n%s\n", s);
    if (fh != NULL) fprintf(fh, "\r\n%s", s);
  }
  else {
    printf("\n");
    if (fh != NULL) fprintf(fh, "\r\n");
  }
  
  if (fh != NULL) fclose(fh);
}

- (void)logRequest:(WORequest *)_rq {
  NSString *rl;
  printf("PROXY REQUEST:---\n");
  
  rl = [NSString stringWithFormat:@"%@ %@ %@\r\n", 
		   [_rq method], [_rq uri], [_rq httpVersion]];
  [self logMessage:_rq prefix:rl ext:@"http"];
  printf("---\n");
}

- (void)logResponse:(WOResponse *)_r {
  NSString *rl;
  printf("PROXY RESPONSE:---\n");
  
  rl = [NSString stringWithFormat:@"%@ %i\r\n", [_r httpVersion], [_r status]];
  [self logMessage:_r prefix:rl ext:@"http-rs"];
  printf("---\n");
}

/* dispatching */

- (WOResponse *)failedResponse:(NSString *)_txt forRequest:(WORequest *)_rq{
  WOResponse *r;

  r = [WOResponse responseWithRequest:_rq];
  [r setStatus:500];
  [r appendContentHTMLString:_txt];
  return r;
}

- (WORequest *)fixupRequest:(WORequest *)_request {
  return _request;
}
- (WOResponse *)fixupResponse:(WOResponse *)_r {
  return _r;
}

- (WORequest *)makeProxyRequest:(WORequest *)_request url:(NSURL *)_url {
  /* this is basically a copy with a modified URI ... */
  WORequest *rq;
  
  rq = [[WORequest alloc]
	 initWithMethod:[_request method]
	 uri:[_url path]
	 httpVersion:[_request httpVersion]
	 headers:[_request headers]
	 content:[_request content]
	 userInfo:[_request userInfo]];
  return [rq autorelease];
}

- (WOResponse *)handleRequest:(WORequest *)_request {
  WOHTTPConnection *targetClient;
  WOResponse *r;
  
  self->rqcount++;
  targetClient = self->client;
  
  _request = [self fixupRequest:_request];
  
  if ([[_request uri] hasPrefix:@"http://"]) {
    NSURL *purl;
    
    purl = [NSURL URLWithString:[_request uri]];
    [self logWithFormat:@"got a proxy request: %@", purl];
    
    _request = [self makeProxyRequest:_request url:purl];
    
    targetClient = [[WOHTTPConnection alloc] initWithHost:[purl host]
					     onPort:[[purl port] intValue]];
    targetClient = [targetClient autorelease];
  }
  
  if (self->rawLogRequest)
    [self logRequest:_request];
  
  /* force HTTP/1.0 ... */
  [_request setHTTPVersion:@"HTTP/1.0"];
  
  if (![targetClient sendRequest:_request]) {
    [self logWithFormat:@"forwarding request to client failed."];
    return [self failedResponse:@"forwarding request to client failed."
		 forRequest:_request];
  }
  
  if ((r = [targetClient readResponse]) == nil) {
    [self logWithFormat:@"reading response from client failed."];
    return [self failedResponse:@"reading response from client failed."
		 forRequest:_request];
  }
  
  r = [self fixupResponse:r];
  
  if (self->rawLogResponse)
    [self logResponse:r];
  
  return r;
}

/* logging */

- (NSString *)loggingPrefix {
  return @"[proxy-handler]";
}

@end /* WOProxyRequestHandler */
