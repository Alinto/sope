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

#ifndef __NGStreams_NGFileStream_H__
#define __NGStreams_NGFileStream_H__

/*
  NGFileStream
  
  NGFileStream is a stream which allows reading/writing local files.
*/

#if defined(__MINGW32__) && defined(HAVE_WINDOWS_H)
#  include <windows.h>
#endif
#ifdef HAVE_POLL_H
#  include <poll.h>
#endif
#ifdef HAVE_SYS_POLL_H
#  include <sys/poll.h>
#endif
#ifdef HAVE_UNISTD_H
#  include <unistd.h>
#endif

#if defined(__MINGW32__)
#  include <winsock.h>
#endif

#include <NGStreams/NGStreamsDecls.h>
#include <NGStreams/NGStream.h>
#include <NGStreams/NGStreamProtocols.h>

@class NSFileHandle;

NGStreams_EXPORT NSString *NGFileReadOnly;
NGStreams_EXPORT NSString *NGFileWriteOnly;
NGStreams_EXPORT NSString *NGFileReadWrite;
NGStreams_EXPORT NSString *NGFileAppend;
NGStreams_EXPORT NSString *NGFileReadAppend;

NGStreams_EXPORT id<NGInputStream>  NGIn;
NGStreams_EXPORT id<NGOutputStream> NGOut;
NGStreams_EXPORT id<NGOutputStream> NGErr;
NGStreams_EXPORT void NGInitStdio(void);

@interface NGFileStream : NGStream < NGPositionableStream >
{
@private
#if defined(__MINGW32__)
  HANDLE fh; // Windows file handle
#else
  int    fd; // Unix file descriptor
#endif
  
  NGStreamMode streamMode;
  NSString     *systemPath;
  NSFileHandle *handle;     // not retained !
  
  int markDelta; // tracks mark, for marking (special value -1)
}

- (id)initWithPath:(NSString *)_path;
- (id)initWithFileHandle:(NSFileHandle *)_handle; // use with care !

// throws
//   NGUnknownStreamModeException  when _mode is invalid
//   NGCouldNotOpenStreamException when the file could not be opened
- (BOOL)openInMode:(NSString *)_mode;

- (BOOL)isOpen;

// Foundation file handles

- (NSFileHandle *)fileHandle;
- (int)fileDescriptor;

#if defined(__MINGW32__)
- (HANDLE)windowsFileHandle;
#endif

// primitives

// throws
//   NGWriteOnlyStreamException when the stream is not readable
//   NGStreamNotOpenException   when the stream is not open
//   NGEndOfStreamException     when the end of the stream is reached
//   NGReadErrorException       when the read call failed
- (unsigned)readBytes:(void *)_buf count:(unsigned)_len;

// throws
//   NGReadOnlyStreamException when the stream is not writeable
//   NGStreamNotOpenException  when the stream is not open
//   NGWriteErrorException     when the write call failed
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len;

// throws NGCouldNotCloseStreamException when the close call failed
- (BOOL)close;

- (NGStreamMode)mode;
- (BOOL)isRootStream;

// blocking

- (BOOL)wouldBlockInMode:(NGStreamMode)_mode; // not supported with Windows

// marking

- (BOOL)mark;
- (BOOL)rewind;
- (BOOL)markSupported; // returns YES

// NGPositionableStream

// throws
//   NGStreamSeekErrorException
- (BOOL)moveToLocation:(unsigned)_location; // note that absolute moves delete marks

// throws
//   NGStreamSeekErrorException
- (BOOL)moveByOffset:(int)_delta;

@end

#endif /* __NGStreams_NGFileStream_H__ */
