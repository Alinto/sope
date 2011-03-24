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

#include "NGMimeType.h"
#include "NGConcreteMimeType.h"
#include "NGMimeUtilities.h"
#include "common.h"
#include <string.h>

NGMime_DECLARE NSString *NGMimeTypeText        = @"text";
NGMime_DECLARE NSString *NGMimeTypeAudio       = @"audio";
NGMime_DECLARE NSString *NGMimeTypeVideo       = @"video";
NGMime_DECLARE NSString *NGMimeTypeImage       = @"image";
NGMime_DECLARE NSString *NGMimeTypeApplication = @"application";
NGMime_DECLARE NSString *NGMimeTypeMultipart   = @"multipart";
NGMime_DECLARE NSString *NGMimeTypeMessage     = @"message";
NGMime_DECLARE NSString *NGMimeParameterTextCharset = @"charset";

static BOOL _parseMimeType(id self, NSString *_str, NSString **type,
                           NSString **subType, NSDictionary **parameters);

@implementation NGMimeType

+ (int)version {
  return 2;
}

static NSMutableDictionary *typeToClass = nil;

static inline Class
classForType(NSString *_type, NSString *_subType, NSDictionary *_parameters)
{
  Class c = Nil;
  if (_type == nil) return Nil;

  if ([_type isEqualToString:@"*"] || [_subType isEqualToString:@"*"])
    return [NGConcreteWildcardType class];

  if ([_type isEqualToString:NGMimeTypeApplication]) {
    if ([_subType isEqualToString:@"octet"])
      return [NGConcreteAppOctetMimeType class];
  }
  if ([_type isEqualToString:NGMimeTypeText]) {
    if ([_subType isEqualToString:@"x-vcard"]
        || [_subType isEqualToString:@"vcard"])
      return [NGConcreteTextVcardMimeType class];
  }
  
  c = [typeToClass objectForKey:_type];
  return c ? c : [NGConcreteGenericMimeType class];
}
static Class NSStringClass  = Nil;

+ (void)initialize {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;

    typeToClass = [[NSMutableDictionary alloc] initWithCapacity:10];
    [typeToClass setObject:[NGConcreteTextMimeType  class] 
		 forKey:NGMimeTypeText];
    [typeToClass setObject:[NGConcreteVideoMimeType class] 
		 forKey:NGMimeTypeVideo];
    [typeToClass setObject:[NGConcreteAudioMimeType class] 
		 forKey:NGMimeTypeAudio];
    [typeToClass setObject:[NGConcreteImageMimeType class] 
		 forKey:NGMimeTypeImage];
    [typeToClass setObject:[NGConcreteApplicationMimeType class]
                 forKey:NGMimeTypeApplication];
    [typeToClass setObject:[NGConcreteMultipartMimeType class]
                 forKey:NGMimeTypeMultipart];
    [typeToClass setObject:[NGConcreteMessageMimeType class]
                 forKey:NGMimeTypeMessage];
  }
}

+ (NSStringEncoding)stringEncodingForCharset:(NSString *)_s {
  NSString         *charset;
  NSStringEncoding encoding;
  BOOL             foundUnsupported;

  foundUnsupported = NO;  
  charset          = [_s lowercaseString];
  
  if ([charset length] == 0)
    encoding = [NSString defaultCStringEncoding];
  
  /* UTF-, ASCII */
  else if ([charset isEqualToString:@"us-ascii"])
    encoding = NSASCIIStringEncoding;
  else if ([charset isEqualToString:@"utf-8"])
    encoding = NSUTF8StringEncoding;
  else if ([charset isEqualToString:@"utf-16"])
    encoding = NSUnicodeStringEncoding;

  /* ISO Latin 1 */
  else if ([charset isEqualToString:@"iso-latin-1"])
    encoding = NSISOLatin1StringEncoding;
  else if ([charset isEqualToString:@"iso-8859-1"])
    encoding = NSISOLatin1StringEncoding;
  else if ([charset isEqualToString:@"8859-1"])
    encoding = NSISOLatin1StringEncoding;
  
  /* some unsupported, but known encoding */
  else if ([charset isEqualToString:@"ks_c_5601-1987"]) {
    encoding = NSISOLatin1StringEncoding;
    foundUnsupported = YES;
  }
  else if ([charset isEqualToString:@"euc-kr"]) {
    encoding = NSKoreanEUCStringEncoding;
  }
  else if ([charset isEqualToString:@"big5"]) {
    encoding = NSBIG5StringEncoding;
  }
  else if ([charset isEqualToString:@"iso-2022-jp"]) {
    encoding = NSISO2022JPStringEncoding;
  }
  else if ([charset isEqualToString:@"gb2312"]) {
    encoding = NSGB2312StringEncoding;
  }
  else if ([charset isEqualToString:@"koi8-r"]) {
    encoding = NSKOI8RStringEncoding;
  }
  else if ([charset isEqualToString:@"windows-1250"]) {
    encoding = NSWindowsCP1250StringEncoding;
  }
  else if ([charset isEqualToString:@"windows-1251"]) {
    encoding = NSWindowsCP1251StringEncoding;
  }
  else if ([charset isEqualToString:@"windows-1252"]) {
    encoding = NSWindowsCP1252StringEncoding;
  }
  else if ([charset isEqualToString:@"iso-8859-2"]) {
    encoding = NSISOLatin2StringEncoding;
  }
  else if ([charset isEqualToString:@"x-unknown"] ||
           [charset isEqualToString:@"unknown"]) {
    encoding = NSISOLatin1StringEncoding;
  }
  /* ISO Latin 9 */
#if !(NeXT_Foundation_LIBRARY || APPLE_Foundation_LIBRARY)
  else if ([charset isEqualToString:@"iso-latin-9"])
    encoding = NSISOLatin9StringEncoding;
  else if ([charset isEqualToString:@"iso-8859-15"])
    encoding = NSISOLatin9StringEncoding;
  else if ([charset isEqualToString:@"8859-15"])
    encoding = NSISOLatin9StringEncoding;
#endif
  else {
    [self logWithFormat:@"%s: unknown charset '%@'",
          __PRETTY_FUNCTION__, _s];
    encoding = NSISOLatin1StringEncoding;
  }
  return encoding;
}

// init

- (id)initWithType:(NSString *)_type subType:(NSString *)_subType
  parameters:(NSDictionary *)_parameters
{
  Class c;

  c = classForType(_type, _subType, _parameters);
  [self release];
  
  return [[c alloc] initWithType:_type subType:_subType
                    parameters:_parameters];
}

+ (id)mimeType:(NSString *)_type subType:(NSString *)_subType {
  Class c;

  c = classForType(_type, _subType, nil);
  
  NSAssert(c, @"did not find class for mimetype ..");

  return [[[c alloc] initWithType:_type subType:_subType
                     parameters:nil] autorelease];
}

+ (id)mimeType:(NSString *)_type subType:(NSString *)_subType
  parameters:(NSDictionary *)_parameters
{
  Class c;

  c = classForType(_type, _subType, _parameters);
  NSAssert(c, @"did not find class for mimetype ..");
  
  return [[[c alloc] initWithType:_type subType:_subType
                     parameters:_parameters] autorelease];
}

+ (id)mimeType:(NSString *)_stringValue {
  NSString     *type, *subType;
  NSDictionary *parameters;

  if ([_stringValue length] == 0)
    /* empty ... */
    return nil;

  parameters = nil;
  type       = nil;
  subType    = nil;

  if (_parseMimeType(self, _stringValue, &type, &subType, &parameters)) {
    Class c;
    id    result;

    c = classForType(type, subType, nil);
    NSAssert(c,       @"did not find class for mimetype ..");
    NSAssert(type,    @"didn't parse type ..");
    NSAssert(subType, @"didn't parse subtype ..");

    result = [c alloc];
    NSAssert(result, @"allocation of mimetype failed ..");

    result = [result initWithType:type subType:subType parameters:parameters];
    NSAssert(result, @"initialization of mimetype failed ..");

    result = [result autorelease];
    NSAssert(result, @"autorelease of mimetype failed ..");

    return result;
  }
  else {
    [self logWithFormat:@"ERROR[%s]: parsing of mimetype '%@' failed !",
          __PRETTY_FUNCTION__, _stringValue];
    return nil; // parsing failed
  }
}

/* types */

- (NSString *)type {
  [self subclassResponsibility:_cmd];
  return nil;
}
- (NSString *)subType {
  [self subclassResponsibility:_cmd];
  return nil;
}
- (BOOL)isCompositeType {
  [self subclassResponsibility:_cmd];
  return NO;
}

/* comparing types */

- (BOOL)isEqual:(id)_other {
  if (_other == nil)  return NO;
  if (_other == self) return YES;

  return ([_other isKindOfClass:[NGMimeType class]])
    ? [self isEqualToMimeType:_other]
    : NO;
}

- (BOOL)isEqualToMimeType:(NGMimeType *)_type {
  if (_type == nil)  return NO;
  if (_type == self) return YES;

  if (![self hasSameType:_type])
    return NO;

  if (![[_type parametersAsDictionary] isEqual:[self parametersAsDictionary]])
    return NO;

  return YES;
}

- (BOOL)hasSameGeneralType:(NGMimeType *)_other { // only the 'type' must match
  if (_other == self) return YES;
  if ([_other isCompositeType] != [self isCompositeType]) return NO;
  if (![[_other type]    isEqualToString:[self type]])    return NO;
  return YES;
}
- (BOOL)hasSameType:(NGMimeType *)_other { // parameters need not match
  if (_other == nil)  return NO;
  if (_other == self) return YES;
  if ([_other isCompositeType] != [self isCompositeType]) return NO;
  if (![[_other type]    isEqualToString:[self type]])    return NO;
  if (![[_other subType] isEqualToString:[self subType]]) return NO;
  return YES;
}

- (BOOL)doesMatchType:(NGMimeType *)_other { // interpretes wildcards
  NSString *t, *st, *ot, *ost;

  t   = [self type];
  st  = [self subType];
  ot  = [_other type];
  ost = [_other subType];

  if ([t isEqualToString:@"*"] || [ot isEqualToString:@"*"]) {
    t   = @"*";
    ot  = @"*";
  }
  if (![t  isEqualToString:ot]) return NO;

  if ([st isEqualToString:@"*"] || [ost isEqualToString:@"*"]) {
    ot  = @"*";
    ost = @"*";
  }
  if (![st isEqualToString:ost]) return NO;
  
  return YES;
}

/* parameters */

- (NSEnumerator *)parameterNames {
  [self doesNotRecognizeSelector:_cmd]; // subclass
  return nil;
}
- (id)valueOfParameter:(NSString *)_parameterName {
  [self doesNotRecognizeSelector:_cmd]; // subclass
  return nil;
}

/* representations */

- (NSDictionary *)parametersAsDictionary {
  NSMutableDictionary *parameters;
  NSString            *name;
  NSDictionary        *d;
  NSEnumerator        *names;

  if ((names = [self parameterNames]) == nil)
    return nil;

  parameters = [[NSMutableDictionary alloc] init];
  while ((name = [names nextObject]))
    [parameters setObject:[self valueOfParameter:name] forKey:name];

  d = [parameters copy];
  [parameters release];
  return [d autorelease];
}

- (NSString *)parametersAsString {
  NSEnumerator    *names;
  NSMutableString *result;
  NSString        *name;

  if ((names = [self parameterNames]) == nil)
    return nil;
  
  result = [NSMutableString stringWithCapacity:64];
  while ((name = [names nextObject])) {
    NSString *value;

    value = [[self valueOfParameter:name] stringValue];
    
    [result appendString:@"; "];
    [result appendString:name];
    [result appendString:@"="];
    
    if ([self valueNeedsQuotes:value]) {
      [result appendString:@"\""];
      [result appendString:value];
      [result appendString:@"\""];
    }
    else
      [result appendString:value];
  }
  return result;
}

- (BOOL)valueNeedsQuotes:(NSString *)_parameterValue {
  NSData *stringData;
  const char *cstr;
  unsigned int count, max;
  BOOL needsQuote;

  needsQuote = NO;

  stringData = [_parameterValue dataUsingEncoding:NSUTF8StringEncoding];
  cstr = [stringData bytes];
  max = [stringData length];
  count = 0;
  while (!needsQuote && count < max) {
    if (isMime_SpecialByte(*(cstr + count))
	|| *(cstr + count) == 32)
      needsQuote = YES;
    else
      count++;
  }

  return needsQuote;
}

- (NSString *)stringValue {
  [self subclassResponsibility:_cmd];
  return nil;
}

// NSCoding

- (Class)classForCoder {
  return [NGMimeType class];
}

- (void)encodeWithCoder:(NSCoder *)_encoder {
  [_encoder encodeObject:[self type]];
  [_encoder encodeObject:[self subType]];
  [_encoder encodeObject:[self parametersAsDictionary]];
}

- (id)initWithCoder:(NSCoder *)_decoder {
  NSString     *type, *subType;
  NSDictionary *paras;

  type    = [_decoder decodeObject];
  subType = [_decoder decodeObject];
  paras   = [_decoder decodeObject];

  return [self initWithType:type subType:subType parameters:paras];
}

// NSCopying

- (id)copyWithZone:(NSZone *)_zone {
  return [[NGMimeType allocWithZone:_zone]
                      initWithType:[self type] subType:[self subType]
                      parameters:[self parametersAsDictionary]];
}

// description

- (NSString *)description {
  return [NSString stringWithFormat:@"<NGMimeType: %@>", [self stringValue]];
}

@end /* NGMimeType */

typedef struct {
  NSString *image;
  NSString *video;
  NSString *audio;
  NSString *text;
  NSString *star;
  NSString *application;
  NSString *multipart;
  NSString *message;
} NGMimeTypeConstants;

typedef struct {
  NSString *plain;
  NSString *star;
  NSString *mixed;
  NSString *jpeg;
  NSString *png;
  NSString *gif;
  NSString *xml;
  NSString *html;
  NSString *css;
  NSString *xMng;
  NSString *xhtmlXml;
  NSString *rfc822;
  NSString *octetStream;
} NGMimeSubTypeConstants;

static NGMimeTypeConstants      *MimeTypeConstants      = NULL;
static NGMimeSubTypeConstants   *MimeSubTypeConstants   = NULL;

static NSString *_stringForType(char *_type, int _len) {
  if (NSStringClass == Nil) NSStringClass = [NSString class];

  if (MimeTypeConstants == NULL) {
    MimeTypeConstants = malloc(sizeof(NGMimeTypeConstants));
    MimeTypeConstants->image       = NGMimeTypeImage;
    MimeTypeConstants->video       = NGMimeTypeVideo;
    MimeTypeConstants->audio       = NGMimeTypeAudio;
    MimeTypeConstants->text        = NGMimeTypeText;
    MimeTypeConstants->star        = @"*";
    MimeTypeConstants->application = NGMimeTypeApplication;
    MimeTypeConstants->multipart   = NGMimeTypeMultipart;
    MimeTypeConstants->message     = NGMimeTypeMessage;
  }
  switch (_len) {
    case 0:
      return @"";
    case 1:
      if (_type[0] == '*')
        return MimeTypeConstants->star;
      break;
    case 4:
      if (strncmp(_type, "text", 4) == 0) 
        return MimeTypeConstants->text;
      break;
    case 5:
      if (_type[0] == 'i') {
        if (strncmp(_type, "image", 5) == 0) 
          return MimeTypeConstants->image;
      }
      else if (_type[0] == 'v') {
        if (strncmp(_type, "video", 5) == 0) 
          return MimeTypeConstants->video;
      }
      else if (_type[0] == 'a') {
        if (strncmp(_type, "audio", 5) == 0) 
          return MimeTypeConstants->audio;
      }
      break;
    case 7:
      if (strncmp(_type, "message", 7) == 0)
        return MimeTypeConstants->message;
      break;
    case 9:
      if (strncmp(_type, "multipart", 9) == 0)
        return MimeTypeConstants->multipart;
      break;    case 11:
      if (strncmp(_type, "application", 11) == 0)
        return MimeTypeConstants->application;
      break;
  }
  return [NSStringClass stringWithCString:_type length:_len];
}

static NSString *_stringForSubType(char *_type, int _len) {
  if (NSStringClass == Nil) NSStringClass = [NSString class];

  if (MimeSubTypeConstants == NULL) {
    MimeSubTypeConstants = malloc(sizeof(NGMimeSubTypeConstants));

    MimeSubTypeConstants->plain       = @"plain";
    MimeSubTypeConstants->star        = @"*";
    MimeSubTypeConstants->mixed       = @"mixed";
    MimeSubTypeConstants->jpeg        = @"jpeg";
    MimeSubTypeConstants->png         = @"png";
    MimeSubTypeConstants->gif         = @"gif";
    MimeSubTypeConstants->xml         = @"xml";
    MimeSubTypeConstants->html        = @"html";
    MimeSubTypeConstants->css         = @"css";
    MimeSubTypeConstants->xMng        = @"xMng";
    MimeSubTypeConstants->xhtmlXml    = @"xhtmlXml";
    MimeSubTypeConstants->rfc822      = @"rfc822";
    MimeSubTypeConstants->octetStream = @"octet-stream";
  }
  switch (_len) {
    case 0:
      return @"";

    case 1:
      if (_type[0] == '*')
        return MimeSubTypeConstants->star;
      break;
    case 3:
      if (_type[0] == 'p') {
        if (strncmp(_type, "png", 3) == 0) 
          return MimeSubTypeConstants->png;
      }
      else if (_type[0] == 'g') {
        if (strncmp(_type, "gif", 3) == 0) 
          return MimeSubTypeConstants->gif;
      }
      else if (_type[0] == 'c') {
        if (strncmp(_type, "css", 3) == 0) 
          return MimeSubTypeConstants->css;
      }
      else if (_type[0] == 'x') {
        if (strncmp(_type, "xml", 3) == 0) 
          return MimeSubTypeConstants->xml;
      }
      break;
    case 4:
      if (_type[0] == 'h') {
        if (strncmp(_type, "html", 4) == 0) 
          return MimeSubTypeConstants->html;
      }
      else if (_type[0] == 'j') {
        if (strncmp(_type, "jpeg", 4) == 0) 
          return MimeSubTypeConstants->jpeg;
      }
      break;
    case 5:
      if (_type[0] == 'p') {
        if (strncmp(_type, "plain", 5) == 0) 
          return MimeSubTypeConstants->plain;
      }
      else if (_type[0] == 'm') {
        if (strncmp(_type, "mixed", 5) == 0) 
          return MimeSubTypeConstants->mixed;
      }
      else if (_type[0] == 'x') {
        if (strncmp(_type, "x-mng", 5) == 0) 
          return MimeSubTypeConstants->xMng;
      }
      break;
    case 6:
      if (strncmp(_type, "rfc822", 6) == 0) 
          return MimeSubTypeConstants->rfc822;
      break;
    case 9:
      if (strncmp(_type, "xhtml+xml", 9) == 0) 
          return MimeSubTypeConstants->xhtmlXml;
      break;
    case 12:
      if (strncmp(_type, "octet-stream", 12) == 0) 
          return MimeSubTypeConstants->octetStream;
      break;
  }
  return [NSStringClass stringWithCString:_type length:_len];
}

static BOOL _parseMimeType(id self, NSString *_str, NSString **type,
                           NSString **subType, NSDictionary **parameters)
{
  unsigned len;
  unichar  *cstr, *tmp;
  unsigned slen  = [_str length];
  unichar  buf[slen + 1];

  len  = 0;
  cstr = &(buf[0]);

  [_str getCharacters:buf]; buf[slen] = '\0';

  /* skip leading spaces */
  while (isRfc822_LWSP(*cstr) && (*cstr != '\0'))
    cstr++;

  /* type name */
  tmp = cstr; // keep beginning of type name
  len = 0;
  while ((*cstr != '/') && (*cstr != '\0') && (*cstr != ';')) {
    cstr++;
    len++;
  }
  if (len == 0) return NO; // no type was read

  {
    unsigned char     buf[len + 3];
    register unsigned i;
    
    buf[len] = '\0';
    for (i = 0; i < len; i++) buf[i] = tolower(tmp[i]);
    *type = _stringForType((char *)buf, len);
  }

  if (*cstr == '/') { // subtype name
    cstr++; // skip '/'

    tmp = cstr; // keep beginning of subtype name
    len = 0;
    while ((*cstr != ';') && (!isRfc822_LWSP(*cstr)) && (*cstr != '\0')) {
      cstr++;
      len++;
    }
    if (len <= 0) {
      *subType = @"*";
      return YES; // no subtype was read      
    }
    else {
      unsigned char     buf[len + 1];
      register unsigned i;
      
      buf[len] = '\0';
      for (i = 0; i < len; i++) buf[i] = tolower(tmp[i]);
      *subType = _stringForSubType((char *)buf, len);
    }
  }
  else {
    *subType = @"*";
  }

  // skip spaces
  while (isRfc822_LWSP(*cstr) && (*cstr != '\0'))
    cstr++;
  
  if (*cstr == ';') // skip ';' (parameter separator)
    cstr++;

  // skip spaces
  while (isRfc822_LWSP(*cstr) && (*cstr != '\0'))
    cstr++;

  if (*cstr == '\0') { // string ends, no parameters defined
    *parameters = nil;
    return YES;
  }
  // parse parameters
  *parameters = parseParameters(self, _str, cstr);
  if (![*parameters isNotEmpty])
    *parameters = nil;
  
  return YES;
}
