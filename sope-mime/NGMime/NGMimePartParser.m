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

#include "NGMimePartParser.h"
#include "NGMimeBodyParser.h"
#include "NGMimeType.h"
#include "NGMimeUtilities.h"
#include "common.h"
#include <string.h>

/* this tunes, how big reused data cache objects may get (10MB) */
#define MAX_DATA_OBJECT_SIZE_CACHE (10*1024*1024)

@implementation NSData(MIMEContentTransferEncoding)

- (NSData *)dataByApplyingMimeContentTransferEncoding:(NSString *)_enc {
  // TODO: make this an NSData category
  unsigned len;
  unichar  c;
  
  if ((len = [_enc length]) == 0)
    return self;
  
  _enc = [_enc lowercaseString];
  
  c = [_enc characterAtIndex:0];
  switch (c) {
  case 'q':
    if ([_enc hasPrefix:@"quoted"])
      return [self dataByDecodingQuotedPrintableTransferEncoding];
    break;
  case 'b':
    if ([_enc hasPrefix:@"base64"])
      return [self dataByDecodingBase64];
    if ([@"binary" isEqualToString:_enc])
      return self;
    break;
  case '7':
  case '8':
  case 'i':
    if (len == 4) {
      if ([@"7bit" isEqualToString:_enc])
	return self;
      if ([@"8bit" isEqualToString:_enc])
	return self;
      break;
    }
    else if (len == 8) {
      if ([@"identity" isEqualToString:_enc])
	return self;
    }
    
  case 'u':
    if (len == 12) {
      if ([@"unknown-8bit" isEqualToString:_enc])
        return self;
    }
  default:
    break;
  }
  
  [self warnWithFormat:@"%s: unknown content-transfer-encoding: '%@'", 
	__PRETTY_FUNCTION__, _enc];
  return nil;
}

@end /* NSData(MIMEContentTransferEncoding) */


@implementation NGMimePartParser

static Class StringClass  = Nil;
static Class MStringClass = Nil;
static Class DataClass    = Nil;
static Class NSMutableDataClass = NULL;

static NGMimeHeaderNames *HeaderNames = NULL;

+ (int)version {
  return 3;
}

static int MimeLogEnabled = -1;

+ (void)initialize {
  static BOOL isInitialized = NO;
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  if (isInitialized) return;
  isInitialized = YES;
  
  MimeLogEnabled     = [ud boolForKey:@"MimeLogEnabled"] ? 1 : 0;
  MStringClass       = [NSMutableString class];
  StringClass        = [NSString class];
  DataClass          = [NSData class];
  NSMutableDataClass = [NSMutableData class];
}

static inline int  _la(NGMimePartParser *self, int _la);
static inline void _consume(NGMimePartParser *self, int _cnt);
static inline BOOL _checkKey(NGMimePartParser *self, NGHashMap *_map,
                             NSString *_key);

+ (NGMimeHeaderNames *)headerFieldNames {
  if (HeaderNames == NULL) {
    HeaderNames = malloc(sizeof(NGMimeHeaderNames));

    HeaderNames->accept                  = @"accept";
    HeaderNames->acceptLanguage          = @"accept-language";
    HeaderNames->acceptEncoding          = @"accept-encoding";
    HeaderNames->acceptCharset           = @"accept-charset";
    HeaderNames->cacheControl            = @"cache-control";
    HeaderNames->cc                      = @"cc";
    HeaderNames->connection              = @"connection";
    HeaderNames->contentDisposition      = @"content-disposition";
    HeaderNames->contentLength           = @"content-length";
    HeaderNames->contentTransferEncoding = @"content-transfer-encoding";
    HeaderNames->contentType             = @"content-type";
    HeaderNames->cookie                  = @"cookie";
    HeaderNames->date                    = @"date";
    HeaderNames->from                    = @"from";
    HeaderNames->host                    = @"host";
    HeaderNames->keepAlive               = @"keep-alive";
    HeaderNames->messageID               = @"message-id";
    HeaderNames->mimeVersion             = @"mime-version";
    HeaderNames->organization            = @"organization";
    HeaderNames->received                = @"received";
    HeaderNames->returnPath              = @"return-path";
    HeaderNames->referer                 = @"referer";
    HeaderNames->replyTo                 = @"reply-to";
    HeaderNames->subject                 = @"subject";
    HeaderNames->to                      = @"to";
    HeaderNames->userAgent               = @"user-agent";
    HeaderNames->xMailer                 = @"x-mailer";
  }
  return HeaderNames;
}

- (id)init {
  if ((self = [super init])) {
    self->bufLen        = 1024;
    self->contentLength = -1;
  }
  return self;
}

- (void)dealloc {
  [self->contentTransferEncoding release];
  [self->source     release];
  [self->sourceData release];
  [super dealloc];
}

/* accessors */

- (void)setDelegate:(id)_delegate {
  self->delegate = _delegate;

  self->delegateRespondsTo.parserWillParseHeader =
    [self->delegate respondsToSelector:@selector(parserWillParseHeader:)];
  
  self->delegateRespondsTo.parserDidParseHeader =
    [self->delegate respondsToSelector:@selector(parser:didParseHeader:)];

  self->delegateRespondsTo.parserKeepHeaderFieldData =
    [self->delegate respondsToSelector:@selector(parser:keepHeaderField:data:)];
  
  self->delegateRespondsTo.parserKeepHeaderFieldValue =
    [self->delegate respondsToSelector:
                      @selector(parser:keepHeaderField:value:)];

  self->delegateRespondsTo.parserFoundCommentInHeaderField =
    [self->delegate respondsToSelector:
                      @selector(parser:foundComment:inHeaderField:)];

  self->delegateRespondsTo.parserWillParseBodyOfPart =
    [self->delegate respondsToSelector:@selector(parser:willParseBodyOfPart:)];
  
  self->delegateRespondsTo.parserDidParseBodyOfPart =
    [self->delegate respondsToSelector:@selector(parser:didParseBodyOfPart:)];

  self->delegateRespondsTo.parserParseRawBodyDataOfPart =
    [self->delegate respondsToSelector:
                      @selector(parser:parseRawBodyData:ofPart:)];
  
  self->delegateRespondsTo.parserBodyParserForPart =
    [self->delegate respondsToSelector:@selector(parser:bodyParserForPart:)];

  self->delegateRespondsTo.parserDecodeBodyOfPart =
    [self->delegate respondsToSelector:@selector(parser:decodeBody:ofPart:)];

  self->delegateRespondsTo.parserParseHeaderFieldData =
    [self->delegate respondsToSelector:@selector(parser:parseHeaderField:data:)];
}

- (id)delegate {
  return self->delegate;
}

/* header */

- (id<NGMimeHeaderFieldParser>)parserForHeaderField:(NSString *)_name {
  static id defParserSet = nil;
  if (defParserSet == nil) {
    defParserSet =
      [[NGMimeHeaderFieldParserSet defaultRfc822HeaderFieldParserSet] retain];
  }
  return defParserSet;
}

+ (NSStringEncoding)defaultHeaderFieldEncoding {
  return NSUTF8StringEncoding;
}

- (id)valueOfHeaderField:(NSString *)_name data:(id)_data {
  // TODO: use iconv (if available, eg not on OSX !!!) to convert
  //       an unknown encoding to UTF-16 and create an NSConcrete*UTF16String
  id<NGMimeHeaderFieldParser> parser;
  NSString                    *tmp;
  id value = nil;
  
  if (self->delegateRespondsTo.parserParseHeaderFieldData)
    value = [delegate parser:self parseHeaderField:_name data:_data];
  
  if (value)
    return value;
  
  if ([_data isKindOfClass:DataClass]) {
    tmp = [[StringClass alloc]
	    initWithData:_data
	    encoding:[NGMimePartParser defaultHeaderFieldEncoding]];
  }
  else
    tmp = [_data retain];
  
  if ((parser = [self parserForHeaderField:_name]))
    value = [parser parseValue:tmp ofHeaderField:_name];
  else
    value = [tmp stringByTrimmingSpaces];
  
  value = [[value retain] autorelease];
  [tmp release];
  return value;
}

/*
  possible constants:
  
  NGMime_CC                      = @"cc"; 
  NGMime_To                      = @"to";                        : 2

  NGMime_Date                    = @"date";
  NGMime_Host                    = @"host";
  NGMime_From                    = @"from";                      : 4

  NGMime_Cookie                  = @"cookie"
  NGMime_Accept                  = @"accept"                     : 6
  
  NGMime_Referer                 = @"referer"
  NGMime_Subject                 = @"subject";                   : 7

  NGMime_xMailer                 = @"x-mailer";
  NGMime_ReplyTo                 = @"reply-to"
  NGMime_Received                = @"received";                  : 8

  NGMime_Connection              = @"connection"
  NGMime_KeepAlive               = @"keep-alive"
  NGMime_UserAgent               = @"user-agent";
  NGMime_MessageID               = @"message-id";                : 10
  
  NGMime_ReturnPath              = @"return-path";               : 11

  NGMime_MimeVersion             = @"mime-version";
  NGMime_Organization            = @"organization";
  NGMime_ContentType             = @"content-type";              : 12

  NGMime_CacheControl            = @"cache-control"              : 13
  
  NGMime_AcceptCharset           = @"accept-charset"
  NGMime_ContentLength           = @"content-length";            : 14

  NGMime_AcceptEncoding          = @"accept-encoding"
  NGMime_AcceptLanguage          = @"accept-language"            : 15

  NGMime_ContentDisposition      = @"content-disposition";       : 19

  NGMime_ContentTransferEncoding = @"content-transfer-encoding"; : 25
*/

static NSString *fieldNameForCString(id self, char *_cstring, int _len) {
  if (HeaderNames == NULL)
    [NGMimePartParser headerFieldNames];
  
  switch  (_len) {
    case 0:
      return @"";
    case 2:
      if (_cstring[0] == 'c' && _cstring[1] == 'c')
        return HeaderNames->cc;
      else if (_cstring[0] == 't' && _cstring[1] == 'o')
        return HeaderNames->to;
      break;
    case 4:
      if (_cstring[3] == 'e') {
        if (strncmp(_cstring, "date", 4) == 0)
          return HeaderNames->date;
      }
      else if (_cstring[3] == 'm') {
        if (strncmp(_cstring, "from", 4) == 0)
          return HeaderNames->from;
      }
      else if (_cstring[3] == 't') {
        if (strncmp(_cstring, "host", 4) == 0)
          return HeaderNames->host;
      }
      break;
    case 6:
      if (_cstring[5] == 't') {
        if (strncmp(_cstring, "accept", 6) == 0)
          return HeaderNames->accept;
      }
      if (_cstring[5] == 'e') {
        if (strncmp(_cstring, "cookie", 6) == 0)
          return HeaderNames->cookie;
      }
      break;
    case 7:
      if (_cstring[6] == 't') {
        if (strncmp(_cstring, "subject", 7) == 0)
          return HeaderNames->subject;
      }
      if (_cstring[6] == 'r') {
        if (strncmp(_cstring, "referer", 7) == 0)
          return HeaderNames->referer;
      }
      break;
    case 8:
      if (_cstring[5] == '-') {
        if (strncmp(_cstring, "reply-to", 8) == 0)
          return HeaderNames->replyTo;
      }
      if (_cstring[7] == 'd') {
        if (strncmp(_cstring, "received", 8) == 0)
          return HeaderNames->received;
      }
      if (_cstring[1] == '-') {
        if (strncmp(_cstring, "x-mailer", 8) == 0)
          return HeaderNames->xMailer;
      }
      break;
    case 10:
      if (_cstring[4] == '-') {
        if (_cstring[6] == 'g') {
          if (strncmp(_cstring, "user-agent", 10) == 0)
            return HeaderNames->userAgent;
        }
        if (_cstring[6] == 'l') {
          if (strncmp(_cstring, "keep-alive", 10) == 0)
            return HeaderNames->keepAlive;
        }
      }
      else if (_cstring[7] == '-') {
        if (strncmp(_cstring, "message-id", 10) == 0)
          return HeaderNames->messageID;
      }
      else if (_cstring[9] == 'n') {
        if (strncmp(_cstring, "connection", 10) == 0)
          return HeaderNames->connection;
      }
      break;
    case 11:
      if (_cstring[6] == '-') {
        if (strncmp(_cstring, "return-path", 11) == 0)
          return HeaderNames->returnPath;
      }
      break;
    case 12:
      if (_cstring[4] == '-') {
        if (strncmp(_cstring, "mime-version", 12) == 0)
          return HeaderNames->mimeVersion;
      }
      else if (_cstring[11] == 'n') {
        if (strncmp(_cstring, "organization", 12) == 0)
          return HeaderNames->organization;
      }
      else if (_cstring[7] == '-') {
        if (strncmp(_cstring, "content-type", 12) == 0)
          return HeaderNames->contentType;
      }
      break;
    case 13:
      if (_cstring[5] == '-') {
        if (strncmp(_cstring, "cache-control", 13) == 0)
          return HeaderNames->cacheControl;
      }
      break;
    case 14:
      if (_cstring[7] == '-') {
        if (strncmp(_cstring, "content-length", 14) == 0) {
          return HeaderNames->contentLength;
        }
      }
      else if (_cstring[6] == '-') {
        if (strncmp(_cstring, "accept-charset", 14) == 0)
          return HeaderNames->acceptCharset;
      }
      break;
    case 15:
      if (_cstring[6] == '-') {
        if (_cstring[7] == 'l') {
          if (strncmp(_cstring, "accept-language", 15) == 0)
            return HeaderNames->acceptLanguage;
        }
        else if (_cstring[7] == 'e') {
          if (strncmp(_cstring, "accept-encoding", 15) == 0)
            return HeaderNames->acceptEncoding;
        }
      }
      break;
    case 19:
      if (_cstring[7] == '-') {
        if (strncmp(_cstring, "content-disposition", 19) == 0)
          return HeaderNames->contentDisposition;
      }
      break;
    case 25:
      if (_cstring[7] == '-') {
        if (strncmp(_cstring, "content-transfer-encoding", 25) == 0)
          return HeaderNames->contentTransferEncoding;
      }
      break;
  }
  {
    NSString *result;

    result = [NSString stringWithCString:_cstring length:_len];
#if DEBUG & 0    
    if (MimeLogEnabled)
      [self logWithFormat:@"%s: found no headerfield constant for <%@>, "
            @"generate new string", __PRETTY_FUNCTION__, result];
#endif
    return result;
  }
}


- (NSString *)fieldNameForCString:(char *)_cstring length:(int)_len {
  return fieldNameForCString(self, _cstring, _len);
}

- (NGHashMap *)parseHeader {
  // TODO: split up this huge method!
  /* parse headers until an empty line is seen */
  NGMutableHashMap *header           = nil;
  NSMutableData    *fieldValue       = nil;
  NSMutableString  *fieldName        = nil;
  NSString         *realFieldName    = nil;
  BOOL             foundEndOfHeaders = NO;
  int              bufCnt            = 0;
  char             *buf              = NULL;
  NSAutoreleasePool *pool;
  
  ASSIGN(self->contentTransferEncoding, (id)nil);
  
  if (self->delegateRespondsTo.parserWillParseHeader) {
    if (![self->delegate parserWillParseHeader:self])
      return nil;
  }
  
  pool       = [[NSAutoreleasePool alloc] init];
  fieldValue = [NSMutableData dataWithCapacity:512];
  header     = [NGMutableHashMap hashMapWithCapacity:128];
  buf        = calloc(self->bufLen, 1);
  bufCnt     = *&bufCnt;
  
  while (!foundEndOfHeaders) {
    int  c              = 0;
    BOOL endOfFieldBody = NO;
    
    /* reset mutable vars */
    
    if (fieldName) {
      [fieldName release];
      fieldName = nil;
    }
    
    [fieldValue setLength:0];
    
    /* parse fieldName */
    {
      unsigned fnlen;
      BOOL lastWasCR;
      
      bufCnt    = 0;
      fnlen     = 0;
      lastWasCR = NO;
      
      while ((c = _la(self, 0)) != ':') {
        if (c == -1)
          /* EOF */
          break;

        /* check for leading '\r\n' or '\n' */
        if (fnlen == 0) {
          if (c == '\r') {
            lastWasCR = YES;
          }
          else if (c == '\n') {
            /* finish, found header starting with newline */
            foundEndOfHeaders = YES;
            endOfFieldBody    = YES;
            self->useContentLength = NO;
            _consume(self, 1); // consume newline
            break; /* leave local loop */
          }
        }
        else if ((fnlen == 1) && lastWasCR) {
          if (c == '\n') {
            /* finish, found \r\n */
            foundEndOfHeaders = YES;
            endOfFieldBody    = YES;
            self->useContentLength = NO;
            bufCnt = 0;
            _consume(self, 1); // consume newline
            break; /* leave local loop */
          }
        }
        /* add to buffer */
        buf[bufCnt] = c;
        bufCnt++;
        fnlen++;
        
        _consume(self, 1);
      
        if (bufCnt >= self->bufLen) {
          register int i;

          for (i = 0; i < bufCnt; i++)
            buf[i] = tolower((int)buf[i]);

          
          if (fieldName == nil) {
            fieldName = [[MStringClass alloc] initWithCString:buf length:bufCnt];
          }
          else {
            NSString *s;

            s = [[StringClass alloc] initWithCString:buf length:bufCnt];
            [fieldName appendString:s];
	    [s release]; s = nil;
          }
          bufCnt = 0;
        }
      }
      if (foundEndOfHeaders)
        /* leave main loop */
        break;
      
      if (bufCnt > 0) {
        register int i;

        for (i = 0; i < bufCnt; i++) 
          buf[i] = tolower((int)buf[i]);
	
        if ([fieldName length] == 0) { 
	  /* const headernames are always smaller than bufLen */
          realFieldName = fieldNameForCString(self, buf, bufCnt);
        }
        else {
          NSString *s;

          s = [[StringClass alloc] initWithCString:buf length:bufCnt];
          [fieldName appendString:s];
	  [s release]; s = nil;
          realFieldName = fieldName;
	  
          if (c == -1) {
            NSLog(@"WARNING(%s:%i): 1 an error occured during header-field "
                  @" parsing (maybe end of stream) fieldName: %@",
                  __PRETTY_FUNCTION__, __LINE__, fieldName);
            foundEndOfHeaders = YES;
            endOfFieldBody    = YES;
          }
        }
      }
      else {
        realFieldName = fieldName;
      }
      _consume(self, 1);    // consume ':'
    }
    /* parse fieldBody */

    bufCnt = 0;
    while (!endOfFieldBody) {
      int laC0 = _la(self, 0);
      
      if (laC0 == -1)
        break;
      
      if (laC0 == '\r') {                        // CR
        int laC1 = _la(self, 1);

        if (isRfc822_LWSP(laC1)) {               // CR LSWSP
          _consume(self, 2);  // folding
        }
        else if (laC1 == '\n') {                 // CR LF
          int laC2 = _la(self, 2);

          if (isRfc822_LWSP(laC2)) {             // CR LF LWSP
            _consume(self, 3); // folding
          }
          else if (laC2 == '\r') {               // CR LF CR
            int laC3 = _la(self, 3);

            if (laC3 == '\n') {                  // CR LF CR LF
              _consume(self, 4);
              foundEndOfHeaders = YES;  // end of headers
              endOfFieldBody    = YES;             
            }
            else {                               // CR LF CR *
              _consume(self, 3); // ignored ??
            }
          }
          else if (laC2 == '\n') {               // CR LF LF
            _consume(self, 3);
            foundEndOfHeaders = YES;  // end of headers
            endOfFieldBody    = YES;            
          }
          else {                                 // CR LF *
            _consume(self, 2);
            endOfFieldBody = YES; //  next header field
          }
        }
        else {                                   // CR *
          _consume(self, 1);
          endOfFieldBody = YES; // next header field
        }
      }
      else  if (laC0 == '\n') {                  // LF
        int laC1 = _la(self, 1);

        if (isRfc822_LWSP(laC1)) {               // LF LWSP
          _consume(self, 2); // folding
        }
        else if (laC1 == '\n') {                 // LF LF
          _consume(self, 2);
          foundEndOfHeaders = YES; // end of headers
          endOfFieldBody    = YES; 
        }
        else if (laC1 == '\r') {                 // LF CR
          int laC2 = _la(self, 2);
          
          if (isRfc822_LWSP(laC2)) {             // LF CR LWSP
            _consume(self, 3); // folding
          }
          else if (laC2 == '\n') {               // LF CR LF
            _consume(self, 3); //
            foundEndOfHeaders = YES; // end of headers
            endOfFieldBody    = YES; 
          }
          else {                                 // LF CR *
            _consume(self, 2);
            endOfFieldBody = YES; // next header field
          }
        }
        else {                                   // LF *
          _consume(self, 1);
          endOfFieldBody = YES; // next header field
        }
      }
      else {                                     // *
        if ((bufCnt != 0) || (!isRfc822_LWSP(laC0))) {
          /* ignore leading white spaces */
          buf[bufCnt++] = laC0;
        }
        _consume(self, 1);
        if (bufCnt >= self->bufLen) {
          [fieldValue appendBytes:buf length:bufCnt];
          bufCnt = 0;
        }
      }
    }
    if (bufCnt > 0) {
      [fieldValue appendBytes:buf length:bufCnt];
      bufCnt = 0;
    }
    if (!endOfFieldBody) {
      [self logWithFormat:
	      @"WARNING(%s:%i): 2 an error occured during body parsing "
              @"(maybe end of stream)", __PRETTY_FUNCTION__, __LINE__];
      foundEndOfHeaders = YES;
    }
    if (realFieldName != nil) {
      BOOL keepHeader = YES;

      if (HeaderNames == NULL)
        [NGMimePartParser headerFieldNames];

      if (realFieldName == HeaderNames->contentTransferEncoding) {
        int                 len;
        const unsigned char *cstr;

        len  = [fieldValue length];
        cstr = [fieldValue bytes];
          
        keepHeader = NO; // don't keep content-tranfer-encodings
          
        while (isRfc822_LWSP(*cstr) && (len > 0)) { // strip leading spaces
          cstr++;
          len--;
        }
        if (len > 0) { // len==0 means the value was a string of LWSP
          [self->contentTransferEncoding release];
          self->contentTransferEncoding =
            [[StringClass alloc] initWithCString:(char *)cstr length:len];
        }
        else {
          [self->contentTransferEncoding release];
	  self->contentTransferEncoding = nil;
	}
      }
      /*
        take a look on content-length headers, since the parser
        needs to know this for reading in the body ..
      */
      if (keepHeader && self->useContentLength) {
        if (realFieldName == HeaderNames->contentLength) {
          int                 len;
	  const unsigned char *cstr;
          
          len  = [fieldValue length];
          cstr = [fieldValue bytes];

          while (isRfc822_LWSP(*cstr) && (len > 0)) { // strip leading spaces
            cstr++;
            len--;
          }
          if (len > 0) { // len==0 means the value was a string of LWSP
            unsigned char buf[len + 1];
            int i = 0;

            while (isdigit(*cstr) && (i < len)) { // extract following digits
              buf[i++] = *cstr;
              cstr++;
            }
            buf[i] = '\0'; // stop string after last digit (ignore the rest)
            self->contentLength = atoi((char *)buf);
          }
          else {
            /* header value are only spaces */
            self->contentLength = -1;
          }
        }
      }
      /* ask delegate if the header is to be kept */
      if (keepHeader) {
        if (self->delegateRespondsTo.parserKeepHeaderFieldData)
          keepHeader = [self->delegate parser:self
                                       keepHeaderField:realFieldName
                                       data:fieldValue];
      }
      if (keepHeader) {
        id value = nil;

        value = [self valueOfHeaderField:realFieldName
                      data:fieldValue];

        if (value) {
          value = [value retain];
          /* ask delegate if the header is to be kept */
          if (self->delegateRespondsTo.parserKeepHeaderFieldValue) {
            keepHeader = [self->delegate parser:self
                                         keepHeaderField:realFieldName
                                         value:value];
          }
          if (keepHeader) {
            NSAssert(realFieldName, @"missing field name ..");
            NSAssert(value,     @"missing field value ..");

            /*
              check whether content-length, content-type,
              subject already in hashmap
            */
            if (_checkKey(self, header, realFieldName))
              [header addObject:value forKey:realFieldName];
          }
          [value release];
        }
      }
    }
  }
  if (buf) {
    free(buf);
    buf = NULL;
  }
  
  if (self->delegateRespondsTo.parserDidParseHeader)
    [self->delegate parser:self didParseHeader:header];
  
  header = [header retain];
  [pool release];
  
  return [header autorelease];
}

- (NSData *)readBodyUnknownLengthStream {
  static NSMutableData *dataObject = nil;
  NGIOReadMethodType readBytes = NULL;
  NSData             *rbody;
  NSMutableData      *body;
  int  bufCnt;
  char buf[self->bufLen];
  void (*appendBytes)(id,SEL,const void *,unsigned);
  BOOL decodeBase64;
  
  *(&readBytes) = NULL;
  
  if ([self->source respondsToSelector:@selector(methodForSelector:)]) {
    readBytes = (NGIOReadMethodType)
                [self->source methodForSelector:@selector(readBytes:count:)];
  }
  
  *(&appendBytes) = NULL;
  *(&bufCnt)      = 0;
  
  // THREAD
  /* check whether we can reuse the dataObj ... */
  if (dataObject) {
    *(&body) = [dataObject autorelease];
    dataObject = nil; /* mark as used ... */
  }
  else {
    *(&body) = [[[NSMutableData alloc] initWithCapacity:100010] autorelease];
  }

  decodeBase64 = NO;
  appendBytes  = (void(*)(id,SEL,const void *, unsigned))
    [body methodForSelector:@selector(appendBytes:length:)];
  
  NS_DURING {
    while (YES) {
      NSException *e;

      NS_DURING {
        _la(self, self->bufLen - 1);
      }
      NS_HANDLER {
        if (![localException isKindOfClass:[NGEndOfStreamException class]])
          [localException raise];
      }
      NS_ENDHANDLER;
      
      e = nil;
      bufCnt = (readBytes != NULL)
	? readBytes(self->source, @selector(readBytes:count:),
		    buf, self->bufLen)
	: [self->source readBytes:buf count:self->bufLen];

      if (bufCnt == NGStreamError) {
	e = [self->source lastException];
          
	if ([e isKindOfClass:[NGEndOfStreamException class]])
	  /* leave loop */
	  break;
	else
	  [e raise];
      }
      
      /* perform any on-the-fly encodings */
      
      /* add to body data */
      appendBytes(body, @selector(appendBytes:length:), buf, bufCnt);
      bufCnt = 0;
    }
  }
  NS_HANDLER {
    if (![localException isKindOfClass:[NGEndOfStreamException class]])
      [localException raise];
  }
  NS_ENDHANDLER;
  if (bufCnt > 0 && bufCnt != NGStreamError) {
    appendBytes(body, @selector(appendBytes:length:), buf, bufCnt);
    bufCnt = 0;
  }
  
  if (decodeBase64) {
    ASSIGN(self->contentTransferEncoding, (id)nil);
  }
  rbody = [body copy];
  // THREAD
  /* remember that object for reuse ... */
  if (dataObject == nil && [body length] < MAX_DATA_OBJECT_SIZE_CACHE) {
    dataObject = [body retain];
    [dataObject setLength:0];
  }
  
  return [rbody autorelease];
}

- (NSData *)readBodyUnknownLengthData {
  return [self->sourceData subdataWithRange:
              NSMakeRange(self->dataIdx, self->byteLen - self->dataIdx)];
}

- (NSData *)readBodyUnknownLength {
  return (self->source)
    ? [self readBodyUnknownLengthStream]
    : [self readBodyUnknownLengthData];
}

- (NSData *)readBodyWithKnownLengthFromStream:(unsigned)_len {
  NGIOReadMethodType readBytes = NULL;
  NSData             *rbody = nil;
  unsigned char *buf = NULL;
  int  readB     = 0;
  
  *(&readBytes) = NULL;
  
  if ([self->source respondsToSelector:@selector(methodForSelector:)]) {
    readBytes = (NGIOReadMethodType)
                [self->source methodForSelector:@selector(readBytes:count:)];
  }
  

  *(&buf) = NULL;
  readB   = 0;
    
  buf = calloc(_len, sizeof(char));
    
  NS_DURING {

    NS_DURING {
    if (self->contentLength > self->bufLen)
      _la(self, self->bufLen - 1);
    else
      _la(self, self->contentLength - 1);
    }
    NS_HANDLER {
      if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
        fprintf(stderr,
                "WARNING(%s): EOF occurred before whole content was read "
                "(content-length=%i, read=%i)\n", __PRETTY_FUNCTION__,
                self->contentLength, readB);
      }
      else {
        if (buf) free(buf);
        [localException raise];
      }
    }
    NS_ENDHANDLER;
      
      
    while (self->contentLength != readB) {
      int tmp = self->contentLength - readB;
        
      readB += (readBytes != NULL)
	? readBytes(self->source, @selector(readBytes:count:),
		    (buf + readB), tmp)
	: [self->source readBytes:(buf + readB) count:tmp];

      if (readB == NGStreamError) {
	[[self->source lastException] raise];
      }
        
      tmp = self->contentLength - readB;
      if (tmp > 0) {
	if (tmp > self->bufLen)
	  _la(self, self->bufLen - 1);
	else
	  _la(self, tmp - 1);
      }
    }
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
      fprintf(stderr,
	      "WARNING(%s): EOF occurred before whole content was read "
	      "(content-length=%i, read=%i)\n", __PRETTY_FUNCTION__,
	      self->contentLength, readB);
    }
    else {
      if (buf) free(buf);
      [localException raise];
    }
  }
  NS_ENDHANDLER;
  
  rbody = buf ? [NSData dataWithBytes:buf length:readB] : nil;
  if (buf) free(buf);
  return rbody;
}

- (NSData *)readBodyWithKnownLengthFromData:(unsigned)_len {
  NSData *data;

  data = [self->sourceData subdataWithRange:
              NSMakeRange(self->dataIdx, self->byteLen - self->dataIdx)];
  if ([data length] != _len) {
    NSLog(@"%s[%i]: got wrong data %d _len %d", __PRETTY_FUNCTION__, __LINE__,
          [data length], _len);
    return nil;
  }
  return data;
}

- (NSData *)readBodyWithKnownLength:(unsigned)_len {
  return (self->source != nil)
    ? [self readBodyWithKnownLengthFromStream:_len]
    : [self readBodyWithKnownLengthFromData:_len];
}

- (NSData *)applyTransferEncoding:(NSString *)_enc onData:(NSData *)_data{
  // Note: this method is used in WebUI
  return [_data dataByApplyingMimeContentTransferEncoding:_enc];
}

- (NSData *)readBody {
  /* Read data of body and apply content-transfer-encoding if required. */
  NSAutoreleasePool *pool;
  NSData            *rbody = nil;
  
  pool = [[NSAutoreleasePool alloc] init];

  if ((self->contentLength == -1) || (self->contentLength == 0)) {
    rbody = [self readBodyUnknownLength];
  }
  else {
    /* note: this is called only, if self->useContentLength is set ! */
    rbody = [self readBodyWithKnownLength:self->contentLength];
  }

  if ([self->contentTransferEncoding length] > 0) {
    NSData *new;
    
    new = [self applyTransferEncoding:self->contentTransferEncoding
		onData:rbody];
    if (new) {
      ASSIGN(self->contentTransferEncoding, (id)nil);
      rbody = new;
    }
    else {
      [self logWithFormat:@"WARNING(%s): "
	      @"encountered unknown content-transfer-encoding: '%@'",
              __PRETTY_FUNCTION__,
              self->contentTransferEncoding];
    }
  }
  
  rbody = [rbody retain];
  [pool release];
  return [rbody autorelease];
}

- (NSData *)decodeBody:(NSData *)_data ofPart:(id<NGMimePart>)_part {
  return (self->delegateRespondsTo.parserDecodeBodyOfPart)
    ? [self->delegate parser:self decodeBody:_data ofPart:_part]
    : _data;
}

- (NGMimeType *)defaultContentTypeForPart:(id<NGMimePart>)_part {
  static NGMimeType *octetType = nil;
  
  if (octetType == nil)
    octetType = [[NGMimeType mimeType:@"application/octet-stream"] retain];
  return octetType;
}

- (id<NGMimeBodyParser>)parserForBodyOfPart:(id<NGMimePart>)_p
  data:(NSData *)_dt
{
  id                   ctype;
  NGMimeType           *contentType;
  id<NGMimeBodyParser> bodyParser   = nil;
  
  ctype = [_p contentType];
  if (!ctype
      && self->delegateRespondsTo.parserContentTypeOfPart)
    ctype = [self->delegate parser: self contentTypeOfPart: _p];

  contentType = ([ctype isKindOfClass:[NGMimeType class]])
    ? ctype
    : [NGMimeType mimeType:[ctype stringValue]];
  
  if (self->delegateRespondsTo.parserBodyParserForPart) {
    if ((bodyParser = [self->delegate parser:self bodyParserForPart:_p]))
      return bodyParser;
  }
  
  if (contentType == nil) {
    contentType = [self defaultContentTypeForPart:_p];
  }
  
  if (contentType) {
    if ([[contentType type] isEqualToString:@"multipart"]) {
      bodyParser = [[[NGMimeMultipartBodyParser alloc] init] autorelease];
    }
    else if ([[contentType type] isEqualToString:@"text"] &&
             [[contentType subType] isEqualToString:@"plain"]) {
      bodyParser = [[[NGMimeTextBodyParser alloc] init] autorelease];
    }
  }
  return bodyParser;
}

- (void)parseBodyOfPart:(id<NGMimePart>)_part {
  NGMimeBodyParser *parser  = nil;
  NSData           *rawBody = nil;
  id               body     = nil;

  rawBody = [self readBody];

  /* apply content-encoding, transfer-encoding and similiar */
  rawBody = [self decodeBody:rawBody ofPart:_part];

  if (self->delegateRespondsTo.parserParseRawBodyDataOfPart) {
    BOOL didParse;

    didParse =
      [self->delegate parser:self parseRawBodyData:rawBody ofPart:_part];

    if (didParse) return;
  }
  
  parser = (NGMimeBodyParser *)[self parserForBodyOfPart:_part data:rawBody];
  if (parser) {
    /* make sure delegate keeps being around .. */
    self->delegate = [[self->delegate retain] autorelease];

    body = [parser parseBodyOfPart:_part
                   data:rawBody
                   delegate:self->delegate];
  }
  else if (rawBody) { /* no parser found for body */
    if (body == nil) body = rawBody;
  }
  [_part setBody:body];
}

/* part */

- (id<NGMimePart>)producePartWithHeader:(NGHashMap *)_header {
  [self subclassResponsibility:_cmd];
  return nil;
}

- (BOOL)prepareForParsingFromData:(NSData *)_data {
  if (_data == nil)
    return NO;

  ASSIGN(self->sourceData, _data);
  self->sourceBytes   = [self->sourceData bytes];
  self->byteLen       = [self->sourceData length];
  self->dataIdx       = 0;
  self->contentLength = -1;

  return YES;
}

- (BOOL)prepareForParsingFromStream:(id<NGStream>)_stream {
  if (_stream == nil)
    return NO;
  
  if (self->source != _stream) {
    NGByteBuffer *bb;

    bb = [NGByteBuffer alloc];
    bb = [bb initWithSource:_stream la:self->bufLen];
    [self->source release];
    self->source = bb;
  }
  if ([self->source respondsToSelector:@selector(methodForSelector:)]) {
    self->la         = (int (*)(id, SEL, unsigned))
                       [self->source methodForSelector:@selector(la:)];
    self->consume    = (void (*)(id, SEL))
                       [self->source methodForSelector:@selector(consume)];
    self->consumeCnt = (void (*)(id, SEL, unsigned))
                       [self->source methodForSelector:@selector(consume:)];
  }
  else {
    self->la         = NULL;
    self->consume    = NULL;
    self->consumeCnt = NULL;
  }
  self->contentLength = -1;

  return YES;
}

- (void)finishParsingOfPart:(id<NGMimePart>)_part {
  [self->source release]; self->source = nil;
  self->contentLength = -1;
  
  self->la         = NULL;
  self->consume    = NULL;
  self->consumeCnt = NULL;
}

- (void)finishParsingOfPartFromData:(id<NGMimePart>)_part {
  [self->sourceData release]; self->sourceData = nil;
  self->sourceBytes   = NULL;
  self->byteLen       = 0;
  self->dataIdx       = 0;
  self->contentLength = -1;
}

- (BOOL)parsePrefix {
  return YES;
}

- (void)parseSuffix {
}

- (id<NGMimePart>)parsePart {
  id<NGMimePart> part = nil;
  NGHashMap *header;
  BOOL      doParse = YES;
  
  if (![self parsePrefix])
    return nil;
  
  if ((header = [self parseHeader]) == nil)
    return nil;
  
  part = [self producePartWithHeader:header];
  
  doParse = (delegateRespondsTo.parserWillParseBodyOfPart)
    ? [delegate parser:self willParseBodyOfPart:part]
    : YES;
  
  if (doParse) {
    NSAutoreleasePool *pool;

    pool = [[NSAutoreleasePool alloc] init];
    [self parseBodyOfPart:part];
    [pool release];
    
    if (delegateRespondsTo.parserDidParseBodyOfPart)
      [delegate parser:self didParseBodyOfPart:part];
    
    [self parseSuffix];
  }
  return part;
}

- (id<NGMimePart>)parsePartFromStream:(id<NGStream>)_stream {
  id<NGMimePart> p;
  
  if (![self prepareForParsingFromStream:_stream])
    return nil;
  
  p = [self parsePart];
  [self finishParsingOfPart:p];
  return p;
}

- (id<NGMimePart>)parsePartFromData:(NSData *)_data {
  id<NGMimePart> part;
  
  if ([_data isKindOfClass:NSMutableDataClass]) {
    NGDataStream *dataStream;
  
    dataStream = [NGDataStream streamWithData:_data];
    part = [self parsePartFromStream:dataStream];
    [dataStream close];
    return part;
  }

  if ([self prepareForParsingFromData:_data]) {
    part = [self parsePart];
    [self finishParsingOfPartFromData:part];
    return part;
  }
  
  return nil;
}

/* accessors */

- (BOOL)doesUseContentLength {
  return self->useContentLength;
}
- (void)setUseContentLength:(BOOL)_use {
  self->useContentLength = _use;
}

/* functions */

static inline int _la(NGMimePartParser *self, int _la) {
  if (self->source) {
    return (self->la != NULL) ? self->la(self->source, @selector(la:), _la)
      : [self->source la:_la];
  }
  else {
    if ((self->dataIdx+_la) < self->byteLen)
      return self->sourceBytes[self->dataIdx+_la];
    else
      return -1;
  }
}

static inline void _consume(NGMimePartParser *self, int _cnt) {
  if (self->source) {
    if (_cnt == 1) {
      if (self->consume != NULL)
        self->consume(self->source, @selector(consume));
      else
        [self->source consume];
    }
    else {
      if (self->consumeCnt != NULL)
        self->consumeCnt(self->source, @selector(consume:), _cnt);
      else
        [self->source consume:_cnt];
    }
  }
  else {
    if ((self->dataIdx+_cnt) <= self->byteLen) {
      self->dataIdx += _cnt;
    }
    else {
      NSLog(@"%s[%i]: error try to read over buffer len self->dataIdx %d "
            @"_cnt %d byteLen %d", __PRETTY_FUNCTION__, __LINE__,
            self->dataIdx, _cnt, self->byteLen);
    }
  }
}

static inline BOOL _checkKey(NGMimePartParser *self, NGHashMap *_map,
                             NSString *_key)
{
  if (HeaderNames == NULL)
    [NGMimePartParser headerFieldNames];
  
  if  ((_key == HeaderNames->contentLength) ||
       _key == HeaderNames->contentType) {
    if ([_map countObjectsForKey:_key] > 0)
      return NO;
  }
  return YES;
}
 
@end /* NGMimePartParser */
