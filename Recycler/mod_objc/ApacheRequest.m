// $Id: ApacheRequest.m,v 1.1 2004/06/08 11:15:59 helge Exp $

#include "ApacheRequest.h"
#import <Foundation/Foundation.h>
#include "httpd.h"
#include "http_request.h"
#include "http_protocol.h"

#define ApCharSetAccessor(_field, _val_) \
  {\
    char *val;\
    unsigned len;\
    \
    len = [_val_ cStringLength];\
    val = ap_palloc(AP_HANDLE->pool, len + 1);\
    [_val_ getCString:val];\
    val[len] = '\0';\
    \
    AP_HANDLE->_field = val;\
  }

@implementation ApacheRequest
#define AP_HANDLE ((request_rec *)self->handle)

/* accessors */

- (ApacheResourcePool *)requestPool {
  return [ApacheResourcePool objectWithHandle:AP_HANDLE->pool];
}
- (ApacheConnection *)connection {
  return [ApacheConnection objectWithHandle:AP_HANDLE->connection];
}
- (ApacheServer *)server {
  return [ApacheServer objectWithHandle:AP_HANDLE->server];
}

/* requests */

- (ApacheRequest *)redirectToRequest {
  return [ApacheRequest objectWithHandle:AP_HANDLE->next];
}
- (ApacheRequest *)redirectFromRequest {
  return [ApacheRequest objectWithHandle:AP_HANDLE->prev];
}
- (ApacheRequest *)mainRequest {
  return [ApacheRequest objectWithHandle:AP_HANDLE->main];
}

/*
  Info about the request itself... we begin with stuff that only
  protocol.c should ever touch...
*/

- (NSString *)firstRequestLine {
  return [NSString stringWithCString:AP_HANDLE->the_request];
}
- (BOOL)isBackwards {
  return AP_HANDLE->assbackwards ? YES : NO;
}
/* proxy ? */
- (BOOL)isHeadRequest {
  return AP_HANDLE->header_only ? YES : NO;
}

- (NSString *)protocol {
  return [NSString stringWithCString:AP_HANDLE->protocol];
}
- (int)protocolNumber {
  return AP_HANDLE->proto_num;
}

- (NSString *)hostName {
  return [NSString stringWithCString:AP_HANDLE->hostname];
}

- (NSDate *)requestTime {
  return [NSDate dateWithTimeIntervalSince1970:AP_HANDLE->request_time];
}

- (NSString *)statusLine {
  return [NSString stringWithCString:AP_HANDLE->status_line];
}
- (int)status {
  return AP_HANDLE->status;
}

/*
  Request method, two ways; also, protocol, etc..  Outside of protocol.c,
  look, but don't touch.
*/
- (NSString *)method {
  return [NSString stringWithCString:AP_HANDLE->method];
}
- (int)methodNumber {
  return AP_HANDLE->method_number;
}
+ (int)numberForMethod:(NSString *)_method {
  return ap_method_number_of([_method cString]);
}

- (void)allowMethodNumber:(int)_num {
  AP_HANDLE->allowed |= (1 << _num);
}
- (BOOL)isMethodNumberAllowed:(int)_num {
  return (AP_HANDLE->allowed & (1 << _num)) ? YES : NO;
}

- (unsigned int)bytesSent {
  return AP_HANDLE->bytes_sent;
}
- (NSDate *)lastModified {
  return [NSDate dateWithTimeIntervalSince1970:AP_HANDLE->mtime];
}

/* HTTP/1.1 connection-level features */

- (BOOL)isChunkedSending {
  return AP_HANDLE->chunked ? YES : NO;
}
- (int)byteRangeCount {
  return AP_HANDLE->byterange;
}
- (NSString *)byteRangeBoundary {
  return [NSString stringWithCString:AP_HANDLE->boundary];
}
- (NSString *)range {
  return [NSString stringWithCString:AP_HANDLE->range];
}
- (unsigned int)contentLength {
  return AP_HANDLE->clength;
}

- (unsigned int)numberOfRemainingBytes {
  return AP_HANDLE->remaining;
}
- (unsigned int)numberOfReadBytes {
  return AP_HANDLE->read_length;
}
- (BOOL)isChunkedReceiving {
  return AP_HANDLE->read_chunked ? YES : NO;
}
- (BOOL)isExpecting100 {
  return AP_HANDLE->expecting_100 ? YES : NO;
}

/*
  MIME header environments, in and out.  Also, an array containing
  environment variables to be passed to subprocesses, so people can
  write modules to add to that environment.

  The difference between headers_out and err_headers_out is that the
  latter are printed even on error, and persist across internal redirects
  (so the headers printed for ErrorDocument handlers will have them).

  The 'notes' table is for notes from one module to another, with no
  other set purpose in mind...
*/

- (ApacheTable *)headersIn {
  return [ApacheTable objectWithHandle:AP_HANDLE->headers_in];
}
- (ApacheTable *)headersOut {
  return [ApacheTable objectWithHandle:AP_HANDLE->headers_out];
}
- (ApacheTable *)errorHeadersOut {
  return [ApacheTable objectWithHandle:AP_HANDLE->err_headers_out];
}
- (ApacheTable *)subprocessEnvironment {
  return [ApacheTable objectWithHandle:AP_HANDLE->subprocess_env];
}
- (ApacheTable *)notes {
  return [ApacheTable objectWithHandle:AP_HANDLE->notes];
}

/*
  content_type, handler, content_encoding, content_language, and all
  content_languages MUST be lowercased strings.  They may be pointers
  to static strings; they should not be modified in place.
*/

- (void)setContentType:(NSString *)_ctype {
  _ctype = [_ctype lowercaseString];
  ApCharSetAccessor(content_type, _ctype);
}
- (NSString *)contentType {
  return [NSString stringWithCString:AP_HANDLE->content_type];
}

- (void)setContentEncoding:(NSString *)_cencoding {
  _cencoding = [_cencoding lowercaseString];
  ApCharSetAccessor(content_encoding, _cencoding);
}
- (NSString *)contentEncoding {
  return [NSString stringWithCString:AP_HANDLE->content_encoding];
}

- (void)setContentLanguage:(NSString *)_clanguage {
  _clanguage = [_clanguage lowercaseString];
  ApCharSetAccessor(content_language, _clanguage);
}
- (NSString *)contentLanguage {
  return [NSString stringWithCString:AP_HANDLE->content_language];
}

- (NSString *)vlistValidator {
  return [NSString stringWithCString:AP_HANDLE->vlist_validator];
}

- (NSArray *)contentLanguages {
  // array_header *content_languages;	/* array of (char*) */
  
  return [self notImplemented:_cmd];
}

- (void)setHandler:(NSString *)_value {
  ApCharSetAccessor(handler, _value);
}
- (NSString *)handler {
  return [NSString stringWithCString:AP_HANDLE->handler];
}

- (BOOL)noCache {
  return AP_HANDLE->no_cache ? YES : NO;
}
- (BOOL)noLocalCopy {
  return AP_HANDLE->no_local_copy ? YES : NO;
}

/*
  What object is being requested (either directly, or via include
  or content-negotiation mapping).
*/
- (NSString *)unparsedURI {
  return [NSString stringWithCString:AP_HANDLE->unparsed_uri];
}
- (NSString *)uri {
  return [NSString stringWithCString:AP_HANDLE->uri];
}
- (NSString *)filename {
  return [NSString stringWithCString:AP_HANDLE->filename];
}
- (NSString *)pathInfo {
  return [NSString stringWithCString:AP_HANDLE->path_info];
}
- (NSString *)queryArgs {
  return [NSString stringWithCString:AP_HANDLE->args];
}
// finfo, parse_uri

- (NSString *)casePreservedFilename {
  return [NSString stringWithCString:AP_HANDLE->case_preserved_filename];
}

- (void)parseURI:(NSString *)_uri {
  ap_parse_uri(AP_HANDLE, [_uri cString]);
}

/* sub-requests */

- (ApacheRequest *)subRequestLookupURI:(NSString *)_newfile {
  request_rec *sr;
  sr = ap_sub_req_lookup_uri([_newfile cString], AP_HANDLE);
  return [ApacheRequest objectWithHandle:sr];
}
- (ApacheRequest *)subRequestLookupURI:(NSString *)_newfile
  method:(NSString *)_method
{
  request_rec *sr;
  sr = ap_sub_req_method_uri([_method cString], [_newfile cString], AP_HANDLE);
  return [ApacheRequest objectWithHandle:sr];
}
- (ApacheRequest *)subRequestLookupFile:(NSString *)_newfile {
  request_rec *sr;
  sr = ap_sub_req_lookup_file([_newfile cString], AP_HANDLE);
  return [ApacheRequest objectWithHandle:sr];
}

/* operations */

- (int)runSubRequest {
  return ap_run_sub_req(AP_HANDLE);
}
- (void)destroySubRequest {
  ap_destroy_sub_req(AP_HANDLE);
}

- (void)internalRedirect:(NSString *)_uri {
  ap_internal_redirect([_uri cString], AP_HANDLE);
}
- (void)internalRedirectHandler:(NSString *)_uri {
  ap_internal_redirect_handler([_uri cString], AP_HANDLE);
}

- (int)someAuthorizationRequired {
  return ap_some_auth_required(AP_HANDLE);
}
- (BOOL)isInitialRequest {
  return ap_is_initial_req(AP_HANDLE);
}

- (NSDate *)updateModificationTime:(NSDate *)_date {
  return [NSDate dateWithTimeIntervalSince1970:
                   ap_update_mtime(AP_HANDLE, [_date timeIntervalSince1970])];
}

/* sending headers */

- (void)sendBasicHttpHeader {
  ap_basic_http_header(AP_HANDLE);
}
- (void)sendHttpHeader {
  ap_send_http_header(AP_HANDLE);
}
- (int)sendHttpTrace {
  return ap_send_http_trace(AP_HANDLE);
}
- (int)sendHttpOptions {
  return ap_send_http_options(AP_HANDLE);
}

- (void)finalizeRequestProtocol {
  ap_finalize_request_protocol(AP_HANDLE);
}

- (void)sendErrorResponse {
  [self sendErrorResponseWithRecursiveFailStatus:500];
}
- (void)sendErrorResponseWithRecursiveFailStatus:(int)_state {
  ap_send_error_response(AP_HANDLE, _state);
}

/* modifying headers */

- (int)setContentLength:(unsigned int)_len {
  return ap_set_content_length(AP_HANDLE, _len);
}
- (int)setKeepAlive {
  return ap_set_keepalive(AP_HANDLE);
}
- (NSDate *)rationalizeModificationTime:(NSDate *)_mtime {
  time_t t;
  t = ap_rationalize_mtime(AP_HANDLE, [_mtime timeIntervalSince1970]);
  return [NSDate dateWithTimeIntervalSince1970:t];
}
- (NSString *)makeETag:(BOOL)_forceWeak {
  return [NSString stringWithCString:ap_make_etag(AP_HANDLE, _forceWeak)];
}
- (void)setETag {
  ap_set_etag(AP_HANDLE);
}
- (void)setLastModified {
  ap_set_last_modified(AP_HANDLE);
}
- (int)meetsConditions {
  return ap_meets_conditions(AP_HANDLE);
}

/* sending content */

- (long)sendFile:(FILE *)_file {
  return ap_send_fd(_file, AP_HANDLE);
}
- (long)sendFile:(FILE *)_file length:(long)_len {
  return ap_send_fd_length(_file, AP_HANDLE, _len);
}
- (unsigned int)sendMMap:(void *)_mm
  offset:(unsigned int)_off length:(unsigned int)_len
{
  return ap_send_mmap(_mm, AP_HANDLE, _off, _len);
}

- (int)rputc:(int)_c {
  return ap_rputc(_c, AP_HANDLE);
}
- (int)rputs:(const char *)_cstr {
  return ap_rputs(_cstr, AP_HANDLE);
}
- (int)rwrite:(const void *)_buf length:(unsigned int)_len {
  return ap_rwrite(_buf, _len, AP_HANDLE);
}
- (int)rflush {
  return ap_rflush(AP_HANDLE);
}

- (int)rwriteData:(NSData *)_data {
  return ap_rwrite([_data bytes], [_data length], AP_HANDLE);
}

/* Reading a block of data from the client connection (e.g., POST arg) */

- (int)setupClientBlock:(int)_readPolicy {
  return ap_setup_client_block(AP_HANDLE, _readPolicy);
}
- (int)shouldClientBlock {
  return ap_should_client_block(AP_HANDLE);
}
- (long)getClientBlock:(char *)_buffer length:(int)_bufsiz {
  return ap_get_client_block(AP_HANDLE, _buffer, _bufsiz);
}
- (int)discardRequestBody {
  return ap_discard_request_body(AP_HANDLE);
}

/* Sending a byterange */

- (int)setByteRange {
  return ap_set_byterange(AP_HANDLE);
}
// ap_each_byterange(request_rec *r, long *offset, long *length);

/* basic authentication */

- (void)noteAuthFailure {
  ap_note_auth_failure(AP_HANDLE);
}
- (void)noteBasicAuthFailure {
  ap_note_basic_auth_failure(AP_HANDLE);
}
- (int)getBasicAuthPassword:(const char **)_pwd {
  return ap_get_basic_auth_pw(AP_HANDLE, _pwd);
}

#undef AP_HANDLE

- (NSString *)description {
  NSMutableString *ms;
  id tmp;
  
  ms = [NSMutableString stringWithCapacity:128];
  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  [ms appendFormat:@" 0x%p", self->handle];
  
  if ([self isHeadRequest]) [ms appendString:@" head"];
  
  tmp = [self method];
  if ([tmp length] > 0) [ms appendFormat:@" %@", tmp];
  tmp = [self uri];
  if ([tmp length] > 0) [ms appendFormat:@" uri='%@'", tmp];

  if ([self isChunkedReceiving]) [ms appendString:@" in-chunked"];
  if ([self isChunkedSending])   [ms appendString:@" out-chunked"];
  
  if ([self numberOfReadBytes] > 0)
    [ms appendFormat:@" bytesRead=%i", [self numberOfReadBytes]];
  if ([self numberOfRemainingBytes] > 0)
    [ms appendFormat:@" remainingBytes=%i", [self numberOfRemainingBytes]];
  if ([self bytesSent] > 0)
    [ms appendFormat:@" bytesSent=%i", [self bytesSent]];

  if ((tmp = [self connection]))
    [ms appendFormat:@" con=%@", tmp];
  
  [ms appendString:@">"];
  return ms;
}

@end /* ApacheRequest */
