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

#import "common.h"
#import "NGHttpMessageParser.h"
#import "NGHttpMessage.h"
#import "NGHttpRequest.h"
#import "NGHttpResponse.h"
#import "NGHttpHeaderFieldParser.h"
#import "NGHttpBodyParser.h"

static inline void NGAddChar(NSMutableData *_data, int c) {
  unsigned char c8 = c;
  static Class lastClass = Nil; // THREAD
  static void  (*addBytes)(id,SEL,void*,unsigned) = NULL;
  if (_data == nil) return;
  
  if (*(Class *)_data != lastClass) {
    lastClass  = *(Class *)_data;
    addBytes = (void*)[_data methodForSelector:@selector(appendBytes:length:)];
  }
  
  if (addBytes)
    addBytes(_data, @selector(appendBytes:length:), &c8, 1);
  else
    [_data appendBytes:&c8 length:1];
}

@implementation NGHttpMessageParser

+ (int)version {
  return [super version] + 0 /* v3 */;
}

static NGMimeType           *wwwFormUrlEncoded = nil;
static NGMimeType           *multipartFormData = nil;
static id<NGMimeBodyParser> wwwFormUrlParser   = nil;
static id<NGMimeBodyParser> multipartFormDataParser = nil;

+ (void)initialize {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;

    NSAssert2([super version] == 3,
	      @"invalid superclass (%@) version %i !",
	      NSStringFromClass([self superclass]), [super version]);
    
    wwwFormUrlEncoded = 
      [[NGMimeType mimeType:@"application/x-www-form-urlencoded"] retain];
    multipartFormData = [[NGMimeType mimeType:@"multipart/form-data"] retain];
    
    wwwFormUrlParser = [[NGFormUrlBodyParser alloc] init];
    multipartFormDataParser = [[NGHttpMultipartFormDataBodyParser alloc] init];
  }
}

static inline int _readByte(NGHttpMessageParser *self) {
  return self->readByte
    ? self->readByte(self->source, @selector(readByte))
    : [self->source readByte];
}

static inline int _skipLWSP(NGHttpMessageParser *self, int _c) {
  int c = _c;
  while ((c == 32) || (c == '\t'))
    c = _readByte(self);
  return c;
}

/* init */

- (id)init {
  if ((self = [super init])) {
    self->useContentLength = YES;
  }
  return self;
}

- (void)dealloc {
  [self->reason     release];
  [self->methodName release];
  [self->uri     release];
  [self->version release];
  [super dealloc];
}

// accessors

- (void)setDelegate:(id)_delegate {
  [super setDelegate:_delegate];
  
  self->httpDelegateRespondsTo.httpParserWillParseRequest
    = [self->delegate respondsToSelector:@selector(httpParserWillParseRequest:)];
  self->httpDelegateRespondsTo.httpParserWillParseResponse
    = [self->delegate respondsToSelector:@selector(httpParserWillParseResponse:)];

  self->httpDelegateRespondsTo.httpParserDidParseRequest
    = [self->delegate respondsToSelector:@selector(httpParser:didParseRequest:)];
  self->httpDelegateRespondsTo.httpParserDidParseResponse
    = [self->delegate respondsToSelector:@selector(httpParser:didParseResponse:)];
}

/* headers */

- (id<NGMimeHeaderFieldParser>)parserForHeaderField:(NSString *)_name {
  //NSLog(@"asked for header field parser of %@", _name);
#if 1
  //#warning does not use header field parsers by default ...
  return nil;
#else
  return [NGMimeHeaderFieldParserSet defaultHttpHeaderFieldParserSet];
#endif
}

// preparation

- (BOOL)prepareForParsingFromStream:(id<NGStream>)_stream {
  if ([super prepareForParsingFromStream:_stream]) {
    if (self->methodName) {
      [self->methodName release]; self->methodName = nil;
    }
    if (self->uri) {
      [self->uri release]; self->uri = nil;
    }
    if (self->version) {
      [self->version release]; self->version = nil;
    }
    
    return YES;
  }
  return NO;
}
- (void)finishParsingOfPart:(id<NGMimePart>)_part {
  [self->methodName release]; self->methodName = nil;
}

// parse request/response line

- (BOOL)parseRequestLine {
  int c;
  
#if DEBUG
  NSAssert1(self->source, @"missing source %@ !", self);
#endif
  
  /* ignore prefix CRLF's, as described in RFC (HTTP/1.1, section 4.1) */
  do {
    c = _readByte(self);
  }
  while ((c == 13) || (c == 10));
  if (c == -1) /* unexpected EOF */
    return NO;

#if 1
  /* parse the request method */
  {
    char buf[16];
    int  i = 0;
    
    do {
      buf[i] = c; // one char is already present ..
      c = _readByte(self);
      i++;
    }
    while ((c != 32) && (c != '\r') && (c != '\n') && (c != -1) && (i < 15));
    buf[i] = '\0';
    
    if (c == -1) // unexpected EOF
      return NO;

    if (i >= 15) {
      [self warnWithFormat:@"truncated request method "
            @"(may not longer than 15 chars): %s", buf];
    }

    self->methodName = [[NSString alloc] initWithCString:buf length:i];
  }
  
  c = _skipLWSP(self, c);
  if (c == -1) { // unexpected EOF
    RELEASE(self->methodName); self->methodName = nil;
    return NO;
  }
  
  /* read data till end of line ... */
  {
    NSMutableData *data = nil;
    unsigned char *bytes, *tmp;
    unsigned len;
    
    data = [[NSMutableData alloc] initWithCapacity:256];
    do {
      NGAddChar(data, c); /* one char is in queue ... */
      c = _readByte(self);
    }
    while ((c != 13) && (c != 10) && (c != -1));
    NGAddChar(data, 0);
    
    if (c == -1) { /* unexpected EOF */
      [data             release]; data = nil;
      [self->methodName release]; self->methodName = nil;
      return NO;
    }
    
    if (c == 13) { /* if CR */
      c = _readByte(self); /* read LF */
      
      if ((c != 10) && (c != -1)) {
        [self warnWithFormat:@"%s: missed LF after CR (got %i)\n",
              __PRETTY_FUNCTION__, c];
      }
    }
    
    bytes = [data mutableBytes];
    
    /* strip trailing spaces ... */
    len = strlen((char *)bytes);
    while (len > 0) {
      if (bytes[len - 1] != 32) break;
      len--;
      bytes[len] = '\0';
    }
    
    if ((tmp = (unsigned char *)rindex((char *)bytes, 32))) {
      unsigned char *t2;
      
      if ((t2 = (unsigned char *)strstr((char *)tmp, "HTTP"))) {
        /* has a HTTP version spec ... */
        
        *tmp = '\0';
        tmp++;
        self->version = [[NSString alloc] initWithCString:(char *)tmp];
        
        /* strip trailing spaces ... */
        len = strlen((char *)bytes);
        while (len > 0) {
          if (bytes[len - 1] != 32) break;
          len--;
          bytes[len] = '\0';
        }
      }
      else {
        /* has no HTTP version spec, but possibly trailing spaces */
        
        /* strip trailing spaces ... */
        len = strlen((char *)bytes);
        while (len > 0) {
          if (bytes[len - 1] != 32) break;
          len--;
          bytes[len] = '\0';
        }
      }
    }
    else {
      /* has no HTTP version spec */
    }
    self->uri = [[NSString alloc] initWithCString:(char *)bytes];
    
    [data release]; data = nil;
  }

#if 0
  [self logWithFormat:@"parsed request line: %@ uri=%@",
	  self->methodName, self->uri];
#endif
#else
  /* now start processing request line (one char is already present) .. */
  
  { /* process method */
    char buf[16];
    int  i = 0;

    do {
      buf[i] = c; // one char is already present ..
      c = _readByte(self);
      i++;
    }
    while ((c != 32) && (c != '\r') && (c != '\n') && (c != -1) && (i < 15));
    buf[i] = '\0';
    
    if (c == -1) // unexpected EOF
      return NO;

    if (i >= 15) {
      [self warnWithFormat:@"truncated request method "
            @"(may not longer than 15 chars): %s",
            buf];
    }

    self->methodName = [[NSString alloc] initWithCString:buf length:i];
  }
  
  c = _skipLWSP(self, c);
  if (c == -1) { // unexpected EOF
    RELEASE(self->methodName); self->methodName = nil;
    return NO;
  }

  { /* process path */
    NSMutableData *data = nil;
    
    data = [[NSMutableData allocWithZone:NULL] initWithCapacity:256];
    do {
      NGAddChar(data, c);
      c = _readByte(self);
    }
    while ((c != 32) && (c != '\r') && (c != '\n') && (c != -1));
    if (c == -1) { // unexpected EOF
      RELEASE(data); data = nil;
      RELEASE(self->methodName); self->methodName = nil;
      return NO;
    }

    self->uri = [[NSString allocWithZone:NULL]
                           initWithCString:[data bytes] length:[data length]];
    RELEASE(data); data = nil;
  }

  c = _skipLWSP(self, c);
  if (c == -1) { // unexpected EOF
    RELEASE(self->methodName); self->methodName = nil;
    RELEASE(self->uri);        self->uri        = nil;
    return NO;
  }
  
  if ((c == 13) || (c == 10)) { // no HTTP version was provided, using HTTP/0.9
    if (c == 13) // if CR
      c = _readByte(self); // read LF

    if (c != 10)
      [self warnWithFormat:@"expected LF after CR in request line, got %i", c];

    self->version = @"HTTP/0.9";
  }
  else { /* HTTP version next .. */
    char buf[16];
    int  i = 0;

    do {
      buf[i] = c; // one char is already present ..
      c = _readByte(self);
      i++;
    }
    while ((c != 13) && (c != 10) && (c != 32) && (c != '\t') &&
           (c != -1) && (i < 15));
    buf[i] = '\0';
    
    if (c == -1) { // unexpected EOF
      RELEASE(self->methodName); self->methodName = nil;
      RELEASE(self->uri);        self->uri        = nil;
      return NO;
    }

    if (i >= 15) {
      [self warnWithFormat:@"truncated protocol version "
            @"(may not be longer than 15 chars): %s", buf];
    }

    self->version =
      [[NSString allocWithZone:NULL] initWithCString:buf length:i];

    /* and now read all remaining chars (spaces and CRLF..) */
    while ((c != 10) && (c != -1))
      c = _readByte(self);

    if (c == -1) { // unexpected EOF
      RELEASE(self->methodName); self->methodName = nil;
      RELEASE(self->uri);        self->uri        = nil;
      RELEASE(self->version);    self->version    = nil;
      return NO;
    }
  }
#endif
  return YES;
}

- (BOOL)parseStatusLine {
  int c;

#if DEBUG
  NSAssert1(self->source, @"missing source %@ !", self);
#endif

  /* ignore prefix CRLF's, as described in RFC (HTTP/1.1, section 4.1) */
  do {
    c = _readByte(self);
  }
  while ((c == 13) || (c == 10));
  if (c == -1) // unexpected EOF
    return NO;
  
  /* now start processing response line (one char is already present) .. */

  { /* process HTTP version */
    char buf[16];
    int  i = 0;
    
    do {
      buf[i] = c; // one char is already present ..
      c = _readByte(self);
      i++;
    }
    while ((c != 32) && (c != '\r') && (c != '\n') && (c != -1) && (i < 15));
    buf[i] = '\0';
    
    if (c == -1) // unexpected EOF
      return NO;
    
    if (i >= 15) {
      [self warnWithFormat:@"truncated response version "
            @"(may not longer than 15 chars): %s",
            buf];
    }
    
    self->version = [[NSString alloc] initWithCString:buf length:i];
  }

  c = _skipLWSP(self, c);
  if (c == -1) { // unexpected EOF
    RELEASE(self->methodName); self->methodName = nil;
    return NO;
  }

  { /* process HTTP status */
    char buf[5];
    int  i = 0;
    
    do {
      buf[i] = c; // one char is already present ..
      c = _readByte(self);
      i++;
    }
    while ((c != 32) && (c != '\r') && (c != '\n') && (c != -1) && (i < 5));
    buf[i] = '\0';
    
    if (c == -1) // unexpected EOF
      return NO;
    
    if (i >= 5) {
      [self warnWithFormat:@"truncated response status "
              @"(may not longer than 3 chars): %s",
              buf];
    }

    self->status = atoi(buf);
  }
  
  if ((c = _skipLWSP(self, c)) == -1) { // unexpected EOF
    RELEASE(self->methodName); self->methodName = nil;
    RELEASE(self->uri);        self->uri        = nil;
    return NO;
  }
  
  if ((c == 13) || (c == 10)) { // no HTTP reason was provided
    if (c == 13) // if CR
      c = _readByte(self); // read LF

    if (c != 10)
      [self warnWithFormat:@"expected LF after CR in request line, got %i", c];
  }
  else { // HTTP reason text next
    // to be done ..
    
    // and now read all remaining chars (spaces and CRLF..)
    while ((c != 10) && (c != -1))
      c = _readByte(self);

    if (c == -1) { // unexpected EOF
      RELEASE(self->reason);  self->reason  = nil;
      RELEASE(self->version); self->version = nil;
      return NO;
    }
  }
  
  return YES;
}

- (BOOL)parseStartLine {
  return (self->flags.parseRequest)
    ? [self parseRequestLine]
    : [self parseStatusLine];
}

- (BOOL)parsePrefix {
  if ([super parsePrefix])
    return [self parseStartLine];
  else
    return NO;
}

- (id<NGMimeBodyParser>)parserForBodyOfPart:(id<NGMimePart>)_part
  data:(NSData *)_dt
{
  NGMimeType *contentType;
  
  contentType = [_part contentType];
  
#if 0
  NSLog(@"%s: was asked for parser for type %@ (data with len %d) ..",
        __PRETTY_FUNCTION__, contentType, [_dt length]);
#endif
  
  if ([contentType hasSameType:wwwFormUrlEncoded])
    return (NGMimeBodyParser *)wwwFormUrlParser;
  
  return (NGMimeBodyParser *)[super parserForBodyOfPart:_part data:_dt];
}

- (void)parseBodyOfPart:(id<NGMimePart>)_part {
  BOOL doParse, hasCLenHeader;
  id   clenValues;
  
  if (_part == nil) {
    [self warnWithFormat:@"%s:%i: got no part!", __PRETTY_FUNCTION__,__LINE__];
    return;
  }
  
  /* parse only if content-length > 0 */
  clenValues = [_part valuesOfHeaderFieldWithName:@"content-length"];
  hasCLenHeader = clenValues ? YES : NO;
  if ((clenValues = [clenValues nextObject])) {
    if ([(id)_part contentLength] > 0)
      doParse = YES;
    else {
      //NSLog(@"%s: does not parse body, clen is 0", __PRETTY_FUNCTION__);
      doParse = NO;
    }
  }
  else {
    /* parse until EOF */
#if 0
    [self warnWithFormat:@"%s: parsing until EOF, "
          @"missed content-length header in part %@..",
          __PRETTY_FUNCTION__, _part];
#endif
    doParse = YES;
  }
  
  if (self->flags.parseRequest) {
    NGHttpRequest *rq;
    
    rq = (NGHttpRequest *)_part;
#if DEBUG
    if (![rq isKindOfClass:[NGHttpRequest class]]) {
      [self errorWithFormat:@"%s:%i: got invalid part for request parsing !",
	    __PRETTY_FUNCTION__, __LINE__];
    }
#endif
    
    switch ([rq method]) {
      case NGHttpMethod_GET:
      case NGHttpMethod_OPTIONS:
      case NGHttpMethod_HEAD:
      case NGHttpMethod_DELETE:
      case NGHttpMethod_UNLOCK:
        /* never parse body of the requests above */
        if ([rq contentLength] > 0) {
	  [self warnWithFormat:
		  @"expected no content with this method !"];
	}
	doParse = NO;
        break;
        
      case NGHttpMethod_POST:
      case NGHttpMethod_PUT:
      default:
	if (doParse && ([rq contentLength] == 0)) {
	  /*
	    Two cases: 
	      HTTP/1.0, HTTP/0.9 - read till EOF if no content-length is set
	      HTTP/1.1 and above: if no content-length is set, body is empty
	  */
	  if ([rq majorVersion] < 1)
	    doParse = YES;
	  else if ([rq majorVersion] == 1 && [rq minorVersion] == 0)
	    doParse = YES;
	  else
	    doParse = NO;
	}
        break;
    }
    
    if (doParse)
      [super parseBodyOfPart:_part];
  }
  else {
#if DEBUG
    NSAssert([_part isKindOfClass:[NGHttpResponse class]],
             @"part should be a response ..");
#endif
    
    doParse = YES;
    
    if (doParse)
      [super parseBodyOfPart:_part];
  }
}

/* part parsing */

- (NGHttpRequest *)produceRequestWithMethodName:(NSString *)_method
  uri:(NSString *)_uri version:(NSString *)_version
  header:(NGHashMap *)_header
{
  NGHttpRequest *request = nil;

  request = [[NGHttpRequest allocWithZone:NULL]
                            initWithMethod:_method
                            uri:_uri
                            header:_header
                            version:_version];
  return AUTORELEASE(request);
}

- (NGHttpResponse *)produceResponseWithStatusCode:(int)_code
  statusText:(NSString *)_text version:(NSString *)_version
  header:(NGHashMap *)_header
{
  NGHttpResponse *response = nil;
  
  response = [[NGHttpResponse allocWithZone:NULL]
                              initWithStatus:_code
                              reason:_text
                              header:_header
                              version:_version];
  return AUTORELEASE(response);
}

- (id<NGMimePart>)producePartWithHeader:(NGHashMap *)_header {
  // NSLog(@"producing part with header: %@", _header);
  
  if (self->flags.parseRequest) {
    NGHttpRequest *request = nil;

    request = [self produceRequestWithMethodName:self->methodName
                    uri:self->uri
                    version:self->version
                    header:_header];
    
    RELEASE(self->methodName); self->methodName = nil;
    RELEASE(self->uri);        self->uri        = nil;
    RELEASE(self->version);    self->version    = nil;

    return request;
  }
  else {
    NGHttpResponse *response = nil;

    response = [self produceResponseWithStatusCode:self->status
                     statusText:self->reason
                     version:self->version
                     header:_header];
    
    RELEASE(self->version); self->version = nil;
    
    return response;
  }
}

- (NGHttpRequest *)parseRequestFromStream:(id<NGStream>)_stream {
  NGHttpRequest *request = nil;

#if DEBUG
  NSAssert1(_stream, @"missing stream %@ ..", _stream);
#endif
  
  self->flags.parseRequest = YES;

  if (self->httpDelegateRespondsTo.httpParserWillParseRequest) {
    if ([self->delegate httpParserWillParseRequest:self] == NO) {
      // parsing aborted
      return nil;
    }
  }

  //NSLog(@"%s: parse part from stream ..", __PRETTY_FUNCTION__);
  request = (NGHttpRequest *)[self parsePartFromStream:_stream];

  if (request) {
    if (self->httpDelegateRespondsTo.httpParserDidParseRequest)
      [self->delegate httpParser:self didParseRequest:request];
  }
  return request;
}

- (NGHttpResponse *)parseResponseFromStream:(id<NGStream>)_stream {
  NGHttpResponse *response = nil;
  
#if DEBUG
  NSAssert1(_stream, @"missing stream %@ ..", _stream);
#endif
  
  self->flags.parseRequest = NO;

  if (self->httpDelegateRespondsTo.httpParserWillParseResponse) {
    if ([self->delegate httpParserWillParseResponse:self] == NO) {
      // parsing aborted
      return nil;
    }
  }
  
  response = (NGHttpResponse *)[self parsePartFromStream:_stream];

  if (response) {
    if (self->httpDelegateRespondsTo.httpParserDidParseResponse)
      [self->delegate httpParser:self didParseResponse:response];
  }
  return response;
}

#if 0
- (id<NGMimePart>)parsePartFromStream:(id<NGByteSequenceStream>)_stream {
  NSLog(@"do not use parsePartFromStream: with NGHttpMessageParser !");
  abort();
  return nil;
}
#endif

@end /* NGHttpMessageParser */
