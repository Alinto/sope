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

#ifndef __NGStreams_NGStreamPipe_H__
#define __NGStreams_NGStreamPipe_H__

#import <Foundation/NSFileHandle.h>

@interface NGStreamPipe : NSPipe < NGStream, NGByteSequenceStream >
{
@private
  int          fildes[2];
  NSFileHandle *fhIn;
  NSFileHandle *fhOut;
}

+ (id)pipe;
- (id)init;

- (NSFileHandle *)fileHandleForReading;
- (NSFileHandle *)fileHandleForWriting;

- (id<NGByteSequenceStream>)streamForReading;
- (id<NGOutputStream>)streamForWriting;

// NGInputStream

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len;
- (BOOL)safeReadBytes:(void *)_buf count:(unsigned)_len;

- (BOOL)mark;
- (BOOL)rewind;
- (BOOL)markSupported;

// NGOutputStream

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len;
- (BOOL)safeWriteBytes:(const void *)_buf count:(unsigned)_len;
- (BOOL)flush;

// NGStream

- (BOOL)close;
- (NGStreamMode)mode;

// Extensions

- (BOOL)isOpen;

@end

#endif /* __NGStreams_NGStreamPipe_H__ */
