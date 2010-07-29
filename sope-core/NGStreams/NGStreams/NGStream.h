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

#ifndef __NGStreams_NGStream_H__
#define __NGStreams_NGStream_H__

#import <Foundation/NSObject.h>
#include <NGStreams/NGStreamsDecls.h>
#include <NGStreams/NGStreamProtocols.h>

@class NSData, NSException;

static inline BOOL NGCanReadInStreamMode(NGStreamMode _mode) {
  return ((_mode == NGStreamMode_readOnly) ||
          (_mode == NGStreamMode_readWrite));
}
static inline BOOL NGCanWriteInStreamMode(NGStreamMode _mode) {
  return ((_mode == NGStreamMode_writeOnly) ||
          (_mode == NGStreamMode_readWrite));
}

@interface NGStream : NSObject < NGStream, NGByteSequenceStream >

// ******************** primitives ********************

// Never returns 0. If an EOF like condition occures, NGEndOfStreamException
// is thrown.
- (unsigned)readBytes:(void *)_buf count:(unsigned)_len;       // abstract
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len; // abstract

- (void)setLastException:(NSException *)_exception;

- (BOOL)flush; // empty
- (BOOL)close; // empty

- (NGStreamMode)mode; // abstract
- (BOOL)isRootStream; // abstract

/* methods which read/write exactly _len bytes */

// TODO: should return exception? (would change the API significantly)
- (BOOL)safeReadBytes:(void *)_buf count:(unsigned)_len;
- (BOOL)safeWriteBytes:(const void *)_buf count:(unsigned)_len;

/* marking */

- (BOOL)mark;           // does nothing
- (BOOL)rewind;         // does nothing
- (BOOL)markSupported;  // returns NO

/* convenience methods */

- (int)readByte; // java semantics (-1 returned on EOF)

// description

- (NSString *)modeDescription;

@end

@interface NGStream(DataMethods)

- (NSData *)readDataOfLength:(unsigned int)_length;
- (NSData *)safeReadDataOfLength:(unsigned int)_length;
- (unsigned int)writeData:(NSData *)_data;
- (BOOL)safeWriteData:(NSData *)_data;

@end

// concrete implementations as functions (to be used in non-subclasses)

NGStreams_EXPORT int NGReadByteFromStream(id<NGInputStream> _stream);

NGStreams_EXPORT BOOL
NGSafeReadBytesFromStream(id<NGInputStream> _in, void *_buf, unsigned _len);

NGStreams_EXPORT BOOL
NGSafeWriteBytesToStream(id<NGOutputStream> _out,const void *_buf,unsigned _len);

#endif /* __NGStreams_NGStream_H__ */
