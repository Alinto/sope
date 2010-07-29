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

#include <NGStreams/NGDataStream.h>
#include <NGStreams/NGStreamExceptions.h>
#include "common.h"

// TODO: cache -bytes and -length of NSData for immutable data!

@implementation NGDataStream

+ (int)version {
  return [super version] + 2;
}

+ (id)dataStream {
  return [self streamWithData:[NSMutableData dataWithCapacity:1024]];
}
+ (id)dataStreamWithCapacity:(int)_capacity {
  return [self streamWithData:[NSMutableData dataWithCapacity:_capacity]];
}

+ (id)streamWithData:(NSData *)_data {
  return [[[self alloc] initWithData:_data] autorelease];
}
- (id)initWithData:(NSData *)_data mode:(NGStreamMode)_mode {
  if ((self = [super init])) {
    self->data     = [_data retain];
    self->position = 0;

    if ([self->data respondsToSelector:@selector(methodForSelector:)] == YES) {
      self->dataLength = (unsigned int(*)(id, SEL))
                         [self->data methodForSelector:@selector(length)];
      self->dataBytes  = (const void*(*)(id, SEL))
                         [self->data methodForSelector:@selector(bytes)];
    }
    else {
      self->dataLength = NULL;
      self->dataBytes  = NULL;
    }
    
    self->streamMode = _mode;

    /* for read-only streams */
    if (self->streamMode == NGStreamMode_readOnly) {
      self->bytes  = [self->data bytes];
      self->length = [self->data length];
    }
  }
  return self;
}
- (id)initWithData:(NSData *)_data {
  NGStreamMode smode;
  
  smode = [data isKindOfClass:[NSMutableData class]]
    ? NGStreamMode_readWrite
    : NGStreamMode_readOnly;
  return [self initWithData:_data mode:smode];
}

- (void)dealloc {
  [self->data          release];
  [self->lastException release];
  [super dealloc];
}

/* accessors */

/* NGTextInputStream */

- (NSException *)lastException {
  return self->lastException;
}
- (void)setLastException:(NSException *)_exception {
  ASSIGN(self->lastException, _exception);
}
- (void)resetLastException {
  [self->lastException release];
  self->lastException = nil;
}

- (NSData *)data {
  return self->data;
}

- (unsigned)availableBytes {
  // returns number of available bytes
  register unsigned currentLength = 0;
  
  if (self->bytes == NULL) {
    currentLength = (self->dataLength == NULL)
      ? [self->data length]
      : self->dataLength(self->data, @selector(length));
  }
  else
    currentLength = self->length;
  
  return (currentLength == position)
    ? 0
    : (currentLength - position);
}

/* primitives */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  // throws
  //   NGStreamNotOpenException   when the stream is not open
  //   NGEndOfStreamException     when the end of the stream is reached
  register unsigned currentLength = 0;
  
  if (self->bytes == NULL) {
    currentLength = (self->dataLength == NULL)
      ? [self->data length]
      : self->dataLength(self->data, @selector(length));
  }
  else
    currentLength = self->length;

  if (self->data == nil) {
    NSException *e;
    
    e = [NGStreamNotOpenException exceptionWithStream:self reason:
				    @"tried to read from a data stream "
				    @"which was closed"];
    [self setLastException:e];
    return NGStreamError;
  }

  if (currentLength == position) {
    [self setLastException:
	    [NGEndOfStreamException exceptionWithStream:self]];
    return NGStreamError;
  }
  {
    NSRange range;
    range.location = position;

    if ((position + _len) > currentLength)
      range.length = currentLength - position;
    else
      range.length = _len;

    [self->data getBytes:_buf range:range];

    position += range.length;
    return range.length;
  }
}

- (int)readByte {
  register const unsigned char *p;
  register unsigned int currentLength = 0;
  int result = 0;
  
  if (self->bytes == NULL) {
    currentLength = (self->dataLength == NULL)
      ? [self->data length]
      : self->dataLength(self->data, @selector(length));
  }
  else
    currentLength = self->length;
  
  if (currentLength == position)
    return -1;
  
  if (self->bytes == NULL) {
    p = (self->dataBytes == NULL)
      ? [self->data bytes]
      : self->dataBytes(self->data, @selector(bytes));
  }
  else
    p = self->bytes;
  result = p[self->position];
  self->position++;
  return result;
}

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  // throws
  //   NGReadOnlyStreamException when the stream is not writeable
  //   NGStreamNotOpenException  when the stream is not open
  
  if (self->data == nil) {
    NSException *e;

    e = [NGStreamNotOpenException exceptionWithStream:self reason:
                                    @"tried to write to a data stream "
				    @"which was closed"];
    [self setLastException:e];
    return NGStreamError;
  }
  if (!NGCanWriteInStreamMode(streamMode)) {
    NSException *e;
    
    e = [NGReadOnlyStreamException exceptionWithStream:self];
    [self setLastException:e];
    return NGStreamError;
  }
  [(NSMutableData *)self->data appendBytes:_buf length:_len];

  return _len;
}

- (BOOL)close {
  ASSIGN(self->lastException, (id)nil);
  [self->data release]; self->data = nil;
  position   = 0;
  streamMode = NGStreamMode_undefined;
  return YES;
}

- (NGStreamMode)mode {
  return streamMode;
}
- (BOOL)isRootStream {
  return YES;
}

// NGPositionableStream

- (BOOL)moveToLocation:(unsigned)_location {
  position = _location;
  return YES;
}
- (BOOL)moveByOffset:(int)_delta {
  position += _delta;
  return YES;
}

/* blocking .. */

- (BOOL)wouldBlockInMode:(NGStreamMode)_mode {
  return NO;
}

- (id)retain {
  return [super retain];
}

/* bytebuffer / lookahead API */

- (int)la:(unsigned)_la {
  register unsigned int currentLength, newpos;
  register const unsigned char *p;
  int result = 0;
  
  if (self->bytes == NULL) {
    currentLength = (self->dataLength == NULL)
      ? [self->data length]
      : self->dataLength(self->data, @selector(length));
  }
  else
    currentLength = self->length;
  
  if (currentLength == self->position) // already at EOF
    return -1;
  
  newpos = (self->position + _la);
  if (newpos >= currentLength)
    return -1; /* a look into EOF */
  
  if (self->bytes == NULL) {
    p = (self->dataBytes == NULL)
      ? [self->data bytes]
      : self->dataBytes(self->data, @selector(bytes));
  }
  else
    p = self->bytes;
  
  result = p[newpos];
  return result;
}

- (void)consume { // consume one byte
  register unsigned int currentLength = 0;
  
  if (self->bytes == NULL) {
    currentLength = (self->dataLength == NULL)
      ? [self->data length]
      : self->dataLength(self->data, @selector(length));
  }
  else
    currentLength = self->length;
  
  if (currentLength == self->position)
    return;
  
  self->position++; // consume
}
- (void)consume:(unsigned)_cnt { // consume _cnt bytes
  register unsigned int currentLength = 0;

  if (self->bytes == NULL) {
    currentLength = (self->dataLength == NULL)
      ? [self->data length]
      : self->dataLength(self->data, @selector(length));
  }
  else
    currentLength = self->length;
  
  if (currentLength == self->position)
    return;
  
  self->position += _cnt; // consume
  
  if (self->position > currentLength)
    self->position = currentLength;
}

@end /* NGDataStream */
