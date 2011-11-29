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

#include <NGObjWeb/WOMessage.h>
#include <NGExtensions/NGHashMap.h>
#include <NGExtensions/NSString+misc.h>
#include "common.h"
#include <string.h>

// #define STRIP_MULTIPLE_SPACES // this doesn't work with <pre> tags !

@implementation WOMessage

typedef struct _WOMessageProfileInfo {
  unsigned append;
  unsigned appendC;
  unsigned appendChr;
  unsigned appendXML;
  unsigned appendHTML;
} WOMessageProfileInfo;

static Class            NSStringClass    = Nil;
static BOOL             printProfile     = NO;
static int              DEF_CONTENT_SIZE = 20000;
static NSStringEncoding defaultEncoding  = 0;

static WOMessageProfileInfo profile    = { 0, 0, 0, 0, 0 };
static WOMessageProfileInfo profilemax = { 0, 0, 0, 0, 0 };
static WOMessageProfileInfo profiletot = { 0, 0, 0, 0, 0 };

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  
  if (NSStringClass == Nil)
    NSStringClass = [NSString class];
  
  printProfile = [ud boolForKey:@"WOProfileResponse"];

  if ([ud boolForKey:@"WOMessageUseUTF8"]) {
    defaultEncoding = NSUTF8StringEncoding;
  }
  else {
#ifdef __APPLE__
    //#warning default encoding is ISO Latin 1 ...
    // TODO: why are we doing this?
    defaultEncoding = NSISOLatin1StringEncoding;
#else
    defaultEncoding = [NSStringClass defaultCStringEncoding];
#endif
  }
}

static inline void _ensureBody(WOMessage *self) {
  if (self->content == nil) {
    self->content = [[NSMutableData alloc] initWithCapacity:DEF_CONTENT_SIZE];
    self->addBytes = (void *)
      [self->content methodForSelector:@selector(appendBytes:length:)];
  }
}

static __inline__ NSMutableData *_checkBody(WOMessage *self) {
  if (self->content == nil) {
    self->content = [[NSMutableData alloc] initWithCapacity:DEF_CONTENT_SIZE];
    self->addBytes = (void *)
      [self->content methodForSelector:@selector(appendBytes:length:)];
  }
  return self->content;
}

+ (int)version {
  return 5;
}

+ (void)setDefaultEncoding:(NSStringEncoding)_encoding {
  defaultEncoding = _encoding;
}
+ (NSStringEncoding)defaultEncoding {
  return defaultEncoding;
}

- (id)init {
  if ((self = [super init])) {
    self->contentEncoding = [[self class] defaultEncoding];
    
    self->addChar = (void*)
      [self methodForSelector:@selector(appendContentCharacter:)];
    self->addStr  = (void *)
      [self methodForSelector:@selector(appendContentString:)];
    self->addHStr = (void *)
      [self methodForSelector:@selector(appendContentHTMLString:)];
    self->addCStr = (void *)
      [self methodForSelector:@selector(appendContentCString:)];
    
    self->header  = [[NGMutableHashMap allocWithZone:[self zone]] init];
    self->version = @"HTTP/1.1";
  }
  return self;
}

- (void)dealloc {
  [self->domCache      release];
  [self->contentStream release];
  [self->cookies  release];
  [self->version  release];
  [self->content  release];
  [self->header   release];
  [self->userInfo release];
  [super dealloc];
}

/* accessors */

- (void)setUserInfo:(NSDictionary *)_userInfo {
  ASSIGN(self->userInfo, _userInfo);
}
- (NSDictionary *)userInfo {
  return self->userInfo;
}

/* HTTP */

- (void)setHTTPVersion:(NSString *)_httpVersion {
  id old;
  if (self->version == _httpVersion)
    return;
  old = self->version;
  self->version = [_httpVersion copy];
  [old release];
  
  if (self->version != nil && ![_httpVersion hasPrefix:@"HTTP/"]) {
    [self warnWithFormat:
            @"you apparently passed in an invalid HTTP version: '%@'",
            _httpVersion];
  }
}
- (void)setHttpVersion:(NSString *)_httpVersion {
  // deprecated
  [self setHTTPVersion:_httpVersion];
}
- (NSString *)httpVersion {
  return self->version;
}

/* cookies (new in WO4) */

- (void)addCookie:(WOCookie *)_cookie {
  if (self->cookies == nil)
    self->cookies = [[NSMutableArray allocWithZone:[self zone]] init];
  [self->cookies addObject:_cookie];
}

- (void)removeCookie:(WOCookie *)_cookie {
  [self->cookies removeObject:_cookie];
}

- (NSArray *)cookies {
  return self->cookies;
}

/* header */

- (void)setHeaders:(NSDictionary *)_headers {
  NSEnumerator *keys;
  NSString *key;

  keys = [_headers keyEnumerator];
  while ((key = [[keys nextObject] lowercaseString])) {
    id value;
    
    value = [_headers objectForKey:key];
    if ([value isKindOfClass:[NSArray class]]) {
      NSEnumerator *e = [value objectEnumerator];

      while ((value = [e nextObject]))
	[self appendHeader:value forKey:key];
    }
    else
      [self appendHeader:value forKey:key];
  }
}

- (void)setHeader:(NSString *)_header forKey:(NSString *)_key {
  [self->header setObject:[_header stringValue]
                   forKey:[_key lowercaseString]];
}
- (NSString *)headerForKey:(NSString *)_key {
  return [[self->header objectEnumeratorForKey:[_key lowercaseString]]
           nextObject];
}

- (void)appendHeader:(NSString *)_header forKey:(NSString *)_key {
  [self->header addObject:_header forKey:[_key lowercaseString]];
}
- (void)appendHeaders:(NSArray *)_headers forKey:(NSString *)_key {
  [self->header addObjects:_headers forKey:[_key lowercaseString]];
}

- (void)setHeaders:(NSArray *)_headers forKey:(NSString *)_key {
  NSEnumerator *e;
  id value;
  NSString *lowerKey;

  lowerKey = [_key lowercaseString];
  e = [_headers objectEnumerator];

  [self->header removeAllObjectsForKey:lowerKey];
  
  while ((value = [e nextObject]))
    [self->header addObject:value forKey:lowerKey];
}
- (NSArray *)headersForKey:(NSString *)_key {
  NSEnumerator *values;

  if ((values
       = [self->header objectEnumeratorForKey:[_key lowercaseString]])) {
    NSMutableArray *array = nil;
    id value = nil;
    
    array = [[NSMutableArray allocWithZone:[self zone]] init];

    while ((value = [values nextObject]))
      [array addObject:value];

    return [array autorelease];
  }
  return nil;
}

- (NSArray *)headerKeys {
  NSEnumerator *values;

  if ((values = [self->header keyEnumerator])) {
    NSMutableArray *array;
    id name = nil;
    array = [NSMutableArray array];

    while ((name = [values nextObject]))
      [array addObject:name];

    return array;
  }
  return nil;
}

- (NSDictionary *)headers {
  return [self->header asDictionary];
}

- (NSString *)headersAsString {
  NSMutableString *ms;
  NSEnumerator *keys;
  NSString     *key;
  
  ms = [NSMutableString stringWithCapacity:1024];
  
  /* headers */
  keys = [[self headerKeys] objectEnumerator];
  while ((key = [keys nextObject])) {
    NSEnumerator *vals;
    id val;
    
    vals = [[self headersForKey:key] objectEnumerator];
    while ((val = [vals nextObject])) {
      [ms appendString:key];
      [ms appendString:@": "];
      [ms appendString:[val stringValue]];
      [ms appendString:@"\r\n"];
    }
  }
  return ms;
}

/* profiling */

- (void)_printProfile {
  if (profile.append + profile.appendC + profile.appendChr +
      profile.appendXML + profile.appendHTML == 0)
    return;
  
  /* calc max */
  if (profile.append > profilemax.append)
    profilemax.append = profile.append;
  if (profile.appendC > profilemax.appendC) 
    profilemax.appendC = profile.appendC;
  if (profile.appendHTML > profilemax.appendHTML) 
    profilemax.appendHTML = profile.appendHTML;
  
  /* calc total */
  profiletot.append     += profile.append;
  profiletot.appendC    += profile.appendC;
  profiletot.appendChr  += profile.appendChr;
  profiletot.appendHTML += profile.appendHTML;
  profiletot.appendXML  += profile.appendXML;
  
  /* print */
  
  [self logWithFormat:@"PROFILE: WOResponse:\n"
        @"  appendContentString:     %8i max %8i total %8i\n"
        @"  appendContentCString:    %8i max %8i total %8i\n"
        @"  appendContentCharacter:  %8i max %8i total %8i\n"
        @"  appendContentXMLString:  %8i max %8i total %8i\n"
        @"  appendContentHTMLString: %8i max %8i total %8i\n",
        profile.append,     profilemax.append,     profiletot.append,
        profile.appendC,    profilemax.appendC,    profiletot.appendC,
        profile.appendChr,  profilemax.appendChr,  profiletot.appendChr,
        profile.appendXML,  profilemax.appendXML,  profiletot.appendXML,
        profile.appendHTML, profilemax.appendHTML, profiletot.appendHTML];
  
  /* reset profile */
  memset(&profile, 0, sizeof(profile));
}

/* generic content */

- (void)setContent:(NSData *)_data {
  id old;
  
  if (self->content == (id)_data) 
    return;
  
  old = self->content;
  self->content = [_data mutableCopy];
  [old release];
}
- (NSData *)content {
  if (printProfile) [self _printProfile];
  return self->content;
}
- (NSString *)contentAsString {
  NSString *s;
  NSData   *c;
  
  if ((c = [self content]) == nil)
    return nil;
  
  s = [[NSString alloc] initWithData:c encoding:[self contentEncoding]];
  if (s == nil) {
    [self warnWithFormat:
	    @"could not convert request content (len=%d) to encoding %i (%@)",
	    [c length], [self contentEncoding],
	    [NSString localizedNameOfStringEncoding:[self contentEncoding]]];
  }
  return [s autorelease];
}
- (BOOL)doesStreamContent {
  return self->contentStream != nil ? YES : NO;
}

- (void)setContentEncoding:(NSStringEncoding)_encoding {
  self->contentEncoding = _encoding;
}  
- (NSStringEncoding)contentEncoding {
  return self->contentEncoding;
}

/* structured content */

- (void)appendContentBytes:(const void *)_bytes length:(unsigned)_l {
  if (_bytes == NULL || _l == 0) return;
  if (self->content == nil) _ensureBody(self);
  self->addBytes(self->content, @selector(appendBytes:length:), _bytes, _l);
}

- (void)appendContentCharacter:(unichar)_c {
  unsigned char bc[2] = {0, 0};
  
  profile.appendChr++;
  
  *(&bc[0]) = _c;
  if (self->content == nil) _ensureBody(self);
  
  switch (self->contentEncoding) {
    case NSISOLatin1StringEncoding:
    case NSASCIIStringEncoding:
      /* those two encodings are == Unicode ... */
      self->addBytes(self->content, @selector(appendBytes:length:), &(bc[0]), 1);
      break;
      
    case NSUnicodeStringEncoding:
      /* directly add 16-byte char ... */
      self->addBytes(self->content, @selector(appendBytes:length:), 
                     &_c, sizeof(_c));
      break;
      
    case NSUTF8StringEncoding:
      /* directly add a byte if 1-byte char (<127 in UTF-8) */
      if (_c < 127) {
        self->addBytes(self->content, @selector(appendBytes:length:), &(bc[0]), 1);
        break;
      }
      /* *intended* fall-through !!! */
      
    default: {
      /* otherwise create string for char and ask string to convert to data */
      NSString *s;
    
#if DEBUG
      [self warnWithFormat:
              @"using NSString to add a character %i,0x%p"
              @"(slow, encoding=%i).", _c, _c, self->contentEncoding];
#endif
      
      if ((s = [[NSStringClass alloc] initWithCharacters:&_c length:1])) {
        self->addStr(self, @selector(appendContentString:), s);
        [s release];
      }
      break;
    }
  }
}
- (void)appendContentData:(NSData *)_data {
  if (_data == nil) return;
  [_checkBody(self) appendData:_data];
}

- (void)appendContentHTMLAttributeValue:(NSString *)_value {
  self->addStr(self, @selector(appendContentString:), 
               [_value stringByEscapingHTMLAttributeValue]);
  profile.appendHTML++;
}
- (void)appendContentHTMLString:(NSString *)_value {
  self->addStr(self, @selector(appendContentString:), 
               [_value stringByEscapingHTMLString]);
  profile.appendHTML++;
}

- (void)appendContentXMLAttributeValue:(NSString *)_value {
  self->addStr(self, @selector(appendContentString:), 
               [_value stringByEscapingXMLAttributeValue]);
  profile.appendXML++;
}
- (void)appendContentXMLString:(NSString *)_value {
  if (_value == nil) return;
  self->addStr(self, @selector(appendContentString:), 
               [_value stringByEscapingXMLString]);
  profile.appendXML++;
}

- (void)appendContentCString:(const unsigned char *)_value {
  /* we assume that cString == ASCII !!! */
  register unsigned len;

  profile.appendC++;

  if (self->content == nil) _ensureBody(self);
  if ((len = _value ? strlen((char *)_value) : 0) == 0)
    return;
  
  switch (self->contentEncoding) {
    case NSISOLatin1StringEncoding:
    case NSASCIIStringEncoding:
    case NSUTF8StringEncoding:
      self->addBytes(self->content, @selector(appendBytes:length:), 
                     _value, len);
      return;
    
    case NSUnicodeStringEncoding:
    default: {
      /* worst case ... */
      NSString *s;
      
      if ((s = [[NSString alloc] initWithCString:(char *)_value])) {
        self->addStr(self, @selector(appendContentString:), s);
        [s release];
      }
    }
  }
}

- (void)appendContentString:(NSString *)_value {
  NSData *cdata;
  
  profile.append++;
  
  if ([_value length] == 0)
    return;
  
  cdata = [_value dataUsingEncoding:self->contentEncoding
                  allowLossyConversion:NO];
#if 0
  if ([_value length] > 9000) {
    char *cstr;
    unsigned i, len;

#if 0
    cstr = [cdata bytes];
    len  = [cdata length];
#else
    cstr = [_value cString];
    len  = [_value cStringLength];
#endif

    printf("\n\n*** add contentstring (value-enc=%i,%i,%i) "
           "(len=%i, dlen=%i): '",
           [_value smallestEncoding],
           [_value fastestEncoding],
           self->contentEncoding,
           [_value length], len);
    fwrite(cstr, 1, len, stdout);
    printf("'\n");
    
    for (i = len - 20; i < len; i++)
      printf("%5i: 0x%p %4i\n", i, cstr[i], cstr[i]);
    fflush(stdout);
  }
#endif
  if (cdata == NULL) {
    [self errorWithFormat:
            @"(%s): could not convert string non-lossy to encoding %i !",
            __PRETTY_FUNCTION__, self->contentEncoding];
    cdata = [_value dataUsingEncoding:self->contentEncoding
                    allowLossyConversion:YES];
  }
  [self appendContentData:cdata];
}

@end /* WOMessage */

@implementation WOMessage(Escaping)

static inline void
_escapeHtmlValue(unsigned char c, unsigned char *buf, int *pos)
{
  int j = *pos;
  switch (c) {
    case '&':
      buf[j] = '&'; j++; buf[j] = 'a'; j++; buf[j] = 'm'; j++;
      buf[j] = 'p'; j++; buf[j] = ';';
      break;
    case '"':
      buf[j] = '&'; j++; buf[j] = 'q'; j++; buf[j] = 'u'; j++;
      buf[j] = 'o'; j++; buf[j] = 't'; j++; buf[j] = ';';
      break;
    case '<':
      buf[j] = '&'; j++; buf[j] = 'l'; j++; buf[j] = 't'; j++;
      buf[j] = ';';
      break;
    case '>':
      buf[j] = '&'; j++; buf[j] = 'g'; j++; buf[j] = 't'; j++;
      buf[j] = ';';
      break;

    default:
      buf[j] = c;
      break;
  }
  *pos = j;
}

static inline void
_escapeAttrValue(unsigned char c, unsigned char *buf, int *pos)
{
  int j = *pos;
  switch (c) {
    case '&':
      buf[j] = '&'; j++; buf[j] = 'a'; j++; buf[j] = 'm'; j++;
      buf[j] = 'p'; j++; buf[j] = ';';
      break;
    case '"':
      buf[j] = '&'; j++; buf[j] = 'q'; j++; buf[j] = 'u'; j++;
      buf[j] = 'o'; j++; buf[j] = 't'; j++; buf[j] = ';';
      break;
    case '<':
      buf[j] = '&'; j++; buf[j] = 'l'; j++; buf[j] = 't'; j++;
      buf[j] = ';';
      break;
    case '>':
      buf[j] = '&'; j++; buf[j] = 'g'; j++; buf[j] = 't'; j++;
      buf[j] = ';';
      break;

    case '\t':
      buf[j] = '&'; j++; buf[j] = '#'; j++; buf[j] = '9'; j++;
      buf[j] = ';';
      break;
    case '\n':
      buf[j] = '&'; j++; buf[j] = '#'; j++; buf[j] = '1'; j++;
      buf[j] = '0'; j++; buf[j] = ';';
      break;
    case '\r':
      buf[j] = '&'; j++; buf[j] = '#'; j++; buf[j] = '1'; j++;
      buf[j] = '3'; j++; buf[j] = ';';
      break;
          
    default:
      buf[j] = c;
      break;
  }
  *pos = j;
}


+ (NSString *)stringByEscapingHTMLString:(NSString *)_string {
  return [_string stringByEscapingHTMLString];
}

+ (NSString *)stringByEscapingHTMLAttributeValue:(NSString *)_string {
  return [_string stringByEscapingHTMLAttributeValue];
}

@end /* WOMessage(Escaping) */
