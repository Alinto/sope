/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "NGUrlFormCoder.h"
#include "common.h"

// TODO: can we replace that with NSString+URLEscaping.m in NGExtensions?
//       I think there was 'some' special thing

#if !LIB_FOUNDATION_LIBRARY
static BOOL debugDecoding = NO;
#endif

static __inline__ int _valueOfHexChar(unsigned char _c) {
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

static __inline__ unsigned
_unescapeUrl(const unsigned char *_src, unsigned _len, unsigned char *_dest) 
{
  // ODO: return Unicode?
  register unsigned i, i2;

  for (i = 0, i2 = 0; i < _len; i++, i2++) {
    register char c = _src[i];
    
    switch (c) {
      case '+': // encoded space
        _dest[i2] = ' ';
        break;
          
      case '%': // encoded hex ('%FF')
        _dest[i2] = _valueOfHexChar(_src[i + 1]) * 16 +
          _valueOfHexChar(_src[i + 2]);
        i += 2; // skip the two hexchars
        break;

      default:  // normal char
        _dest[i2] = c;
        break;
    }
  }
  return i2; // return unescaped length
}

static Class StrClass = Nil;

static __inline__ NSString *urlStringFromBuffer(const unsigned char *buffer,
						unsigned len)
{
  // TODO: we assume ISO-Latin-1/Unicode encoding, which might be wrong
#if LIB_FOUNDATION_LIBRARY
  return [[StrClass alloc] initWithCString:(char *)buffer length:len];
#else
  // TODO: patch by Mont? We cannot assume NSUTF8StringEncoding?!
  NSString *value;
  
  value = [[StrClass alloc] initWithBytes:buffer length:len
                            encoding:NSUTF8StringEncoding];
  if (debugDecoding) {
    NSLog(@"decoded data len %d value (len=%d): %@", 
	  len, [value length], value);
  }
  return value;
#if 0
  register signed int i;
  unichar  *s;
  NSString *value;
  
  s = calloc((len + 2), sizeof(unichar));
  for (i = len - 1; i >= 0; i--)
    s[i] = buffer[i];
  value = [[StrClass alloc] initWithCharacters:s length:len];
  if (s != NULL) free(s);
  
  if (debugDecoding) {
    NSLog(@"decoded data len %d value (len=%d): %@", 
	  len, [value length], value);
  }
  return value;
#endif
#endif
}

NGHashMap *NGDecodeUrlFormParameters(const unsigned char *_buffer,
				     unsigned _len)
{
  NGMutableHashMap *dict = nil;
  unsigned pos = 0;
  
  if (_len == 0) return nil;
  
  if (StrClass == Nil) StrClass = [NSString class];
  dict = [[NGMutableHashMap alloc] initWithCapacity:16];

  do {
    NSString *key = nil, *value = nil;
    unsigned tmp, len;
    unsigned char buffer[_len];

    /* read key */
    tmp = pos;
    while ((pos < _len) && (_buffer[pos] != '='))
      pos++;
    
    len = _unescapeUrl(&(_buffer[tmp]), (pos - tmp), buffer);
    key = len > 0 ? urlStringFromBuffer(buffer, len) : (NSString *)@"";
    
    if (pos < _len) { // value pending
      NSCAssert(_buffer[pos] == '=', @"invalid parser state ..");
      pos++; // skip '='

      /* read value */
      tmp = pos;
      while ((pos < _len) && (_buffer[pos] != '&') && (_buffer[pos] != '?')) {
        pos++;
      }
      
      len   = _unescapeUrl(&(_buffer[tmp]), (pos - tmp), buffer);
      value = len > 0 ? urlStringFromBuffer(buffer, len) : (NSString *)@"";
      
      // skip '&'
      if ((pos < _len) && (_buffer[pos] == '&' || _buffer[pos] == '?')) pos++;
    }
    
    if (value == nil)
      value = @"";

    /* store in dictionary */
    if (key)
      [dict addObject:value forKey:key];

    [key   release]; key   = nil;
    [value release]; value = nil;
  }
  while (pos < _len);

  return dict;
}

@implementation NSString(FormURLCoding)

- (NSString *)stringByApplyingURLEncoding {
  /* NGExtensions/NSString+misc.h */
  NSLog(@"Note: Called deprecated -stringByApplyingURLEncoding method "
	@"(use -stringByEscapingURL instead)", __PRETTY_FUNCTION__);
  return [self stringByEscapingURL];
}

@end /* NSString(FormURLCoding) */
