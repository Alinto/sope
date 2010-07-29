// $Id: ApacheRequest.h,v 1.1 2004/06/08 11:15:59 helge Exp $

#ifndef __ApacheRequest_H__
#define __ApacheRequest_H__

#include "ApacheObject.h"
#include <stdio.h>

@class NSString, NSDate, NSData;
@class ApacheResourcePool, ApacheConnection, ApacheServer;
@class ApacheTable;

/*
  An Objective-C wrapper for the Apache request structure.

  Note: the Apache request itself is allocated from it's
  request resource pool !
*/

@interface ApacheRequest : ApacheObject
{
}

/* accessors */

- (ApacheResourcePool *)requestPool;
- (ApacheConnection   *)connection;
- (ApacheServer       *)server;

/* requests */

/*
  If we wind up getting redirected, pointer to the request we redirected to.
*/
- (ApacheRequest *)redirectToRequest;

/* If this is an internal redirect, pointer to where we redirected *from*. */
- (ApacheRequest *)redirectFromRequest;

/*
  If this is a sub_request (see request.h) pointer back to the main request.
*/
- (ApacheRequest *)mainRequest;

/*
  Info about the request itself... we begin with stuff that only
  protocol.c should ever touch...
*/
- (NSString *)firstRequestLine;
- (BOOL)isBackwards;
- (BOOL)isHeadRequest;
- (NSString *)protocol;
- (int)protocolNumber;
- (NSString *)hostName;
- (NSDate *)requestTime;
- (NSString *)statusLine;
- (int)status;

/*
  Request method, two ways; also, protocol, etc..  Outside of protocol.c,
  look, but don't touch.
*/
- (NSString *)method;
- (int)methodNumber;
+ (int)numberForMethod:(NSString *)_method;

/* modifying the allowed-method set */
- (void)allowMethodNumber:(int)_num;
- (BOOL)isMethodNumberAllowed:(int)_num;

- (unsigned int)bytesSent;
- (NSDate *)lastModified;

/* HTTP/1.1 connection-level features */

- (BOOL)isChunkedSending;
- (int)byteRangeCount;
- (NSString *)byteRangeBoundary;
- (NSString *)range;
- (unsigned int)contentLength;

- (unsigned int)numberOfRemainingBytes;
- (unsigned int)numberOfReadBytes;
- (BOOL)isChunkedReceiving;
- (BOOL)isExpecting100;

/* MIME tables */

- (ApacheTable *)headersIn;
- (ApacheTable *)headersOut;
- (ApacheTable *)errorHeadersOut;
- (ApacheTable *)subprocessEnvironment;
- (ApacheTable *)notes;

/* content-info */

- (void)setContentType:(NSString *)_ctype;
- (NSString *)contentType;
- (void)setContentEncoding:(NSString *)_cencoding;
- (NSString *)contentEncoding;
- (void)setContentLanguage:(NSString *)_clanguage;
- (NSString *)contentLanguage;
- (NSArray *)contentLanguages;
- (NSString *)vlistValidator;

- (void)setHandler:(NSString *)_value;
- (NSString *)handler;

- (BOOL)noCache;
- (BOOL)noLocalCopy;

/*
  What object is being requested (either directly, or via include
  or content-negotiation mapping).
*/
- (NSString *)unparsedURI;
- (NSString *)uri;
- (NSString *)filename;
- (NSString *)pathInfo;
- (NSString *)queryArgs;
- (NSString *)casePreservedFilename;

- (void)parseURI:(NSString *)_uri;

/* sub-requests */

- (ApacheRequest *)subRequestLookupURI:(NSString *)_newfile;
- (ApacheRequest *)subRequestLookupURI:(NSString *)_newfile
  method:(NSString *)_method;
- (ApacheRequest *)subRequestLookupFile:(NSString *)_newfile;

/* operations */

- (int)runSubRequest;
- (void)destroySubRequest;

- (void)internalRedirect:(NSString *)_uri;
- (void)internalRedirectHandler:(NSString *)_uri;

- (int)someAuthorizationRequired;
- (BOOL)isInitialRequest;

- (NSDate *)updateModificationTime:(NSDate *)_date;

/* sending headers */

- (void)sendBasicHttpHeader;
- (void)sendHttpHeader;
- (int)sendHttpTrace;
- (int)sendHttpOptions;

/* Finish up stuff after a request */
- (void)finalizeRequestProtocol;

- (void)sendErrorResponse;
- (void)sendErrorResponseWithRecursiveFailStatus:(int)_state;

/* modifying headers */

- (int)setContentLength:(unsigned int)_len;
- (int)setKeepAlive;
- (NSDate *)rationalizeModificationTime:(NSDate *)_mtime;
- (NSString *)makeETag:(BOOL)_forceWeak;
- (void)setETag;
- (void)setLastModified;
- (int)meetsConditions;

/* sending content */

- (long)sendFile:(FILE *)_file;
- (long)sendFile:(FILE *)_file length:(long)_len;
- (unsigned int)sendMMap:(void *)_mm
  offset:(unsigned int)_off length:(unsigned int)_len;

- (int)rputc:(int)_c;
- (int)rputs:(const char *)_cstr;
- (int)rwrite:(const void *)_buf length:(unsigned int)_len;
- (int)rflush;
- (int)rwriteData:(NSData *)_data;

/* Reading a block of data from the client connection (e.g., POST arg) */

- (int)setupClientBlock:(int)_readPolicy;
- (int)shouldClientBlock;
- (long)getClientBlock:(char *)_buffer length:(int)_bufsiz;
- (int)discardRequestBody;

/* Sending a byterange */

- (int)setByteRange;

/* basic authentication */

- (void)noteAuthFailure;
- (void)noteBasicAuthFailure;
- (int)getBasicAuthPassword:(const char **)_pwd;

@end

#endif /* __ApacheRequest_H__ */
