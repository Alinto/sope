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

#include "common.h"
#include "NGHttpHeaderFields.h"

@implementation NGHttpHostHeaderField

- (id)initWithString:(NSString *)_value {
  if ([_value length] < 1) {
    NSLog(@"invalid value for HTTP host header field ..");
    self = AUTORELEASE(self);
    return nil;
  }
  
  if ((self = [super init])) {
    NSRange rng = [_value rangeOfString:@":"];

    if (rng.length == 0) {
      self->hostName = [_value copyWithZone:[self zone]];
      self->port     = -1;
    }
    else {
      self->hostName = [[_value substringToIndex:rng.location] retain];
      self->port     = [[_value substringFromIndex:(rng.location + rng.length)]
                                intValue];
    }
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->hostName);
  [super dealloc];
}
#endif

// accessors

- (NSString *)hostName {
  return self->hostName;
}
- (int)port {
  return self->port;
}

// advanced conversions

- (NGInternetSocketAddress *)socketAddress {
  return [NGInternetSocketAddress addressWithPort:[self port]
                                  onHost:[self hostName]];
}
- (NSHost *)host {
  return [NSHost hostWithName:[self hostName]];
}

/* description */

- (NSString *)stringValue {
  if (self->port > 0) {
    return [NSString stringWithFormat:@"%s:%i",
                       [self->hostName cString], self->port];
  }
  else
    return self->hostName;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<HostField[0x%p]: host=%@ port=%i>",
                     self, [self hostName], [self port]];
}

@end /* NGHttpHostHeaderField */

@implementation NGHttpCharsetHeaderField

- (id)init {
  return [self initWithString:nil];
}

- (id)initWithArray:(NSArray *)_charsetArray {
  if ([_charsetArray count] < 1) {
    NSLog(@"invalid value for HTTP charset header field ..");
    self = AUTORELEASE(self);
    return nil;
  }

  if ((self = [super init])) {
    self->charsets = RETAIN(_charsetArray);
    NSAssert([self->charsets count] >= 1, @"no content in array ..");

    self->containsWildcard = [self->charsets containsObject:@"*"];
  }
  return self;
}
- (id)initWithString:(NSString *)_value {
  if ([_value length] < 1) {
    NSLog(@"invalid value for HTTP charset header field ..");
    self = AUTORELEASE(self);
    return nil;
  }

  return [self initWithArray:[_value componentsSeparatedByString:@","]];
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->charsets);
  [super dealloc];
}
#endif

// accessors

- (NSEnumerator *)charsets {
  return [self->charsets objectEnumerator];
}
- (BOOL)containsCharset:(NSString *)_setName {
  if (self->containsWildcard)
    return YES;
  else
    return [self->charsets containsObject:_setName];
}

/* description */

- (NSString *)stringValue {
  NSMutableString *str = [[NSMutableString allocWithZone:[self zone]] init];
  int  cnt, count = [self->charsets count];

  for (cnt = 0; cnt < count; cnt++) {
    if (cnt != 0) [str appendString:@","];
    [str appendString:[self->charsets objectAtIndex:cnt]];
  }
  return AUTORELEASE(str);
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<HttpCharset[0x%p]: %@>",
                     self, self->charsets];
}

@end /* NGHttpCharsetHeaderField */

@implementation NGHttpTypeSetHeaderField

- (id)init {
  return [self initWithArray:nil];
}

- (id)initWithArray:(NSArray *)_typeArray {
  if ([_typeArray count] < 1) {
    NSLog(@"invalid value for HTTP charset header field ..");
    self = AUTORELEASE(self);
    return nil;
  }

  if ((self = [super init])) {
    self->types = RETAIN(_typeArray);
    NSAssert([self->types count] >= 1, @"no content in array ..");
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->types); self->types = nil;
  [super dealloc];
}
#endif

// accessors

- (NSEnumerator *)types {
  return [self->types objectEnumerator];
}
- (BOOL)containsMimeType:(NGMimeType *)_type {
  return [self->types containsObject:_type];
}

/* description */

- (NSString *)stringValue {
  NSMutableString *str;
  int  cnt, count;

  str = [[NSMutableString allocWithZone:[self zone]] init];
  count = [self->types count];

  for (cnt = 0; cnt < count; cnt++) {
    if (cnt != 0) [str appendString:@", "];
    [str appendString:[[self->types objectAtIndex:cnt] stringValue]];
  }
  return AUTORELEASE(str);
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<HttpMimeTypes[0x%p]: %@>",
                     self, self->types];
}

@end /* NGHttpTypeSetHeaderField */

@implementation NGHttpLanguageSetHeaderField

- (id)init {
  return [self initWithArray:nil];
}

- (id)initWithArray:(NSArray *)_languageArray {
  if ([_languageArray count] < 1) {
    NSLog(@"invalid value for HTTP charset header field ..");
    self = AUTORELEASE(self);
    return nil;
  }

  if ((self = [super init])) {
    self->languages = RETAIN(_languageArray);
    NSAssert([self->languages count] >= 1, @"no content in array ..");
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  RELEASE(self->languages); self->languages = nil;
  [super dealloc];
}
#endif

// accessors

- (NSEnumerator *)languages {
  return [self->languages objectEnumerator];
}
- (BOOL)containsLanguage:(NSString *)_language {
  return [self->languages containsObject:_language];
}

/* description */

- (NSString *)stringValue {
  NSMutableString *str = [[NSMutableString allocWithZone:[self zone]] init];
  int  cnt, count = [self->languages count];

  for (cnt = 0; cnt < count; cnt++) {
    if (cnt != 0) [str appendString:@", "];
    [str appendString:[self->languages objectAtIndex:cnt]];
  }
  return AUTORELEASE(str);
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<HttpLanguages[0x%p]: %@>",
                     self, self->languages];
}

@end /* NGHttpLanguageSetHeaderField */

@implementation NGHttpUserAgent

static void _parseUserAgent(NGHttpUserAgent *self) {
  [self->browser release]; self->browser = nil;

  if ([self->value hasPrefix:@"Mozilla"]) {
    // Mozilla Browser or compatible
    NSRange r;
    int idx, av, iv;

    r = [self->value rangeOfString:@"/"];
    idx = r.location;
    if (r.length > 0) {
      NSString *tmp;

      tmp = [self->value substringFromIndex:(idx + 1)];
      r   = [tmp rangeOfString:@" "];
      idx = r.location;
      if (r.length > 0)
        tmp = [tmp substringToIndex:idx];

      self->browser = @"Mozilla";

      sscanf([tmp cString], "%i.%i", &av, &iv);
      self->majorVersion = av;
      self->minorVersion = iv;

      if (idx != NSNotFound) {
        r = [self->value rangeOfString:@"MSIE "];
        idx = r.location;
        if (r.length > 0) {
          tmp = [self->value substringFromIndex:(idx + 5)];
          self->browser = @"MSIE";

          sscanf([tmp cString], "%i.%i", &av, &iv);
          self->majorVersion = av;
          self->minorVersion = iv;
        }
      }
      return;
    }
  }
}

- (id)initWithString:(NSString *)_value {
  if ((self = [super init])) {
    self->value = [_value copyWithZone:[self zone]];
    _parseUserAgent(self);
  }
  return self;
}

- (void)dealloc {
  [self->browser release];
  [self->value   release];
  [super dealloc];
}

/* browsers */

- (BOOL)isMozilla {
  return [self->browser isEqualToString:@"Mozilla"];
}
- (BOOL)isInternetExplorer {
  return [self->browser isEqualToString:@"MSIE"];
}

- (int)majorVersion {
  return self->majorVersion;
}
- (int)minorVersion {
  return self->minorVersion;
}

/* description */

- (NSString *)stringValue {
  return self->value;
}

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<HttpUserAgent[0x%p]: %@ "
                     @"(detected=%@, major=%i, minor=%i)>",
                     self, self->value, self->browser,
                     self->majorVersion, self->minorVersion];
}

@end /* NGHttpUserAgent */

@implementation NGHttpConnectionHeaderField

- (id)initWithString:(NSString *)_value {
  NSString *s;
  
  s = [_value lowercaseString];

  if ([s rangeOfString:@"keep-alive"].length > 0) {
    if ((self = [super init])) {
      self->keepAlive = YES;
    }
    return self;
  }
  else if ([s rangeOfString:@"close"].length > 0) {
    if ((self = [super init])) {
      self->close = YES;
    }
    return self;
  }
  else if ([s rangeOfString:@"te"].length > 0) {
    if ((self = [super init])) {
      self->isTE = YES;
    }
    return self;
  }
  else {
    NSLog(@"WARNING(%s): cannot parse HTTP connection header value: '%@'",
          __PRETTY_FUNCTION__, _value);
    self = AUTORELEASE(self);
    return [_value copy];
  }
}

/* accessors */

- (BOOL)keepAlive {
  return self->keepAlive;
}
- (BOOL)close {
  return self->close;
}

/* description */

- (NSString *)stringValue {
  if (self->close)
    return @"close";
  if (self->keepAlive)
    return @"Keep-Alive";
  if (self->isTE)
    return @"TE";

  return nil;
}

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<HttpConnection[0x%p]: keepAlive=%s close=%s TE=%s>",
                     self,
                     self->keepAlive ? "yes" : "no",
                     self->close     ? "yes" : "no",
                     self->isTE      ? "yes" : "no"
  ];
}

@end /* NGHttpConnectionHeaderField */

// authorization

@interface NGConcreteHttpBasicCredentials : NGHttpCredentials
{
  NSString *user;
  NSString *password;
}

@end

@interface NGHttpCredentials(PrivateMethods)
- (id)initWithScheme:(NSString *)_scheme credentials:(NSData *)_credentials;
@end

@implementation NGHttpCredentials

+ (id)credentialsWithString:(NSString *)_cred {
  NSRange rng;
  NSString *lscheme;
  NSData   *cred;
  
  if ([_cred length] == 0)
    return nil;
  rng = [_cred rangeOfString:@" "];
  if (rng.length <= 0)
    return nil;

  lscheme = [_cred substringToIndex:rng.location];
  cred    = [[_cred substringFromIndex:(rng.location + 1)]
                    dataUsingEncoding:NSISOLatin1StringEncoding];
  
  return [self credentialsWithScheme:lscheme credentials:cred];
}

+ (id)credentialsWithScheme:(NSString *)_scheme
  credentials:(NSData *)_credentials
{
  if ([_scheme caseInsensitiveCompare:@"basic"] == NSOrderedSame) {
    return [[[NGConcreteHttpBasicCredentials alloc]
                                             initWithScheme:_scheme
                                             credentials:_credentials]
                                             autorelease];
  }

  return [[[self alloc] initWithScheme:_scheme
                        credentials:_credentials] autorelease];
}

- (id)initWithScheme:(NSString *)_scheme credentials:(NSData *)_credentials {
  if ((self = [super init])) {
    self->scheme      = [_scheme      copy];
    self->credentials = [_credentials copy];
  }
  return self;
}
- (id)init {
  return [self initWithScheme:@"basic" credentials:nil];
}

- (void)dealloc {
  [self->scheme      release];
  [self->credentials release];
  [super dealloc];
}

/* accessors */

- (NSString *)scheme {
  return self->scheme;
}

- (NSData *)credentials {
  return self->credentials;
}

- (NSString *)userName {
#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
  // TODO: raise exception
  return nil;
#else
  return [self subclassResponsibility:_cmd];
#endif
}
- (NSString *)password {
#if APPLE_FOUNDATION_LIBRARY || NeXT_Foundation_LIBRARY
  // TODO: raise exception
  return nil;
#else
  return [self subclassResponsibility:_cmd];
#endif
}

/* description */

- (NSString *)stringValue {
  NSMutableString *str;
  
  str = [NSMutableString stringWithCapacity:64];
  [str appendString:self->scheme];
  [str appendString:@" "];
  [str appendString:[NSString stringWithCString:[self->credentials bytes]
                              length:[self->credentials length]]];
  return str;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: %@>",
                     NSStringFromClass([self class]), self,
                     [self stringValue]];
}

@end /* NGHttpCredentials */

@implementation NGConcreteHttpBasicCredentials

- (id)initWithScheme:(NSString *)_scheme credentials:(NSData *)_credentials {
  if ((self = [super initWithScheme:_scheme credentials:_credentials])) {
    NSData *data = [_credentials dataByDecodingBase64];

    if (data) {
      char *str   = (char *)[data bytes];
      int  len    = [data length];
      char *start = str;

      while ((*str != '\0') && (*str != ':') && (len > 0)) {
        str++;
        len--;
      }
      self->user = 
        [[NSString alloc] initWithCString:start length:(str - start)];
      // skip ':'
      str++; len--;
      
      if (len > 0) {
        self->password = [[NSString alloc] initWithCString:str length:len];
      }

      //NSLog(@"decoded user %@ password %@", self->user, self->password);
    }
    else
      NSLog(@"ERROR: could not decode credentials (invalid base64 encoding)");
  }
  return self;
}

- (void)dealloc {
  [self->user     release];
  [self->password release];
  [super dealloc];
}

/* accessors */

- (NSString *)userName {
  return self->user;
}
- (NSString *)password {
  return self->password;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<BasicCredentials[0x%p]: user=%@ hasPassword=%s>",
                     self,
                     [self userName],
                     self->password ? "yes" : "no"
                   ];
}

@end /* NGConcreteHttpBasicCredentials */

@implementation NGHttpChallenge

+ (id)basicChallengeWithRealm:(NSString *)_realm {
  return [[[self alloc] initWithScheme:@"basic" realm:_realm] autorelease];
}

- (id)initWithScheme:(NSString *)_scheme realm:(NSString *)_realm {
  if ((self = [super init])) {
    self->scheme     = [_scheme copy];
    self->parameters = [[NSMutableDictionary alloc] init];

    if (_realm)
      [(NSMutableDictionary *)self->parameters setObject:_realm forKey:@"realm"];
  }
  return self;
}
- (id)init {
  return [self initWithScheme:@"basic" realm:@"NGHttp"];
}

- (void)dealloc {
  [self->scheme     release];
  [self->parameters release];
  [super dealloc];
}

/* accessors */

- (NSString *)scheme {
  return self->scheme;
}

- (void)setRealm:(NSString *)_realm {
  [(NSMutableDictionary *)self->parameters setObject:_realm forKey:@"realm"];
}
- (NSString *)realm {
  return [self->parameters objectForKey:@"realm"];
}

/* description */

- (NSString *)stringValue {
  NSMutableString *str;
  NSEnumerator    *keys;
  NSString        *key  = nil;

  str  = [NSMutableString stringWithCapacity:128];
  keys = [self->parameters keyEnumerator];
  [str appendString:self->scheme];
  
  while ((key = [keys nextObject])) {
    [str appendString:@" "];
    [str appendString:key];
    [str appendString:@"=\""];
    [str appendString:[[self->parameters objectForKey:key] stringValue]];
    [str appendString:@"\""];
  }

  return str;
}

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p]: %@>",
                     NSStringFromClass([self class]), self,
                     [self stringValue]];
}

@end /* NGHttpChallenge */
