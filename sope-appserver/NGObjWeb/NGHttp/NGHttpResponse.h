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

#ifndef __NGHttp_NGHttpResponse_H__
#define __NGHttp_NGHttpResponse_H__

#import "NGHttpMessage.h"

@class NSString;
@class NGHttpRequest, NGHttpChallenge;

typedef enum {
  NGHttpStatusCode_unknown = 0,

  // 1xx informational
  NGHttpStatusCode_Continue                    = 100,
  NGHttpStatusCode_SwitchingProtocols          = 101,

  // 2xx successful
  NGHttpStatusCode_OK                          = 200,
  NGHttpStatusCode_Created                     = 201,
  NGHttpStatusCode_Accepted                    = 202,
  NGHttpStatusCode_NonAuthoritativeInformation = 203,
  NGHttpStatusCode_NoContent                   = 204,
  NGHttpStatusCode_ResetContent                = 205,
  NGHttpStatusCode_PartialContent              = 206,

  // 3xx redirection
  NGHttpStatusCode_MultipleChoices             = 300,
  NGHttpStatusCode_MovedPermanently            = 301,
  NGHttpStatusCode_MovedTemporarily            = 302,
  NGHttpStatusCode_SeeOther                    = 303,
  NGHttpStatusCode_NotModified                 = 304,
  NGHttpStatusCode_UseProxy                    = 305,

  // 4xx client error
  NGHttpStatusCode_BadRequest                  = 400,
  NGHttpStatusCode_Unauthorized                = 401,
  NGHttpStatusCode_PaymentRequired             = 402,
  NGHttpStatusCode_Forbidden                   = 403,
  NGHttpStatusCode_NotFound                    = 404,
  NGHttpStatusCode_MethodNotAllowed            = 405,
  NGHttpStatusCode_NoneAcceptable              = 406,
  NGHttpStatusCode_ProxyAuthenticationRequired = 407,
  NGHttpStatusCode_RequestTimeout              = 408,
  NGHttpStatusCode_Conflict                    = 409,
  NGHttpStatusCode_Gone                        = 410,
  NGHttpStatusCode_LengthRequired              = 411,
  NGHttpStatusCode_UnlessTrue                  = 412,

  // 5xx server error
  NGHttpStatusCode_InternalServerError         = 500,
  NGHttpStatusCode_NotImplemented              = 501,
  NGHttpStatusCode_BadGateway                  = 502,
  NGHttpStatusCode_ServiceUnavailable          = 503,
  NGHttpStatusCode_GatewayTimeout              = 504,

  NGHttpStatusCode_last
} NGHttpStatusCode;

@interface NGHttpResponse : NGHttpMessage
{
  NGHttpStatusCode statusCode;
  NSString         *reason;

  NGHttpRequest *request;
}

- (id)initWithRequest:(NGHttpRequest *)_request;

- (id)initWithStatus:(int)_status reason:(NSString *)_reason
  header:(NGHashMap *)_header version:(NSString *)_version;

// accessors

- (void)setStatusCode:(NGHttpStatusCode)_code;
- (NGHttpStatusCode)statusCode;

- (void)setReason:(NSString *)_text;
- (NSString *)reason;

- (void)setRequest:(NGHttpRequest *)_request;
- (NGHttpRequest *)request;

@end

@interface NGHttpResponse(CommonHeaders)

- (void)setWWWAuthenticate:(NGHttpChallenge *)_challenge;
- (NGHttpChallenge *)wwwAuthenticate;

@end

static inline BOOL NGIsInformationalHttpStatusCode(NGHttpStatusCode _code) {
  return ((_code >= 100) && (_code < 200)) ? YES : NO;
}
static inline BOOL NGIsSuccessfulHttpStatusCode(NGHttpStatusCode _code) {
  return ((_code >= 200) && (_code < 300)) ? YES : NO;
}
static inline BOOL NGIsRedirectionHttpStatusCode(NGHttpStatusCode _code) {
  return ((_code >= 300) && (_code < 400)) ? YES : NO;
}
static inline BOOL NGIsClientErrorHttpStatusCode(NGHttpStatusCode _code) {
  return ((_code >= 400) && (_code < 500)) ? YES : NO;
}
static inline BOOL NGIsServerErrorHttpStatusCode(NGHttpStatusCode _code) {
  return ((_code >= 500) && (_code < 600)) ? YES : NO;
}

#endif /* __NGHttp_NGHttpResponse_H__ */
