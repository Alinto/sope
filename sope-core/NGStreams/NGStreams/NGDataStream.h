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

#ifndef __NGStreams_NGDataStream_H__
#define __NGStreams_NGDataStream_H__

#include <NGStreams/NGStream.h>
#include <NGStreams/NGStreamProtocols.h>

@class NSData;

@interface NGDataStream : NGStream < NGPositionableStream >
{
@private
  NSException  *lastException;
  NGStreamMode streamMode;
  NSData       *data;
  unsigned     position;
  
  unsigned int (*dataLength)(id, SEL);
  const void   *(*dataBytes)(id, SEL);  
  
  /* for read-only streams */
  unsigned int length;
  const void   *bytes;
}

+ (id)dataStream;
+ (id)dataStreamWithCapacity:(int)_capacity;
+ (id)streamWithData:(NSData *)_data;
- (id)initWithData:(NSData *)_data mode:(NGStreamMode)_mode;
- (id)initWithData:(NSData *)_data;

- (NSException *)lastException;
- (void)setLastException:(NSException *)_exception;
- (void)resetLastException;

// accessors

- (NSData *)data;

- (unsigned)availableBytes; // returns number of available bytes

// primitives

// throws
//   NGStreamNotOpenException   when the stream is not open
//   NGEndOfStreamException     when the end of the stream is reached
- (unsigned)readBytes:(void *)_buf count:(unsigned)_len;

// throws
//   NGReadOnlyStreamException when the stream is not writeable
//   NGStreamNotOpenException  when the stream is not open
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len;

- (BOOL)close;

- (NGStreamMode)mode;
- (BOOL)isRootStream;

// NGPositionableStream

- (BOOL)moveToLocation:(unsigned)_location;
- (BOOL)moveByOffset:(int)_delta;

// blocking ..

- (BOOL)wouldBlockInMode:(NGStreamMode)_mode; // always NO ..

@end

#endif /* __NGStreams_NGDataStream_H__ */
