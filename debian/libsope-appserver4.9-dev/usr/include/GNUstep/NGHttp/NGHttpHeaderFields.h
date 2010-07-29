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

#ifndef __NGHttp_NGHttpHeaderFields_H__
#define __NGHttp_NGHttpHeaderFields_H__

#import <Foundation/NSObject.h>

@class NSString, NSHost, NSDate, NSDictionary;
@class NGInternetSocketAddress;

/*
  Value field that occures in the HTTP 'Host' header field.
  Looks like this: 'Host: trex@skyrix.com:80'
*/
@interface NGHttpHostHeaderField : NSObject
{
@protected
  NSString *hostName;
  int      port;
}

- (id)initWithString:(NSString *)_value;

// accessors

- (NSString *)hostName;
- (int)port;

// advanced conversions

- (NGInternetSocketAddress *)socketAddress;
- (NSHost *)host;

// description

- (NSString *)stringValue;

@end

/*
  Value field that occures in the HTTP 'accept-charset' header field.
  Looks like this: 'accept-charset: iso-8859-1,*,utf-8'
*/
@interface NGHttpCharsetHeaderField : NSObject
{
  NSArray *charsets;
  BOOL    containsWildcard;
}

- (id)initWithArray:(NSArray *)_charsetArray;
- (id)initWithString:(NSString *)_value;

// accessors

- (NSEnumerator *)charsets;
- (BOOL)containsCharset:(NSString *)_setName;

@end

/*
  Value field that occures in the HTTP 'accept' header field.
  Looks like this: 'accept: image/gif, image/x-xbitmap, image/jpeg, wildcard'
*/
@interface NGHttpTypeSetHeaderField : NSObject
{
  NSArray *types;
}

- (id)initWithArray:(NSArray *)_typeArray;

// accessors

- (NSEnumerator *)types;
- (BOOL)containsMimeType:(NGMimeType *)_type;

@end

/*
  Value field that occures in the HTTP 'accept-language' header field.
*/
@interface NGHttpLanguageSetHeaderField : NSObject
{
  NSArray *languages;
}

- (id)initWithArray:(NSArray *)_langArray;

// accessors

- (NSEnumerator *)languages;
- (BOOL)containsLanguage:(NSString *)_language;

@end

/*
  Value field that occures in the HTTP 'user-agent' header field.
  Looks like this: 'user-agent: Mozilla/4.5b2 [en] '
*/
@interface NGHttpUserAgent : NSObject
{
@protected
  NSString *value;
  NSString *browser;
  char     majorVersion;
  char     minorVersion;
}

- (id)initWithString:(NSString *)_value;

// browsers

- (BOOL)isMozilla;
- (BOOL)isInternetExplorer;
- (int)majorVersion;
- (int)minorVersion;

@end

/*
  Value field that occures in the HTTP 'connection' header field.
  Looks like this: 'connection: Keep-Alive'
*/
@interface NGHttpConnectionHeaderField : NSObject
{
@protected
  BOOL close;
  BOOL keepAlive;
  BOOL isTE;
}

- (id)initWithString:(NSString *)_value;

// accessors

- (BOOL)keepAlive;

@end

/*
  Value field that occures in the HTTP 'authorization' header field.
  Looks like this: 'authorization: Basic aGVsZ2U6ZG9vZg=='
  (class cluster)
*/
@interface NGHttpCredentials : NSObject
{
  NSString *scheme;
  NSData   *credentials;
}

+ (id)credentialsWithString:(NSString *)_cred;
+ (id)credentialsWithScheme:(NSString *)_scheme
  credentials:(NSData *)_credentials;

// accessors

- (NSString *)scheme;
- (NSData *)credentials;

- (NSString *)userName;
- (NSString *)password;

// description

- (NSString *)stringValue;

@end

/*
  Value field that occures in the HTTP 'www-authenticate' header field.
  Looks like this: 'www-authorization: Basic realm="SKYRIX"'
*/
@interface NGHttpChallenge : NSObject
{
  NSString     *scheme;
  NSDictionary *parameters;
}

+ (id)basicChallengeWithRealm:(NSString *)_realm;
- (id)initWithScheme:(NSString *)_scheme realm:(NSString *)_realm;

// accessors

- (NSString *)scheme;

- (void)setRealm:(NSString *)_realm;
- (NSString *)realm;

// description

- (NSString *)stringValue;

@end

#endif /* __NGHttp_NGHttpHeaderFields_H__ */
