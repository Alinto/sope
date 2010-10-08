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

#include "NGBase64Coding.h"
#include "common.h"
#import <Foundation/NSString.h>
#import <Foundation/NSException.h>
#import <NGExtensions/NSObject+Logs.h>

static inline BOOL isbase64(char a) {
  if (('A' <= a) && (a <= 'Z'))
    return YES;
  if (('a' <= a) && (a <= 'z'))
    return YES;
  if (('0' <= a) && (a <= '9'))
    return YES;
  if ((a == '+') || (a == '/'))
    return YES;
  return NO;
}

static inline int encode_base64(const char *_src, size_t _srcLen, char *_dest,
                                size_t _destSize, size_t *_destLen,
                                int _maxLineWidth);
static inline int decode_base64(const char *_src, size_t _srcLen, char *_dest,
                                size_t _destSize, size_t *_destLen);

@implementation NSString(Base64Coding)

static Class StringClass = Nil;
static int NSStringMaxLineWidth = 1024;

- (NSString *)stringByEncodingBase64 {
  unsigned len;
  size_t destSize;
  size_t destLength = -1;
  const char *src;
  char *dest;
  NSString *result;

  src = [self UTF8String];
  len = strlen (src);
  if (len > 0) {
    destSize = ((len + 2) * 4) / 3; // 3:4 conversion ratio
    destSize += destSize / NSStringMaxLineWidth + 2; // space for '\n' and '\0'
    destSize += 64;
    dest = malloc (destSize + 4);
    NSAssert(dest, @"invalid buffer ..");
    if (encode_base64 (src, len,
                       dest, destSize,
                       &destLength, NSStringMaxLineWidth)
        == 0) {
      // base64 must *always* be transported as ascii
      result = [[NSString alloc]
                     initWithBytesNoCopy:dest
                                  length:destLength
                                encoding:NSASCIIStringEncoding
                            freeWhenDone:YES];
      [result autorelease];
    }
    else {
      free(dest);
      result = nil;
    }
  }
  else
    result = @"";

  return result;
}

- (NSString *)stringByDecodingBase64 {
  unsigned len;
  size_t destSize;
  size_t destLength = -1;
  const char *src;
  char *dest;
  NSString *result;

  if (StringClass == Nil) StringClass = [NSString class];
  
  src = [self UTF8String];
  len = strlen (src);
  if (len > 0) {
    destSize = ((len * 3 ) / 4) + 4;
    dest = malloc (destSize + 1);
    NSAssert(dest, @"invalid buffer ..");

    if (decode_base64(src, len, dest, destSize, &destLength) == 0) {
      NSAssert (destLength < destSize, @"buffer overflow");
      if (*dest == '\0' && destLength > 0) {
        [self errorWithFormat: @"(%s): could not decode '%@' as string (contains \\0 bytes)!", 
              __PRETTY_FUNCTION__, self];
        abort(); // not executed past this point
        result = nil;
      }
      else {
        result = [[StringClass alloc]
                   initWithBytesNoCopy:dest
                                length:destLength
                              encoding:NSUTF8StringEncoding
                          freeWhenDone:YES];
        // we fallback on latin 1
        if (!result)
          result = [[StringClass alloc]
                     initWithBytesNoCopy:dest
                                  length:destLength
                                encoding:NSISOLatin1StringEncoding
                            freeWhenDone:YES];
        [result autorelease];
      }
    }
    else {
      free(dest);
      result = nil;
    }
  }
  else
    result = @"";

  return result;
}

- (NSData *)dataByDecodingBase64 {
  unsigned len;
  size_t destSize;
  size_t destLength = -1;
  const char *src;
  char *dest;
  NSData *result;

  if (StringClass == Nil) StringClass = [NSString class];

  src = [self UTF8String];
  len = strlen(src);
  if (len > 0) {
    destSize = ((len * 3) / 4) + 4;
    dest = malloc(destSize + 1);
    NSAssert(dest, @"invalid buffer ..");

    if (decode_base64(src, len, dest, destSize, &destLength) == 0) {
      NSAssert (destLength < destSize, @"buffer overflow");
      result = [NSData dataWithBytesNoCopy:dest length:destLength];
    }
    else {
      free(dest);
      result = nil;
    }
  }
  else
    result = [NSData data];

  return result;
}

@end /* NSString(Base64Coding) */

@implementation NSData(Base64Coding)

// TODO: explain that size (which RFC specifies that?)
static int NSDataMaxLineWidth = 72;

- (NSData *)dataByEncodingBase64WithLineLength:(unsigned)_lineLength {
  unsigned len;
  size_t destSize;
  size_t destLength = -1;
  char   *dest;
  
  if ((len = [self length]) == 0)
    return [NSData data];
  
  destSize   = ((len + 2) * 4) / 3; // 3:4 conversion ratio
  destSize += destSize / _lineLength + 2; // space for newlines and '\0'
  destSize += 64;

  dest = malloc(destSize + 4);

  NSAssert(dest,         @"invalid buffer ..");
  
  if (encode_base64([self bytes], len,
                    dest, destSize, &destLength, _lineLength) == 0) {
    NSAssert (destLength < destSize, @"buffer overflow");
    return [NSData dataWithBytesNoCopy:dest length:destLength];
  }

  if (dest != NULL) free((void *)dest);
  return nil;
}
- (NSData *)dataByEncodingBase64 {
  return [self dataByEncodingBase64WithLineLength:NSDataMaxLineWidth];
}

- (NSData *)dataByDecodingBase64 {
  unsigned len;
  size_t destSize;
  size_t destLength = -1;
  char   *dest;

  if ((len = [self length]) == 0)
    return [NSData data];
  
  destSize = (len / 4 + 1) * 3 + 1;
  dest = malloc(destSize + 4);

  NSAssert(dest, @"invalid buffer ..");
  
  if (decode_base64([self bytes], len, dest, destSize, &destLength) == 0) {
    NSAssert (destLength < destSize, @"buffer overflow");
    return [NSData dataWithBytesNoCopy:dest length:destLength];
  }

  if (dest) free(dest);
  return nil;
}

- (NSString *)stringByEncodingBase64 {
  NSData *data;
  NSString *result;

  data = [self dataByEncodingBase64];
  if (data) {
    // base64 must *always* be transported as ascii
    result = [[NSString alloc] initWithData:data 
                                   encoding:NSASCIIStringEncoding];
    [result autorelease];
  }
  else
    result = nil;

  return result;
}

- (NSString *)stringByDecodingBase64 {
  NSData *data;
  NSString *result;
 
  data = [self dataByDecodingBase64];
  if (data) {
    result = [[NSString alloc] initWithData:data 
                                   encoding:NSUTF8StringEncoding];
    if (!result)
      result = [[NSString alloc] initWithData:data 
                                     encoding:NSISOLatin1StringEncoding];
    [result autorelease];
  }
  else
    result = nil;
 
  return result;
}

@end /* NSData(Base64Coding) */

// functions

int NGEncodeBase64(const void *_source, unsigned _len,
                   void *_buffer, unsigned _bufferCapacity,
                   int _maxLineWidth) {
  size_t len;

  if ((_source == NULL) || (_buffer == NULL) || (_bufferCapacity == 0))
    return -1;
  
  { // check whether buffer is big enough
    size_t outSize;
    outSize =  ((_len + 2) * 4) / 3;            // 3:4 conversion ratio
    outSize += (outSize / _maxLineWidth) + 2; // Space for newlines and NUL

    if (_bufferCapacity < outSize)
      return -1;
  }
  
  if (encode_base64(_source, _len,
                    _buffer, _bufferCapacity, &len, _maxLineWidth) == 0) {
    return len;
  }
  else
    return -1;
}

int NGDecodeBase64(const void *_source, unsigned _len,
                   void *_buffer, unsigned _bufferCapacity) {
  size_t len;
  
  if ((_source == NULL) || (_buffer == NULL) || (_bufferCapacity == 0))
    return -1;
  
  if (((_len / 4 + 1) * 3 + 1) > _bufferCapacity)
    return -1;
  
  if (decode_base64(_source, _len, _buffer, _bufferCapacity, &len) == 0)
    return len;
  else
    return -1;
}

// private implementation

static char base64tab[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "abcdefghijklmnopqrstuvwxyz0123456789+/";

static char base64idx[128] = {
    '\377','\377','\377','\377','\377','\377','\377','\377',
    '\377','\377','\377','\377','\377','\377','\377','\377',
    '\377','\377','\377','\377','\377','\377','\377','\377',
    '\377','\377','\377','\377','\377','\377','\377','\377',
    '\377','\377','\377','\377','\377','\377','\377','\377',
    '\377','\377','\377',    62,'\377','\377','\377',    63,
        52,    53,    54,    55,    56,    57,    58,    59,
        60,    61,'\377','\377','\377','\377','\377','\377',
    '\377',     0,     1,     2,     3,     4,     5,     6,
         7,     8,     9,    10,    11,    12,    13,    14,
        15,    16,    17,    18,    19,    20,    21,    22,
        23,    24,    25,'\377','\377','\377','\377','\377',
    '\377',    26,    27,    28,    29,    30,    31,    32,
        33,    34,    35,    36,    37,    38,    39,    40,
        41,    42,    43,    44,    45,    46,    47,    48,
        49,    50,    51,'\377','\377','\377','\377','\377'
};

static inline int encode_base64(const char *_src, size_t _srcLen, char *_dest,
                                size_t _destSize, size_t *_destLen,
                                int _maxLineWidth) {
  size_t inLen  = _srcLen;
  char   *out   = _dest;
  size_t inPos  = 0;
  size_t outPos = 0;
  int    c1, c2, c3;
  unsigned i;
  
  // Get three characters at a time and encode them.
  for (i = 0; i < inLen / 3; ++i) {
    c1 = _src[inPos++] & 0xFF;
    c2 = _src[inPos++] & 0xFF;
    c3 = _src[inPos++] & 0xFF;
    out[outPos++] = base64tab[(c1 & 0xFC) >> 2];
    out[outPos++] = base64tab[((c1 & 0x03) << 4) | ((c2 & 0xF0) >> 4)];
    out[outPos++] = base64tab[((c2 & 0x0F) << 2) | ((c3 & 0xC0) >> 6)];
    out[outPos++] = base64tab[c3 & 0x3F];

    if ((outPos + 1) % (_maxLineWidth + 1) == 0)
      out[outPos++] = '\n';
  }
  
  // Encode the remaining one or two characters.
  switch (inLen % 3) {
    case 0:
      //out[outPos++] = '\n';
      break;
    case 1:
      c1 = _src[inPos] & 0xFF;
      out[outPos++] = base64tab[(c1 & 0xFC) >> 2];
      out[outPos++] = base64tab[((c1 & 0x03) << 4)];
      out[outPos++] = '=';
      out[outPos++] = '=';
      //out[outPos++] = '\n';
      break;
    case 2:
      c1 = _src[inPos++] & 0xFF;
      c2 = _src[inPos] & 0xFF;
      out[outPos++] = base64tab[(c1 & 0xFC) >> 2];
      out[outPos++] = base64tab[((c1 & 0x03) << 4) | ((c2 & 0xF0) >> 4)];
      out[outPos++] = base64tab[((c2 & 0x0F) << 2)];
      out[outPos++] = '=';
      //out[outPos++] = '\n';
      break;
  }
  out[outPos] = 0;
  *_destLen = outPos;
  return 0;
}

static inline int decode_base64(const char *_src, size_t inLen, char *out,
                                size_t _destSize, size_t *_destLen) 
{
  BOOL   isErr     = NO;
  BOOL   isEndSeen = NO;
  register int    b1, b2, b3;
  register int    a1, a2, a3, a4;
  register size_t inPos  = 0;
  register size_t outPos = 0;
  
  /* Get four input chars at a time and decode them. Ignore white space
   * chars (CR, LF, SP, HT). If '=' is encountered, terminate input. If
   * a char other than white space, base64 char, or '=' is encountered,
   * flag an input error, but otherwise ignore the char.
   */
  while (inPos < inLen) {
    a1 = a2 = a3 = a4 = 0;

    // get byte 1
    while (inPos < inLen) {
      a1 = _src[inPos++] & 0xFF;
      
      if (isbase64(a1))
        break;
      else if (a1 == '=') {
        isEndSeen = YES;
        break;
      }
      else if (a1 != '\r' && a1 != '\n' && a1 != ' ' && a1 != '\t') {
        isErr = YES;
      }
    }
    
    // get byte 2
    while (inPos < inLen) {
      a2 = _src[inPos++] & 0xFF;

      if (isbase64(a2))
        break;
      else if (a2 == '=') {
        isEndSeen = YES;
        break;
      }
      else if (a2 != '\r' && a2 != '\n' && a2 != ' ' && a2 != '\t') {
        isErr = YES;
      }
    }
    
    // get byte 3
    while (inPos < inLen) {
      a3 = _src[inPos++] & 0xFF;

      if (isbase64(a3))
        break;
      else if (a3 == '=') {
        isEndSeen = YES;
        break;
      }
      else if (a3 != '\r' && a3 != '\n' && a3 != ' ' && a3 != '\t') {
        isErr = YES;
      }
    }

    // get byte 4
    while (inPos < inLen) {
      a4 = _src[inPos++] & 0xFF;

      if (isbase64(a4))
        break;
      else if (a4 == '=') {
        isEndSeen = YES;
        break;
      }
      else if (a4 != '\r' && a4 != '\n' && a4 != ' ' && a4 != '\t') {
        isErr = YES;
      }
    }

    // complete chunk
    if (isbase64(a1) && isbase64(a2) && isbase64(a3) && isbase64(a4)) {
      a1 = base64idx[a1] & 0xFF;
      a2 = base64idx[a2] & 0xFF;
      a3 = base64idx[a3] & 0xFF;
      a4 = base64idx[a4] & 0xFF;
      b1 = ((a1 << 2) & 0xFC) | ((a2 >> 4) & 0x03);
      b2 = ((a2 << 4) & 0xF0) | ((a3 >> 2) & 0x0F);
      b3 = ((a3 << 6) & 0xC0) | ( a4       & 0x3F);
      out[outPos++] = (char)b1;
      out[outPos++] = (char)b2;
      out[outPos++] = (char)b3;
    }
    // 3-chunk
    else if (isbase64(a1) && isbase64(a2) && isbase64(a3) && a4 == '=') {
      a1 = base64idx[a1] & 0xFF;
      a2 = base64idx[a2] & 0xFF;
      a3 = base64idx[a3] & 0xFF;
      b1 = ((a1 << 2) & 0xFC) | ((a2 >> 4) & 0x03);
      b2 = ((a2 << 4) & 0xF0) | ((a3 >> 2) & 0x0F);
      out[outPos++] = (char)b1;
      out[outPos++] = (char)b2;
      break;
    }
    // 2-chunk
    else if (isbase64(a1) && isbase64(a2) && a3 == '=' && a4 == '=') {
      a1 = base64idx[a1] & 0xFF;
      a2 = base64idx[a2] & 0xFF;
      b1 = ((a1 << 2) & 0xFC) | ((a2 >> 4) & 0x03);
      out[outPos++] = (char)b1;
      break;
    }
    // invalid state
    else {
      break;
    }
    
    if (isEndSeen)
      break;
  }
  *_destLen = outPos;
  return (isErr) ? -1 : 0;
}

// for static linking

void __link_NGBase64Coding(void) {
  __link_NGBase64Coding();
}
