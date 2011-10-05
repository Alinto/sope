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

#import "common.h"
#import "NGHttpHeaderFieldParser.h"
#import "NGHttpHeaderFields.h"
#import "NGHttpCookie.h"

static Class NSArrayClass = Nil;

@implementation NGHttpStringHeaderFieldParser

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  unsigned              len   = 0;
  const unsigned char   *src  = NULL;
  NGHttpHostHeaderField *value = nil;
  NSString *str = nil;

  if ([_data isKindOfClass:[NSData class]]) {
    len   = [_data length];
    src = (unsigned char *)[_data bytes];
  }
  else {
    len = [_data cStringLength];
    src = (const unsigned char *)[_data cString];
  }
  if (len == 0) {
#if DEBUG
    NSLog(@"WARNING: empty value for header field %@ ..", _field);
#endif
    return nil;
  }

  // strip leading spaces
  while (isRfc822_LWSP(*src) && (len > 0)) {
    src++;
    len--;
  }

  str = [[NSString alloc] initWithCString:(char *)src length:len];
  NSAssert(str, @"string allocation failed ..");

  if ([_field isEqualToString:@"host"])
    value = [[NGHttpHostHeaderField alloc] initWithString:str];
  else if ([_field isEqualToString:@"user-agent"])
    value = [[NGHttpUserAgent alloc] initWithString:str];
  else if ([_field isEqualToString:@"connection"])
    value = [[NGHttpConnectionHeaderField alloc] initWithString:str];
  else
    value = RETAIN(str);
  
  RELEASE(str); str = nil;
  
  return AUTORELEASE(value);
}

@end /* NGHttpStringHeaderFieldParser */

@implementation NGHttpCredentialsFieldParser

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  unsigned      len     = 0;
  const unsigned char *src    = NULL;
  NSString      *scheme = nil;
  NSData        *data   = nil;
  
  if ([_data isKindOfClass:[NSData class]]) {
    len   = [_data length];
    src = (unsigned char *)[_data bytes];
  }
  else {
    len = [_data cStringLength];
    src = (const unsigned char *)[_data cString];
  }

  if (len == 0) {
    NSLog(@"WARNING: empty value for header field %@ ..", _field);
    return nil;
  }

  // strip leading spaces
  while (isRfc822_LWSP(*src) && (len > 0)) {
    src++;
    len--;
  }
  if (len == 0) {
    NSLog(@"WARNING: empty value for header field %@ ..", _field);
    return nil;
  }

  // find name
  {
    const unsigned char *start = src;
    
    while (!isRfc822_LWSP(*src) && (len > 0)) {
      src++;
      len--;
    }
    scheme = [NSString stringWithCString:(char *)start length:(src - start)];
  }

  // skip spaces
  while (isRfc822_LWSP(*src) && (len > 0)) {
    src++;
    len--;
  }
  if (len == 0) {
    NSLog(@"WARNING: invalid credentials header field %@ .. (missing credentials)",
          _field);
    return nil;
  }
  
  // make credentials
  data = [NSData dataWithBytes:src length:len];

  return [NGHttpCredentials credentialsWithScheme:[scheme lowercaseString]
                            credentials:data];
}

@end /* NGHttpCredentialsFieldParser */

@implementation NGHttpStringArrayHeaderFieldParser

- (id)initWithSplitChar:(unsigned char)_c {
  if ((self = [super init])) {
    self->splitChar = _c;
  }
  return self;
}
- (id)init {
  return [self initWithSplitChar:','];
}

- (id)parseValuePart:(const char *)_b length:(unsigned)_len
  zone:(NSZone *)_zone
{
  return [[NSString allocWithZone:_zone]
                    initWithCString:_b length:_len];
}

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  unsigned       len   = 0;
  const unsigned char  *src  = NULL;
  NSMutableArray *array = nil;
  
  if ([_data isKindOfClass:[NSData class]]) {
    len   = [_data length];
    src = (unsigned char *)[_data bytes];
  }
  else {
    len = [_data cStringLength];
    src = (const unsigned char *)[_data cString];
  }

  if (len == 0) {
#if DEBUG
    NSLog(@"WARNING: empty value for header field %@ ..", _field);
#endif
    return nil;
  }
  
#if 0 && DEBUG
  NSLog(@"field %@ is %@",
        _field,
        [[NSString alloc] initWithData:_data encoding:NSASCIIStringEncoding]);
#endif
  

  array = [NSMutableArray arrayWithCapacity:16];
  NSAssert(array, @"array allocation failed ..");
  do {
    const unsigned char *startPos = NULL;
    
    // strip leading spaces
    while ((len > 0) && (*src != '\0') && isRfc822_LWSP(*src)) {
      src++;
      len--;
    }
    if (len <= 0)
      break;
    else
      startPos = src;
    
    while ((len > 0) && (*src != self->splitChar) && !isRfc822_LWSP(*src)) {
      src++;
      len--;
    }
    
    if (src > startPos) {
      id part = nil;
      unsigned partLen;

      partLen = (src - startPos);
#if DEBUG && 0
      NSLog(@"field %@: current len=%i %s(%i)", _field, len, startPos, partLen);
#endif
      
      part = [self parseValuePart:(const char *)startPos
                   length:partLen
                   zone:[array zone]];
      if (part) {
        [array addObject:part];
        RELEASE(part); part = nil;
      }
    }

    if (len > 0) {
      if (isRfc822_LWSP(*src)) { // skip until splitchar or to len ..
        while ((*src != '\0') && (*src != self->splitChar) && (len > 0)) {
          src++;
          len--;
        }
      }
      else if (*src == self->splitChar) { // skip ','
        src++;
        len--;
      }
    }
  }
  while ((len > 0) && (*src != '\0'));

  return array;
}

@end /* NGHttpStringArrayHeaderFieldParser */

@implementation NGHttpCharsetHeaderFieldParser

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  id value = nil;

  if ((value = [super parseValue:_data ofHeaderField:_field]) == nil)
    return nil;
  
  if (NSArrayClass == Nil)
    NSArrayClass = [NSArray class];
    
  NSAssert([value isKindOfClass:NSArrayClass], @"invalid value ..");
  
  value = [[NGHttpCharsetHeaderField alloc] initWithArray:value];
  value = [value autorelease];
  return value;
}

@end /* NGHttpCharsetHeaderFieldParser */

@implementation NGHttpTypeArrayHeaderFieldParser

- (id)parseValuePart:(const char *)_b length:(unsigned)_len zone:(NSZone *)_zone {
  NSString   *typeString = [[NSString alloc] initWithCString:_b length:_len];
  NGMimeType *type       = nil;

  type = typeString ? [NGMimeType mimeType:typeString] : nil;
  RELEASE(typeString);
  
  return RETAIN(type);
}

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  id value = nil;

  value = [super parseValue:_data ofHeaderField:_field];
  if (value) {
    if (NSArrayClass == Nil)
      NSArrayClass = [NSArray class];
    
    NSAssert([value isKindOfClass:NSArrayClass], @"invalid value ..");
    
    value = [[NGHttpTypeSetHeaderField alloc] initWithArray:value];
    value = AUTORELEASE(value);
  }
  return value;
}

@end /* NGHttpTypeArrayHeaderFieldParser */

@implementation NGHttpLanguageArrayHeaderFieldParser

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  id value = nil;

  value = [super parseValue:_data ofHeaderField:_field];
  if (value) {
    if (NSArrayClass == Nil)
      NSArrayClass = [NSArray class];
    
    NSAssert([value isKindOfClass:NSArrayClass], @"invalid value ..");
    
    value = [[NGHttpLanguageSetHeaderField alloc] initWithArray:value];
    value = AUTORELEASE(value);
  }
  return value;
}

@end /* NGHttpLanguageArrayHeaderFieldParser */

@implementation NGHttpCookieFieldParser

- (id)init {
  return [self initWithSplitChar:';'];
}
- (id)initWithSplitChar:(unsigned char)_splitChar {
  if ((self = [super initWithSplitChar:_splitChar])) {
    self->fetchedCookies = NSCreateMapTable(NSObjectMapKeyCallBacks,
                                            NSObjectMapValueCallBacks,
                                            16);
    self->isRunning      = NO;
    self->foundInvalidPairs = NO;
  }
  return self;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  if (self->fetchedCookies) {
    NSFreeMapTable(self->fetchedCookies);
    self->fetchedCookies = NULL;
  }
  [super dealloc];
}
#endif

- (id)parseValuePart:(const char *)_bytes length:(unsigned)_len
  zone:(NSZone *)_z
{
  NGHttpCookie *cookie   = nil;
  unsigned     pos, toGo;

  for (pos = 0, toGo = _len; (toGo > 0) && (_bytes[pos] != '='); toGo--, pos++)
    ;
  
  if (toGo > 0) {
    NSString *name   = nil;
    NSString *value  = nil;
    
    // NSLog(@"pos=%i toGo=%i", pos, toGo);
    
    name  = [[NSString allocWithZone:_z]
                       initWithCString:_bytes
                       length:pos];
    value = [[NSString allocWithZone:_z]
                       initWithCString:&(_bytes[pos + 1])
                       length:(toGo - 1)];

    //NSLog(@"pair='%@'", [NSString stringWithCString:_bytes length:_len]);
    //NSLog(@"name='%@' value='%@'", name, value);

    if (name == nil) {
      NSLog(@"ERROR: invalid cookie pair missing name: %@",
            [NSString stringWithCString:_bytes length:_len]);
      RELEASE(name);
      RELEASE(value);
      return nil;
    }
    else if (value == nil) {
      NSLog(@"ERROR: invalid cookie pair missing value (name=%@): %@",
            name,
            [NSString stringWithCString:_bytes length:_len]);
      RELEASE(name);
      RELEASE(value);
      return nil;
    }
    else {
      cookie = (id)NSMapGet(self->fetchedCookies, name);
      
      if (cookie) {
        [cookie addAdditionalValue:[value stringByUnescapingURL]];
        cookie = nil;
      }
      else {
        cookie = [[NGHttpCookie allocWithZone:_z]
                                initWithName:[name stringByUnescapingURL]
                                value:[value stringByUnescapingURL]];
        NSMapInsert(self->fetchedCookies, name, cookie);
      }
    }
    
    RELEASE(name);  name  = nil;
    RELEASE(value); value = nil;
  }
#if DEBUG
  else {
    NSLog(@"ERROR(%s:%i): invalid cookie pair: %@",
          __PRETTY_FUNCTION__, __LINE__,
          [NSString stringWithCString:_bytes length:_len]);
    self->foundInvalidPairs = YES;
  }
#endif
  return cookie;
}

- (id)parseValue:(id)_data ofHeaderField:(NSString *)_field {
  id value = nil;
  
  if (NSArrayClass == Nil)
    NSArrayClass = [NSArray class];

  NSAssert(self->isRunning == NO, @"parser used in multiple threads !");
  self->foundInvalidPairs = NO;

#if 0 && DEBUG
  NSLog(@"cookie: field %@ is %@",
        _field,
        [[NSString alloc] initWithData:_data encoding:NSUTF8StringEncoding]);
#endif
  
  self->isRunning = YES; // semi-lock
  {
    value = [super parseValue:_data ofHeaderField:_field];
    NSResetMapTable(self->fetchedCookies);
  }
  self->isRunning = NO; // semi-unlock
  
  if (self->foundInvalidPairs) {
#if DEBUG
    NSString *s;

    if ([_data isKindOfClass:[NSData class]]) 
      s = [[NSString alloc] initWithData:_data encoding:NSASCIIStringEncoding];
    else
      s = _data;
    
    NSLog(@"ERROR(%s:%i): got invalid cookie pairs for field %@ data %@.",
          __PRETTY_FUNCTION__, __LINE__,
          _field, s);
    RELEASE(s);
#endif
    // return nil;
  }
  
  if (value) {
    NSAssert1([value isKindOfClass:NSArrayClass],
              @"invalid value '%@' ..", value);
    
    //value = [[NGHttpTypeSetHeaderField alloc] initWithArray:value];
    //AUTORELEASE(value);
  }
  return value;
}

@end /* NGHttpCookieFieldParser */

@implementation NGMimeHeaderFieldParserSet(HttpFieldParserSet)

static NGMimeHeaderFieldParserSet *httpSet = nil;

static inline void NGRegisterParser(NSString *_field, NSString *_parserClass) {
  id parser = [[NSClassFromString(_parserClass) alloc] init];
  
  if (parser) {
    [httpSet setParser:parser forField:_field];
    RELEASE(parser);
    parser = nil;
  }
  else {
    NSLog(@"WARNING: did not find header field parser %@", _parserClass);
  }
}

+ (id)defaultHttpHeaderFieldParserSet {
  if (httpSet == nil) {
    id parser = nil;
    
    httpSet = [[self alloc] initWithParseSet:
      [NGMimeHeaderFieldParserSet defaultRfc822HeaderFieldParserSet]];

    parser = [[NGHttpStringHeaderFieldParser alloc] init];
    [httpSet setParser:parser forField:@"host"];
    [httpSet setParser:parser forField:@"user-agent"];
    [httpSet setParser:parser forField:@"connection"];
    RELEASE(parser); parser = nil;

    NGRegisterParser(@"accept-charset",  @"NGHttpCharsetHeaderFieldParser");
    NGRegisterParser(@"accept-language", @"NGHttpLanguageArrayHeaderFieldParser");
    NGRegisterParser(@"accept",          @"NGHttpTypeArrayHeaderFieldParser");
    NGRegisterParser(@"accept-encoding", @"NGHttpStringArrayHeaderFieldParser");
    NGRegisterParser(@"cookie",          @"NGHttpCookieFieldParser");
    NGRegisterParser(@"authorization",   @"NGHttpCredentialsFieldParser");
  }
  return httpSet;
}

@end /* NGMimeHeaderFieldParserSet(HttpFieldParserSet) */
