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

#ifndef __NGHttp_NGHttpMessage_H__
#define __NGHttp_NGHttpMessage_H__

#import <Foundation/NSObject.h>
#import <NGMime/NGPart.h>

@class NSString, NSArray;
@class NGHashMap;
@class NGMimeType;
@class NGHttpCookie;

// used in 'Accept-Encoding' and 'Content-Encoding'
extern NSString *NGHttpContentCoding_gzip;     // 'gzip'
extern NSString *NGHttpContentCoding_compress; // 'compress'
extern NSString *NGHttpContentCoding_deflate;  // 'deflate'
extern NSString *NGHttpContentCoding_identity; // 'identity'

// used in 'Transfer-Encoding'
extern NSString *NGHttpTransferCoding_chunked;  // 'chunked'
extern NSString *NGHttpTransferCoding_identity; // 'identity'
extern NSString *NGHttpTransferCoding_gzip;     // 'gzip'
extern NSString *NGHttpTransferCoding_compress; // 'compress'
extern NSString *NGHttpTransferCoding_deflate;  // 'deflate'

@interface NGHttpMessage : NSObject < NGPart, NGMimePart >
{
@protected
  NGHashMap *header;
  id        body;

  // http enhancements
  char      majorVersion;
  char      minorVersion;
}

// accessors

- (NSString *)httpVersion;
- (char)majorVersion;
- (char)minorVersion;

// Cookies

- (NSArray *)cookies; // 'cookie' header
- (id)valueOfCookieWithName:(NSString *)_name;

- (void)addClientCookie:(NGHttpCookie *)_cookie; // 'Set-Cookie' header
- (NSArray *)clientCookies;

// headers

- (id)valueOfHeaderFieldWithName:(NSString *)_name;

// NGPart

- (NSEnumerator *)valuesOfHeaderFieldWithName:(NSString *)_name;
- (NSEnumerator *)headerFieldNames;

- (void)setBody:(id)_body;
- (id)body;

// NGMimePart

- (NGMimeType *)contentType;
- (NSString *)contentId;
- (NSArray *)contentLanguage;
- (NSString *)contentMd5;
- (NSString *)encoding;
- (NSString *)contentDescription;

// headers

- (void)setValue:(id)_value ofHeaderFieldWithName:(NSString *)_name;
- (void)addValue:(id)_value toHeaderFieldWithName:(NSString *)_name;
- (void)removeValue:(id)_value fromHeaderFieldWithName:(NSString *)_name;
  
- (void)setContentType:(NGMimeType *)_type;
- (void)setContentLength:(unsigned)_length;
- (unsigned)contentLength;

@end

#endif /* __NGHttp_NGHttpMessage_H__ */
