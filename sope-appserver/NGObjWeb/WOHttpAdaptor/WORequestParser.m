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

#include "WORequestParser.h"
#include <NGStreams/NGBufferedStream.h>
#include <NGObjWeb/WORequest.h>
#include "common.h"

@implementation WORequestParser

static NGLogger *logger = nil;

+ (void)initialize {
  NGLoggerManager *lm;
  static BOOL didInit = NO;
  if (didInit)
    return;
  didInit = YES;
  lm      = [NGLoggerManager defaultLoggerManager];
  logger  = [lm loggerForDefaultKey:@"WORequestParserDebugEnabled"];
  if (!logger) {
    logger = [lm loggerForClass:self];
    [logger setLogLevel:NGLogLevelInfo];
  }
}

- (id)initWithBufferedStream:(NGBufferedStream *)_in {
  if (_in == nil) {
    [self release];
    return nil;
  }
  
  self->in = [_in retain];
  self->readByte = (void *)[self->in methodForSelector:@selector(readByte)];
  return self;
}

- (void)dealloc {
  [self->lastException release];
  [self->in            release];
  [super dealloc];
}

/* parsing */

- (void)takeLastException {
  ASSIGN(self->lastException, [self->in lastException]);
}

static inline int nextChar(WORequestParser *self) {
  int c;
  if (self->pushBack != 0) {
    c = self->pushBack;
    self->pushBack = 0;
    return c;
  }
  if ((c = self->readByte(self->in, @selector(readByte))) < 0)
    [self takeLastException];
  return c;
}

static inline int nextCharAfterSpaces(WORequestParser *self) {
  int c;
  
  if (self->pushBack != 0) {
    if (self->pushBack == ' ' || self->pushBack == '\t')
      self->pushBack = 0;
    else {
      c = self->pushBack;
      self->pushBack = 0;
      return c;
    }
  }
  
  do {
    c = self->readByte(self->in, @selector(readByte));
    if (c < 0) {
      [self takeLastException];
      return c;
    }
  }
  while ((c == ' ') || (c == '\t'));
  return c;
}
static inline BOOL skipSpaces(WORequestParser *self) {
  int c;
  
  if ((c = nextCharAfterSpaces(self)) > 0)
    return NO;
  self->pushBack = c;
  return YES;
}

- (BOOL)readCRLF {
  int c;
  
  c = nextChar(self);
  if (c < 0)     return NO;
  if (c == '\n') return YES;
  if (c != '\r') return NO;
  
  c = nextChar(self);
  if (c < 0)     return NO;
  if (c == '\n') return YES;
  return NO;
}

/* header line */

- (NSString *)parseMethod {
  unsigned count;
  unsigned char m[32];
  int c;
  
  count = 0;
  for (c = nextChar(self); isalpha(c) && (count < 30); c = nextChar(self)) {
    m[count] = c;
    count++;
  }
  m[count] = '\0';
  
  if (count == 30) {
    /* method name too long */
    [self logWithFormat:@"method name got too long"];
    return nil;
  }
  else if (count == 0) {
    /* method name too short */
    [self logWithFormat:@"method name got too short"];
    return nil;
  }
  
  return [NSString stringWithCString:(char *)m length:count];
}

- (NSString *)parseURI {
  unsigned char *uri;
  unsigned      count;
  NSString      *s;
  int c;
  
  if ((c = nextCharAfterSpaces(self)) < 0)
    return nil;
  
  uri = calloc(4096, sizeof(unsigned char));
  
  for (count = 0; count < 4001 && (c > 0); count++) {
    if (c == ' '  || c == '\t') break;
    if (c == '\r' || c == '\n') break;
    
    uri[count] = c;
    c = nextChar(self);
  }
  
  if (c < 0) return nil;
  if (count == 4001) {
    [self logWithFormat:@"uri got too long (max 4000 chars)"];
    return nil;
  }
  
  /* feed last char to next parsing step */
  self->pushBack = c;
  
  s = [NSString stringWithCString:(char *)uri length:count];
  if (uri) free(uri);
  return s;
}

- (NSString *)parseVersion {
  unsigned count;
  unsigned char m[16];
  int c;
  
  c = nextCharAfterSpaces(self);
  if (c == '\r' || c == '\n') {
    /* no version specified */
    self->pushBack = c;
    return @"HTTP/0.9";
  }
  
  count = 0;
  for (; isprint(c) && (count < 15); c = nextChar(self)) {
    m[count] = c;
    count++;
  }
  m[count] = '\0';
  
  if (count == 15) {
    /* version too long */
    [self logWithFormat:@"http version got too long"];
    return nil;
  }
  else if (count == 0) {
    /* version too short, guessing HTTP/0.9 */
    return @"HTTP/0.9";
  }
  
  return [NSString stringWithCString:(char *)m length:count];
}

/* headers */

- (NSDictionary *)parseHeaders {
  return nil;
}

/* body */

- (unsigned)ramDataSizeLimitation {
  // 64KB TODO: make default
  return (64 * 1064);
}
- (unsigned)spoolDataSizeLimitation {
  // 64MB TODO: make default
  return (64 * 1024 * 1064);
}

- (NSData *)readContentUntilEOF {
  // TODO
  return nil;
}

- (NSData *)readContentOfLength:(unsigned int)_count {
  if (_count == 0) {
    static NSData *emptyData = nil;
    if (emptyData == nil) emptyData = [[NSData alloc] init];
    return emptyData;
  }
  
  if (_count <= [self ramDataSizeLimitation])
    return [self->in safeReadDataOfLength:_count];
  
  // TODO
  return nil;
}

/* full request */

- (BOOL)isContentLessMethod:(NSString *)_method {
  static NSMutableSet *methods = nil;
  if (methods == nil) {
    methods = [[NSMutableSet alloc] initWithObjects:nil];
  }
  return [methods containsObject:_method];
}

- (WORequest *)parseNextRequest {
  NSString     *method, *uri, *v;
  NSDictionary *headers;
  NSData       *content;
  WORequest    *result;

  ASSIGN(self->lastException, (id)nil);
  
  /* request line */
  
  if ((method = [self parseMethod]) == nil)
    return nil;
  if ((uri = [self parseURI]) == nil)
    return nil;
  if ((v = [self parseVersion]) == nil)
    return nil;
  
  if (![self readCRLF])
    return nil;

  [self debugWithFormat:@"stage 1: method=%@ uri=%@ version=%@",
          method, uri, v];

  /* headers */
  
  if ((headers = [self parseHeaders]) == nil)
    return nil;
  
  /* body */
  
  if (![self isContentLessMethod:method]) {
    unsigned int clen;
    
    if ((clen = [[headers objectForKey:@"content-length"] intValue])) {
      content = [self readContentOfLength:clen];
    }
    else {
      /*
        Two cases: 
          HTTP/1.0, HTTP/0.9 - read till EOF if no content-length is set
	  HTTP/1.1 and above: if no content-length is set, body is empty
      */
      
      if ([v hasPrefix:@"HTTP/0"])
	content = [self readContentUntilEOF];
      else if ([v hasPrefix:@"HTTP/1.0"])
	content = [self readContentUntilEOF];
      else
	content = nil;
    }
  }
  else
    content = nil;
  
  /* construct */
  
  result = [[WORequest alloc] initWithMethod:method uri:uri httpVersion:v
			      headers:headers content:content
			      userInfo:nil];
  return [result autorelease];
}

- (NSException *)lastException {
  return self->lastException;
}

/* logging */

- (id)logger {
  return logger;
}

- (NSString *)loggingPrefix {
  return @"[http-parser]";
}
- (BOOL)isDebuggingEnabled {
  static int debugOn = -1;
  if (debugOn == -1) {
    debugOn = [[NSUserDefaults standardUserDefaults]
		boolForKey:@"WORequestParserDebugEnabled"] ? 1 : 0;
  }
  return debugOn ? YES : NO;
}

@end /* WORequestParser */
