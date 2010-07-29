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

#ifndef __NGObjWeb_WOMessage_H__
#define __NGObjWeb_WOMessage_H__

#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#include <NGStreams/NGStreamProtocols.h>

/*
  WOMessage
  
  Abstract superclass of both, WORequest and WOResponse.
*/

@class NSDictionary, NSArray, NSData, NSMutableData, NSMutableArray;
@class NGMutableHashMap;
@class WOCookie;

@interface WOMessage : NSObject
{
@private
  NSString         *version;
  NSMutableData    *content;
  NGMutableHashMap *header;
  NSDictionary     *userInfo;
  NSMutableArray   *cookies;
  NSStringEncoding contentEncoding;
  id<NGStream>     contentStream;
  id               domCache;
  
  struct {
    BOOL didStartWriting:1; // afterwards no headers may be changed
    int  reserved:31;
  } womFlags;
  
@public // cached selectors
  void (*addChar)(id, SEL, char);
  void (*addStr)(id, SEL, NSString *);
  void (*addHStr)(id, SEL, NSString *);
  void (*addCStr)(id, SEL, const unsigned char *);
  void (*addBytes)(id, SEL, const void *, unsigned);
}

/* accessors */

- (void)setUserInfo:(NSDictionary *)_userInfo;
- (NSDictionary *)userInfo;

/* HTTP */

- (void)setHTTPVersion:(NSString *)_httpVersion;
- (NSString *)httpVersion;

/* cookies (new in WO4) */

- (void)addCookie:(WOCookie *)_cookie;
- (void)removeCookie:(WOCookie *)_cookie;
- (NSArray *)cookies;

/* header */

- (void)setHeader:(NSString *)_header forKey:(NSString *)_key;
- (NSString *)headerForKey:(NSString *)_key;
- (void)setHeaders:(NSArray *)_headers forKey:(NSString *)_key;
- (NSArray *)headersForKey:(NSString *)_key;
- (NSArray *)headerKeys;

- (void)appendHeader:(NSString *)_header forKey:(NSString *)_key;
- (void)appendHeaders:(NSArray *)_headers forKey:(NSString *)_key;

- (void)setHeaders:(NSDictionary *)_headers;
- (NSDictionary *)headers;
- (NSString *)headersAsString;

/* generic content */

- (void)setContent:(NSData *)_data;
- (NSData *)content;
- (void)setContentEncoding:(NSStringEncoding)_encoding;
- (NSStringEncoding)contentEncoding;
+ (void)setDefaultEncoding:(NSStringEncoding)_encoding;
+ (NSStringEncoding)defaultEncoding;

/* structured content */

- (void)appendContentBytes:(const void *)_bytes length:(unsigned)_length;
- (void)appendContentCharacter:(unichar)_c;
- (void)appendContentData:(NSData *)_data;

- (void)appendContentString:(NSString *)_value;
- (void)appendContentCString:(const unsigned char *)_value;

- (void)appendContentHTMLAttributeValue:(NSString *)_value;
- (void)appendContentHTMLString:(NSString *)_value;
- (void)appendContentXMLAttributeValue:(NSString *)_value;
- (void)appendContentXMLString:(NSString *)_value;

@end

@interface WOMessage(Escaping)

/* this escapes '&', '"', '<' and '>' */
+ (NSString *)stringByEscapingHTMLString:(NSString *)_string;

/* this escapes '&', '"', '<', '>', '\t', '\r' and '\n' */
+ (NSString *)stringByEscapingHTMLAttributeValue:(NSString *)_string;

@end

@interface WOMessage(NGObjWebExtensions)
- (NSString *)contentAsString;
- (BOOL)doesStreamContent;
- (NSArray *)validateContent;
@end

@interface WOMessage(DOMXML)
- (void)setContentDOMDocument:(id)_dom;
- (void)appendContentDOMDocumentFragment:(id)_domfrag;
- (id)contentAsDOMDocument;
@end

#endif /* __NGObjWeb_WOMessage_H__ */
