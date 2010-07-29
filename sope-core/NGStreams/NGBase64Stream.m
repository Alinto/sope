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

#include <NGStreams/NGBase64Stream.h>
#include <NGStreams/NGCTextStream.h>
#include "common.h"

static inline BOOL isbase64(char a) {
  if (('A' <= a) && (a <= 'Z')) return YES;
  if (('a' <= a) && (a <= 'z')) return YES;
  if (('0' <= a) && (a <= '9')) return YES;
  if ((a == '+') || (a == '/')) return YES;
  return NO;
}

@implementation NGBase64Stream

// ******************** decoding ********************

static char dmap[256] = {
  127, 127, 127, 127, 127, 127, 127, 127,      //   000-007
  127, 127, 127, 127, 127, 127, 127, 127,      //   010-017
  127, 127, 127, 127, 127, 127, 127, 127,      //   020-027
  127, 127, 127, 127, 127, 127, 127, 127,      //   030-037
  127, 127, 127, 127, 127, 127, 127, 127,      //   040-047   !"#$%&'
  127, 127, 127,  62, 127, 127, 127,  63,      //   050-057  ()*+,-./
   52,  53,  54,  55,  56,  57,  58,  59,      //   060-067  01234567
   60,  61, 127, 127, 127, 126, 127, 127,      //   070-077  89:;<=>?

  127,   0,   1,   2,   3,   4,   5,   6,      //   100-107  @ABCDEFG
    7,   8,   9,  10,  11,  12,  13,  14,      //   110-117  HIJKLMNO
   15,  16,  17,  18,  19,  20,  21,  22,      //   120-127  PQRSTUVW
   23,  24,  25, 127, 127, 127, 127, 127,      //   130-137  XYZ[\]^_
  127,  26,  27,  28,  29,  30,  31,  32,      //   140-147  `abcdefg
   33,  34,  35,  36,  37,  38,  39,  40,      //   150-157  hijklmno
   41,  42,  43,  44,  45,  46,  47,  48,      //   160-167  pqrstuvw
   49,  50,  51, 127, 127, 127, 127, 127,      //   170-177  xyz{|}~

  127, 127, 127, 127, 127, 127, 127, 127,      //   200-207
  127, 127, 127, 127, 127, 127, 127, 127,      //   210-217
  127, 127, 127, 127, 127, 127, 127, 127,      //   220-227
  127, 127, 127, 127, 127, 127, 127, 127,      //   230-237
  127, 127, 127, 127, 127, 127, 127, 127,      //   240-247
  127, 127, 127, 127, 127, 127, 127, 127,      //   250-257
  127, 127, 127, 127, 127, 127, 127, 127,      //   260-267
  127, 127, 127, 127, 127, 127, 127, 127,      //   270-277

  127, 127, 127, 127, 127, 127, 127, 127,      //   300-307
  127, 127, 127, 127, 127, 127, 127, 127,      //   310-317
  127, 127, 127, 127, 127, 127, 127, 127,      //   320-327
  127, 127, 127, 127, 127, 127, 127, 127,      //   330-337
  127, 127, 127, 127, 127, 127, 127, 127,      //   340-347
  127, 127, 127, 127, 127, 127, 127, 127,      //   350-357
  127, 127, 127, 127, 127, 127, 127, 127,      //   360-367
  127, 127, 127, 127, 127, 127, 127, 127,      //   370-377
};

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  unsigned char chunk[4]; // input buffer
  unsigned char chunkLen; // input buffer length
  unsigned      readLen = 0;

  if (self->decBufferLen == 0) { // no bytes in buffer, read next token
    register unsigned value;
    {
      volatile unsigned pos = 0, toGo = 4;
      char     tmp[4];

      memset(chunk, 126, sizeof(chunk)); // set all EOF

      NS_DURING {
        do {
          unsigned      readCount = 0;
          unsigned char i;

          readCount = [super readBytes:tmp count:toGo];
          NSAssert(readCount != 0, @"invalid result from readBytes:count:");

          for (i = 0; i < readCount; i++) {
            if (isbase64(tmp[(int)i])) {
              chunk[pos] = tmp[(int)i];
              pos++;
              toGo--;
            }
          }
        }
        while (toGo > 0);
      }
      NS_HANDLER {
        if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
          if (pos == 0)
            [localException raise];
        }
        else
          [localException raise];
      }
      NS_ENDHANDLER;

      chunkLen = pos;
    }
    NSAssert(chunkLen > 0, @"invalid chunk len (should have thrown EOF) ..");

    if (chunkLen == 4) { // complete token
      NSCAssert(self->decBufferLen  == 0, @"data pending in buffer ..");
      NSCAssert(chunkLen == 4, @"invalid chunk size ..");
  
      value = ((dmap[chunk[0]] << 18) |
               (dmap[chunk[1]] << 12) |
               (dmap[chunk[2]] << 6) |
               (dmap[chunk[3]]));
  
      self->decBuffer[0] = (unsigned char)(0xFF & (value >> 16));
      self->decBuffer[1] = (unsigned char)(0xFF & (value >> 8));
      self->decBuffer[2] = (unsigned char)(0xFF & (value));
      self->decBufferLen = 3;
    }
    else {
      unsigned char b0 = dmap[chunk[0]];
      unsigned char b1 = dmap[chunk[1]];
      unsigned char b2 = dmap[chunk[2]];
      unsigned char b3 = dmap[chunk[3]];
      char          eqCount = 0; // number of equal signs

      NSCAssert(self->decBufferLen == 0, @"data pending in buffer ..");

      if (b0 == 126) { b0 = 0; eqCount++; }
      if (b1 == 126) { b1 = 0; eqCount++; }
      if (b2 == 126) { b2 = 0; eqCount++; }
      if (b3 == 126) { b3 = 0; eqCount++; }

      value = ((b0 << 18) | (b1 << 12) | (b2 << 6) | (b3));

      self->decBuffer[0] = (unsigned char)(value >> 16);
      self->decBufferLen = 1;
      if (eqCount <= 1) {
        self->decBuffer[1] = (unsigned char)((value >> 8) & 0xFF);
        self->decBufferLen = 2;
        if (eqCount == 0) {
          self->decBuffer[2] = (unsigned char)((value & 0xFF));
          self->decBufferLen = 3;
        }
      }
    }

    NSAssert((self->decBufferLen > 0) && (self->decBufferLen < 4),
             @"invalid result length ..");
  }

  // copy decoded bytes to output buffer
  if (_len >= self->decBufferLen) {
    readLen = self->decBufferLen;
    memcpy(_buf, self->decBuffer, readLen);
    self->decBufferLen = 0;
  }
  else {
    readLen = _len;
    NSAssert((readLen > 0) && (readLen < 3), @"invalid length ..");

    if (readLen == 1) {
      *(char *)_buf = self->decBuffer[0];
      self->decBuffer[0] = self->decBuffer[1];
      self->decBuffer[1] = self->decBuffer[2];
      self->decBufferLen--;
    }
    else { // readLen == 2;
      ((char *)_buf)[0] = self->decBuffer[0];
      ((char *)_buf)[1] = self->decBuffer[1];
      self->decBuffer[0] = self->decBuffer[2];
      self->decBufferLen -= 2;
    }
  }
  return readLen;
}

// ******************** encoding ********************

static char emap[] = {
  'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',     // 0-7
  'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',     // 8-15
  'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',     // 16-23
  'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',     // 24-31
  'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',     // 32-39
  'o', 'p', 'q', 'r', 's', 't', 'u', 'v',     // 40-47
  'w', 'x', 'y', 'z', '0', '1', '2', '3',     // 48-55
  '4', '5', '6', '7', '8', '9', '+', '/'      // 56-63
};
  
static inline void _encodeToken(NGBase64Stream *self) {
  int i = self->lineLength;

  // ratio 3:4
  self->line[i]     = emap[0x3F & (self->buf >> 18)]; // sextet 1 (octet 1)
  self->line[i + 1] = emap[0x3F & (self->buf >> 12)]; // sextet 2 (octet 1 and 2)
  self->line[i + 2] = emap[0x3F & (self->buf >> 6)];  // sextet 3 (octet 2 and 3)
  self->line[i + 3] = emap[0x3F & (self->buf)];       // sextet 4 (octet 3)
  self->lineLength += 4;
  self->buf        =  0;
  self->bufBytes   =  0;
}

static inline void _encodePartialToken(NGBase64Stream *self) {
  int i = self->lineLength;

  self->line[i]     = emap[0x3F & (self->buf >> 18)]; // sextet 1 (octet 1)
  self->line[i + 1] = emap[0x3F & (self->buf >> 12)]; // sextet 2 (octet 1 and 2)
  self->line[i + 2] = (self->bufBytes == 1) ? '=' : emap[0x3F & (self->buf >> 6)];
  self->line[i + 3] = (self->bufBytes <= 2) ? '=' : emap[0x3F & (self->buf)];

  self->lineLength += 4;
  self->buf        =  0;
  self->bufBytes   =  0;
}

static inline void _flushLine(NGBase64Stream *self) {
  [self->source safeWriteBytes:self->line count:self->lineLength];
  self->lineLength = 0;
}

static inline void 
_encode(NGBase64Stream *self, const char *_in, unsigned _inLen) 
{
  // Given a sequence of input bytes, produces a sequence of output bytes
  // using the base64 encoding.
  register unsigned int i;

  for (i = 0; i < _inLen; i++) {
    if (self->bufBytes == 0)
      self->buf = ((self->buf & 0xFFFF) | (_in[i] << 16));
    else if (self->bufBytes == 1)
      self->buf = ((self->buf & 0xFF00FF) | ((_in[i] << 8) & 0xFFFF));
    else
      self->buf = ((self->buf & 0xFFFF00) | (_in[i] & 0xFF));

    if ((++(self->bufBytes)) == 3) {
      _encodeToken(self);
      if (self->lineLength >= 72)
        _flushLine(self);
    }

    if (i == (_inLen - 1)) {
      if ((self->bufBytes > 0) && (self->bufBytes < 3))
        _encodePartialToken(self);
      if (self->lineLength > 0)
        _flushLine(self);
    }
  }

  // reset line buffer
  memset(self->line, 0, sizeof(self->line));
}

- (BOOL)close {
  if (![self flush])  return NO;
  if (![super close]) return NO;
  return YES;
}
- (BOOL)flush {
  // output buffer
  if (self->bufBytes)
    _encodePartialToken(self);
  _flushLine(self);

  // reset line buffer
  memset(self->line, 0, sizeof(self->line));
  
  return [super flush];
}

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  _encode(self, _buf, _len);
  return _len;
}

@end /* NGBase64Stream */
