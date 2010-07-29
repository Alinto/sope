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

#include "NSData+gzip.h"
#include "common.h"

#ifdef Assert
#  undef Assert
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

@implementation NSData(gzip)

- (NSData *)gzip {
  return [self gzipWithLevel:Z_DEFAULT_COMPRESSION];
}

static inline void putLong(uLong x, NSMutableData *data, IMP addBytes) {
  int n;
  for (n = 0; n < 4; n++) {
    unsigned char c = (int)(x & 0xff);
    addBytes(data, @selector(appendBytes:length:), &c, 1);
    x >>= 8;
  }
}

- (NSData *)gzipWithLevel:(int)_level {
  NSMutableData *data     = nil;
  int           errorCode = 0;
  unsigned      len       = [self length];
  void          *src      = (void *)[self bytes];
  IMP           addBytes  = NULL;
  char          outBuf[4096];
  z_stream      out;
  uLong         crc;

  NSAssert1((_level >= NGGZipMinimalCompression &&
             _level <= NGGZipMaximalCompression)
            || (_level == Z_DEFAULT_COMPRESSION),
            @"invalid compression level %i (0-9)", _level);

  data = [NSMutableData dataWithCapacity:
                          (len / 10 < 128) ? len : len / 10];
  addBytes = [data methodForSelector:@selector(appendBytes:length:)];

  out.zalloc    = (alloc_func)NULL;
  out.zfree     = (free_func)NULL;
  out.opaque    = (voidpf)NULL;
  out.next_out  = (Byte*)&outBuf;
  out.avail_out = sizeof(outBuf);
  out.next_in   = Z_NULL;
  out.avail_in  = 0;
  errorCode     = Z_OK;
  crc           = crc32(0L, Z_NULL, 0);

  errorCode = deflateInit2(&out, _level, Z_DEFLATED, -MAX_WBITS,
                           DEF_MEM_LEVEL,
                           0); // windowBits is passed <0 to suppress zlib header
  if (errorCode != Z_OK) {
    NSLog(@"ERROR: could not init deflate !");
    return nil;
  }

  { // add gzip header
    char buf[10] = {
      0x1f, 0x8b,    // magic
      Z_DEFLATED, 0, // flags
      0, 0, 0, 0,    // time
      0, OS_CODE     // flags
    };
    addBytes(data, @selector(appendBytes:length:), &buf, 10);
  }
  
  { // gz_write
    out.next_in  = src;
    out.avail_in = len;
    
    while (out.avail_in > 0) {
      if (out.avail_out == 0) {
        out.next_out = (void *)&outBuf; // reset buffer position
        addBytes(data, @selector(appendBytes:length:), &outBuf, sizeof(outBuf));
        out.avail_out = sizeof(outBuf);
      }
      errorCode = deflate(&out, Z_NO_FLUSH);
      if (errorCode != Z_OK) {
        NSLog(@"ERROR: could not deflate chunk !");
        if (out.state) deflateEnd(&out);
        return nil;
      }
    }
    crc = crc32(crc, src, len);
  }

  { // gz_flush
    BOOL done = NO;
    
    out.next_in  = NULL;
    out.avail_in = 0; // should be zero already anyway
    
    for (;;) {
      len = sizeof(outBuf) - out.avail_out;

      if (len > 0) {
        addBytes(data, @selector(appendBytes:length:), &outBuf, len);
        out.next_out  = (void *)&outBuf;
        out.avail_out = sizeof(outBuf);
      }
      if (done)
        break;
      errorCode = deflate(&out, Z_FINISH);

      // deflate has finished flushing only when it hasn't used up
      // all the available space in the output buffer: 
      done = (out.avail_out != 0 || errorCode == Z_STREAM_END);

      if (errorCode != Z_OK && errorCode != Z_STREAM_END)
        break;
    }
    if (errorCode != Z_STREAM_END) {
      NSLog(@"ERROR: flush failed.");
      if (out.state) deflateEnd(&out);
      return nil;
    }
  }
  { // write trailer (checksum and filesize)
    putLong(crc, data, addBytes);
    putLong(out.total_in, data, addBytes);
  }
  if (out.state) deflateEnd(&out);

  return data;
}

@end

void __link_NSData_gzip(void) {
  __link_NSData_gzip();
}
