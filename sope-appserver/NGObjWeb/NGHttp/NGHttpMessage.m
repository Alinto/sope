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

#include "NGHttpMessage.h"
#include "common.h"
#include "NGHttpCookie.h"

@interface NGHttpMessage(PrivateMethods)
- (void)extractCommonHeaders;
@end

@implementation NGHttpMessage

- (id)initWithHeader:(NGHashMap *)_header version:(NSString *)_version {
  if ((self = [super init])) {
    self->header = [_header retain];
    self->body   = nil;

    if ([_version hasSuffix:@"0.9"]) {
      self->majorVersion = 0;
      self->minorVersion = 9;
    }
    else if ([_version hasSuffix:@"1.0"]) {
      self->majorVersion = 1;
      self->minorVersion = 0;
    }
    else if ([_version hasSuffix:@"1.1"]) {
      self->majorVersion = 1;
      self->minorVersion = 1;
    }
    else {
      self->majorVersion = 0;
      self->minorVersion = 9;
    }
    
    [self extractCommonHeaders];
  }
  return self;
}
- (id)init {
  return [self initWithHeader:nil version:nil];
}

- (void)dealloc {
  [self->header release];
  [self->body   release];
  [super dealloc];
}

/* headers */

- (void)extractCommonHeaders {
}

- (void)setValue:(id)_value ofHeaderFieldWithName:(NSString *)_name {
  if (![self->header isKindOfClass:[NGMutableHashMap class]]) {
    id new = [self->header mutableCopy];
    [self->header release];
    self->header = new;
  }
  [(NGMutableHashMap *)self->header setObject:_value forKey:_name];
}
- (void)addValue:(id)_value toHeaderFieldWithName:(NSString *)_name {
  if (![self->header isKindOfClass:[NGMutableHashMap class]]) {
    id new = [self->header mutableCopy];
    [self->header release];
    self->header = new;
  }
  [(NGMutableHashMap *)self->header addObject:_value forKey:_name];
}
- (void)removeValue:(id)_value fromHeaderFieldWithName:(NSString *)_name {
  if (![self->header isKindOfClass:[NGMutableHashMap class]]) {
    id new = [self->header mutableCopyWithZone:[self zone]];
    [self->header release];
    self->header = new;
  }
  [(NGMutableHashMap *)self->header removeAllObjects:_value forKey:_name];
}

/* common headers */

- (void)setContentType:(NGMimeType *)_type {
  [self setValue:_type ofHeaderFieldWithName:@"content-type"];
}
- (void)setContentLength:(unsigned)_length {
  [self setValue:[NSNumber numberWithUnsignedInt:_length]
        ofHeaderFieldWithName:@"content-length"];
}

- (unsigned)contentLength {
  return [[self->header objectForKey:@"content-length"] intValue];
}

- (id)valueOfHeaderFieldWithName:(NSString *)_name {
  return [self->header objectForKey:_name];
}

/* accessors */

- (NSString *)httpVersion {
  return [NSString stringWithFormat:@"HTTP/%i.%i",
                     self->majorVersion,
                     self->minorVersion];
}
- (char)majorVersion {
  return self->majorVersion;
}
- (char)minorVersion {
  return self->minorVersion;
}

/* Cookies */

- (NSArray *)cookies {
  return [self->header objectForKey:@"cookie"];
}

- (id)valueOfCookieWithName:(NSString *)_name {
  NSArray *cookies   = [self->header objectForKey:@"cookie"];
  int     pos, count = [cookies count];

  //NSLog(@"cookies=%@", cookies);

  for (pos = 0; pos < count; pos++) {
    NGHttpCookie *cookie = [cookies objectAtIndex:pos];

    NSAssert([cookie isKindOfClass:[NGHttpCookie class]],
             @"invalid cookie value");
    
    if ([[cookie cookieName] isEqualToString:_name])
      return [cookie value];
  }
  return nil;
}

- (void)addClientCookie:(NGHttpCookie *)_cookie {
  // 'Set-Cookie' header
  [(NGMutableHashMap *)self->header addObject:_cookie forKey:@"set-cookie"];
}
- (NSArray *)clientCookies {
  return [self->header objectsForKey:@"set-cookie"];
}

/* NGPart */

- (NSEnumerator *)valuesOfHeaderFieldWithName:(NSString *)_name {
  return [self->header objectEnumeratorForKey:_name];
}
- (NSEnumerator *)headerFieldNames {
  return [self->header keyEnumerator];
}

- (void)setBody:(id)_body {
  ASSIGN(self->body, _body);
}
- (id)body {
  return self->body;
}

/* NGMimePart */

- (NGMimeType *)contentType {
  id type;
  
  if ((type = [self valueOfHeaderFieldWithName:@"content-type"]) == nil)
    return [NGMimeType mimeType:@"text/plain"];

  if (![type isKindOfClass:[NGMimeType class]])
    type = [NGMimeType mimeType:[type stringValue]];
  
  return type;
}
- (NSString *)contentId {
  return [[self->header objectForKey:@"content-id"] stringValue];
}
- (NSArray *)contentLanguage {
  id val;

  if ((val = [self->header objectForKey:@"content-language"]) == nil)
    return nil;

  if (![val isKindOfClass:[NSArray class]])
    val = [[val stringValue] componentsSeparatedByString:@","];
  
  return val;
}
- (NSString *)contentMd5 {
  return [[self->header objectForKey:@"content-md5"] stringValue];
}
- (NSString *)encoding {
  return [[self->header objectForKey:@"content-encoding"] stringValue];
}
- (NSString *)contentDescription {
  return [[self->header objectForKey:@"content-description"] stringValue];
}

@end /* NGHttpMessage */

/* constants */

// used in 'Accept-Encoding' and 'Content-Encoding'
NSString *NGHttpContentCoding_gzip      = @"gzip";
NSString *NGHttpContentCoding_compress  = @"compress";
NSString *NGHttpContentCoding_deflate   = @"deflate";
NSString *NGHttpContentCoding_identity  = @"identity";

// used in 'Transfer-Encoding'
NSString *NGHttpTransferCoding_chunked  = @"chunked";
NSString *NGHttpTransferCoding_identity = @"identity";
NSString *NGHttpTransferCoding_gzip     = @"gzip";
NSString *NGHttpTransferCoding_compress = @"compress";
NSString *NGHttpTransferCoding_deflate  = @"deflate";
