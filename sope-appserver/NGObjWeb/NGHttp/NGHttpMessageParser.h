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

#ifndef __NGHttp_NGHttpMessageParser_H__
#define __NGHttp_NGHttpMessageParser_H__

#import <NGMime/NGMimePartParser.h>
#import <NGMime/NGPart.h>

@class NGHashMap;
@class NGHttpMessage, NGHttpRequest, NGHttpResponse;

@interface NGHttpMessageParser : NGMimePartParser
{
@protected
  struct {
    BOOL parseRequest:1; // whether a request or a response is expected
  } flags;
  
  struct {
    BOOL httpParserWillParseRequest:1;
    BOOL httpParserDidParseRequest:1;
    BOOL httpParserWillParseResponse:1;
    BOOL httpParserDidParseResponse:1;
  } httpDelegateRespondsTo;

  // used during parsing
  NSString *methodName; // 'GET', 'PUT', ..
  NSString *uri;        // either '*' | absolute-URI | absolute-path
  NSString *version;    // eg 'HTTP/1.1'
  int      status;
  NSString *reason;
}

// accessors

- (void)setDelegate:(id)_delegate; // sets the additional flags ..

/* HTTP parsing */

- (BOOL)parseRequestLine;
- (BOOL)parseStatusLine;
- (BOOL)parseStartLine;

/* body parsing */

- (id<NGMimePart>)producePartWithHeader:(NGHashMap *)_header;

- (NGHttpRequest *)produceRequestWithMethodName:(NSString *)_method
  uri:(NSString *)_uri version:(NSString *)_version
  header:(NGHashMap *)_header;

- (NGHttpResponse *)produceResponseWithStatusCode:(int)_code
  statusText:(NSString *)_text version:(NSString *)_version
  header:(NGHashMap *)_header;

- (NGHttpRequest *)parseRequestFromStream:(id<NGStream>)_stream;
- (NGHttpResponse *)parseResponseFromStream:(id<NGStream>)_stream;

@end

@interface NSObject(NGHttpMessageParserDelegate)

- (BOOL)httpParserWillParseRequest:(NGHttpMessageParser *)_parser;
- (BOOL)httpParserWillParseResponse:(NGHttpMessageParser *)_parser;

- (void)httpParser:(NGHttpMessageParser *)_parser
  didParseRequest:(NGHttpRequest *)_request;
- (void)httpParser:(NGHttpMessageParser *)_parser
  didParseResponse:(NGHttpResponse *)_response;

@end

#endif /* __NGHttp_NGHttpMessageParser_H__ */
