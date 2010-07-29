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

#ifndef __NGStreams_NGByteBuffer_H__
#define __NGStreams_NGByteBuffer_H__

#include <NGStreams/NGFilterStream.h>
#include <NGStreams/NGStreamProtocols.h>

struct NGByteBufferLA;

/*
  Although NGByteBuffer is defined to be a stream, it is usually not used as
  such. Instead most parsers implemented using NGByteBuffer will only call
  -la: and -consume.

  The stream interface is provided to read large blocks with a known length. Eg
  if you have a structure that prefixes some data with the data's length, you
  can first parse the length and then call -safeReadBytes:count: to read the
  content.
  
  Note that -readByte and -la: return -1 on EOF.
*/

@interface NGByteBuffer : NGFilterStream
{
@protected
  struct NGByteBufferLA *la;

  unsigned bufLen;
  BOOL     wasEOF;
  unsigned headIdx;
  unsigned sizeLessOne;

  int (*readByte)(id, SEL);
  int (*laFunction)(id, SEL, unsigned);
}

/*
  Initialize a byte buffer with a lookahead depth of _la bytes.
*/
+ (id)byteBufferWithSource:(id<NGStream>)_stream la:(unsigned)_la;
- (id)initWithSource:(id<NGStream>)_stream la:(unsigned)_la;

// LA
- (int)la:(unsigned)_lookaheadPosition;

- (void)consume;                // consume one byte
- (void)consume:(unsigned)_cnt; // consume _cnt bytes

// NGStream
- (int)readByte;
- (unsigned)readBytes:(void *)_buf count:(unsigned)_len;

@end

#endif /* __NGStreams_NGByteBuffer_H__ */
