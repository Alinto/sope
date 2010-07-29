/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#import <Foundation/NSObject.h>

@class NSString, NSURL;
@class WOHTTPConnection;

@interface DavPropGetTool : NSObject
{
  WOHTTPConnection *client;
  NSURL    *url;
  NSString *prop;
  NSString *ns;
  NSString *creds;

  BOOL debugOn;
  BOOL outputFlat;
  BOOL outputPList;
  BOOL didOutputOne;
}

@end

#include "common.h"
#include <NGObjWeb/WOHTTPConnection.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <SaxObjC/SaxObjC.h>
#include <SaxObjC/XMLNamespaces.h>
#include <NGObjWeb/SaxDAVHandler.h>

#define DEFAULT_NS @"DAV:"

@implementation DavPropGetTool

static id<NSObject,SaxXMLReader> xmlParser = nil;
static SaxDAVHandler             *davsax   = nil;

- (void)usage {
  fprintf(stderr, "usage: davpropget <url> [property] [ns]\n");
  exit(1);
}

- (id)initWithArguments:(NSArray *)args {
  if ((self = [super init])) {
    NSString *tmp;
    
    if ([args count] < 2) {
      [self usage];
      [self release];
      return nil;
    }

    url  = [[NSURL URLWithString:[args objectAtIndex:1]] copy];
    prop = ([args count] > 2) ? [[args objectAtIndex:2] copy] : nil;
    ns   = ([args count] > 3) ? [[args objectAtIndex:3] copy] : (id)DEFAULT_NS;
    
    if ((tmp = [url user])) {
      creds = [NSString stringWithFormat:@"%@:%@", tmp, [url password]];
      creds = [creds stringByEncodingBase64];
      creds = [[@"Basic " stringByAppendingString:creds] copy];
    }
  }
  return self;
}

- (void)dealloc {
  [self->creds  release];
  [self->url    release];
  [self->prop   release];
  [self->ns     release];
  [self->client release];
  [super dealloc];
}

/* parser */

- (void)lockParser:(id)_sax {
  [_sax reset];
  [xmlParser setContentHandler:_sax];
  [xmlParser setErrorHandler:_sax];
}
- (void)unlockParser:(id)_sax {
  [xmlParser setContentHandler:nil];
  [xmlParser setErrorHandler:nil];
  [_sax reset];
}

- (BOOL)setupXmlParser {
  if (xmlParser == nil) {
    xmlParser =
      [[[SaxXMLReaderFactory standardXMLReaderFactory] 
                             createXMLReaderForMimeType:@"text/xml"]
                             retain];
    if (xmlParser == nil)
      return NO;
  }
  if (davsax == nil) {
    if ((davsax = [[SaxDAVHandler alloc] init]) == nil)
      return NO;
  }
  return YES;
}

/* connection */

- (WOHTTPConnection *)client {
  if (self->client) return self->client;
  
  self->client = [[WOHTTPConnection alloc] 
                   initWithHost:[self->url host] 
                   onPort:[[self->url port] intValue]];
  if (debugOn) NSLog(@"  client: %@", client);
  return self->client;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return self->debugOn;
}

/* operations */

- (void)davHandler:(SaxDAVHandler *)_handler
  receivedProperties:(NSDictionary *)_record
  forURI:(NSString *)_uri
{
  NSEnumerator *keys;
  NSString *key;
  
  if (debugOn) {
    [self debugWithFormat:@"URI: %@", _uri];
    [self debugWithFormat:@"  properties: %@", _record];
  }
  
  if (self->didOutputOne)
    printf("\n");
  
  if (self->outputPList) {
    printf("%s\n", [[_record description] cString]);
    return;
  }
  
  keys = [[[_record allKeys] sortedArrayUsingSelector:@selector(compare:)]
                    objectEnumerator];
  while ((key = [keys nextObject])) {
    printf("%-40s: %s\n",
           [key cString],
           [[[_record objectForKey:key] stringValue] cString]);
  }
  
  // [self logWithFormat:@"RECORD: %@", _record];
  self->didOutputOne = YES;
}

- (void)logResponse:(WOResponse *)_response {
  if (self->debugOn) {
    [self debugWithFormat:@"received:\n----------\n%@----------", 
            [_response contentAsString]];
  }
  
  if (![self setupXmlParser]) {
    [self logWithFormat:@"could not setup XML parser ..."];
    return;
  }
  
  [self lockParser:davsax];
  {
    [davsax setDelegate:self];
    [xmlParser parseFromSource:[_response content]];
  }
  [self unlockParser:davsax];
}

- (void)sendRequestWithAuth:(WORequest *)rq {
  WOHTTPConnection *httpClient;

  httpClient = [self client];
  
  do {
    WOResponse *r;
    
    if (![httpClient sendRequest:rq]) {
      [self logWithFormat:@"ERROR: send failed: %@", 
              [httpClient lastException]];
      break;
    }
    if ((r = [httpClient readResponse]) == nil) {
      [self logWithFormat:@"ERROR: receive failed: %@", 
              [httpClient lastException]];
      break;
    }
    
    if ([r status] == 401) {
      id auth;
      
      if ((auth = [rq headerForKey:@"authorization"])) {
	[self logWithFormat:@"invalid credentials: %@", auth];
	break;
      }
      
      auth = [r headerForKey:@"www-authenticate"];
      [self logWithFormat:@"authentication required: %@", auth];
      
      break;
    }
    
    [self logResponse:r];
    break;
  }
  while (YES);
}

- (void)appendBodyToRequest:(WORequest *)rq {
  [rq appendContentString:
	@"<?xml version=\"1.0\" encoding=\"utf-8\" ?>\n"
        @"<propfind xmlns=\"DAV:\" "];
  [rq appendContentString:@" xmlns:V=\""];
  [rq appendContentString:ns];
  [rq appendContentString:@"\""];
  [rq appendContentString:@">"];
  
  if (self->prop) {
    [rq appendContentString:@"<prop>"];
    [rq appendContentString:@"<V:"];
    [rq appendContentString:prop];
    [rq appendContentString:@"/>"];
    [rq appendContentString:@"</prop>"];
  }
  else
    [rq appendContentString:@"<allprop/>"];
  [rq appendContentString:@"</propfind>\n"];
}

- (void)run {
  WORequest *rq;
  
  [self debugWithFormat:
          @"Query:\n  url:  %@\n  prop: %@\n  ns:   %@", 
          url, prop, ns];
  
  rq = [[[WORequest alloc] initWithMethod:@"PROPFIND"
	 		   uri:[url path]
			   httpVersion:@"HTTP/1.0"
			   headers:nil
			   content:nil
			   userInfo:nil]
                           autorelease];
  [rq setHeader:@"t" forKey:@"Brief"];
  [rq setHeader:@"0" forKey:@"Depth"];
  [self appendBodyToRequest:rq];
  
  if (creds) [rq setHeader:creds forKey:@"authorization"];
  [rq setHeader:@"text/xml" forKey:@"content-type"];
  
  [self sendRequestWithAuth:rq];
}

@end /* DavPropGetTool */

int main(int argc, char **argv, char **env) {
  NSAutoreleasePool *pool;
  NSArray *args;
  
  pool = [[NSAutoreleasePool alloc] init];
#if LIB_FOUNDATION_LIBRARY
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  
  args = [[NSProcessInfo processInfo] argumentsWithoutDefaults];
  [[[DavPropGetTool alloc] initWithArguments:args] run];
  
  exit(0);
  return 0;
}
