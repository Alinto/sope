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

#include "WOSimpleHTTPParser.h"
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WORequest.h>
#include <NGMime/NGMimeType.h>
#include "common.h"
#include <string.h>

@implementation WOSimpleHTTPParser

static Class NSStringClass  = Nil;
static BOOL  debugOn        = NO;
static BOOL  heavyDebugOn   = NO;
static int   fileIOBoundary = 0;
static int   maxUploadSize  = 0;

+ (int)version {
  return 1;
}
+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  debugOn        = [ud boolForKey:@"WOSimpleHTTPParserDebugEnabled"];
  heavyDebugOn   = [ud boolForKey:@"WOSimpleHTTPParserHeavyDebugEnabled"];
  fileIOBoundary = [ud integerForKey:@"WOSimpleHTTPParserFileIOBoundary"];
  maxUploadSize  = [ud integerForKey:@"WOSimpleHTTPParserMaxUploadSizeInKB"];
  
  if (maxUploadSize == 0)
    maxUploadSize = 256 * 1024; /* 256MB */
  if (fileIOBoundary == 0)
    fileIOBoundary = 16384;
  
  if (debugOn) {
    NSLog(@"WOSimpleHTTPParser: max-upload-size:  %dKB", maxUploadSize);
    NSLog(@"WOSimpleHTTPParser: file-IO boundary: %d",   fileIOBoundary);
  }
}

- (id)initWithStream:(id<NGStream>)_stream {
  if (NSStringClass == Nil) NSStringClass = [NSString class];
  
  if ((self = [super init])) {
    if ((self->io = [_stream retain]) == nil) {
      [self release];
      return nil;
    }
    
    self->readBytes = (void *)
      [(NSObject *)self->io methodForSelector:@selector(readBytes:count:)];
    if (self->readBytes == NULL) {
      [self warnWithFormat:@"(%s): got invalid stream object: %@",
        __PRETTY_FUNCTION__,
	      self->io];
      [self release];
      return nil;
    }
  }
  return self;
}
- (void)dealloc {
  [self reset];
  [self->io release];
  [super dealloc];
}

/* transient state */

- (void)reset {
  self->clen = -1;
  
  [self->content       release]; self->content     = nil;
  [self->lastException release]; self->lastException = nil;
  [self->httpVersion   release]; self->httpVersion   = nil;
  [self->headers removeAllObjects];

  if (self->lineBuffer) {
    free(self->lineBuffer);
    self->lineBuffer = NULL;
  }
  self->lineBufSize = 0;
}

/* low-level reading */

- (unsigned int)defaultLineSize {
  return 512;
}

- (NSException *)readNextLine {
  unsigned i;
  
  if (self->lineBuffer == NULL) {
    self->lineBufSize = [self defaultLineSize];
    self->lineBuffer  = malloc(self->lineBufSize + 10);
  }
  
  for (i = 0; YES; i++) {
    register unsigned rc;
    unsigned char c;
    
    rc = self->readBytes(self->io, @selector(readBytes:count:), &c, 1);
    if (rc != 1) {
      if (debugOn) {
	[self debugWithFormat:@"got result %u, exception: %@", 
	        rc, [self->io lastException]];
      }
      return [self->io lastException];
    }
    
    /* check buffer capacity */
    if ((i + 2) > self->lineBufSize) {
      static int reallocCount = 0;
      reallocCount++;
      if (reallocCount > 1000) {
	static BOOL didLog = NO;
	if (!didLog) {
	  didLog = YES;
	  [self warnWithFormat:@"(%s): reallocated the HTTP line buffer %i times, "
            @"consider increasing the default line buffer size!",
            __PRETTY_FUNCTION__, reallocCount];
	}
      }
      
      if (self->lineBufSize > (56 * 1024)) {
	/* to avoid DOS attacks ... */
	return [NSException exceptionWithName:@"HTTPParserHeaderSizeExceeded"
			    reason:
			      @"got a HTTP line of 100KB+ (DoS attack?)!"
			    userInfo:nil];
      }
      
      self->lineBufSize *= 2;
      self->lineBuffer = realloc(self->lineBuffer, self->lineBufSize + 10);
    }
    
    if (c == '\n') {
      /* found EOL */
      break;
    }
    else if (c == '\r') {
      /* skip CR */
      i--;
      continue;
    }
    else {
      /* store byte */
      self->lineBuffer[i] = c;
    }
  }
  self->lineBuffer[i] = 0; /* 0-terminate buffer */
  
  return nil /* nil means: everything OK */;
}

/* common HTTP parsing */

static NSString *ContentLengthHeaderName = @"content-length";

static NSString *stringForHeaderName(char *p) { /* Note: arg is _not_ const */
  /* 
     process header name
     
     we try to be smart to avoid creation of NSString objects ...
  */
  register unsigned len;
  register char c1;
  
  if ((len = strlen(p)) == 0)
    return @"";
  c1 = *p;

  switch (len) {
  case 0:
  case 1:
    break;
  case 2:
    if (strcasecmp(p, "te") == 0) return @"te";
    if (strcasecmp(p, "if") == 0) return @"if";
    break;
  case 3:
    if (strcasecmp(p, "via") == 0)   return @"via";
    if (strcasecmp(p, "age") == 0)   return @"age";
    if (strcasecmp(p, "p3p") == 0)   return @"p3p";
    break;
  case 4: 
    switch (c1) {
    case 'd': case 'D':
      if (strcasecmp(p, "date") == 0) return @"date";
      break;
    case 'e': case 'E':
      if (strcasecmp(p, "etag") == 0) return @"etag";
      break;
    case 'f': case 'F':
      if (strcasecmp(p, "from") == 0) return @"from";
      break;
    case 'h': case 'H':
      if (strcasecmp(p, "host") == 0) return @"host";
      break;
    case 'v': case 'V':
      if (strcasecmp(p, "vary") == 0) return @"vary";
      break;
    }
    break;
  case 5:
    if (strcasecmp(p, "allow") == 0) return @"allow";
    if (strcasecmp(p, "brief") == 0) return @"brief";
    if (strcasecmp(p, "range") == 0) return @"range";
    if (strcasecmp(p, "depth") == 0) return @"depth";
    if (strcasecmp(p, "ua-os") == 0) return @"ua-os"; /* Entourage */
    break;
  case 6:
    switch (c1) {
    case 'a': case 'A':
      if (strcasecmp(p, "accept") == 0)	return @"accept";
      break;
    case 'c': case 'C':
      if (strcasecmp(p, "cookie") == 0)	return @"cookie";
      break;
    case 'e': case 'E':
      if (strcasecmp(p, "expect") == 0) return @"expect";
      break;
    case 'p': case 'P':
      if (strcasecmp(p, "pragma") == 0)	return @"pragma";
      break;
    case 's': case 'S':
      if (strcasecmp(p, "server") == 0)	return @"server";
      break;
    case 'u': case 'U':
      if (strcasecmp(p, "ua-cpu") == 0)	return @"ua-cpu"; /* Entourage */
      break;
    }
    break;

  default:
    switch (c1) {
    case 'a': case 'A': 
      if (len > 10) {
	if (p[6] == '-') {
	  if (strcasecmp(p, "accept-charset")  == 0) return @"accept-charset";
	  if (strcasecmp(p, "accept-encoding") == 0) return @"accept-encoding";
	  if (strcasecmp(p, "accept-language") == 0) return @"accept-language";
	  if (strcasecmp(p, "accept-ranges")   == 0) return @"accept-ranges";
	}
	else if (strcasecmp(p, "authorization") == 0)
	  return @"authorization";
      }
      break;
      
    case 'c': case 'C':
      if (len > 8) {
	if (p[7] == '-') {
	  if (strcasecmp(p, "content-length") == 0)  
	    return ContentLengthHeaderName;
	  
	  if (strcasecmp(p, "content-type") == 0)    return @"content-type";
	  if (strcasecmp(p, "content-md5") == 0)     return @"content-md5";
	  if (strcasecmp(p, "content-range") == 0)   return @"content-range";
	  
	  if (strcasecmp(p, "content-encoding") == 0)
	    return @"content-encoding";
	  if (strcasecmp(p, "content-language") == 0)
	    return @"content-language";

	  if (strcasecmp(p, "content-location") == 0)
	    return @"content-location";
	  if (strcasecmp(p, "content-class") == 0) /* Entourage */
	    return @"content-class";
	}
	else if (strcasecmp(p, "call-back") == 0)
	  return @"call-back";
      }
      
      if (strcasecmp(p, "connection") == 0)    return @"connection";
      if (strcasecmp(p, "cache-control") == 0) return @"cache-control";
      
      break;

    case 'd': case 'D':
      if (strcasecmp(p, "destination") == 0) return @"destination";
      if (strcasecmp(p, "destroy")     == 0) return @"destroy";
      break;

    case 'e': case 'E':
      if (strcasecmp(p, "expires")   == 0) return @"expires";
      if (strcasecmp(p, "extension") == 0) return @"extension"; /* Entourage */
      break;

    case 'i': case 'I':
      if (strcasecmp(p, "if-modified-since") == 0) 
        return @"if-modified-since";
      if (strcasecmp(p, "if-none-match") == 0) /* Entourage */
        return @"if-none-match";
      if (strcasecmp(p, "if-match") == 0) 
        return @"if-match";
      break;

    case 'k': case 'K':
      if (strcasecmp(p, "keep-alive") == 0) return @"keep-alive";
      break;
      
    case 'l': case 'L':
      if (strcasecmp(p, "last-modified") == 0) return @"last-modified";
      if (strcasecmp(p, "location")      == 0) return @"location";
      if (strcasecmp(p, "lock-token")    == 0) return @"lock-token";
      break;

    case 'm': case 'M':
      if (strcasecmp(p, "ms-webstorage") == 0) return @"ms-webstorage";
      if (strcasecmp(p, "max-forwards")  == 0) return @"max-forwards";
      break;
      
    case 'n': case 'N':
      if (len > 16) {
	if (p[12] == '-') {
	  if (strcasecmp(p, "notification-delay") == 0)
	    return @"notification-delay";
	  if (strcasecmp(p, "notification-type") == 0)
	    return @"notification-type";
	}
      }
      break;

    case 'o': case 'O':
      if (len == 9) {
	if (strcasecmp(p, "overwrite") == 0) 
	  return @"overwrite";
      }
      break;
      
    case 'p': case 'P':
      if (len == 16) {
	if (strcasecmp(p, "proxy-connection") == 0) 
	  return @"proxy-connection";
      }
      break;
      
    case 'r': case 'R':
      if (len == 7) {
	if (strcasecmp(p, "referer") == 0) return @"referer";
      }
      break;
      
    case 's': case 'S':
      switch (len) {
      case 21:
	if (strcasecmp(p, "subscription-lifetime") == 0)
	  return @"subscription-lifetime";
        break;
      case 15:
	if (strcasecmp(p, "subscription-id") == 0)
	  return @"subscription-id";
        break;
      case 10:
	if (strcasecmp(p, "set-cookie") == 0)
	  return @"set-cookie";
        break;
      }
      break;
      
    case 't': case 'T':
      if (strcasecmp(p, "transfer-encoding") == 0) return @"transfer-encoding";
      if (strcasecmp(p, "translate") == 0)         return @"translate";
      if (strcasecmp(p, "trailer") == 0)           return @"trailer";
      if (strcasecmp(p, "timeout") == 0)           return @"timeout";
      break;
      
    case 'u': case 'U':
      if (strcasecmp(p, "user-agent") == 0) return @"user-agent";
      break;
      
    case 'w': case 'W':
      if (strcasecmp(p, "www-authenticate") == 0) return @"www-authenticate";
      if (strcasecmp(p, "warning") == 0)          return @"warning";
      break;
      
    case 'x': case 'X':
      if ((p[2] == 'w') && (len > 22)) {
	if (strstr(p, "x-webobjects-") == (void *)p) {
	  p += 13; /* skip x-webobjects- */
	  if (strcmp(p, "server-protocol") == 0)
	    return @"x-webobjects-server-protocol";
	  else if (strcmp(p, "server-protocol") == 0)
	    return @"x-webobjects-server-protocol";
	  else if (strcmp(p, "remote-addr") == 0)
	    return @"x-webobjects-remote-addr";
	  else if (strcmp(p, "remote-host") == 0)
	    return @"x-webobjects-remote-host";
	  else if (strcmp(p, "server-name") == 0)
	    return @"x-webobjects-server-name";
	  else if (strcmp(p, "server-port") == 0)
	    return @"x-webobjects-server-port";
	  else if (strcmp(p, "server-url") == 0)
	    return @"x-webobjects-server-url";
	}
      }
      if (len == 7) {
	if (strcasecmp(p, "x-cache") == 0)
	  return @"x-cache";
      }
      else if (len == 12) {
	if (strcasecmp(p, "x-powered-by") == 0)
	  return @"x-powered-by";
      }
      if (strcasecmp(p, "x-zidestore-name") == 0)
	return @"x-zidestore-name"; 
      if (strcasecmp(p, "x-forwarded-for") == 0)
	return @"x-forwarded-for";
      if (strcasecmp(p, "x-forwarded-host") == 0)
	return @"x-forwarded-host";
      if (strcasecmp(p, "x-forwarded-server") == 0)
	return @"x-forwarded-server";
      break;
    }
  }
  
  if (debugOn)
    NSLog(@"making custom header name '%s'!", p);
  
  /* make name lowercase (we own the buffer, so we can work on it) */
  {
    unsigned char *t;
    
    for (t = (unsigned char *)p; *t != '\0'; t++)
      *t = tolower(*t);
  }
  return [[NSString alloc] initWithCString:p];
}

- (NSException *)parseHeader {
  NSException *e = nil;
  
  while ((e = [self readNextLine]) == nil) {
    unsigned char *p, *v;
    unsigned int  idx;
    NSString *headerName;
    NSString *headerValue;
    
    if (heavyDebugOn)
      printf("read header line: '%s'\n", self->lineBuffer);
    
    if (strlen((char *)self->lineBuffer) == 0) {
      /* found end of header */
      break;
    }
    
    p = self->lineBuffer;
    
    if (*p == ' ' || *p == '\t') {
      // TODO: implement folding (remember last header-key, add string)
      [self errorWithFormat:
              @"(%s): got a folded HTTP header line, cannot process!",
              __PRETTY_FUNCTION__];
      continue;
    }
    
    /* find key/value separator */
    if ((v = (unsigned char *)index((char *)p, ':')) == NULL) {
      [self warnWithFormat:@"got malformed header line: '%s'",
              self->lineBuffer];
      continue;
    }
    
    *v = '\0'; v++; /* now 'p' points to name and 'v' to value */
    
    /* skip leading spaces */
    while (*v != '\0' && (*v == ' ' || *v == '\t'))
      v++;

    if (*v != '\0') {
      /* trim trailing spaces */
      for (idx = strlen((char *)v) - 1; idx >= 0; idx--) {
        if ((v[idx] != ' ' && v[idx] != '\t'))
          break;
        
        v[idx] = '\0';
      }
    }
    
    headerName  = stringForHeaderName((char *)p);
    headerValue = [[NSStringClass alloc] initWithCString:(char *)v];
    
    if (headerName == ContentLengthHeaderName)
      self->clen = atoi((char *)v);
    
    if (headerName != nil || headerValue != nil) {
      if (self->headers == nil)
	self->headers = [[NSMutableDictionary alloc] initWithCapacity:32];
      
      [self->headers setObject:headerValue forKey:headerName];
    }
    
    [headerValue release];
    [headerName  release];
  }
  
  return e;
}

- (NSException *)parseEntityOfMethod:(NSString *)_method {
  /*
    TODO: several cases are caught:
    a) content-length = 0   => empty data
    b) content-length small => read into memory
    c) content-length large => streamed into the filesystem to safe RAM
    d) content-length unknown => ??
  */
  
  if (self->clen == 0) {
    /* nothing to do */
  }
  else if (self->clen < 0) {
    /* I think HTTP/1.1 requires a content-length header to be present ? */
    
    if ([self->httpVersion isEqualToString:@"HTTP/1.0"] ||
	[self->httpVersion isEqualToString:@"HTTP/0.9"]) {
      /* content-length unknown, read till EOF */
      BOOL readToEOF = YES;

      if ([_method isEqualToString:@"HEAD"])
	readToEOF = NO;
      else if ([_method isEqualToString:@"GET"])
	readToEOF = NO;
      else if ([_method isEqualToString:@"DELETE"])
	readToEOF = NO;
      
      if (readToEOF) {
        [self warnWithFormat:
                @"not processing entity of request without contentlen!"];
      }
    }
  }
  else if (self->clen > maxUploadSize*1024) {
    /* entity is too large */
    NSString *s;

    s = [NSString stringWithFormat:@"The maximum HTTP transaction size was "
                  @"exceeded (%d vs %d)", self->clen, maxUploadSize * 1024];
    return [NSException exceptionWithName:@"LimitException"
			reason:s userInfo:nil];
  }
  else if (self->clen > fileIOBoundary) {
    /* we are streaming the content to a file and use a memory mapped data */
    unsigned toGo;
    NSString *fn;
    char buf[4096];
    BOOL ok = YES;
    int  writeError = 0;
    FILE *t;
    
    [self debugWithFormat:@"streaming %i bytes into file ...", self->clen];
    
    fn = [[NSProcessInfo processInfo] temporaryFileName];
    
    if ((t = fopen([fn cString], "w")) == NULL) {
      [self errorWithFormat:@"could not open temporary file '%@'!", fn];
      
      /* read into memory as a fallback ... */
      
      self->content =
	[[(NGStream *)self->io safeReadDataOfLength:self->clen] retain];
      if (self->content == nil)
	return [self->io lastException];
      return nil;
    }
    
    for (toGo = self->clen; toGo > 0; ) {
      unsigned readCount, writeCount;
      
      /* read from socket */
      readCount = [self->io readBytes:buf count:sizeof(buf)];
      if (readCount == NGStreamError) {
	/* an error */
	ok = NO;
	break;
      }
      toGo -= readCount;
      
      /* write to file */
      if ((writeCount = fwrite(buf, readCount, 1, t)) != 1) {
	/* an error */
	ok = NO;
	writeError = ferror(t);
	break;
      }
    }
    fclose(t);
    
    if (!ok) {
      unlink([fn cString]); /* delete temporary file */
      
      if (writeError == 0) {
	return [NSException exceptionWithName:@"SystemWriteError"
			    reason:@"failed to write data to upload file"
			    userInfo:nil];
      }
      
      return [self->io lastException];
    }
    
    self->content = [[NSData alloc] initWithContentsOfMappedFile:fn];
    unlink([fn cString]); /* if the mmap disappears, the storage is freed */
  }
  else {
    /* content-length known and small */
    //[self logWithFormat:@"reading %i bytes of the entity", self->clen];
    
    self->content =
      [[(NGStream *)self->io safeReadDataOfLength:self->clen] retain];
    if (self->content == nil)
      return [self->io lastException];
    
    //[self logWithFormat:@"read %i bytes.", [self->content length]];
  }
  
  return nil;
}

/* handling expectations */

- (BOOL)processContinueExpectation {
  // TODO: this should check the credentials of a request before accepting the
  //       body. The current implementation is far from optimal and only added
  //       for Mono compatibility (and actually produces the same behaviour
  //       like with HTTP/1.0 ...)
  static char *contStatLine = 
    "HTTP/1.0 100 Continue\r\n"
    "content-length: 0\r\n"
    "\r\n";
  static char *failStatLine = 
    "HTTP/1.0 417 Expectation Failed\r\n"
    "content-length: 0\r\n"
    "\r\n";
  char *respline = NULL;
  BOOL ok = YES;
  
  [self debugWithFormat:@"process 100 continue on IO: %@", self->io];
  
  if (self->clen > 0 && (self->clen > (maxUploadSize * 1024))) {
    // TODO: return a 417 expectation failed
    ok = NO;
    respline = failStatLine;
  }
  else {
    ok = YES;
    respline = contStatLine;
  }
  
  if (![self->io safeWriteBytes:respline count:strlen(respline)]) {
    ASSIGN(self->lastException, [self->io lastException]);
    return NO;
  }
  if (![self->io flush]) {
    ASSIGN(self->lastException, [self->io lastException]);
    return NO;
  }
  
  return ok;
}

/* parsing */

- (void)_fixupContentEncodingOfMessageBasedOnContentType:(WOMessage *)_msg {
  // DUP: NGHttp+WO.m
  NSStringEncoding enc = 0;
  NSString   *ctype;
  NGMimeType *rqContentType;
  NSString   *charset;
  
  if (![(ctype = [_msg headerForKey:@"content-type"]) isNotEmpty])
    /* an HTTP message w/o a content type? */
    return;
  
  if ((rqContentType = [NGMimeType mimeType:ctype]) == nil) {
    [self warnWithFormat:@"could not parse MIME type: '%@'", ctype];
    return;
  }
  
  charset = [rqContentType valueOfParameter:@"charset"];

  if ([charset isNotEmpty]) {
    enc = [NSString stringEncodingForEncodingNamed:charset];
  }
  else if (rqContentType != nil) {
    /* process default charsets for content types */
    NSString *majorType = [rqContentType type];
      
    if ([majorType isEqualToString:@"text"]) {
      NSString *subType = [rqContentType subType];
	
      if ([subType isEqualToString:@"calendar"]) {
	/* RFC2445, section 4.1.4 */
	enc = NSUTF8StringEncoding;
      }
    }
    else if ([majorType isEqualToString:@"application"]) {
      NSString *subType = [rqContentType subType];
	
      if ([subType isEqualToString:@"xml"]) {
	// TBD: we should look at the actual content! (<?xml declaration
	//      and BOM
	enc = NSUTF8StringEncoding;
      }
    }
  }

  if (enc != 0)
    [_msg setContentEncoding:enc];
}

- (WORequest *)parseRequest {
  NSException *e = nil;
  WORequest   *r = nil;
  NSString    *uri    = @"/";
  NSString    *method = @"GET";
  NSString    *expect;
  
  [self reset];
  if (heavyDebugOn)
    [self logWithFormat:@"HeavyDebug: parsing response ..."];
  
  /* process request line */
  
  if ((e = [self readNextLine])) {
    ASSIGN(self->lastException, e);
    return nil;
  }
  if (heavyDebugOn)
    printf("read request line: '%s'\n", self->lineBuffer);
  
  {
    /* sample line: "GET / HTTP/1.0" */
    char *p, *t;
    
    /* parse method */
    
    p = (char *)self->lineBuffer;
    if ((t = index(p, ' ')) == NULL) {
      [self logWithFormat:@"got broken request line '%s'", self->lineBuffer];
      return nil;
    }
    *t = '\0';
    
    switch (*p) {
      /* intended fall-throughs ! */
    case 'b': case 'B':
      if (strcasecmp(p, "BPROPFIND")  == 0) { method = @"BPROPFIND";  break; }
      if (strcasecmp(p, "BPROPPATCH") == 0) { method = @"BPROPPATCH"; break; }
    case 'c': case 'C':
      if (strcasecmp(p, "COPY")     == 0) { method = @"COPY";     break; }
      if (strcasecmp(p, "CHECKOUT") == 0) { method = @"CHECKOUT"; break; }
      if (strcasecmp(p, "CHECKIN")  == 0) { method = @"CHECKIN";  break; }
    case 'd': case 'D':
      if (strcasecmp(p, "DELETE")  == 0) { method = @"DELETE"; break; }
    case 'h': case 'H':
      if (strcasecmp(p, "HEAD")    == 0) { method = @"HEAD";   break; }
    case 'l': case 'L':
      if (strcasecmp(p, "LOCK")    == 0) { method = @"LOCK";   break; }
    case 'g': case 'G':
      if (strcasecmp(p, "GET")     == 0) { method = @"GET";    break; }
    case 'm': case 'M':
      if (strcasecmp(p, "MKCOL")   == 0) { method = @"MKCOL";  break; }
      if (strcasecmp(p, "MOVE")    == 0) { method = @"MOVE";   break; }
    case 'n': case 'N':
      if (strcasecmp(p, "NOTIFY")  == 0) { method = @"NOTIFY"; break; }
    case 'o': case 'O':
      if (strcasecmp(p, "OPTIONS") == 0) { method = @"OPTIONS"; break; }
    case 'p': case 'P':
      if (strcasecmp(p, "PUT")       == 0) { method = @"PUT";       break; }
      if (strcasecmp(p, "POST")      == 0) { method = @"POST";      break; }
      if (strcasecmp(p, "PROPFIND")  == 0) { method = @"PROPFIND";  break; }
      if (strcasecmp(p, "PROPPATCH") == 0) { method = @"PROPPATCH"; break; }
      if (strcasecmp(p, "POLL")      == 0) { method = @"POLL";      break; }
    case 'r': case 'R':
      if (strcasecmp(p, "REPORT")    == 0) { method = @"REPORT";    break; }
    case 's': case 'S':
      if (strcasecmp(p, "SEARCH")    == 0) { method = @"SEARCH";    break; }
      if (strcasecmp(p, "SUBSCRIBE") == 0) { method = @"SUBSCRIBE"; break; }
    case 'u': case 'U':
      if (strcasecmp(p, "UNLOCK")     == 0) { method = @"UNLOCK";      break; }
      if (strcasecmp(p, "UNSUBSCRIBE")== 0) { method = @"UNSUBSCRIBE"; break; }
      if (strcasecmp(p, "UNCHECKOUT") == 0) { method = @"UNCHECKOUT";  break; }
    case 'v': case 'V':
      if (strcasecmp(p, "VERSION-CONTROL") == 0) { 
        method = @"VERSION-CONTROL";      
        break; 
      }
      
    default:
      if (debugOn)
        [self debugWithFormat:@"making custom HTTP method name: '%s'", p];
      method = [NSString stringWithCString:p];
      break;
    }
    
    /* parse URI */
    
    p = t + 1; /* skip space */
    while (*p != '\0' && (*p == ' ' || *p == '\t')) /* skip spaces */
      p++;
    
    if (*p == '\0') {
      [self logWithFormat:@"got broken request line '%s'", self->lineBuffer];
      return nil;
    }
    
    if ((t = index(p, ' ')) == NULL) {
      /* the URI isn't followed by a HTTP version */
      self->httpVersion = @"HTTP/0.9";
      /* TODO: strip trailing spaces for better compliance */
      uri = [NSString stringWithCString:p];
    }
    else {
      *t = '\0';
      uri = [NSString stringWithCString:p];

      /* parse version */
      
      p = t + 1; /* skip space */
      while (*p != '\0' && (*p == ' ' || *p == '\t')) /* skip spaces */
	p++;
      
      if (*p == '\0')
	self->httpVersion = @"HTTP/0.9";
      else if (strcasecmp(p, "http/1.0") == 0)
	self->httpVersion = @"HTTP/1.0";
      else if (strcasecmp(p, "http/1.1") == 0)
	self->httpVersion = @"HTTP/1.1";
      else {
	/* TODO: strip trailing spaces */
	self->httpVersion = [[NSString alloc] initWithCString:p];
      }
    }
  }
  
  /* process header */
  
  if ((e = [self parseHeader]) != nil) {
    ASSIGN(self->lastException, e);
    return nil;
  }
  if (heavyDebugOn)
    [self logWithFormat:@"parsed header: %@", self->headers];
  
  /* check for expectations */
  
  if ((expect = [self->headers objectForKey:@"expect"]) != nil) {
    if ([expect rangeOfString:@"100-continue" 
                options:NSCaseInsensitiveSearch].length > 0) {
      if (![self processContinueExpectation])
        return nil;
    }
  }
  
  /* process body */
  
  if (clen != 0) {
    if ((e = [self parseEntityOfMethod:method])) {
      ASSIGN(self->lastException, e);
      return nil;
    }
  }
  
  if (heavyDebugOn)
    [self logWithFormat:@"HeavyDebug: got all .."];
  
  r = [[WORequest alloc] initWithMethod:method
			 uri:uri
			 httpVersion:self->httpVersion
			 headers:self->headers
			 content:self->content
			 userInfo:nil];
  [self _fixupContentEncodingOfMessageBasedOnContentType:r];
  [self reset];
  
  if (heavyDebugOn)
    [self logWithFormat:@"HeavyDebug: request: %@", r];
  
  return [r autorelease];
}

- (WOResponse *)parseResponse {
  NSException *e           = nil;
  int         code         = 200;
  WOResponse  *r = nil;
  
  [self reset];
  if (heavyDebugOn)
    [self logWithFormat:@"HeavyDebug: parsing response ..."];
  
  /* process response line */
  
  if ((e = [self readNextLine])) {
    ASSIGN(self->lastException, e);
    return nil;
  }
  if (heavyDebugOn)
    printf("read response line: '%s'\n", self->lineBuffer);
  
  {
    /* sample line: "HTTP/1.0 200 OK" */
    char *p, *t;
    
    /* version */
    
    p = (char *)self->lineBuffer;
    if ((t = index(p, ' ')) == NULL) {
      [self logWithFormat:@"got broken response line '%s'", self->lineBuffer];
      return nil;
    }
    
    *t = '\0';
    if (strcasecmp(p, "http/1.0") == 0)
      self->httpVersion = @"HTTP/1.0";
    else if (strcasecmp(p, "http/1.1") == 0)
      self->httpVersion = @"HTTP/1.1";
    else
      self->httpVersion = [[NSString alloc] initWithCString:p];
    
    /* code */
    
    p = t + 1; /* skip space */
    while (*p != '\0' && (*p == ' ' || *p == '\t')) /* skip spaces */
      p++;
    if (*p == '\0') {
      [self logWithFormat:@"got broken response line '%s'", self->lineBuffer];
      return nil;
    }
    code = atoi(p);
    
    /* we don't need to parse a reason ... */
  }
  
  /* process header */
  
  if ((e = [self parseHeader])) {
    ASSIGN(self->lastException, e);
    return nil;
  }
  if (heavyDebugOn)
    [self logWithFormat:@"parsed header: %@", self->headers];
  
  /* process body */
  
  if (clen != 0) {
    if ((e = [self parseEntityOfMethod:nil /* parsing a response */])) {
      ASSIGN(self->lastException, e);
      return nil;
    }
  }
  
  if (heavyDebugOn)
    [self logWithFormat:@"HeavyDebug: got all .."];
  
  r = [[[WOResponse alloc] init] autorelease];
  [r setStatus:code];
  [r setHTTPVersion:self->httpVersion];
  [r setHeaders:self->headers];
  [r setContent:self->content];
  [self _fixupContentEncodingOfMessageBasedOnContentType:r];
  
  [self reset];
  
  if (heavyDebugOn)
    [self logWithFormat:@"HeavyDebug: response: %@", r];
  
  return r;
}

- (NSException *)lastException {
  return self->lastException;
}

/* debugging */

- (BOOL)isDebuggingEnabled {
  return debugOn;
}

@end /* WOSimpleHTTPParser */
