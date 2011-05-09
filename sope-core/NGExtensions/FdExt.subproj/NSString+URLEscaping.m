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

#include "NSString+misc.h"
#include "common.h"

/*
  TODO: support new Panther API?:
- (NSString *)stringByAddingPercentEscapesUsingEncoding:(NSStringEncoding)e
- (NSString *)stringByReplacingPercentEscapesUsingEncoding:(NSStringEncoding)e
*/

@implementation NSString(URLEscaping)

static int useUTF8Encoding = -1;

static inline BOOL doUseUTF8Encoding(void) {
  if (useUTF8Encoding == -1) {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    
    useUTF8Encoding = [ud boolForKey:@"NGUseUTF8AsURLEncoding"] ? 1 : 0;
    if (useUTF8Encoding)
      NSLog(@"Note: Using UTF-8 as URL encoding in NGExtensions.");
  }
  return useUTF8Encoding ? YES : NO;
}

static inline BOOL isUrlAlpha(unsigned char _c) {
  return
    (((_c >= 'a') && (_c <= 'z')) ||
     ((_c >= 'A') && (_c <= 'Z')))
    ? YES : NO;
}
static inline BOOL isUrlDigit(unsigned char _c) {
  return ((_c >= '0') && (_c <= '9')) ? YES : NO;
}
static inline BOOL isUrlSafeChar(unsigned char _c) {
  switch (_c) {
    case '$': case '-': case '_': case '.':
#if 0 /* see OGo bug #1260, required for forms */
    case '+':
#endif
    case '@': // TODO: not a safe char?!
      return YES;

    default:
      return NO;
  }
}
static inline BOOL isUrlExtraChar(unsigned char _c) {
  switch (_c) {
    case '!': case '*': case '"': case '\'':
    case '|': case ',':
      return YES;
  }
  return NO;
}
static inline BOOL isUrlEscapeChar(unsigned char _c) {
  return (_c == '%') ? YES : NO;
}
static inline BOOL isUrlReservedChar(unsigned char _c) {
  switch (_c) {
    case '=': case ';': case '/':
    case '#': case '?': case ':':
    case ' ':
      return YES;
  }
  return NO;
}

static inline BOOL isUrlXalpha(unsigned char _c) {
  if (isUrlAlpha(_c))      return YES;
  if (isUrlDigit(_c))      return YES;
  if (isUrlSafeChar(_c))   return YES;
  if (isUrlExtraChar(_c))  return YES;
  if (isUrlEscapeChar(_c)) return YES;
  return NO;
}

static inline BOOL isUrlHexChar(unsigned char _c) {
  if (isUrlDigit(_c))
    return YES;
  if ((_c >= 'a') && (_c <= 'f'))
    return YES;
  if ((_c >= 'A') && (_c <= 'F'))
    return YES;
  return NO;
}

static inline BOOL isUrlAlphaNum(unsigned char _c) {
  return (isUrlAlpha(_c) || isUrlDigit(_c)) ? YES : NO;
}

static inline BOOL isToBeEscaped(unsigned char _c) {
  return (isUrlAlphaNum(_c) || (_c == '_') || isUrlSafeChar(_c)) ? NO : YES;
}

static void
NGEscapeUrlBuffer(const unsigned char *_source, unsigned char *_dest,
		  unsigned srclen)
{
  register const unsigned char *src = (void*)_source;
  register unsigned i;
  for (i = 0; i < srclen; i++, src++) {
#if 0 // explain!
    if (*src == ' ') { // a ' ' becomes a '+'
      *_dest = '+'; _dest++;
    }
#endif
    if (!isToBeEscaped(*src)) {
      *_dest = *src;
      _dest++;
    } 
    else { // any other char is escaped ..
      *_dest = '%'; _dest++;
      sprintf((char *)_dest, "%02X", (unsigned)*src);
      _dest += 2;
    }
  }
  *_dest = '\0';
}

static inline int _valueOfHexChar(register unichar _c) {
  switch (_c) {
    case '0': case '1': case '2': case '3': case '4':
    case '5': case '6': case '7': case '8': case '9':
      return (_c - 48); // 0-9 (ascii-char)'0' - 48 => (int)0
      
    case 'A': case 'B': case 'C':
    case 'D': case 'E': case 'F':
      return (_c - 55); // A-F, A=10..F=15, 'A'=65..'F'=70
      
    case 'a': case 'b': case 'c':
    case 'd': case 'e': case 'f':
      return (_c - 87); // a-f, a=10..F=15, 'a'=97..'f'=102

    default:
      return -1;
  }
}
static inline BOOL _isHexDigit(register unichar _c) {
  switch (_c) {
    case '0': case '1': case '2': case '3': case '4':
    case '5': case '6': case '7': case '8': case '9':
    case 'A': case 'B': case 'C':
    case 'D': case 'E': case 'F':
    case 'a': case 'b': case 'c':
    case 'd': case 'e': case 'f':
      return YES;

    default:
      return NO;
  }
}

static void
NGUnescapeUrlBuffer(const unsigned char *_source, unsigned char *_dest)
{
  BOOL done = NO;

  while (!done && (*_source != '\0')) {
    char c = *_source;

    //if (c == '+') // '+' stands for a space
    //  *_dest = ' ';
    if (c == '%') {
      _source++; c = *_source;
      
      if (c == '\0') {
        *_dest = '%';
        done = YES;
      }
      else if (_isHexDigit(c)) { // hex-escaped char, like '%F3'
        int decChar = _valueOfHexChar(c);
        _source++;
        c = *_source;
        decChar = decChar * 16 + _valueOfHexChar(c);
        *_dest = (unsigned char)decChar;
      }
      else // escaped char, like '%%' -> '%'
        *_dest = c;
    }
    else // char passed through
      *_dest = c;

    _dest++;
    _source++;
  }
  *_dest = '\0';
}

- (BOOL)containsURLEscapeCharacters {
  register unsigned i, len;
  register unichar (*charAtIdx)(id,SEL,unsigned);
  
  if ((len = [self length]) == 0) return NO;
  
  charAtIdx = (void*)[self methodForSelector:@selector(characterAtIndex:)];
  for (i = 0; i < len; i++) {
    if (charAtIdx(self, @selector(characterAtIndex:), i) == '%')
      return YES;
  }
  return NO;
}
- (BOOL)containsURLInvalidCharacters {
  register NSUInteger i, len;
  const char *utf8String;
  
  utf8String = [self UTF8String];
  len = strlen (utf8String);

  for (i = 0; i < len; i++) {
    if (isToBeEscaped(utf8String[i]))
      return YES;
  }
  return NO;
}

- (NSString *)stringByUnescapingURL {
  /* 
     Input is a URL string - per definition ASCII(?!), like "hello%98%88.txt"
     output is a unicode string (never longer than the input)
     
     Note that the input itself is in some encoding! That is, the input is
     turned into a buffer eg containing UTF-8 and needs to be converted into
     a unicode string.
  */
  unsigned len;
  char     *cstr;
  char     *buffer = NULL;
  NSString *s;
  
  if (![self containsURLEscapeCharacters]) /* scan for '%' */
    return [[self copy] autorelease];
  
  if ((len = [self cStringLength]) == 0) return @"";
  
  cstr = malloc(len + 10);
  [self getCString:cstr]; /* this is OK, a URL is always in ASCII! */
  cstr[len] = '\0';
  
  buffer = malloc(len + 4);
  NGUnescapeUrlBuffer((unsigned char *)cstr, (unsigned char *)buffer);
  
  if (doUseUTF8Encoding()) {
    /* OK, the input is considered UTF-8 encoded in a string */
    s = [[NSString alloc] initWithUTF8String:buffer];
    if (buffer != NULL) free(buffer); buffer = NULL;
  }
  else {
    s = [[NSString alloc]
	  initWithCStringNoCopy:buffer
	  length:strlen(buffer)
	  freeWhenDone:YES];
  }
  if (cstr != NULL) free(cstr); cstr = NULL;
  return [s autorelease];
}

- (NSString *)stringByEscapingURL {
  unsigned len;
  NSString *s;
  NSData *data;
  char     *buffer = NULL;
  NSStringEncoding encoding;
  
  if ((len = [self length]) == 0) return @"";
  
  if (![self containsURLInvalidCharacters]) // needs to be escaped ?
    return [[self copy] autorelease];

  // steps:
  // a) encode into a data buffer! (eg UTF8 or ISO)
  // b) encode that buffer into URL encoding
  // c) create an ASCII string from that
  
  encoding = (doUseUTF8Encoding()
              ? NSUTF8StringEncoding
              : NSISOLatin1StringEncoding);
    
  if ((data = [self dataUsingEncoding:encoding]) == nil)
    return nil;
  if ((len = [data length]) == 0)
    return @"";
    
  buffer = malloc(len * 3 + 2);
  NGEscapeUrlBuffer([data bytes], (unsigned char *)buffer, len);

  /* the following assumes that the default-encoding is ASCII compatible */
  s = [[NSString alloc]
        initWithBytesNoCopy:buffer
                     length:strlen(buffer)
                   encoding:NSASCIIStringEncoding
               freeWhenDone:YES];
  return [s autorelease];
}

@end /* NSString(URLEscaping) */
