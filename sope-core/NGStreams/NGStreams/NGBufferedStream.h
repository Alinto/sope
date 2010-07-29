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

#ifndef __NGStreams_NGBufferedStream_H__
#define __NGStreams_NGBufferedStream_H__

#include <NGStreams/NGFilterStream.h>

@interface NGBufferedStream : NGFilterStream
{
@private
  void     *readBuffer;
  void     *readBufferPos;     // current position (ptr) in buffer
  unsigned readBufferFillSize; // number of 'read' bytes in the buffer
  unsigned readBufferSize;     // maximum capacity in bytes

  void     *writeBuffer;
  unsigned writeBufferFillSize;
  unsigned writeBufferSize;

  struct {
    unsigned int _flushOnNewline:1;
  } flags;
}

+ (id)filterWithSource:(id<NGStream>)_source bufferSize:(unsigned)_size;
- (id)initWithSource:(id<NGStream>)_source   bufferSize:(unsigned)_size;
- (id)initWithSource:(id<NGStream>)_source;

/* accessors */

- (void)setReadBufferSize:(unsigned)_size;
- (unsigned)readBufferSize;

- (void)setWriteBufferSize:(unsigned)_size;
- (unsigned)writeBufferSize;

/* blocking .. */

- (BOOL)wouldBlockInMode:(NGStreamMode)_mode;

/* primitives */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len;
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len;
- (BOOL)flush;

@end

@interface NGStream(NGBufferedStreamExtensions)

- (NGBufferedStream *)bufferedStream;

@end

#endif /* __NGStreams_NGBufferedStream_H__ */
