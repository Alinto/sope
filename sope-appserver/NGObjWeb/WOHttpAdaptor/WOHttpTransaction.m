/*
  Copyright (C) 2000-2008 SKYRIX Software AG
  Copyright (C) 2008      Helge Hess

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

#include "WOHttpTransaction.h"
#include "WORecordRequestStream.h"
#include "WOHttpAdaptor.h"
#include "WORequest+Adaptor.h"
#include "NGHttp+WO.h"
#include "WOSimpleHTTPParser.h"
#include <NGObjWeb/WOCoreApplication.h>
#include <NGObjWeb/WORequest.h>
#include <NGObjWeb/WOResponse.h>
#include <NGObjWeb/WOCookie.h>
#include <NGExtensions/NSData+gzip.h>
#include <NGHttp/NGHttp.h>
#include <NGMime/NGMimeType.h>
#include "common.h"

#include <string.h>
#include <sys/time.h>

static inline NSString *
capitalizeHeaderName (NSString *headerName)
{
  NSString *result;
  NSUInteger count, max;
  unichar *chars;
  BOOL capitalize = YES;

  max = [headerName length];
  if (max == 3 && [[headerName lowercaseString] isEqualToString: @"dav"])
    result = @"DAV";
  else
    {
      chars = malloc (max * sizeof (unichar));
      [headerName getCharacters: chars];
      for (count = 0; count < max; count++)
        {
          if (capitalize)
            {
              if (chars[count] >= 97 && chars[count] <= 122)
                chars[count] -= 32;
              capitalize = NO;
            }
          else if (chars[count] == '-')
            capitalize = YES;
        }
      result = [NSString stringWithCharacters: chars length: max];
      free (chars);
    }

  return result;
}

@interface WORequest(UsedPrivates)
- (NSCalendarDate *)startDate;
- (id)startStatistics;
@end

int      WOAsyncResponseStatus = 20001;
NSString *WOAsyncResponseTokenKey = @"WOAsyncResponseToken";
NSString *WOAsyncResponseReadyNotificationName =
  @"WOAsyncResponseReadyNotification";
NSString *WOAsyncResponse = @"WOAsyncResponse";
static BOOL     WOHttpAdaptor_LogStream      = NO;

@interface WOCoreApplication(SimpleParserSelection)

- (BOOL)shouldUseSimpleHTTPParserForTransaction:(id)_tx;

@end

@implementation WOHttpTransaction

static NSMutableDictionary *pendingTransactions = nil; // THREAD
static BOOL useSimpleParser = YES;
static int  doCore  = -1;
static BOOL capitalizeHeaders;
static NSString *adLogPath         = nil;
static NGLogger *debugLogger       = nil;
static NGLogger *perfLogger        = nil;
static NGLogger *transActionLogger = nil;

+ (int)version {
  return 2;
}
+ (void)initialize {
  NSUserDefaults  *ud;
  NGLoggerManager *lm;
  static BOOL didInit = NO;

  if (didInit) return;
  didInit = YES;

  lm                = [NGLoggerManager defaultLoggerManager];
  perfLogger        = [lm loggerForDefaultKey:@"WOProfileHttpAdaptor"];
  debugLogger       = [lm loggerForDefaultKey:@"WODebugHttpTransaction"];
  transActionLogger = [lm loggerForClass:self];

  ud = [NSUserDefaults standardUserDefaults];
  useSimpleParser = [ud boolForKey:@"WOHttpTransactionUseSimpleParser"];
  doCore = [[ud objectForKey:@"WOCoreOnHTTPAdaptorException"] boolValue]?1:0;
  capitalizeHeaders = [[ud objectForKey:@"WOHTTPAdaptorCapitalizeHeaders"] boolValue];
  WOHttpAdaptor_LogStream = [ud boolForKey:@"WOHttpAdaptor_LogStream"];
  
  adLogPath = [[ud stringForKey:@"WOAdaptorLogPath"] copy];
  if (adLogPath == nil) adLogPath = @"";
}

- (BOOL)optionLogStream {
  return WOHttpAdaptor_LogStream;
}
- (BOOL)optionLogPerf {
  return perfLogger ? YES : NO;
}

- (BOOL)isDebuggingEnabled {
  return debugLogger ? YES : NO;
}

- (id)initWithSocket:(id<NGActiveSocket>)_socket
  application:(WOCoreApplication *)_app
{
  NSAssert(_socket, @"missing socket ...");
  NSAssert(_app,    @"missing application ...");
  self->socket      = [_socket retain];
  self->application = [_app    retain];
  if ([[_app recordingPath] length] > 0)
    WOHttpAdaptor_LogStream = YES;

  return self;
}

- (void)dealloc {
#if 0
  [self debugWithFormat:@"dealloc ..."];
#endif
  [self reset];
  [self->socket        release];
  [self->lastException release];
  [self->application   release];
  [super dealloc];
}

/* state management */

- (void)reset {
  if (self->asyncResponseToken) {
    [self warnWithFormat:
            @"resetting while async response pending ... (%@)",
            self->asyncResponseToken];
    abort();
    
    [[self notificationCenter] removeObserver:self];
  }
  [self->asyncResponseToken release]; self->asyncResponseToken = nil;
  [self->io         release]; self->io         = nil;
  [self->log        release]; self->log        = nil;
  [self->startDate  release]; self->startDate  = nil;
  [self->woRequest  release]; self->woRequest  = nil;
  [self->woResponse release]; self->woResponse = nil;
}

- (BOOL)closeConnectionAfterDelivery {
  return YES;
}

- (void)start {
  self->startDate = [[NSDate alloc] init];
  self->t = [self->startDate timeIntervalSince1970];
}
- (void)finish {
  if (self->woResponse == nil)
    return;

  [self logResponse:self->woResponse toRequest:self->woRequest
        connection:self->socket];

  if (perfLogger) {
      struct timeval tv;
      gettimeofday(&tv, NULL);
      self->t = (((double)tv.tv_sec) * ((double)tv.tv_usec) / 1000.0)  - 
        self->t;
      [perfLogger logWithFormat:@"processing of request took %4.3fs.", 
	                  self->t < 0.0 ? -self->t : self->t];
  }
}

- (BOOL)_setupStreamsForSocket {
  if ([self optionLogStream]) {
    self->log = [(WORecordRequestStream *)[WORecordRequestStream alloc] 
      initWithSource:self->socket];
    self->io  = [(NGBufferedStream *)[NGBufferedStream alloc] 
      initWithSource:self->log];
  }
  else {
    self->log = nil;
    self->io = [(NGBufferedStream *)[NGBufferedStream alloc] 
      initWithSource:self->socket];
  }
  return self->io != nil ? YES : NO;
}

static int logCounter = 0;

- (NSString *)currentRecordingPath:(NSString *)_suffix {
  static NSString *s = nil;
  NSString *p;
  
  if (s == nil) {
    s = [[self->application recordingPath] copy];
    if (s == nil) s = @"";
  }
  if ([s length] == 0) return nil;
  
  p = [NSString stringWithFormat:@"%04i-%@", logCounter, _suffix];
  return [s stringByAppendingPathComponent:p];
}

- (void)logRequestData:(NSData *)_data {
  NSString *logPath = nil;
  
  if (![self optionLogStream]) return;
  logCounter++;
  
  if ([adLogPath length] > 0)
    logPath = adLogPath;
  else if ([logPath length] == 0)
    logPath = [self currentRecordingPath:@"request"];
  
  if ([logPath length] == 0)
    logPath = @"/tmp/woadaptor.log";
  
  [_data writeToFile:logPath atomically:NO];
  
#if 1
  NSLog(@"request is\n");
  fflush(stderr);
  fwrite([_data bytes], 1, [_data length], stderr);
  fflush(stderr);
  fprintf(stderr,"\n");
  fflush(stderr);
#endif
}

- (void)logResponse:(WOResponse *)_response
  toRequest:(WORequest *)_request
  data:(NSData *)_data
{
  NSString *logPath;
  
  if (_data == nil) return;
  
  if ((int)[_response status] == (int)WOAsyncResponseStatus)
    return;
  
#if 1
  NSLog(@"response is\n");
  fflush(stderr);
  fwrite([_data bytes], 1, [_data length], stderr);
  fflush(stderr);
  fprintf(stderr,"\n");
  fflush(stderr);
#endif
  
  if ((logPath = [self currentRecordingPath:@"response"]) == nil)
    return;
  
  [_data writeToFile:logPath atomically:NO];
}

- (void)applyAdaptorHeadersWithHttpRequest:(NGHttpRequest *)request {
  /* apply some adaptor headers in direct-connect mode  */

  if (woRequest == nil) return;
  
  if ([woRequest headerForKey:@"x-webobjects-server-url"] == nil) {
    NSString *tmp;
    
    if ((tmp = [woRequest headerForKey:@"host"])) {
      if ([tmp hasSuffix:@":0"] && ([tmp length] > 2)) // TODO: bad bad bad
	tmp = [tmp substringToIndex:([tmp length] - 2)];
      tmp = [@"http://" stringByAppendingString:tmp];
      [woRequest setHeader:tmp forKey:@"x-webobjects-server-url"];
    }
  }
  if ([woRequest headerForKey:@"x-webobjects-server-name"] == nil) {
    NSString *tmp;
    
    if ((tmp = [woRequest headerForKey:@"host"])) {
      NSRange r = [tmp rangeOfString:@":"];
      if (r.length > 0) tmp = [tmp substringToIndex:r.location];
      [woRequest setHeader:tmp forKey:@"x-webobjects-server-name"];
    }
  }
  if ([[woRequest headerForKey:@"x-webobjects-server-port"] intValue] < 1) {
    id tmp;
    
    if ((tmp = [woRequest headerForKey:@"host"])) {
      NSRange r = [tmp rangeOfString:@":"];
      if (r.length > 0) tmp = [tmp substringFromIndex:r.location + r.length];
      tmp = [NSNumber numberWithInt:[tmp intValue]];
      [woRequest setHeader:tmp forKey:@"x-webobjects-server-port"];
    }
  }
  
  if ([woRequest headerForKey:@"x-webobjects-remote-host"] == nil) {
    id<NGSocketAddress> remote = nil;
    NSString *remoteHost = nil;
    
    remote = [self->socket remoteAddress];
    
    if ([remote isKindOfClass:[NGInternetSocketAddress class]])
      remoteHost = [(NGInternetSocketAddress *)remote hostName];
#if !defined(__MINGW32__)
    else if ([remote isKindOfClass:[NGLocalSocketAddress class]])
      remoteHost = @"local";
#endif

    if ([remoteHost length] > 0)
      [woRequest setHeader:remoteHost forKey:@"x-webobjects-remote-host"];
  }
        
  if ([woRequest headerForKey:@"x-webobjects-remote-user"] == nil) {
    id auth;
          
    auth = [[request valuesOfHeaderFieldWithName:@"authorization"]
                     nextObject];
    if (auth) {
      if (![auth isKindOfClass:[NGHttpCredentials class]]) {
        auth =
          [NGHttpCredentials credentialsWithString:[auth stringValue]];
      }
            
      [woRequest setHeader:[auth userName]
                 forKey:@"x-webobjects-remote-user"];
      [woRequest setHeader:[auth scheme]
                 forKey:@"x-webobjects-auth-type"];
    }
  }
}

- (WOResponse *)generateMissingResponse {
  WOResponse *mr;
  NSString   *accept;

  mr = [WOResponse alloc];
  mr = [mr initWithRequest:self->woRequest];
  [mr setHTTPVersion:[woRequest httpVersion]];
  [mr setStatus:500];
  
  accept = [woRequest headerForKey:@"accept"];
  
  if ([accept rangeOfString:@"text/html"].length > 0) {
    const char *txt = "could not perform request !<br />";
    [mr setHeader:@"text/html" forKey:@"content-type"];
    [mr setContent:[NSData dataWithBytes:txt length:strlen(txt)]];
  }
  return [mr autorelease];
}

- (BOOL)_readRequest {
  id request = nil;

  if (self->woRequest)
    [self warnWithFormat:@"woRequest already set ???"];
  
  if ([self->application shouldUseSimpleHTTPParserForTransaction:self]) {
    WOSimpleHTTPParser *parser;
    
    parser = [[WOSimpleHTTPParser alloc] initWithStream:self->io];
    self->woRequest = [[parser parseRequest] retain];
    
    if (self->woRequest == nil) {
      ASSIGN(self->lastException, [parser lastException]);
      [self errorWithFormat:@"failed to parse request: %@", self->lastException];
    }
    [parser release];
  }
  else {
    if ((request = [self parseRequestFromStream:self->io]) == nil)
      return NO;
    
#if DEBUG
    NSAssert([request isKindOfClass:[NGHttpRequest class]],
	     @"invalid request class");
#endif
    self->woRequest = [[request woRequest] retain];
  }
  [self logRequestData:[log readLog]];
  [log resetReadLog];
  
  if ([self->woRequest isCodeRedAttack]) {
    [self logWithFormat:
            @"WOHttpAdaptor: detected 'Code Red' request: '%@', blocking.",
            [self->woRequest uri]];
    ASSIGN(self->woRequest, (id)nil);
    return NO;
  }
  
  [self->woRequest takeStartDate:self->startDate];
  
  /* apply some adaptor headers in direct-connect mode  */
  [self applyAdaptorHeadersWithHttpRequest:request];
  
  if (perfLogger) {
    NSTimeInterval rt;
    self->requestFinishTime = [[NSDate date] timeIntervalSince1970];
    rt = self->requestFinishTime - self->t;
    [perfLogger logWithFormat:@"decoding of request took %4.3fs.",
                  rt < 0.0 ? -1.0 : rt];
  }
  
  return self->woRequest ? YES : NO;
}

- (BOOL)_sendResponse {
  if (perfLogger) {
    NSTimeInterval rt;
    self->dispatchFinishTime = [[NSDate date] timeIntervalSince1970];
    rt = self->dispatchFinishTime - self->requestFinishTime;
    [perfLogger logWithFormat:@"dispatch of request took %4.3fs.",
                  rt < 0.0 ? -1.0 : rt];
  }
  
  if (self->woResponse != nil) {
    [self deliverResponse:self->woResponse
          toRequest:self->woRequest
          onStream:self->io];
    
    if (perfLogger) {
      NSTimeInterval rt;
      rt = [[NSDate date] timeIntervalSince1970] - dispatchFinishTime;
      [perfLogger logWithFormat:@"delivery of request took %4.3fs.",
                    rt < 0.0 ? -1.0 : rt];
    }
  }
  else if (self->woRequest != nil) {
    [self errorWithFormat:@"got no response for request %@ ..",
            self->woRequest];
      
    self->woResponse = [[self generateMissingResponse] retain];
    
    [self deliverResponse:self->woResponse
          toRequest:self->woRequest
          onStream:self->io];
  }
  
  if (![self->io flush]) {
    ASSIGN(self->lastException, [self->io lastException]);
    return NO;
  }
  
  if ([self closeConnectionAfterDelivery]) {
    [self debugWithFormat:@"close connection: %@", self->io];
    if (![self->io close]) {
      ASSIGN(self->lastException, [self->io lastException]);
      [self debugWithFormat:@"close failed: %@", self->lastException];
      return NO;
    }
  }
  else
    [self debugWithFormat:@"not closing connection ..."];
  
  return YES;
}

- (NSNotificationCenter *)notificationCenter {
  return [NSNotificationCenter defaultCenter];
}

- (void)responseReady:(NSNotification *)_notification {
  WOResponse *response;
  
  if ([self->asyncResponseToken length] == 0) {
    [self errorWithFormat:
            @"got response ready notification (%@), "
            @"but no async HTTP transaction is in progress ...",
            _notification];
    return;
  }
  if (![self->asyncResponseToken isEqual:[_notification object]]) {
    [self errorWithFormat:
            @"got response ready notification (%@) for a different "
            @"token (%@ vs %@) !",
            _notification, self->asyncResponseToken, [_notification object]];
    return;
  }
  
  /* OK, everything seems to be correct, so we received a response .. */
  
  [[self retain] autorelease];
  [pendingTransactions removeObjectForKey:self->asyncResponseToken];
  
  response = [[_notification userInfo] objectForKey:WOAsyncResponse];
  ASSIGN(self->woResponse, response);
  
  [[self notificationCenter] removeObserver:self];
  [self->asyncResponseToken release]; self->asyncResponseToken = nil;
  
  /* send response */
  
  [self debugWithFormat:@"sending async response: %@", self->woResponse];
  [self _sendResponse];
  
  [self debugWithFormat:@"logging async response: %@", self->woResponse];
  [self logResponse:self->woResponse
        toRequest:self->woRequest
        data:[log writeLog]];
  [log resetWriteLog];
  
  [self finish];
  [self reset];

  [self->io  release]; self->io  = nil;
  [self->log release]; self->log = nil;
}

- (BOOL)_enterAsyncMode:(WOResponse *)_response {
  NSString *token;
  
  [self debugWithFormat:@"enter async mode ..."];
  
  if (pendingTransactions == nil)
    pendingTransactions = [[NSMutableDictionary alloc] initWithCapacity:16];
  
  [self debugWithFormat:@"PENDING: %@", pendingTransactions];
  
  NSAssert1((int)[_response status] == (int)WOAsyncResponseStatus,
            @"passed in an invalid response %@ ...", _response);
  
  token = [[_response userInfo] objectForKey:WOAsyncResponseTokenKey];
  if ([token length] == 0) {
    [self errorWithFormat:@"missing async response token in response %@",
            _response];
    return NO;
  }

  [self debugWithFormat:@"using token: %@", token];
  ASSIGN(self->asyncResponseToken, token);
  
  [pendingTransactions setObject:self forKey:self->asyncResponseToken];
  
  [[self notificationCenter]
         addObserver:self selector:@selector(responseReady:)
         name:WOAsyncResponseReadyNotificationName
         object:self->asyncResponseToken];
  
  return YES;
}

- (BOOL)_run {
  if (![self _setupStreamsForSocket])
    return NO;
  
  if (![self _readRequest])
    return NO;
  
  /* dispatch request */
  
  if (self->woRequest)
    self->woResponse = [[self->application dispatchRequest:woRequest] retain];
  else
    self->woResponse = nil;
  
  if (self->woResponse) {
    if ((int)[self->woResponse status] == (int)WOAsyncResponseStatus) {
      /* switch to async mode ... */
      if ([self _enterAsyncMode:self->woResponse]) {
        [self logResponse:self->woResponse
              toRequest:self->woRequest
              data:nil];
        return YES;
      }
    }
  }
  
  /* send response */
  
  [self _sendResponse];
  
  [self logResponse:self->woResponse
        toRequest:self->woRequest
        data:[self->log writeLog]];
  [self->log resetWriteLog];
    
  [self->io  release]; self->io  = nil;
  [self->log release]; self->log = nil;
  return YES;
}

- (NSException *)lastException {
  return self->lastException;
}

- (BOOL)_catchedException:(NSException *)localException {
  if ([localException isKindOfClass:[NGSocketShutdownException class]])
    return YES;
  
  ASSIGN(self->lastException, localException);
  
#if DEBUG
  if (doCore) abort();
#endif
  return NO;
}

- (BOOL)run {
  BOOL ok = YES;
  
  [self reset];
  [self start];
  
  NS_DURING {
    if (![self _run])
      ok = NO;
  }
  NS_HANDLER
    ok = [self _catchedException:localException];
  NS_ENDHANDLER;
  
  if (self->asyncResponseToken == nil) {
    [self finish];
    [self reset];
  }
  
  return ok;
}

- (NGHttpRequest *)parseRequestFromStream:(id<NGStream>)_in {
  NGHttpMessageParser *parser = nil;
  volatile id request = nil;
  NSString *format = @"parsing of request failed with exception: %@";
  
  NS_DURING {
    *(&parser) = [[NGHttpMessageParser alloc] init];
    [parser setDelegate:self];
    
    request = [parser parseRequestFromStream:_in];
    
    [parser release]; parser = nil;
  }
  NS_HANDLER {
    [self errorWithFormat:format, localException];
    [parser release]; parser = nil;
    [localException raise];
  }
  NS_ENDHANDLER;

  return request;
}

- (const unsigned char *)_reasonForStatus:(unsigned int)_status {
  const char *reason;
  
  switch (_status) {
    case 200: reason = "OK";           break;
    case 201: reason = "Created";      break;
    case 204: reason = "No Content";   break;
    case 207: reason = "Multi-Status"; break;
    
    case 302: reason = "Found";        break;
    case 304: reason = "Not Modified"; break;
      
    case 401: reason = "Authorization Required"; break;
    case 402: reason = "Payment Required";       break;
    case 403: reason = "Forbidden";              break;
    case 404: reason = "Not Found";              break;
    case 405: reason = "Method Not Allowed";     break;
    case 409: reason = "Conflict";               break;
    case 412: reason = "Precondition Failed";    break;
    case 415: reason = "Unsupported Media Type"; break;
    case 424: reason = "Failed Dependency";      break;
    
    case 507: reason = "Insufficient Storage";   break;
    
    default:
      if (_status < 300)
        reason = "Request Was Successful";
      else
        reason = "Request Failed";
      break;
  }
  return (const unsigned char *) reason;
}

- (void)_httpValidateResponse:(WOResponse *)_response {
  /* check HTTP validity */
  if ([_response status] == NGHttpStatusCode_Unauthorized) {
    if ([_response headerForKey:@"www-authenticate"] == nil) {
      [self warnWithFormat:
              @"response is %i, but no www-authenticate header is set.",
              NGHttpStatusCode_Unauthorized];
    }
  }
}

- (void)deliverResponse:(WOResponse *)_response
  toRequest:(WORequest *)_request
  onStream:(id<NGStream>)_out
{
  /*
    Profiling OSX: - takes 29% of tx -run
      12% CTextStream writeString
        ... to sendto 5.1% (half+ of the performance lost on the way)
      4.6% WOMessage   headersForKey
      4.4% TextStream  writeFormat
    => TODO(perf) reduce usage of writeFormat/writeString
  */
  NGCTextStream *out;
  static NSString *disconnectError =
    @"client disconnected during delivery of response for %@ (len=%i): %@";
  static NSString *deliveryError =
    @"delivering of response failed with exception: %@";

  *(&out) = nil;

  [self _httpValidateResponse:_response];

  out = [(NGCTextStream *)[NGCTextStream alloc] initWithSource:_out];
  
  NS_DURING {
    unsigned char buf[1024];
    NSString *t1;
    id   body;
    BOOL doZip;
    BOOL isok = YES;
    int length;
    
    doZip = [_response shouldZipResponseToRequest:_request];
    
    /* response line */
    if (isok) {
      unsigned int slen, rlen;
      const unsigned char *r;
      int s;

      s  = [_response status];
      t1 = [_response httpVersion];
      r  = [self _reasonForStatus:s];

      // TBD: replace -cStringLength/-getCString:
      slen = [t1 cStringLength];
      rlen = strlen((const char *)r);
      if ((slen + rlen + 8) < 1000) {
        [t1 getCString:(char *)buf]; // HTTP status
        snprintf((char *)&(buf[slen]), sizeof(buf), " %i %s\r\n", s, r);
        isok = [_out safeWriteBytes:buf count:strlen((char *)buf)];
      }
      else
        isok = [out writeFormat:@"%@ %i %s\r\n", t, s, r];
    }
    if (isok) isok = [out flush];
    
    /* zip */
    body = (doZip) 
      ? [_response zipResponse]
      : [_response content];
    
    /* add content length header */
    
    if ((length = [body length]) == 0
        && ![[_response headerForKey: @"content-type"] hasPrefix:@"text/plain"]) {
      [_response setHeader:@"text/plain" forKey:@"content-type"];
    }
    snprintf((char *)buf, sizeof(buf), "%d", length);
    t1 = [[NSString alloc] initWithCString:(char *)buf];
    [_response setHeader:t1 forKey:@"content-length"];
    [t1 release]; t1 = nil;
    
    /* write headers */
    if (isok) {
      /* collect in string to reduce string IO */
      NSEnumerator    *fields;
      NSString        *fieldName;
      NSMutableString *header;
      BOOL hasConnectionHeader;
      IMP  addStr;
      
#if HEAVY_DEBUG
      NSLog(@"DELIVER: %@", _response);
#endif
    
      hasConnectionHeader = NO;
      header = [[NSMutableString alloc] initWithCapacity:4096];
      addStr = [header methodForSelector:@selector(appendString:)];
      fields = [[_response headerKeys] objectEnumerator];
      
      while ((fieldName = [fields nextObject]) && isok) {
        NSEnumerator *values;
        NSString *value;
	
	if (!hasConnectionHeader) {
	  if ([fieldName isEqualToString:@"connection"])
	    hasConnectionHeader = YES;
	}
	
#if HEAVY_DEBUG
	NSLog(@"  FIELD: %@", fieldName);
#endif
	
        values = [[_response headersForKey:fieldName] objectEnumerator];
	
        while ((value = [values nextObject]) && isok) {
#if HEAVY_DEBUG
	  NSLog(@"    VAL: %@", value);
#endif
          addStr(header, @selector(appendString:),
                 capitalizeHeaders ? capitalizeHeaderName (fieldName) : fieldName);
          addStr(header, @selector(appendString:), @": ");
          addStr(header, @selector(appendString:), value);
          addStr(header, @selector(appendString:), @"\r\n");
        }
#if HEAVY_DEBUG
	NSLog(@"  END:   %@", fieldName);
#endif
      }

#if HEAVY_DEBUG
      NSLog(@"  HEADER:\n%@", header);
      NSLog(@"  OUT: %@", out);
#endif
      isok = [out writeString:header];
      [header release]; header = nil;

#if 0
#warning TODO: experimental, need to check for direct connect
      if (!hasConnectionHeader && isok)
	isok = [out writeString:@"connection: close\r\n"];
#endif
    }
#if HEAVY_DEBUG
    else {
      NSLog(@"NOT OK TO DELIVER HEADERS ...");
    }
#endif
    
    /* write cookie headers */
    if (isok) {
      NSEnumerator *cookies;
      WOCookie     *cookie;
      
      cookies = [[_response cookies] objectEnumerator];
      while ((cookie = [cookies nextObject]) && isok) {
        unsigned clen;
        
        t1   = [cookie stringValue];
        clen = [t1 cStringLength];
        
        if (isok) isok = [_out safeWriteBytes:"set-cookie: " count:12];
        if (isok) {
          if (clen > 1000)
            isok = [out writeString:t1];
          else {
            [t1 getCString:(char *)buf];
            [_out safeWriteBytes:buf count:clen];
          }
        }
        if (isok) isok = [_out safeWriteBytes:"\r\n" count:2];
      }
    }
    
    if (isok) isok = [_out safeWriteBytes:"\r\n" count:2];
    if (isok) isok = [out flush];
    
    /* write body */
    
    if (![[_request method] isEqualToString:@"HEAD"] && isok) {
      if ((body != nil) && isok) {
        if (![body isKindOfClass:[NSData class]]) {
          if (![body isKindOfClass:[NSString class]])
            body = [body description];
          
          body = [body dataUsingEncoding:[_response contentEncoding]
                       allowLossyConversion:NO];
        }
        isok = [_out safeWriteBytes:[body bytes] count:[body length]];
        if (isok) isok = [_out flush];
      }
    }
    
    if (!isok) {
      NSException *e;
      
      e = [out lastException];
      if ([e isKindOfClass:[NGSocketShutdownException class]]) {
        [self errorWithFormat:disconnectError,
                _request,
                [[_response content] length],
                [e reason]];
      }
      else
        [e raise];
    }
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGSocketShutdownException class]]) {
      [self errorWithFormat:disconnectError,
              _request,
              [[_response content] length],
              [localException reason]];
    }
    else {
      [self errorWithFormat:deliveryError, localException];
      [out release]; out = nil; // the buffer will be flushed ..

      [localException raise];
    }
  }
  NS_ENDHANDLER;
  
  [out release]; out = nil; // the buffer will be flushed ..
}

static __inline__ const char *monthAbbr(int m) {
  switch (m) {
    case  1:  return "Jan"; case  2:  return "Feb"; case  3:  return "Mar";
    case  4:  return "Apr"; case  5:  return "May"; case  6:  return "Jun";
    case  7:  return "Jul"; case  8:  return "Aug"; case  9:  return "Sep";
    case 10:  return "Oct"; case 11:  return "Nov"; case 12:  return "Dec";
    default: return "UNKNOWN MONTH !";
  }
}

- (void)logResponse:(WOResponse *)_response
  toRequest:(WORequest *)_request
  connection:(id<NGActiveSocket>)_connection
{
  /* 
    NOTE: *obsoleted profiling information*
    TODO: update profiling info! (left the old one for comparison)
    Profiling: this method takes 0.95% of -run if the output is piped to
    /dev/null on OSX, morphing caldate to string is 0.79% of that.
  */
  static BOOL doExtLog = YES;
  NSString        *remoteHost;
  NSNumber        *zippedLen;
  NSCalendarDate  *now;
  NSDate          *lstartDate;
  NSDictionary    *startStats;
  NSMutableString *buf;

  lstartDate = [_request startDate];
  startStats = [_request startStatistics];
  zippedLen  = [[_response userInfo] objectForKey:@"WOResponseZippedLength"];
  
  // host and date
  if ((remoteHost = [_request headerForKey:@"x-webobjects-remote-host"]))
    ;
  else if ((remoteHost = [_request headerForKey:@"x-webobjects-remote-addr"]))
    ;
  else {
    id<NGSocketAddress> remote = nil;

    remote = [_connection remoteAddress];

    if ([remote isKindOfClass:[NGInternetSocketAddress class]])
      remoteHost = [(NGInternetSocketAddress *)remote hostName];
#if !defined(__MINGW32__)
    else if ([remote isKindOfClass:[NGLocalSocketAddress class]])
      remoteHost = @"local";
#endif
  }
  
  // this is supposed to be in GMT ! TODO: explicitly set GMT
  now = [NSCalendarDate calendarDate];

  buf = [[NSMutableString alloc] initWithCapacity:160]; /* 2 terminal lines */

  /* append standard info */
  [buf appendString:remoteHost];
  [buf appendString:@" - - ["];
  [buf appendFormat:@"%02i/%s/%04i:%02i:%02i:%02i",
        [now dayOfMonth],
        monthAbbr([now monthOfYear]),
        [now yearOfCommonEra],
        [now hourOfDay], [now minuteOfHour], [now secondOfMinute]];
  [buf appendString:@" GMT] \""];
  [buf appendString:[_request method]];
  [buf appendString:@" "];
  [buf appendString:[_request uri]];
  [buf appendString:@" "];
  [buf appendString:[_request httpVersion]];
  [buf appendString:@"\" "];
  [buf appendFormat:@"%i %i",  
         [_response status],
         [[_response content] length]];
  if (doExtLog)
    [buf appendFormat:@"/%i", [[_request content] length]];
  
  /* append duration */
  if (lstartDate != nil)
    [buf appendFormat:@" %.3f", [now timeIntervalSinceDate:lstartDate]];
  else
    [buf appendString:@" -"];
  
  /* append zip level */
  if (zippedLen) {
    double p;
    double unzippedLen;
    
    unzippedLen = 
      [[[_response userInfo] objectForKey:@"WOResponseUnzippedLength"] 
	           unsignedIntValue];
    [buf appendFormat:@" %d", (unsigned int)unzippedLen];

    if ([zippedLen unsignedIntValue] == unzippedLen) {
      [buf appendString:@" -"];
    }
    else {
      p = unzippedLen / 100.0; // one percent
      p = [zippedLen doubleValue] / p;
      p = 100.0 - p;
      [buf appendFormat:@" %-2d%%", (unsigned int)p];
    }
  }
  else {
    /* content was not zipped */
    [buf appendString:@" - -"];
  }
  
  /* append statistics */
  
  if (startStats) {
    static NSProcessInfo *pi = nil;
    NSDictionary *currentStats;
    
    if (pi == nil) pi = [[NSProcessInfo processInfo] retain];
    
    if ((currentStats = [pi procStatDictionary])) {
      int old, new, diff;
      
      old = [[startStats   objectForKey:@"rss"] intValue];
      new = [[currentStats objectForKey:@"rss"] intValue];
      diff = new - old; /* number of pages (4KB on ix86 ..) */
      
      diff *= 4; /* in KB */
      if (diff == 0)
        [buf appendString:@" 0"];
      else if (diff > 999)
        [buf appendFormat:@" %iM", diff / 1024];
      else
        [buf appendFormat:@" %iK", diff];
    }
    else
      [buf appendString:@" ?"];
  }
  else
    [buf appendString:@" -"];

  [transActionLogger logLevel:NGLogLevelInfo message:buf];
  [buf release];
}

/* NGHttpMessageParserDelegate */

- (BOOL)httpParserWillParseRequest:(NGHttpMessageParser *)_parser {
  return YES;
}
- (void)httpParser:(NGHttpMessageParser *)_parser
  didParseRequest:(NGHttpRequest *)_request {
}

- (BOOL)parser:(NGMimePartParser *)_parser
  keepHeaderField:(NSString *)_name
  value:(id)_value
{
  return YES;
}
- (void)parser:(NGMimePartParser *)_parser didParseHeader:(NGHashMap *)_header {
}

- (NGMimeType *)parser:(id)_parser
  contentTypeOfPart:(id<NGMimePart>)_part
{
  return [NGMimeType mimeType: @"text/plain; charset=utf-8"];
}

@end /* WOHttpAdaptor */

@implementation WOCoreApplication(SimpleParserSelection)

- (BOOL)shouldUseSimpleHTTPParserForTransaction:(id)_tx {
  return useSimpleParser;
}

@end /* WOCoreApplication(SimpleParserSelection) */
