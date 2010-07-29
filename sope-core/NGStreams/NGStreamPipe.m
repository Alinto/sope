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
#include "common.h"
#include "NGStreamPipe.h"
#include "NGFileStream.h"
#include "NGBufferedStream.h"

#if defined(WIN32)

@implementation NGStreamPipe
@end

#else

static const int NGInvalidUnixDescriptor = -1;

@interface _NGConcretePipeFileHandle : NSFileHandle
{
@public
  int *fd;
}

- (id)initWithDescriptor:(int *)_fd;

@end

@interface NGFileStream(PrivateMethods)
- (id)__initWithDescriptor:(int)_fd mode:(NGStreamMode)_mode;
@end

@implementation NGStreamPipe

+ (id)pipe {
  return [[[self alloc] init] autorelease];
}

- (id)init {
  if (pipe(self->fildes) == -1) {
    NSLog (@"pipe() system call failed: %s", strerror (errno));
    self = [self autorelease];
    return nil;
  }
  return self;
}

- (void)gcFinalize {
  [self close];
}

- (void)dealloc {
  [self gcFinalize];
  [self->fhIn  release];
  [self->fhOut release];
  [super dealloc];
}

- (NSFileHandle *)fileHandleForReading {
  if (self->fhIn == nil) {
    self->fhIn = [[_NGConcretePipeFileHandle alloc]
                      initWithDescriptor:&(self->fildes[0])];
  }
  return self->fhIn;
}
- (NSFileHandle *)fileHandleForWriting {
  if (self->fhOut == nil) {
    self->fhOut = [[_NGConcretePipeFileHandle alloc]
                       initWithDescriptor:&(self->fildes[1])];
  }
  return self->fhOut;
}

- (id<NGByteSequenceStream>)streamForReading {
  return self;
}
- (id<NGOutputStream>)streamForWriting {
  return self;
}

- (NSException *)lastException {
  return nil;
}

/* NGInputStream */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  int readResult;

  if (self->fildes[0] == NGInvalidUnixDescriptor) {
    [NGStreamReadErrorException raiseWithStream:self
                                reason:@"read end of pipe is closed"];
  }
  
  readResult = read(self->fildes[0], _buf, _len);

  if (readResult == 0)
    [NGEndOfStreamException raiseWithStream:self];
  else if (readResult == -1)
    [NGStreamReadErrorException raiseWithStream:self errorCode:errno];

  return readResult;
}
- (BOOL)safeReadBytes:(void *)_buf count:(unsigned)_len {
  return NGSafeReadBytesFromStream(self, _buf, _len);
}

/* marks */

- (BOOL)mark {
  NSLog(@"WARNING: called mark on a stream which doesn't support marking !");
  return NO;
}
- (BOOL)rewind {
  [NGStreamException raiseWithStream:self reason:@"marking not supported"];
  return NO;
}
- (BOOL)markSupported {
  return NO;
}

/* NGOutputStream */

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  int writeResult;

  if (self->fildes[1] == NGInvalidUnixDescriptor) {
    [NGStreamWriteErrorException raiseWithStream:self
                                 reason:@"write end of pipe is closed"];
  }
  
  writeResult = write(self->fildes[1], _buf, _len);

  if (writeResult == -1)
    [NGStreamWriteErrorException raiseWithStream:self errorCode:errno];
  return writeResult;
}
- (BOOL)safeWriteBytes:(const void *)_buf count:(unsigned)_len {
  return NGSafeWriteBytesToStream(self, _buf, _len);
}

- (BOOL)flush {
  return YES;
}

/* NGStream */

- (BOOL)close {
  if (self->fildes[0] != NGInvalidUnixDescriptor) close(self->fildes[0]);
  if (self->fildes[1] != NGInvalidUnixDescriptor) close(self->fildes[1]);
  return YES;
}

- (NGStreamMode)mode {
  NGStreamMode mode = NGStreamMode_undefined;

  if (self->fildes[0] != NGInvalidUnixDescriptor)
    mode |= NGStreamMode_readOnly;
  if (self->fildes[1] != NGInvalidUnixDescriptor)
    mode |= NGStreamMode_writeOnly;

  return mode;
}

// NGByteSequenceStream

- (int)readByte {
  return NGReadByteFromStream(self);
}

// Extensions

- (BOOL)isOpen {
  return (self->fildes[0] == NGInvalidUnixDescriptor) &&
         (self->fildes[1] == NGInvalidUnixDescriptor) ? NO : YES;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<0x%p[%@]: in=%i out=%i>",
                     self, NSStringFromClass([self class]),
                     self->fildes[0], self->fildes[1]];
}

@end /* NGStreamPipe */

@implementation _NGConcretePipeFileHandle

- (id)initWithDescriptor:(int *)_fd {
  self->fd = _fd;
  return self;
}

- (int)fileDescriptor {
  return *(self->fd);
}

- (void)closeFile {
  close(*(self->fd));
  *(self->fd) = NGInvalidUnixDescriptor;
}

@end

#endif /* WIN32 */
