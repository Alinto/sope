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

#include <NGStreams/NGByteCountStream.h>
#include "common.h"

@implementation NGByteCountStream

+ (id)byteCounterForStream:(id<NGStream>)_stream byte:(unsigned char)_byte {
  return [[[self alloc] initWithSource:_stream byte:_byte] autorelease];
}

- (id)initWithSource:(id<NGStream>)_source byte:(unsigned char)_byte {
  if ((self = [super initWithSource:_source])) {
    [self setByteToCount:_byte];
  }
  return self;
}
- (id)initWithSource:(id<NGStream>)_source {
  return [self initWithSource:_source byte:'\n'];
}

// accessors

- (void)setByteToCount:(unsigned char)_byte {
  if (_byte != byteToCount) {
    byteReadCount  = 0;
    byteWriteCount = 0;
    byteToCount    = _byte;
  }
}
- (unsigned char)byteToCount {
  return byteToCount;
}

- (unsigned)readCount {
  return byteReadCount;
}
- (unsigned)writeCount {
  return byteWriteCount;
}

- (unsigned)totalReadCount {
  return totalReadCount;
}
- (unsigned)totalWriteCount {
  return totalWriteCount;
}

// operations

- (void)resetCounters {
  totalReadCount  = 0;
  totalWriteCount = 0;
  byteReadCount   = 0;
  byteWriteCount  = 0;
}

// primitives

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  unsigned result;

  result = (readBytes != NULL)
    ? readBytes(source, _cmd, _buf, _len)
    : [source readBytes:_buf count:_len];

  totalReadCount += result;
  {
    register unsigned char *byteBuffer = _buf;

    for (_len = result - 1; _len >= 0; _len--, byteBuffer++) {
      if (*byteBuffer == byteToCount)
        byteReadCount++;
    }
  }
  return result;
}

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  unsigned result;

  result = (writeBytes != NULL)
    ? writeBytes(source, _cmd, _buf, _len)
    : [source writeBytes:_buf count:_len];

  totalWriteCount += result;
  {
    register unsigned char *byteBuffer = (unsigned char *)_buf;

    for (_len = result - 1; _len >= 0; _len--, byteBuffer++) {
      if (*byteBuffer == byteToCount)
        byteWriteCount++;
    }
  }
  return result;
}

@end
