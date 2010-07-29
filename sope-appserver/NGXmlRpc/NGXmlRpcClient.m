/*
  Copyright (C) 2000-2007 SKYRIX Software AG
  Copyright (C) 2007      Helge Hess

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

#include "NGXmlRpcClient.h"
#include "common.h"
#include <XmlRpc/XmlRpcMethodCall.h>
#include <XmlRpc/XmlRpcMethodResponse.h>
#include <NGObjWeb/WOHTTPConnection.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WORequest.h>
#include <NGStreams/NGBufferedStream.h>
#include <NGStreams/NGActiveSocket.h>
#include <NGStreams/NGStreamExceptions.h>

@interface NSString(DigestInfo)
- (NSDictionary *)parseHTTPDigestInfo;
@end

@implementation NGXmlRpcClient

+ (int)version {
  return 2;
}

- (Class)connectionClass {
  return [WOHTTPConnection class];
}
- (Class)requestClass {
  return [WORequest class];
}

- (id)initWithHost:(NSString *)_h uri:(NSString *)_u port:(unsigned int)_port {
  if ((self = [super init])) {
    self->httpConnection = 
      [[[self connectionClass] alloc] initWithHost:_h onPort:_port];
    self->uri = [_u copy];
  }
  return self;
}

- (id)initWithHost:(NSString *)_host   // e.g. @"inster.in.skyrix.com"
  uri:(NSString *)_uri    // e.g. @"skyxmlrpc.woa/xmlrpc"
  port:(unsigned int)_port // e.g. 20000
  userName:(NSString *)_userName
  password:(NSString *)_password
{
  if ((self = [self initWithHost:_host uri:_uri port:_port])) {
    self->userName = [_userName copy];
    self->password = [_password copy];
  }
  return self;
}
- (id)initWithURL:(id)_url {
  NSURL *url;
  
  url = [_url isKindOfClass:[NSURL class]]
    ? _url
    : [NSURL URLWithString:[_url stringValue]];
  if (url == nil) {
    [self release];
    return nil;
  }

  if ((self = [super init])) {
    self->httpConnection =
      [(WOHTTPConnection *)[[self connectionClass] alloc] initWithURL:url];
    
    if ([[url scheme] hasPrefix:@"http"])
      self->uri = [[url path] copy];
    else
      /* hack for easier XMLRPC-over-Unix-Domain-sockets */
      self->uri = @"/RPC2";
    self->userName = [[url user]     copy];
    self->password = [[url password] copy];
  }
  return self;
}
- (id)initWithURL:(id)_url login:(NSString *)_login password:(NSString *)_pwd {
  if ((self = [self initWithURL:_url])) {
    if (_login) [self setUserName:_login];
    if (_pwd)   [self setPassword:_pwd];
  }
  return self;
}

- (id)initWithRawAddress:(id)_address {
  if (_address == nil) {
    [self release];
    return nil;
  }
  if ((self = [super init])) {
    self->address = [_address retain];
  }
  return self;
}

- (void)dealloc {
  [self->additionalHeaders release];
  [self->address        release];
  [self->httpConnection release];
  [self->userName       release];
  [self->password       release];
  [self->uri            release];
  [super dealloc];
}

/* accessors */

- (NSURL *)url {
  NSString *p;
  NSURL    *url;
  
  // TODO: not final yet ... (hh asks: bjoern, is this used anywhere anyway ?)
  p = [[NSString alloc] initWithFormat:@"http://%@:%i%@",
                  @"localhost",
                  80,
                  self->uri];
  url = [NSURL URLWithString:p];
  [p release];
  return url;
}

- (void)setUserName:(NSString *)_userName {
  ASSIGNCOPY(self->userName, _userName);
}
- (NSString *)userName {
  return self->userName;
}
- (NSString *)login {
  return self->userName;
}

- (void)setPassword:(NSString *)_password {
  ASSIGNCOPY(self->password, _password);
}
- (NSString *)password {
  return self->password;
}

- (void)setUri:(NSString *)_uri {
  ASSIGNCOPY(self->uri, _uri);
}
- (NSString *)uri {
  return self->uri;
}

- (void)setAdditionalHeaders:(NSDictionary *)_headers {
  ASSIGNCOPY(self->additionalHeaders, _headers);
}
- (NSDictionary *)additionalHeaders {
  return self->additionalHeaders;
}

/* performing the method */

- (id)invokeMethodNamed:(NSString *)_methodName {
  return [self invokeMethodNamed:_methodName parameters:nil];
}

- (id)invokeMethodNamed:(NSString *)_methodName withParameter:(id)_param {
  NSArray *params = nil;

  if (_param)
    params = [NSArray arrayWithObject:_param];
                
  return [self invokeMethodNamed:_methodName parameters:params];
}

- (id)invoke:(NSString *)_methodName params:(id)firstObj,... {
  id array, obj, *objects;
  va_list list;
  unsigned int count;
  
  va_start(list, firstObj);
  for (count = 0, obj = firstObj; obj; obj = va_arg(list,id))
    count++;
  va_end(list);
  
  objects = calloc(count, sizeof(id));
  {
    va_start(list, firstObj);
    for (count = 0, obj = firstObj; obj; obj = va_arg(list,id))
      objects[count++] = obj;
    va_end(list);

    array = [NSArray arrayWithObjects:objects count:count];
  }
  free(objects);
  
  return [self invokeMethodNamed:_methodName parameters:array];
}

- (id)call:(NSString *)_methodName,... {
  id array, obj, *objects;
  va_list list;
  unsigned int count;
  
  va_start(list, _methodName);
  for (count = 0, obj = va_arg(list, id); obj; obj = va_arg(list,id))
    count++;
  va_end(list);
  
  objects = calloc(count, sizeof(id));
  {
    va_start(list, _methodName);
    for (count = 0, obj = va_arg(list, id); obj; obj = va_arg(list,id))
      objects[count++] = obj;
    va_end(list);
    
    array = [NSArray arrayWithObjects:objects count:count];
  }
  free(objects);
  return [self invokeMethodNamed:_methodName parameters:array];
}

- (NSString *)_authorization {
  NSString *tmp = nil;
  
  if (self->userName == nil)
    return nil;
  
  if (self->digestInfo) {
    [self logWithFormat:@"need to construct digest authentication using %@", 
	    self->digestInfo];
    return nil;
  }

  tmp = @"";
  tmp = [tmp stringByAppendingString:self->userName];
  tmp = [tmp stringByAppendingString:@":"];
  
  if (self->password)
    tmp = [tmp stringByAppendingString:self->password];
  
  if (tmp != nil) {
    tmp = [tmp stringByEncodingBase64];
    tmp = [@"Basic " stringByAppendingString:tmp];
  }
  return tmp;
}

- (id)sendFailed:(NSException *)e {
  if (e)
    return e;
  else {
    return [NSException exceptionWithName:@"XmlRpcSendFailed"
                        reason:
                          @"unknown reason, no exception set in "
                          @"http-connection"
                        userInfo:nil];
  }
}

- (id)callFailed:(WOResponse *)_response {
  NSException  *exc;
  NSString     *r;
  NSDictionary *ui;
  int          status;
  
#if 0
  NSLog(@"%s: XML-RPC response status: %i", __PRETTY_FUNCTION__,
        [_response status]);
#endif
  
  /* construct exception */
  
  status = [_response status];
  r = [NSString stringWithFormat:@"call failed with HTTP status code %i",
		  status];
  if (status == 301 || status == 302) {
    NSString *l = [_response headerForKey:@"location"];
    if ([l isNotEmpty])
      r = [NSString stringWithFormat:@"%@ [location=%@]", r, l];
  }
  
  ui = [NSDictionary dictionaryWithObjectsAndKeys:
                       self,      @"NGXmlRpcClient",
                       _response, @"WOResponse",
                       [NSNumber numberWithInt:status],
                       @"HTTPStatusCode",
                       nil];
  
  exc = [NSException exceptionWithName:@"XmlRpcCallFailed"
                     reason:r
                     userInfo:ui];
  return exc;
}
- (id)invalidXmlRpcResponse:(WOResponse *)_response {
  return [NSException exceptionWithName:@"XmlRpcCallFailed"
                      reason:@"got malformed XML-RPC response?!"
                      userInfo:nil];
}

- (id)processHTMLResponse:(WOResponse *)_response {
  NSDictionary *ui;
  
  if (_response == nil) return nil;
  [self debugWithFormat:@"Note: got HTML response: %@", _response];

  ui = [NSDictionary dictionaryWithObjectsAndKeys:
		       _response, @"response",
		     nil];
  return [NSException exceptionWithName:@"XmlRpcCallFailed"
		      reason:@"got HTML response"
		      userInfo:ui];
}

- (id)doCallViaHTTP:(XmlRpcMethodCall *)_call {
  XmlRpcMethodResponse *methodResponse;
  WOResponse           *response;
  WORequest            *request;
  NSString             *authorization, *ctype;

  request = [[[self requestClass] alloc] initWithMethod:@"POST"
                               uri:self->uri
                               httpVersion:@"HTTP/1.0"
                               headers:self->additionalHeaders
                               content:nil
                               userInfo:nil];
  [request setHeader:@"text/xml" forKey:@"content-type"];
  [request setContentEncoding:NSUTF8StringEncoding];
  [request appendContentString:[_call xmlRpcString]];
  request = [request autorelease];
  
  if ((authorization = [self _authorization]) != nil)
    [request setHeader:authorization forKey:@"Authorization"];
  
  if (![self->httpConnection sendRequest:request])
    return [self sendFailed:[self->httpConnection lastException]];
  
  response = [self->httpConnection readResponse];
  
  [self->digestInfo release]; self->digestInfo = nil;
  
  if ([response status] != 200) {
    if ([response status] == 401 /* authentication required */) {
      /* process info required for digest authentication */
      NSString *wwwauth;
      
      wwwauth = [response headerForKey:@"www-authenticate"];
      if ([[wwwauth lowercaseString] hasPrefix:@"digest"]) {
        self->digestInfo = [[wwwauth parseHTTPDigestInfo] retain];
        //[self debugWithFormat:@"got HTTP digest info: %@", self->digestInfo];
      }
    }
    
    return [self callFailed:response];
  }

  if ((ctype = [response headerForKey:@"content-type"]) == nil)
    ctype = @"text/xml"; // TODO, does it make sense? For simplistic servers?
  
  if ([ctype hasPrefix:@"text/html"])
    return [self processHTMLResponse:response];
  
  methodResponse = 
    [[XmlRpcMethodResponse alloc] initWithXmlRpcString:
        [response contentAsString]];
  if (methodResponse == nil)
    return [self invalidXmlRpcResponse:response];
  
  return [methodResponse autorelease];
}

- (id)doRawCall:(XmlRpcMethodCall *)_call {
  XmlRpcMethodResponse *methodResponse;
  NGActiveSocket   *socket;
  NGBufferedStream *io;
  NSString *s;
  NSData   *rq;

  /* get body for XML-RPC request */
  
  if ((s = [_call xmlRpcString]) == nil)
    return nil;
  if ((rq = [s dataUsingEncoding:NSUTF8StringEncoding]) == nil)
    return nil;
  
  /* connect */
  
  // TODO: add timeout values
  socket = [NGActiveSocket socketConnectedToAddress:self->address];
  if (socket == nil) {
    [self logWithFormat:@"could not connect %@", self->address];
    return [self sendFailed:nil];
  }
  io = [NGBufferedStream filterWithSource:socket bufferSize:4096];
  
  /* write body + \r\n\r\n */
  
  if (![io writeData:rq])
    return [self sendFailed:[io lastException]];
  if (![io safeWriteBytes:"\r\n\r\n" count:4])
    return [self sendFailed:[io lastException]];
  if (![io flush])
    return [self sendFailed:[io lastException]];
  
  /* read response */
  
  {
    NSMutableData *data;
    NSString *s;
    
    data = [NSMutableData dataWithCapacity:1024];
    do {
      unsigned readCount;
      unsigned char buf[1024 + 10];
      
      readCount = [io readBytes:&buf count:1024];
      if (readCount == NGStreamError) {
	NSException *e;
	
	if ((e = [io lastException]) == nil)
	  break;
	else if ([e isKindOfClass:[NGEndOfStreamException class]])
	  break;
	else
	  /* an error */
	  return [self sendFailed:e];
      }
      buf[readCount] = '\0';
      
      [data appendBytes:buf length:readCount];
    }
    while (YES);
    
    s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    methodResponse = [[XmlRpcMethodResponse alloc] initWithXmlRpcString:s];
    [s release];
  }
  
  [io close];
  
  return [methodResponse autorelease];
}

- (id)invokeMethodNamed:(NSString *)_methodName parameters:(NSArray *)_params {
  XmlRpcMethodCall *methodCall;
  id result;
  
  methodCall = [[XmlRpcMethodCall alloc] initWithMethodName:_methodName
                                         parameters:_params];
  
  if (self->httpConnection)
    result = [self doCallViaHTTP:methodCall];
  else
    result = [self doRawCall:methodCall];
  
  [methodCall release]; methodCall = nil;
  
  if ([result isKindOfClass:[XmlRpcMethodResponse class]])
    result = [result result];
  
  if (result == nil)
    [self logWithFormat:@"got nil value from XML-RPC ..."];
  return result;
}

@end /* NGXmlRpcClient */

@implementation NSString(DigestInfo)

- (NSDictionary *)parseHTTPDigestInfo {
  /*
    eg: 
      www-authenticate: Digest realm="RCD", \
        nonce="1572920321042107679", \
	qop="auth,auth-int", \
	algorithm="MD5,MD5-sess"
  */
  NSMutableDictionary *md;
  NSEnumerator *parts;
  NSString *part;
  
  md = [NSMutableDictionary dictionaryWithCapacity:8];
  
  /* 
     TODO: fix this parser, it only works if the components of the header
     value are separated using ", " and the component *values* are separated
     by a "," (not followed by a space).
     Works with rcd, probably with nothing else ...
  */
  parts = [[self componentsSeparatedByString:@", "] objectEnumerator];
  
  while ((part = [parts nextObject])) {
    NSRange  r;
    NSString *key, *value;
    
    r = [part rangeOfString:@"="];
    if (r.length == 0) continue;
    
    key   = [[part substringToIndex:r.location] stringByTrimmingSpaces];
    value = [[part substringFromIndex:(r.location + r.length)] 
	           stringByTrimmingSpaces];

    //[self logWithFormat:@"key '%@' value '%@'", key, value];
    
    if ([value hasPrefix:@"\""] && [value hasSuffix:@"\""]) {
      r.location = 1;
      r.length   = [value length] - 2;
      value = [value substringWithRange:r];
    }
    //[self logWithFormat:@"key '%@' value '%@'", key, value];
    
    [md setObject:value forKey:[key lowercaseString]];
  }
  return md;
}

@end /* NSString(DigestInfo) */
