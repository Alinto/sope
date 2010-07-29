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

#include <NGStreams/NGBufferedStream.h>
#include "common.h"

#define NEWLINE_CHAR '\n'
#define WRITE_WARN_SIZE (1024 * 1024 * 100) /* 100MB */

@implementation NGBufferedStream

static const unsigned DEFAULT_BUFFER_SIZE = 512;
static Class DataStreamClass = Nil;

+ (void)initialize {
  DataStreamClass = NSClassFromString(@"NGDataStream");
}

// returns the number of bytes which where read from the buffer
#define numberOfConsumedReadBufferBytes(self) \
  ((self->readBufferSize == 0) ? 0 : (self->readBufferPos - self->readBuffer))

// returns the number of bytes which can be read from buffer (without source access)
#define numberOfAvailableReadBufferBytes(self) \
  (self->readBufferFillSize - numberOfConsumedReadBufferBytes(self))

// look whether all bytes in the buffer where consumed, if so, reset the buffer
#define checkReadBufferFillState(self) \
  if (numberOfAvailableReadBufferBytes(self) == 0) { \
    self->readBufferPos = self->readBuffer; \
    self->readBufferFillSize = 0;  \
  }

// ******************** constructors ********************

+ (id)filterWithSource:(id<NGStream>)_source bufferSize:(unsigned)_size {
  if (_source == nil) return nil;
  if (*(Class *)_source == DataStreamClass) return _source;
  return [[[self alloc] initWithSource:_source bufferSize:_size] autorelease];
}

// TODO: can we reduced duplicate code here ...

- (id)initWithSource:(id<NGStream>)_source bufferSize:(unsigned)_size {
  if (_source == nil) {
    [self release];
    return nil;
  }
  if (*(Class *)_source == DataStreamClass) {
    [self release];
    return [_source retain];
  }

  if ((self = [super initWithSource:_source])) {
    self->readBuffer  = calloc(_size, 1);
    self->writeBuffer = calloc(_size, 1);
    
    self->readBufferPos       = self->readBuffer;
    self->readBufferSize      = _size;
    self->readBufferFillSize  = 0; // no bytes are read from source
    self->writeBufferFillSize = 0;
    self->writeBufferSize     = _size;
    self->flags._flushOnNewline = 1;
  }
  return self;
}

- (id)initWithInputSource:(id<NGInputStream>)_source bufferSize:(unsigned)_s {
  if (_source == nil) {
    [self release];
    return nil;
  }
  if (*(Class *)_source == DataStreamClass) {
    [self release];
    return [_source retain];
  }

  if ((self = [super initWithInputSource:_source])) {
    self->readBuffer            = calloc(_s, 1);
    self->readBufferPos         = self->readBuffer;
    self->readBufferSize        = _s;
    self->readBufferFillSize    = 0; // no bytes are read from source
    self->flags._flushOnNewline = 1;
  }
  return self;
}
- (id)initWithOutputSource:(id<NGOutputStream>)_src bufferSize:(unsigned)_s {
  if (_src == nil) {
    [self release];
    return nil;
  }
  if (*(Class *)_src == DataStreamClass) {
    [self release];
    return [_src retain];
  }

  if ((self = [super initWithOutputSource:_src])) {
    self->writeBuffer           = calloc(_s, 1);
    self->writeBufferFillSize   = 0;
    self->writeBufferSize       = _s;
    self->flags._flushOnNewline = 1;
  }
  return self;
}

- (id)initWithSource:(id<NGStream>)_source {
  return [self initWithSource:_source bufferSize:DEFAULT_BUFFER_SIZE];
}
- (id)initWithInputSource:(id<NGInputStream>)_source {
  return [self initWithInputSource:_source bufferSize:DEFAULT_BUFFER_SIZE];
}
- (id)initWithOutputSource:(id<NGOutputStream>)_source {
  return [self initWithOutputSource:_source bufferSize:DEFAULT_BUFFER_SIZE];
}

- (void)dealloc {
  [self flush];
  
  if (self->readBuffer) {
    free(self->readBuffer);
    self->readBuffer    = NULL;
    self->readBufferPos = NULL;
  }
  self->readBufferFillSize = 0;
  self->readBufferSize     = 0;

  if (self->writeBuffer) {
    free(self->writeBuffer);
    self->writeBuffer = NULL;
  }
  self->writeBufferFillSize = 0;
  self->writeBufferSize     = 0;
  [super dealloc];
}

/* accessors */

- (void)setReadBufferSize:(unsigned)_size {
  [self flush];

  if (_size == self->readBufferSize)
    return;

  if (_size == 0) {
    if (self->readBuffer != NULL) {
      free(self->readBuffer);
      self->readBuffer = NULL;
    }
    self->readBufferSize = _size;
    self->readBufferPos  = NULL;
  }
  else {
    if (self->readBuffer != NULL)
      self->readBuffer = realloc(self->readBuffer, _size);
    else
      self->readBuffer = calloc(_size, 1);
    
    self->readBufferSize     = _size;
    self->readBufferPos      = self->readBuffer;
    self->readBufferFillSize = 0; // no bytes a read from source
  }
}
- (unsigned)readBufferSize {
  return self->readBufferSize;
}

- (void)setWriteBufferSize:(unsigned)_size {
  [self flush];

  if (_size == self->writeBufferSize)
    return;

  self->writeBuffer = realloc(self->writeBuffer, _size);
  self->writeBufferSize = _size;
}
- (unsigned)writeBufferSize {
  return self->writeBufferSize;
}

/* blocking .. */

- (BOOL)wouldBlockInMode:(NGStreamMode)_mode {
  BOOL canRead, canWrite;

  if (self->readBufferSize == 0)
    canRead = NO;
  else
    canRead = (numberOfAvailableReadBufferBytes(self) > 0);
  
  canWrite = (self->writeBufferSize == 0)
    ? NO
    : (self->writeBufferFillSize > 0);
  
  if ((_mode == NGStreamMode_readWrite) && canRead && canWrite)
    return NO;
  if ((_mode == NGStreamMode_readOnly) && canRead) {
    return NO;
  }
  if ((_mode == NGStreamMode_writeOnly) && canWrite)
    return NO;

  return ([self->source respondsToSelector:@selector(wouldBlockInMode:)])
    ? [(id)self->source wouldBlockInMode:_mode]
    : YES;
}

/* primitives */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  register unsigned availBytes = numberOfAvailableReadBufferBytes(self);
  
  if (self->readBufferSize == 0) { // no read buffering is done (buffersize==0)
    return (readBytes != NULL)
      ? readBytes(source, _cmd, _buf, _len)
      : [source readBytes:_buf count:_len];
  }
    
  if (availBytes >= _len) {
    // there are enough bytes in the buffer to fulfill the request
    if (_len == 1) {
      *(unsigned char *)_buf = *(unsigned char *)self->readBufferPos;
      self->readBufferPos++;
    }
    else {
      memcpy(_buf, self->readBufferPos, _len);
      self->readBufferPos += _len; // update read position (consumed-size)
    }
    checkReadBufferFillState(self); // check whether all bytes where consumed
    return _len;
  }
  else if (availBytes > 0) {
    // there are some bytes in the buffer, these are returned
    
    memcpy(_buf, self->readBufferPos, availBytes);// copy all bytes from buffer
    self->readBufferPos      = self->readBuffer;  // reset position
    self->readBufferFillSize = 0;   // no bytes available in buffer anymore
    return availBytes;
  }
  else if (_len > self->readBufferSize) {
    /*
      requested _len is bigger than the buffersize, so we can bypass the
      buffer (which is empty, as guaranteed by the previous 'ifs'
    */

    NSAssert(self->readBufferPos == self->readBuffer,
             @"read buffer position is not reset");
    NSAssert(self->readBufferFillSize == 0, @"there are bytes in the buffer");

    availBytes = (readBytes != NULL)
      ? (unsigned)readBytes(source, _cmd, _buf, _len)
      : [source readBytes:_buf count:_len];
    
    if (availBytes == NGStreamError)
      return NGStreamError;
    
    NSAssert(availBytes != 0, @"readBytes:count: may never return zero !");

    return availBytes; // return the number of bytes which could be read
  }
  else {
    /*
      no bytes are available and the requested _len is smaller than the 
      possible buffer size, we have to read the next block of input from the 
      source
    */
    
    NSAssert(self->readBufferPos == self->readBuffer,
             @"read buffer position is not reset");
    NSAssert(self->readBufferFillSize == 0, @"there are bytes in the buffer");
    
    self->readBufferFillSize = (readBytes != NULL)
      ? (unsigned)readBytes(source,_cmd, self->readBuffer,self->readBufferSize)
      : [source readBytes:self->readBuffer count:self->readBufferSize];
    
    if (self->readBufferFillSize == NGStreamError) {
      self->readBufferFillSize = 0;
      return NGStreamError;
    }
    
    NSAssert(self->readBufferFillSize != 0,
             @"readBytes:count: may never return zero !");
    
    /* 
       now comes a section which is roughly the same like the first to 
       conditionals in this method
    */
    if (self->readBufferFillSize >= _len) {
      // there are enough bytes in the buffer to fulfill the request
    
      memcpy(_buf, self->readBufferPos, _len);
      self->readBufferPos += _len;    // update read position (consumed-size)
      checkReadBufferFillState(self); // check whether all bytes where consumed
      return _len;
    }
    else { // (readBufferFillSize > 0) (this is ensured by the above assert)
      // there are some bytes in the buffer, these are returned

      availBytes = self->readBufferFillSize;
      // copy all bytes from buffer
      memcpy(_buf, self->readBufferPos, self->readBufferFillSize);
      self->readBufferPos      = self->readBuffer; // reset position
      self->readBufferFillSize = 0; // no bytes available in buffer anymore
      return availBytes;
    }
  }
}

- (int)readByte {
  if (self->readBufferSize == 0) // no read buffering is done (buffersize==0)
    return [super readByte];
  
  if (numberOfAvailableReadBufferBytes(self) >= 1) {
    unsigned char byte = *(unsigned char *)self->readBufferPos;
    self->readBufferPos++;
    checkReadBufferFillState(self); // check whether all bytes where consumed    
    return byte;
  }
  return [super readByte];
}

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  register unsigned tmp       = 0;
  register unsigned remaining = _len;
  register void     *track    = (void *)_buf;

#if DEBUG
  if (_len > WRITE_WARN_SIZE) {
    NSLog(@"WARNING(%s): got passed in length %uMB (%u bytes, errcode=%u) ...",
          __PRETTY_FUNCTION__, (_len / 1024 / 1024), _len, NGStreamError);
  }
#endif
  
  while (remaining > 0) {
    // how much bytes available in buffer ?
    tmp = self->writeBufferSize - self->writeBufferFillSize; 
    tmp = (tmp > remaining) ? remaining : tmp;
    
    memcpy((self->writeBuffer + self->writeBufferFillSize), track, tmp);
    track += tmp;
    remaining -= tmp;
    self->writeBufferFillSize += tmp;
    
    if (self->writeBufferFillSize == self->writeBufferSize) {
      BOOL ok;
      
      ok = [self->source safeWriteBytes:self->writeBuffer
                         count:self->writeBufferFillSize];
      if (!ok) return NGStreamError;
      
      self->writeBufferFillSize = 0;
    }
  }
  
  if (self->flags._flushOnNewline == 1) {
    // scan buffer for newlines, if one is found, flush buffer
    
    for (tmp = 0; tmp < _len; tmp++) {
      if (tmp == NEWLINE_CHAR) {
        if (![self flush])
          return NGStreamError;
        break;
      }
    }
  }
  
  /* clean up for GC */
  tmp       = 0;    
  track     = NULL; // clean up for GC
  remaining = 0;
  
  return _len;
}

- (BOOL)close {
  if (![self flush])
    return NO;
  
  if (self->readBuffer) {
    free(self->readBuffer);
    self->readBuffer = NULL;
    self->readBufferPos = NULL;
  }
  self->readBufferFillSize = 0;
  self->readBufferSize = 0;
  
  if (self->writeBuffer) {
    free(self->writeBuffer);
    self->writeBuffer = NULL;
  }
  self->writeBufferFillSize = 0;
  self->writeBufferSize = 0;
  
  return [super close];
}

- (BOOL)flush {
  if (self->writeBufferFillSize > 0) {
    BOOL ok;
    
#if DEBUG
    if (self->writeBufferFillSize > WRITE_WARN_SIZE) {
      NSLog(@"WARNING(%s): shall flush %uMB (%u bytes, errcode=%u) ...",
            __PRETTY_FUNCTION__, (self->writeBufferFillSize/1024/1024),
            self->writeBufferFillSize, NGStreamError);
      //abort();
    }
#endif
    
    ok = [self->source
              safeWriteBytes:self->writeBuffer
              count:self->writeBufferFillSize];
    if (!ok) {
      /* should check exception for fill size ? ... */
      return NO;
    }
    
    self->writeBufferFillSize = 0;
  }
  return YES;
}

@end /* NGBufferedStream */

@implementation NGStream(NGBufferedStreamExtensions)

- (NGBufferedStream *)bufferedStream {
  return [NGBufferedStream filterWithSource:self];
}

@end /* NGStream(NGBufferedStreamExtensions) */

@implementation NGBufferedStream(NGBufferedStreamExtensions)

- (NGBufferedStream *)bufferedStream {
  return self;
}

@end /* NGBufferedStream(NGBufferedStreamExtensions) */
