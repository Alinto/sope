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

#include "config.h"

#if HAVE_UNISTD_H || __APPLE__
#  include <unistd.h>
#endif
#if HAVE_SYS_STAT_H
#  include <sys/stat.h>
#endif
#if HAVE_SYS_FCNTL_H
#  include <sys/fcntl.h>
#endif
#if HAVE_FCNTL_H || __APPLE__
#  include <fcntl.h>
#endif

#include <NGStreams/NGFileStream.h>
#include <NGStreams/NGBufferedStream.h>
#include <NGStreams/NGConcreteStreamFileHandle.h>
#include <NGStreams/NGLockingStream.h>
#include <NGStreams/NGStreamExceptions.h>
#include <NGStreams/NGDescriptorFunctions.h>
#include "common.h"
#import <Foundation/NSThread.h>

#if !defined(POLLRDNORM)
#  define POLLRDNORM POLLIN
#endif

// TODO: NGFileStream needs to be changed to operate without throwing 
//       exceptions

NGStreams_DECLARE NSString *NGFileReadOnly    = @"r";
NGStreams_DECLARE NSString *NGFileWriteOnly   = @"w";
NGStreams_DECLARE NSString *NGFileReadWrite   = @"rw";
NGStreams_DECLARE NSString *NGFileAppend      = @"a";
NGStreams_DECLARE NSString *NGFileReadAppend  = @"ra";

static const int NGInvalidUnixDescriptor = -1;
static const int NGFileCreationMask      = 0666; // rw-rw-rw-

@interface _NGConcreteFileStreamFileHandle : NGConcreteStreamFileHandle
@end

NGStreams_DECLARE id<NGInputStream>  NGIn  = nil;
NGStreams_DECLARE id<NGOutputStream> NGOut = nil;
NGStreams_DECLARE id<NGOutputStream> NGErr = nil;

@implementation NGFileStream

// stdio stream

#if defined(__MINGW32__)
- (id)__initWithInConsole {
  if ((self = [self init])) {
    self->systemPath = @"CONIN$";
    self->streamMode = NGStreamMode_readWrite;
    self->fh = GetStdHandle(STD_INPUT_HANDLE);
    /*
    self->fh = CreateFile("CONIN$", GENERIC_READ, FILE_SHARE_READ,
                          NULL,
                          OPEN_EXISTING,
                          0,
                          NULL);
     */
  }
  return self;
}
- (id)__initWithOutConsole {
  if ((self = [self init])) {
    DWORD written;
    self->systemPath = @"CONOUT$";
    self->streamMode = NGStreamMode_readWrite;
    self->fh         = GetStdHandle(STD_OUTPUT_HANDLE);
    /*
    self->fh = CreateFile("CONOUT$", GENERIC_WRITE, FILE_SHARE_WRITE,
                          NULL,
                          OPEN_EXISTING,
                          0,
                          NULL);
     */
    FlushFileBuffers(self->fh);
  }
  return self;
}
#else
- (id)__initWithDescriptor:(int)_fd mode:(NGStreamMode)_mode {
  if ((self = [self init])) {
    self->fd         = _fd;
    self->streamMode = _mode;
  }
  return self;
}
#endif

void NGInitStdio(void) {
  static BOOL isInitialized = NO;
  if (!isInitialized) {
    NGFileStream *ti = nil, *to = nil, *te = nil;
    
    isInitialized = YES;

#if defined(__MINGW32__)
    ti = [[NGFileStream alloc] __initWithInConsole];
    to = [[NGFileStream alloc] __initWithOutConsole];
    te = [to retain];
#else
    ti = [[NGFileStream alloc] __initWithDescriptor:0
			       mode:NGStreamMode_readOnly];
    to = [[NGFileStream alloc] __initWithDescriptor:1
			       mode:NGStreamMode_writeOnly];
    te = [[NGFileStream alloc] __initWithDescriptor:2
			       mode:NGStreamMode_writeOnly];
#endif

    NGIn  = [[NGBufferedStream alloc] initWithSource:(id)ti];
    NGOut = [[NGBufferedStream alloc] initWithSource:(id)to];
    NGErr = [[NGBufferedStream alloc] initWithSource:(id)te];

    [ti release]; ti = nil;
    [to release]; to = nil;
    [te release]; te = nil;
  }
}

+ (void)_makeThreadSafe:(NSNotification *)_notification {
  NGLockingStream *li = nil, *lo = nil, *le = nil;
  
  if ([NGIn isKindOfClass:[NGLockingStream class]])
    return;
  
  li = [[NGLockingStream alloc] initWithSource:(id)NGIn];
  [NGIn  release]; NGIn  = li;
  lo = [[NGLockingStream alloc] initWithSource:(id)NGOut]; 
  [NGOut release]; NGOut = lo;
  le = [[NGLockingStream alloc] initWithSource:(id)NGErr]; 
  [NGErr release]; NGErr = le;
}

+ (void)_flushForExit:(NSNotification *)_notification {
  //[NGIn  flush];
  [NGOut flush];
  [NGErr flush];
}

static void _flushForExit(void) {
  //[NGIn  flush];
  [NGOut flush];
  [NGErr flush];
}

+ (void)initialize {
  BOOL isInitialized = NO;
  if (!isInitialized) {
    isInitialized = YES;

    if ([NSThread isMultiThreaded])
      [self _makeThreadSafe:nil];
    else {
      [[NSNotificationCenter defaultCenter]
                             addObserver:self
                             selector:@selector(_makeThreadSafe:)
                             name:NSWillBecomeMultiThreadedNotification
                             object:nil];
    }
    atexit(_flushForExit);
  }
}

/* normal file stream */

- (id)init {
  if ((self = [super init])) {
    self->streamMode = NGStreamMode_undefined;
    self->systemPath = nil;
    self->markDelta  = -1;
    self->handle     = nil;
#if defined(__MINGW32__)
    self->fh         = INVALID_HANDLE_VALUE;
#else
    self->fd         = NGInvalidUnixDescriptor;
#endif
  }
  return self;
}

- (id)initWithPath:(NSString *)_path {
  if ((self = [self init])) {
    self->systemPath = [_path copy];
  }
  return self;
}

- (id)initWithFileHandle:(NSFileHandle *)_handle {
  if ((self = [self init])) {
#if defined(__MINGW32__)
    self->fh = [_handle nativeHandle];
#else
    self->fd = [_handle fileDescriptor];
#endif
  }
  return self;
}

- (void)gcFinalize {
  if ([self isOpen]) {
#if DEBUG && 0
    NSLog(@"NGFileStream(gcFinalize): closing %@", self);
#endif
    [self close];
  }
}
- (void)dealloc {
  [self gcFinalize];
  self->streamMode = NGStreamMode_undefined;
  [self->systemPath release]; self->systemPath = nil;
  self->handle = nil;
  [super dealloc];
}

// opening

- (BOOL)openInMode:(NSString *)_mode {
  // throws
  //   NGUnknownStreamModeException  when _mode is invalid
  //   NGCouldNotOpenStreamException when the file could not be opened
#if defined(__MINGW32__)
  DWORD openFlags;
  DWORD shareMode;

  if (self->fh != INVALID_HANDLE_VALUE)
    [self close]; // if stream is open, close and reopen

  if ([_mode isEqualToString:NGFileReadOnly]) {
    self->streamMode = NGStreamMode_readOnly;
    openFlags = GENERIC_READ;
    shareMode = FILE_SHARE_READ;
  }
  else if ([_mode isEqualToString:NGFileWriteOnly]) {
    self->streamMode = NGStreamMode_writeOnly;
    openFlags = GENERIC_WRITE;
    shareMode = FILE_SHARE_WRITE;
  }
  else if ([_mode isEqualToString:NGFileReadWrite]) {
    self->streamMode = NGStreamMode_readWrite;
    openFlags = GENERIC_READ | GENERIC_WRITE;
    shareMode = FILE_SHARE_READ | FILE_SHARE_WRITE;
  }
  else {
    [[[NGUnknownStreamModeException alloc]
                                    initWithStream:self mode:_mode] raise];
    return NO;
  }

  self->fh = CreateFile([self->systemPath fileSystemRepresentation],
                        openFlags, shareMode, NULL,
                        OPEN_ALWAYS, // same as the Unix O_CREAT flag
                        0,           // security flags ?
                        NULL);

  if (self->fh == INVALID_HANDLE_VALUE)
    [NGCouldNotOpenStreamException raiseWithStream:self];

#else
  int openFlags; // flags passed to open() call

  if (self->fd != NGInvalidUnixDescriptor)
    [self close]; // if stream is open, close and reopen

  if ([_mode isEqualToString:NGFileReadOnly]) {
    self->streamMode = NGStreamMode_readOnly;
    openFlags = O_RDONLY;
  }
  else if ([_mode isEqualToString:NGFileWriteOnly]) {
    self->streamMode = NGStreamMode_writeOnly;
    openFlags = O_WRONLY | O_CREAT;
  }
  else if ([_mode isEqualToString:NGFileReadWrite]) {
    self->streamMode = NGStreamMode_readWrite;
    openFlags = O_RDWR | O_CREAT;
  }
  else if ([_mode isEqualToString:NGFileAppend]) {
    self->streamMode = NGStreamMode_writeOnly;
    openFlags = O_WRONLY | O_CREAT | O_APPEND;
  }
  else if ([_mode isEqualToString:NGFileReadAppend]) {
    self->streamMode = NGStreamMode_readWrite;
    openFlags = O_RDWR | O_CREAT | O_APPEND;
  }
  else {
    [[[NGUnknownStreamModeException alloc]
              initWithStream:self mode:_mode] raise];
    return NO;
  }

  self->fd = open([self->systemPath fileSystemRepresentation],
                  openFlags,
                  NGFileCreationMask);

  if (self->fd == -1) {
    self->fd = NGInvalidUnixDescriptor;

    [NGCouldNotOpenStreamException raiseWithStream:self];
    return NO;
  }
#endif
  
  self->markDelta = -1; // not marked
  return YES;
}

- (BOOL)isOpen {
#if defined(__MINGW32__)
  return (self->fh != INVALID_HANDLE_VALUE) ? YES : NO;
#else
  return (self->fd != NGInvalidUnixDescriptor) ? YES : NO;
#endif
}

// Foundation file handles

- (void)resetFileHandle { // called by NSFileHandle on dealloc
  self->handle = nil;
}
- (NSFileHandle *)fileHandle {
  if (self->handle == nil)
    self->handle = [[_NGConcreteFileStreamFileHandle allocWithZone:[self zone]]
                                                     initWithStream:self];
  return [self->handle autorelease];
}

#if defined(__MINGW32__)
- (HANDLE)windowsFileHandle {
  return self->fh;
}
#endif

- (int)fileDescriptor {
#if defined(__MINGW32__)
  return (int)[self fileHandle];
#else
  return self->fd;
#endif
}

// primitives

static void _checkOpen(NGFileStream *self, NSString *_reason) {
#if defined(__MINGW32__)
  if (self->fh == INVALID_HANDLE_VALUE)
    [NGStreamNotOpenException raiseWithStream:self reason:_reason];
#else
  if (self->fd == NGInvalidUnixDescriptor)
    [NGStreamNotOpenException raiseWithStream:self reason:_reason];
#endif
}

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  // throws
  //   NGWriteOnlyStreamException  when the stream is not readable
  //   NGStreamNotOpenException    when the stream is not open
  //   NGEndOfStreamException      when the end of the stream is reached
  //   NGStreamReadErrorException  when the read call failed

  _checkOpen(self, @"tried to read from a file stream which is closed");

  if (!NGCanReadInStreamMode(streamMode))
    [NGWriteOnlyStreamException raiseWithStream:self];

  {
#if defined(__MINGW32__)
    DWORD readResult = 0;

    if (ReadFile(self->fh, _buf, _len, &readResult, NULL) == FALSE) {
      DWORD lastErr = GetLastError();

      if (lastErr == ERROR_HANDLE_EOF)
        [NGEndOfStreamException raiseWithStream:self];
      else
        [NGStreamReadErrorException raiseWithStream:self errorCode:lastErr];
    }
    if (readResult == 0)
      [NGEndOfStreamException raiseWithStream:self];
#else
    int readResult;
    int retryCount = 0;
    
    do {
      readResult = read(self->fd, _buf, _len);
      
      if (readResult == 0)
        [NGEndOfStreamException raiseWithStream:self];
      else if (readResult == -1) {
        int errCode = errno;

        if (errCode == EINTR)
          // system call was interrupted
          retryCount++;
        else
          [NGStreamReadErrorException raiseWithStream:self errorCode:errCode];
      }
    }
    while ((readResult <= 0) && (retryCount < 10));

    if (retryCount >= 10)
      [NGStreamReadErrorException raiseWithStream:self errorCode:EINTR];
#endif
    
    NSAssert(readResult > 0, @"invalid read method state");

    // adjust mark
    if (self->markDelta != -1)
      self->markDelta += readResult; // increase delta
    
    return readResult;
  }
}

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  // throws
  //   NGReadOnlyStreamException   when the stream is not writeable
  //   NGStreamNotOpenException    when the stream is not open
  //   NGStreamWriteErrorException when the write call failed
  
  _checkOpen(self, @"tried to write to a file stream which is closed");
  
  if (!NGCanWriteInStreamMode(streamMode))
    [NGReadOnlyStreamException raiseWithStream:self];

  {
#if defined(__MINGW32__)
    DWORD writeResult = 0;

    if (WriteFile(self->fh, _buf, _len, &writeResult, NULL) == FALSE) {
      DWORD errorCode = GetLastError();

      switch (errorCode) {
        case ERROR_INVALID_HANDLE:
          [NGStreamWriteErrorException raiseWithStream:self
                                       reason:@"incorrect file handle"];
          break;
        case ERROR_WRITE_PROTECT:
          [NGStreamWriteErrorException raiseWithStream:self
                                       reason:@"disk write protected"];
          break;
        case ERROR_NOT_READY:
          [NGStreamWriteErrorException raiseWithStream:self
                                       reason:@"the drive is not ready"];
          break;
        case ERROR_HANDLE_EOF:
          [NGStreamWriteErrorException raiseWithStream:self
                                       reason:@"reached end of file"];
          break;
        case ERROR_DISK_FULL:
          [NGStreamWriteErrorException raiseWithStream:self
                                       reason:@"disk is full"];
          break;
        
        default:
          [NGStreamWriteErrorException raiseWithStream:self
                                       errorCode:GetLastError()];
      }
      
      NSLog(@"invalid program state, aborting");
      abort();
    }
#else
    int writeResult;
    int retryCount = 0;

    do {
      writeResult = write(self->fd, _buf, _len);

      if (writeResult == -1) {
        int errCode = errno;

        if (errCode == EINTR)
          // system call was interrupted
          retryCount++;
        else
          [NGStreamWriteErrorException raiseWithStream:self errorCode:errno];
      }
    }
    while ((writeResult == -1) && (retryCount < 10));

    if (retryCount >= 10)
      [NGStreamWriteErrorException raiseWithStream:self errorCode:EINTR];
#endif
    
    return writeResult;
  }
}

- (BOOL)close {
#if defined(__MINGW32__)
  if (self->fh == INVALID_HANDLE_VALUE) {
    NSLog(@"tried to close already closed stream %@", self);
    return YES; /* not signaled as an error .. */
  }

  if (CloseHandle(self->fh) == FALSE) {
    [NGCouldNotCloseStreamException raiseWithStream:self];
    return NO;
  }
  
  self->fh = INVALID_HANDLE_VALUE;
#else
  if (self->fd == NGInvalidUnixDescriptor) {
    NSLog(@"tried to close already closed stream %@", self);
    return YES; /* not signaled as an error .. */
  }

  if (close(self->fd) != 0) {
    [NGCouldNotCloseStreamException raiseWithStream:self];
    return NO;
  }
  
  self->fd = NGInvalidUnixDescriptor;
#endif
  self->markDelta = -1;
  return YES;
}

- (NGStreamMode)mode {
  return self->streamMode;
}
- (BOOL)isRootStream {
  return YES;
}

#if defined(__MINGW32__)
- (BOOL)flush {
  if (self->fh != INVALID_HANDLE_VALUE)
    FlushFileBuffers(self->fh);
  return YES;
}
#endif

// blocking

#if defined(__MINGW32__)
- (BOOL)wouldBlockInMode:(NGStreamMode)_mode {
  NSLog(@"%@ not supported in Windows environment !",
        NSStringFromSelector(_cmd));
  return YES;
}
#else
- (BOOL)wouldBlockInMode:(NGStreamMode)_mode {
  short events = 0;

  if (self->fd == NGInvalidUnixDescriptor)
    return NO;

  if (NGCanReadInStreamMode(_mode))  events |= POLLRDNORM;
  if (NGCanWriteInStreamMode(_mode)) events |= POLLWRNORM;

  // timeout of 0 means return immediatly
  return (NGPollDescriptor(self->fd, events, 0) == 1 ? NO : YES);
}
#endif

// marking

- (BOOL)mark {
  self->markDelta = 0;
  return YES;
}
- (BOOL)rewind {
  if (![self moveByOffset:-(self->markDelta)])
    return NO;
  self->markDelta = -1;
  return YES;
}
- (BOOL)markSupported {
  return YES;
}

// NGPositionableStream

- (BOOL)moveToLocation:(unsigned)_location {
  self->markDelta = -1;

#if defined(__MINGW32__)
  if (SetFilePointer(self->fh, _location, NULL, FILE_BEGIN) == -1) {
    [NGStreamSeekErrorException raiseWithStream:self errorCode:GetLastError()];
    return NO;
  }
#else
  if (lseek(self->fd, _location, SEEK_SET) == -1) {
    [NGStreamSeekErrorException raiseWithStream:self errorCode:errno];
    return NO;
  }
#endif
  return YES;
}
- (BOOL)moveByOffset:(int)_delta {
  self->markDelta += _delta;
  
#if defined(__MINGW32__)
  if (SetFilePointer(self->fh, _delta, NULL, FILE_CURRENT) == -1) {
    [NGStreamSeekErrorException raiseWithStream:self errorCode:GetLastError()];
    return NO;
  }
#else
  if (lseek(self->fd, _delta, SEEK_CUR) == -1) {
    [NGStreamSeekErrorException raiseWithStream:self errorCode:errno];
    return NO;
  }
#endif
  return YES;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p] path=%@ mode=%@>",
                     NSStringFromClass([self class]), self,
		     self->systemPath ? self->systemPath : (NSString *)@"nil",
                     [self modeDescription]];
}

@end /* NGFileStream */


@implementation _NGConcreteFileStreamFileHandle

// accessors

#if defined(__MINGW32__)
- (HANDLE)fileHandle {
  return [(NGFileStream *)stream windowsFileHandle];
}
#endif

- (int)fileDescriptor {
  return [(NGFileStream *)stream fileDescriptor];
}

@end
