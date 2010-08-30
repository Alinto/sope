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

#ifndef __NGMime_NGMimeUtilities_H__
#define __NGMime_NGMimeUtilities_H__

#import <Foundation/Foundation.h>
#import <NGExtensions/NGExtensions.h>
#include <NGMime/NGMimeDecls.h>

// ******************** RFC 822 ********************

static inline BOOL isRfc822_SpecialByte(unsigned char _byte) {
  switch (_byte) {
  case '(': case ')': case '<': case '>': case '@':
  case ',': case ';': case ':': case '"': case '\\':
  case '.': case '[': case ']':
    return YES;
  default:
    return NO;
  }
}

// single chars
NSDictionary *parseParameters(id self, NSString *_str, unichar *cstr);

static inline BOOL isRfc822_CR(unsigned char _byte) {
  return (_byte == 13);
}
static inline BOOL isRfc822_LF(unsigned char _byte) {
  return (_byte == 10);
}
static inline BOOL isRfc822_HTAB(unsigned char _byte) {
  return (_byte == 9);
}
static inline BOOL isRfc822_SPACE(unsigned char _byte) {
  return (_byte == 32);
}
static inline BOOL isRfc822_QUOTE(unsigned char _byte) {
  return (_byte == 34);
}

// ranges

static inline BOOL isRfc822_CHAR(unsigned char _byte) {
  return (_byte < 128);
}

static inline BOOL isRfc822_CTL(unsigned char _byte) {
  return (_byte < 32) || (_byte == 127);
}

static inline BOOL isRfc822_ALPHA(unsigned char _byte) {
  return (((_byte >= 65) && (_byte <= 90)) ||
          ((_byte >= 97) && (_byte <= 122)));
}

static inline BOOL isRfc822_DIGIT(unsigned char _byte) {
  return (_byte >= 48) && (_byte <= 57);
}

static inline BOOL isRfc822_LWSP(unsigned char _byte) {
  return (isRfc822_SPACE(_byte) || isRfc822_HTAB(_byte));
}


static inline BOOL isRfc822_FieldNameChar(unsigned char _byte) {
  return (isRfc822_CHAR(_byte) &&
          !(isRfc822_CTL(_byte) || isRfc822_SPACE(_byte) || (_byte == ':')));
}

static inline BOOL isRfc822_AtomChar(unsigned char _byte) {
  return (isRfc822_CHAR(_byte) &&
          !(isRfc822_SpecialByte(_byte) || isRfc822_SPACE(_byte) ||
            isRfc822_CTL(_byte)));
}

// ******************** MIME ***********************

static inline BOOL isMime_SpecialByte(unsigned char _byte) {
  switch (_byte) {
  case '(': case ')': case '<': case '>': case '@':
  case ',': case ';': case ':': case '"': case '\\':
  case '/': case '=': case '[': case ']': case '?':
    return YES;
  default:
    return NO;
  }
}

static inline BOOL isMime_TokenChar(unsigned char _byte) {
  return (isRfc822_CHAR(_byte) &&
          !(isRfc822_CTL(_byte) || isRfc822_SPACE(_byte) ||
            isMime_SpecialByte(_byte)));
}

static inline BOOL isMime_SafeChar(unsigned char _byte) {
  return ((_byte >= 33 && _byte <= 60) || (_byte >= 62 && _byte <= 126));
}

static inline BOOL isMime_ValidTypeXTokenChar(unsigned char _byte) {
  return !isRfc822_SPACE(_byte);
}

static inline BOOL isMime_ValidTypeAttributeChar(unsigned char _byte) {
  return isMime_TokenChar(_byte);
}

static inline NSData *_quotedPrintableEncoding(NSData *_data) {
  const char   *bytes;
  unsigned int length;
  NSData       *result = nil;  
  char         *des    = NULL;
  unsigned int desLen  = 0;
  unsigned     cnt;
  const char   *test;    
  BOOL         doEnc   = NO;

  bytes  = [_data bytes];
  length = [_data length];
  cnt    = length;
  test   = bytes;    
  
  for (cnt = length, test = bytes; cnt > 0; test++, cnt--) {
    if ((unsigned char)*test > 127) {
      doEnc = YES;
      break;
    }
  }
  if (!doEnc) 
    return _data;
  
  desLen = length *3;
  des = NGMallocAtomic(sizeof(char) * desLen + 2);
  
  desLen = NGEncodeQuotedPrintable(bytes, length, des, desLen);
  if ((int)desLen != -1) {
    result = [NSData dataWithBytesNoCopy:des length:desLen];
  }
  else {
    NSLog(@"WARNING(%s): An error occour during quoted-printable decoding",
          __PRETTY_FUNCTION__);
    if (des) NGFree(des);
    result = _data;
  }
  return result;
}

static inline NSData *_rfc2047Decoding(char _enc, const char *_bytes,
				       NSUInteger _length) 
{
  NSData *data = nil;

  if ((_enc == 'b') || (_enc == 'B')) { // use BASE64 decoding
    // TODO: improve efficiency (directly decode buffers w/o NSData)
    NSData *tmp;
    
    tmp = [[NSData alloc] initWithBytes:_bytes length:_length];
    data = [tmp dataByDecodingBase64];
    [tmp release]; tmp = nil;
  }
  else if ((_enc == 'q') || (_enc == 'Q')) { // use quoted-printable decoding
    char   *dest    = NULL;
    size_t destSize = 0;
    size_t resSize  = 0;

    destSize = _length;
    dest    = calloc(destSize + 2, sizeof(char));
    resSize = NGDecodeQuotedPrintable(_bytes, _length, dest, destSize);
    if ((int)resSize != -1) {
      data = [NSData dataWithBytesNoCopy:dest length:resSize];
    }
    else {
      NSLog(@"WARNING(%s): An error occour during quoted-printable decoding",
            __PRETTY_FUNCTION__);
      if (dest != NULL) free(dest); dest = NULL;
      data = [NSData dataWithBytes:_bytes length:_length];
    }
  }
  else {
    NSLog(@"WARNING(%s): unknown encoding type %c", __PRETTY_FUNCTION__, _enc);
    data = [NSData dataWithBytes:_bytes length:_length];
  }
  return data;
}

#endif /* __NGMime_NGMimeUtilities_H__ */
