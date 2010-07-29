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

#include <NGObjWeb/WOHTTPConnection.h>
#include <NGObjWeb/WOCookie.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOCookie.h>
#include <NGObjWeb/WORunLoop.h>
#include <NGStreams/NGStreams.h>
#include <NGStreams/NGCTextStream.h>
#include <NGStreams/NGBufferedStream.h>
#include <NGStreams/NGNet.h>
#include <NGHttp/NGHttp.h>
#include <NGMime/NGMime.h>
#import <Foundation/Foundation.h>
#include "WOSimpleHTTPParser.h"
#include "WOHttpAdaptor/WORecordRequestStream.h"

@interface WOHTTPConnection(Privates)
- (BOOL)_connect;
- (void)_disconnect;
@end

@interface WOCookie(Privates)
+ (id)cookieWithString:(NSString *)_string;
@end

NSString *WOHTTPConnectionCanReadResponse = @"WOHTTPConnectionCanReadResponse";

@interface NSURL(SocketAddress)
- (id)socketAddressForURL;
- (BOOL)shouldUseWOProxyServer;
@end

@interface WOHTTPConnection(Privates2)
+ (NSString *)proxyServer;
+ (NSURL *)proxyServerURL;
+ (NSArray *)noProxySuffixes;
@end

@implementation WOHTTPConnection

static Class SSLSocketClass  = Nil;
static BOOL  useSimpleParser = YES;
static NSString *proxyServer = nil;
static NSArray  *noProxy     = nil;
static BOOL doDebug   = NO;
static BOOL logStream = NO;

+ (int)version {
  return 3;
}

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
    
  useSimpleParser = [ud boolForKey:@"WOHTTPConnectionUseSimpleParser"];
  proxyServer     = [ud stringForKey:@"WOProxyServer"];
  noProxy         = [ud arrayForKey:@"WONoProxySuffixes"];
  doDebug         = [ud boolForKey:@"WODebugHTTPConnection"];
  logStream       = [ud boolForKey:@"WODebugHTTPConnectionLogStream"];
}

+ (NSString *)proxyServer {
  return proxyServer;
}
+ (NSURL *)proxyServerURL {
  NSString *ps;

  ps = [self proxyServer];
  if ([ps length] == 0)
    return nil;
  
  return [NSURL URLWithString:ps];
}
+ (NSArray *)noProxySuffixes {
  return noProxy;
}

- (id)initWithNSURL:(NSURL *)_url {
  if ((self = [super init])) {
    self->url      = [_url retain];
    self->useSSL   = [[_url scheme] isEqualToString:@"https"];
    self->useProxy = [_url shouldUseWOProxyServer];
    
    if (self->useSSL) {
      static BOOL didCheck = NO;
      if (!didCheck) {
	didCheck = YES;
	SSLSocketClass = NSClassFromString(@"NGActiveSSLSocket");
      }
    }
  }
  return self;
}

- (id)initWithURL:(id)_url {
  NSURL *lurl;
  
  /* create an NSURL object if necessary */
  lurl = [_url isKindOfClass:[NSURL class]]
    ? _url
    : [NSURL URLWithString:[_url stringValue]];
  if (lurl == nil) {
    if (doDebug)
      [self logWithFormat:@"could not construct URL from object '%@' !", _url];
    [self release];
    return nil;
  }
  if (doDebug)
    [self logWithFormat:@"init with URL: %@", lurl];
  return [self initWithNSURL:lurl];
}

- (id)initWithHost:(NSString *)_hostName onPort:(unsigned int)_port 
  secure:(BOOL)_flag
{
  NSString *s;
  
  s = [NSString stringWithFormat:@"http%s://%@:%i/",
		  _flag ? "s" : "", _hostName, 
		  _port == 0 ? (_flag?443:80) : _port];
  return [self initWithURL:s];
}
- (id)initWithHost:(NSString *)_hostName onPort:(unsigned int)_port {
  return [self initWithHost:_hostName onPort:_port secure:NO];
}
- (id)init {
  return [self initWithHost:@"localhost" onPort:80 secure:NO];
}

- (void)dealloc {
  [self->lastException release];
  [self->log      release];
  [self->io       release];
  [self->socket   release];
  [self->url      release];
  [super dealloc];
}

/* error handling */

- (NSException *)lastException {
  return self->lastException;
}

- (BOOL)isDebuggingEnabled {
  return doDebug ? YES : NO;
}
- (NSString *)loggingPrefix {
  /* improve perf ... */
  if (self->url) {
    return [NSString stringWithFormat:@"WOHTTP[0x%p]<%@>", 
		       self, [self->url absoluteString]];
  }
  else
    return [NSString stringWithFormat:@"WOHTTP[0x%p]", self];
}

/* accessors */

- (NSString *)hostName {
  return [self->url host];
}

/* IO */

- (BOOL)_connect {
  id<NGSocketAddress> address;
  
  [self _disconnect];
  
#if DEBUG
  NSAssert(self->socket == nil, @"socket still available after disconnect");
  NSAssert(self->io == nil,     @"IO stream still available after disconnect");
#endif
  
  if (self->useSSL) {
    if (SSLSocketClass == Nil) {
      /* no SSL support is available */
      static BOOL didLog = NO;
      if (!didLog) {
	didLog = YES;
	NSLog(@"NOTE: SSL support is not available !");
      }
      return NO;
    }
  }
  
  if (self->useProxy) {
    NSURL *purl;
    
    purl = [[self class] proxyServerURL];
    address = [purl socketAddressForURL];
  }
  else {
    address = [self->url socketAddressForURL];
  }
  if (address == nil) {
    [self debugWithFormat:@"got no address for connect .."];
    return NO;
  }
  
  NS_DURING {
    self->socket = self->useSSL
      ? [SSLSocketClass socketConnectedToAddress:address]
      : [NGActiveSocket socketConnectedToAddress:address];
  }
  NS_HANDLER {
#if 0
    fprintf(stderr, "couldn't create socket: %s\n",
            [[localException description] cString]);
#endif
    ASSIGN(self->lastException, localException);
    self->socket = nil;
  }
  NS_ENDHANDLER;
  
  if (self->socket == nil) {
    [self debugWithFormat:@"socket is not setup: %@", [self lastException]];
    return NO;
  }
  
  if (![self->socket isConnected]) {
    self->socket = nil;
    [self debugWithFormat:@"socket is not connected .."];
    return NO;
  }
  
  self->socket = [self->socket retain];
  
  [(NGActiveSocket *)self->socket setSendTimeout:[self sendTimeout]];
  [(NGActiveSocket *)self->socket setReceiveTimeout:[self receiveTimeout]];
  
  if (self->socket != nil) {
    NGBufferedStream *bStr;
    
    bStr = [NGBufferedStream alloc]; // keep gcc happy
    bStr = [bStr initWithSource:self->socket];
    if (logStream) {
      self->log = [WORecordRequestStream alloc]; // keep gcc happy
      self->log = [(WORecordRequestStream *)self->log initWithSource:bStr];
    }
    else
      self->log = nil;
    
    self->io = [NGCTextStream alloc]; // keep gcc happy
    self->io = [self->io initWithSource:
		      (id)(self->log != nil ? self->log : (id)bStr)];
    [bStr release]; bStr = nil;
  }
  
  return YES;
}
- (void)_disconnect {
  [self->log release]; self->log = nil;
  [self->io  release]; self->io  = nil;
  
  NS_DURING
    (void)[self->socket shutdown];
  NS_HANDLER {}
  NS_ENDHANDLER;
  
  [self->socket release]; self->socket = nil;
}

/* logging IO */

- (void)logRequest:(WORequest *)_response data:(NSData *)_data {
  if (_data == nil) return;
  
#if 1
  NSLog(@"request is\n");
  fflush(stderr);
  fwrite([_data bytes], 1, [_data length], stderr);
  fflush(stderr);
  fprintf(stderr,"\n");
  fflush(stderr);
#endif
}
- (void)logResponse:(WOResponse *)_response data:(NSData *)_data {
  if (_data == nil) return;
  
#if 1
  NSLog(@"response is\n");
  fflush(stderr);
  fwrite([_data bytes], 1, [_data length], stderr);
  fflush(stderr);
  fprintf(stderr,"\n");
  fflush(stderr);
#endif
}

/* sending/receiving HTTP */

- (BOOL)sendRequest:(WORequest *)_request {
  NSData *content;
  BOOL isok = YES;
  
  if (doDebug)
    [self debugWithFormat:@"send request: %@", _request];
  
  if (![self->socket isConnected]) {
    if (![self _connect]) {
      /* could not connect */
      if (doDebug)
        [self debugWithFormat:@"  could not connect socket"];
      return NO;
    }
    /* now connected */
  }
  
  content = [_request content];
  
  /* write request line (eg 'GET / HTTP/1.0') */
  if (doDebug)
    [self debugWithFormat:@"  method: %@", [_request method]];
  
  if (isok) isok = [self->io writeString:[_request method]];
  if (isok) isok = [self->io writeString:@" "];
  
  if (self->useProxy) {
    if (isok)
      // TODO: check whether this produces a '//' (may need to strip uri)
      isok = [self->io writeString:[self->url absoluteString]];
    [self debugWithFormat:@"  wrote proxy start ..."];
  }
  if (isok) isok = [self->io writeString:[_request uri]];
  
  if (isok) isok = [self->io writeString:@" "];
  if (isok) isok = [self->io writeString:[_request httpVersion]];
  if (isok) isok = [self->io writeString:@"\r\n"];

  /* set content-length header */
  
  if ([content length] > 0) {
    [_request setHeader:[NSString stringWithFormat:@"%d", [content length]]
              forKey:@"content-length"];
  }

  if ([[self->url scheme] hasPrefix:@"http"]) {
    /* host header */
    
    if (isok) isok = [self->io writeString:@"Host: "];
    if (isok) isok = [self->io writeString:[self hostName]];
    if (isok) isok = [self->io writeString:@"\r\n"];
    [self debugWithFormat:@"  wrote host header: %@", [self hostName]];
  }
  
  /* write request headers */

  if (isok) {
    NSEnumerator *fields;
    NSString *fieldName;
    int cnt;
    
    fields = [[_request headerKeys] objectEnumerator];
    cnt = 0;
    while (isok && (fieldName = [fields nextObject])) {
      NSEnumerator *values;
      id value;

      if ([fieldName length] == 4) {
	if ([fieldName isEqualToString:@"host"])
	  /* did already write host ... */
	  continue;
	if ([fieldName isEqualToString:@"Host"])
	  /* did already write host ... */
	  continue;
      }
      
      values = [[_request headersForKey:fieldName] objectEnumerator];
        
      while ((value = [values nextObject]) && isok) {
        if (isok) isok = [self->io writeString:fieldName];
        if (isok) isok = [self->io writeString:@": "];
        if (isok) isok = [self->io writeString:value];
        if (isok) isok = [self->io writeString:@"\r\n"];
        cnt++;
      }
    }
    [self debugWithFormat:@"  wrote %i request headers ...", cnt];
  }
  
  /* write some required headers */
  
  if ([_request headerForKey:@"accept"] == nil) {
    if (isok) isok = [self->io writeString:@"Accept: */*\r\n"];
    [self debugWithFormat:@"  wrote accept header ..."];
  }
  if ([_request headerForKey:@"user-agent"] == nil) {
    if (isok) {
      static NSString *s = nil;
      if (s == nil) {
	s = [[NSString alloc] initWithFormat:@"User-Agent: SOPE/%i.%i.%i\r\n",
			      SOPE_MAJOR_VERSION, SOPE_MINOR_VERSION, 
			      SOPE_SUBMINOR_VERSION];
      }
      isok = [self->io writeString:s];
    }
    [self debugWithFormat:@"  wrote user-agent header ..."];
  }
  
  /* write cookie headers */
  
  if ([[_request cookies] count] > 0 && isok) {
    NSEnumerator *cookies;
    WOCookie     *cookie;
    BOOL         isFirst;
    int cnt;
    
    [self->io writeString:@"set-cookie: "];
    cnt = 0;
    cookies = [[_request cookies] objectEnumerator];
    isFirst = YES;
    while (isok && (cookie = [cookies nextObject])) {
      if (isFirst) isFirst = NO;
      else if (isok) isok = [self->io writeString:@"; "];
      
      if (isok) isok = [self->io writeString:[cookie stringValue]];
      cnt ++;
    }
    if (isok) isok = [self->io writeString:@"\r\n"];
    [self debugWithFormat:@"  wrote %i cookies ...", cnt];
  }
  
  /* flush request header on socket */
  
  if (isok) isok = [self->io writeString:@"\r\n"];
  if (isok) isok = [self->io flush];
  [self debugWithFormat:@"  flushed HTTP header."];
  
  /* write content */

  if ([content length] > 0) {
    [self debugWithFormat:@"  writing HTTP entity (length=%i).", 
            [content length]];
    
    if ([content isKindOfClass:[NSString class]]) {
      if (isok) isok = [self->io writeString:(NSString *)content];
    }
    else if ([content isKindOfClass:[NSData class]]) {
      if (isok) isok = [[self->io source]
                         safeWriteBytes:[content bytes]
                         count:[content length]];
    }
    else {
      if (isok) isok = [self->io writeString:[content description]];
    }
    if (isok) isok = [self->io flush];
  }
  else if (doDebug) {
    [self debugWithFormat:@"  no HTTP entity to write ..."];
  }
  
  if (logStream)
    [self logRequest:_request data:[self->log writeLog]];
  [self->log resetWriteLog];
  
  [self debugWithFormat:@"=> finished:\n  url:  %@\n  sock: %@", 
          self->url, self->socket];
  if (!isok) {
    ASSIGN(self->lastException, [self->socket lastException]);
    [self->socket shutdown];
    return NO;
  }
  
  if (![self->socket isConnected])
    return NO;
  
  return YES;
}

- (NSException *)handleResponseParsingError:(NSException *)_exception {
    fprintf(stderr, "%s: caught: %s\n",
            __PRETTY_FUNCTION__,
            [[_exception description] cString]);
    return nil;
}

- (WOResponse *)readResponse {
  /* TODO: split up method */
  WOResponse *response;
  
  *(&response) = nil;
  
  if (self->socket == nil) {
    [self debugWithFormat:@"no socket available for reading response ..."];
    return nil;
  }
  
  [self debugWithFormat:@"parsing response from socket: %@", self->socket];
  
  if (useSimpleParser) {
    WOSimpleHTTPParser *parser;
    
    [self debugWithFormat:@"  using simple HTTP parser ..."];
    
    parser = [[WOSimpleHTTPParser alloc] initWithStream:[self->io source]];
    if (parser == nil)
      return nil;
    parser = [parser autorelease];
    
    if ((response = [parser parseResponse]) == nil) {
      if (doDebug)
        [self debugWithFormat:@"parsing failed: %@", [parser lastException]];
    }
  }
  else {
    NGHttpMessageParser *parser;
    NGHttpResponse *mresponse;
    NGMimeType     *ctype;
    id body;
    
    *(&mresponse) = nil;
    
    if ((parser = [[[NGHttpMessageParser alloc] init] autorelease]) == nil)
      return nil;
    
    [self debugWithFormat:@"  using MIME HTTP parser (complex parser) ..."];
    
    NS_DURING {
      [parser setDelegate:self];
      mresponse = [parser parseResponseFromStream:self->socket];
    }
    NS_HANDLER
      [[self handleResponseParsingError:localException] raise];
    NS_ENDHANDLER;
    
    [self debugWithFormat:@"finished parsing response: %@", mresponse];
    
    /* transform parsed MIME response to WOResponse */
    
    body = [mresponse body];
    if (body == nil) body = [NSData data];
    
    response = [[[WOResponse alloc] init] autorelease];
    [response setHTTPVersion:[mresponse httpVersion]];
    [response setStatus:[mresponse statusCode]];
    [response setUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:
                                          self,      @"NGHTTPConnection",
                                          mresponse, @"NGMimeResponse",
                                          body,      @"NGMimeBody",
                                          nil]];
  
    { /* check content-type */
      id value;
      
      value = [[mresponse valuesOfHeaderFieldWithName:@"content-type"] 
  	                nextObject];
      if (value) {
        NSString *charset;
        
        ctype = [NGMimeType mimeType:[value stringValue]];
        charset = [[ctype valueOfParameter:@"charset"] lowercaseString];
        
        if ([charset length] == 0) {
          /* autodetect charset ... */
          
          if ([[ctype type] isEqualToString:@"text"]) {
            if ([[ctype subType] isEqualToString:@"xml"]) {
              /* default XML encoding is UTF-8 */
              [response setContentEncoding:NSUTF8StringEncoding];
            }
          }
        }
        else {
          NSStringEncoding enc;
          
          enc = [NGMimeType stringEncodingForCharset:charset];
          [response setContentEncoding:enc];
        }
        
        [response setHeader:[ctype stringValue] forKey:@"content-type"];
        
      }
      else {
        ctype = [NGMimeType mimeType:@"application/octet-stream"];
      }
    }
  
    /* check content */
    
    if ([body isKindOfClass:[NSData class]]) {
      [response setContent:body];
    }
    else if ([body isKindOfClass:[NSString class]]) {
      NSData *data;
      
      data = [body dataUsingEncoding:[response contentEncoding]];
      if (data)
        [response setContent:data];
    }
    else if (body) {
      /* generate data from structured body .. */
      NGMimeBodyGenerator *gen;
      NSData *data;
      
      gen = [[[NGMimeBodyGenerator alloc] init] autorelease];
      data = [gen generateBodyOfPart:body
                  additionalHeaders:nil
                  delegate:self];
      [response setContent:data];
    }
    
    { /* transfer headers */
      NSEnumerator *names;
      NSString     *name;
      
      names = [mresponse headerFieldNames];
      while ((name = [names nextObject])) {
        NSEnumerator *values;
        id           value;
        
        if ([name isEqualToString:@"content-type"])
          continue;
        if ([name isEqualToString:@"set-cookie"])
          continue;
        
        values = [mresponse valuesOfHeaderFieldWithName:name];
        while ((value = [values nextObject])) {
          value = [value stringValue];
          [response appendHeader:value forKey:name];
        }
      }
    }
    
    { /* transfer cookies */
      NSEnumerator *cookies;
      NGHttpCookie *mcookie;
  
      cookies = [mresponse valuesOfHeaderFieldWithName:@"set-cookie"];
      
      while ((mcookie = [cookies nextObject])) {
        WOCookie *woCookie;
        
        if (![mcookie isKindOfClass:[NGHttpCookie class]]) {
          /* parse cookie */
          woCookie = [WOCookie cookieWithString:[mcookie stringValue]];
        }
        else {
          woCookie = [WOCookie cookieWithName:[mcookie cookieName]
                               value:[mcookie value]
                               path:[mcookie path]
                               domain:[mcookie domainName]
                               expires:[mcookie expireDate]
                               isSecure:[mcookie needsSecureChannel]];
        }
        if (woCookie == nil) {
          [self logWithFormat:
		  @"Couldn't create WOCookie from NGHttp cookie: %@",
                  mcookie];
          // could not create cookie
          continue;
        }
        
        [self debugWithFormat:@"adding cookie: %@", woCookie];
        
        [response addCookie:woCookie];
      }
    }
  }
  
  if (logStream)
    [self logResponse:response data:[self->log readLog]];
  [self->log resetReadLog];
  
  if (doDebug)
    [self debugWithFormat:@"processed response: %@", response];
  
  /* check keep-alive */
  {
    NSString *conn;
    
    conn = [response headerForKey:@"connection"];
    conn = [conn lowercaseString];
    
    if ([conn isEqualToString:@"close"]) {
      [self setKeepAliveEnabled:NO];
      [self _disconnect];
    }
    else if ([conn isEqualToString:@"keep-alive"]) {
      [self setKeepAliveEnabled:YES];
    }
    else {
      [self setKeepAliveEnabled:NO];
      [self _disconnect];
    }
  }
  
  return response;
}

- (void)setKeepAliveEnabled:(BOOL)_flag {
  self->keepAlive = _flag;
}
- (BOOL)keepAliveEnabled {
  return self->keepAlive;
}

/* timeouts */

- (void)setConnectTimeout:(int)_seconds {
  self->connectTimeout = _seconds;
}
- (int)connectTimeout {
  return self->connectTimeout;
}

- (void)setReceiveTimeout:(int)_seconds {
  self->receiveTimeout = _seconds;
}
- (int)receiveTimeout {
  return self->receiveTimeout;
}

- (void)setSendTimeout:(int)_seconds {
  self->sendTimeout = _seconds;
}
- (int)sendTimeout {
  return self->sendTimeout;
}

/* description */

- (NSString *)description {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:128];
  [str appendFormat:@"<%@[0x%p]:", NSStringFromClass([self class]), self];
  
  if (self->url)      [str appendFormat:@" url=%@", self->url];
  if (self->useProxy) [str appendString:@" proxy"];
  if (self->useSSL)   [str appendString:@" SSL"];

  if (self->socket) [str appendFormat:@" socket=%@", self->socket];
  
  [str appendString:@">"];
  return str;
}

@end /* WOHTTPConnection */

@implementation NSURL(SocketAddress)

- (id)socketAddressForURL {
  NSString *s;
  
  s = [self scheme];
  
  if ([s isEqualToString:@"http"]) {
    int p;
    
    s = [self host];
    if ([s length] == 0) s = @"localhost";
    p = [[self port] intValue];
    
    return [NGInternetSocketAddress addressWithPort:p == 0 ? 80 : p onHost:s];
  }
  else if ([s isEqualToString:@"https"]) {
    int p;
    
    s = [self host];
    if ([s length] == 0) s = @"localhost";
    p = [[self port] intValue];
    
    return [NGInternetSocketAddress addressWithPort:p == 0 ? 443 : p onHost:s];
  }
  else if ([s isEqualToString:@"unix"] || [s isEqualToString:@"file"]) {
    return [NGLocalSocketAddress addressWithPath:[self path]];
  }
  return nil;
}

- (BOOL)shouldUseWOProxyServer {
  if ([[self scheme] hasPrefix:@"http"]) {
    NSString *h;
    
    if ((h = [self host]) == nil)
      return NO;
    
    if ([h isEqualToString:@"127.0.0.1"])
      return NO;
    if ([h isEqualToString:@"localhost"])
      return NO;
    
    if ([[WOHTTPConnection proxyServer] length] > 0) {
      NSEnumerator *e;
      NSString *suffix;
      BOOL     useProxy;
      
      useProxy = YES;
      e = [[WOHTTPConnection noProxySuffixes] objectEnumerator];
      while ((suffix = [e nextObject])) {
        if ([h hasSuffix:suffix]) {
          useProxy = NO;
          break;
        }
      }
      return useProxy;
    }
  }
  return NO;
}

@end /* NSURL(SocketAddress) */
