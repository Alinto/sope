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

#include <NGStreams/NGStreamExceptions.h>
#include <NGStreams/NGGZipStream.h>
#include <NGExtensions/NSData+gzip.h>
#include "common.h"

#ifdef Assert
#undef Assert
#endif

#include <zlib.h>
#ifndef DEF_MEM_LEVEL /* zutil.h */
#  if MAX_MEM_LEVEL >= 8
#    define DEF_MEM_LEVEL 8
#  else
#    define DEF_MEM_LEVEL  MAX_MEM_LEVEL
#  endif
#  define OS_CODE  0x07 /* TODO: probably need to adjust that ... */
#endif

#undef Assert

@implementation NGGZipStream

- (id)initWithSource:(id<NGStream>)_source level:(int)_level {
  if ((self = [super initWithSource:_source])) {
    z_stream *zout;
    
    NSAssert1((_level >= NGGZipMinimalCompression &&
               _level <= NGGZipMaximalCompression)
              || (_level == Z_DEFAULT_COMPRESSION),
              @"invalid compression level %i (0-9)", _level);

    self->outBufLen = 2048;
#if LIB_FOUNDATION_LIBRARY
    self->outBuf    = NSZoneMallocAtomic([self zone], self->outBufLen);
    self->outp       = NSZoneMallocAtomic([self zone], sizeof(z_stream));
#else
    self->outBuf    = NSZoneMalloc([self zone], self->outBufLen);
    self->outp       = NSZoneMalloc([self zone], sizeof(z_stream));
#endif
    zout = self->outp;
    zout->zalloc    = (alloc_func)NULL;
    zout->zfree     = (free_func)NULL;
    zout->opaque    = (voidpf)NULL;
    zout->next_out  = self->outBuf;
    zout->avail_out = self->outBufLen;
    zout->next_in   = Z_NULL;
    zout->avail_in  = 0;
    self->crc       = crc32(0L, Z_NULL, 0);

    if (deflateInit2(zout, _level, Z_DEFLATED, -MAX_WBITS,
                     DEF_MEM_LEVEL, 0) != Z_OK) {
      NSLog(@"Could not init deflate ..");
      self = [self autorelease];
      return nil;
    }
  }
  return self;
}

- (void)gcFinalize {
  [self close];
}

- (void)dealloc {
  if (self->outBuf) NSZoneFree([self zone], self->outBuf);
  if (self->outp)    NSZoneFree([self zone], self->outp);
  [self gcFinalize];
  [super dealloc];
}

/* headers */

- (void)writeGZipHeader {
  // gzip header
  char buf[10] = {
    0x1f, 0x8b,    // magic
    Z_DEFLATED, 0, // flags
    0, 0, 0, 0,    // time
    0, OS_CODE     // flags
  };

  [self safeWriteBytes:buf count:10];
}

static inline void putLong(NGGZipStream *self, uLong x) {
  int n;
  for (n = 0; n < 4; n++) {
    unsigned char c = (int)(x & 0xff);
    [self safeWriteBytes:&c count:1];
    x >>= 8;
  }
}
- (void)writeGZipTrailer {
  putLong(self, self->crc);
  putLong(self, ((z_stream *)self->outp)->total_in);
}

/* primitives */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len { // decoder
  [self notImplemented:_cmd];
  return -1;
}

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len { // encoder
  z_stream *zout = self->outp;
  
  if (!self->headerIsWritten) [self writeGZipHeader];

  { // gz_write
    zout->next_in   = (void*)_buf;
    zout->avail_in  = _len;
    
    while (zout->avail_in > 0) {
      int errorCode;
      
      if (zout->avail_out == 0) {
        [self safeWriteBytes:self->outBuf count:self->outBufLen];
        zout->next_out  = self->outBuf; // reset buffer position
        zout->avail_out = self->outBufLen;
      }
      errorCode = deflate(self->outp, Z_NO_FLUSH);
      if (errorCode != Z_OK) {
        if (zout->state) deflateEnd(self->outp);
        [NGStreamException raiseWithStream:self
                           format:@"could not deflate chunk !"];
      }
    }
    self->crc = crc32(self->crc, _buf, _len);
  }
  return _len;
}
- (BOOL)safeWriteBytes:(const void *)_buf count:(unsigned)_len { // encoder
  // gzip writes are safe
  if ([self writeBytes:_buf count:_len] == NGStreamError)
    return NO;
  else
    return YES;
}

- (void)close {
  [self flush];
  [self writeGZipTrailer];
  if (((z_stream *)self->outp)->state) deflateEnd(self->outp);
  [super close];
}

- (void)flush {
  int      errorCode = Z_OK;
  z_stream *zout     = self->outp;
  BOOL     done      = NO;
    
  zout->next_in  = NULL;
  zout->avail_in = 0; // should be zero already anyway
    
  while (1) {
    int len = self->outBufLen - zout->avail_out;

    if (len > 0) {
      [self safeWriteBytes:self->outBuf count:len];
      zout->next_out  = self->outBuf;
      zout->avail_out = self->outBufLen;
    }
    if (done)
      break;
    errorCode = deflate(zout, Z_FINISH);

    // deflate has finished flushing only when it hasn't used up
    // all the available space in the output buffer: 
    done = (zout->avail_out != 0 || errorCode == Z_STREAM_END);

    if (errorCode != Z_OK && errorCode != Z_STREAM_END)
      break;
  }
  if (errorCode != Z_STREAM_END) {
    if (zout->state) deflateEnd(zout);
    [NGStreamException raiseWithStream:self format:@"flush failed"];
  }

  [super flush];
}

@end
