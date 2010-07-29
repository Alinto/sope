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

#include "common.h"
#include "NGStreamExceptions.h"

@interface NSObject(setLastException)
- (void)setLastException:(NSException *)_exception;
@end

@implementation NGIOException

- (id)init {
  self = [super initWithName:NSStringFromClass([self class])
                reason:@"an IO exception occured"
                userInfo:nil];
  return self;
}
- (id)initWithReason:(NSString *)_reason {
  self = [super initWithName:NSStringFromClass([self class])
                reason:_reason
                userInfo:nil];
  return self;
}

+ (void)raiseWithReason:(NSString *)_reason {
  [[[self alloc] initWithReason:_reason] raise];
}

+ (void)raiseOnStream:(id)_stream reason:(NSString *)_reason {
  NGIOException *e;

  e = [[self alloc] initWithReason:_reason];
  
  if (_stream) {
    if ([_stream respondsToSelector:@selector(setLastException:)]) {
      [_stream setLastException:e];
      [e release];
      return;
    }
  }
  [e raise];
}
+ (void)raiseOnStream:(id)_stream {
  [self raiseOnStream:_stream reason:nil];
}

@end /* NGIOException */

@implementation NGStreamException

- (NSString *)defaultReason {
  return @"a stream exception occured";
}

- (id)init {
  return [self initWithStream:nil reason:[self defaultReason]];
}
- (id)initWithStream:(id<NGStream>)_stream {
  return [self initWithStream:_stream reason:[self defaultReason]];
}

- (id)initWithStream:(id<NGStream>)_stream format:(NSString *)_format,... {
  NSString *tmp = nil;
  va_list  ap;
  
  va_start(ap, _format);
  tmp = [[NSString alloc] initWithFormat:_format arguments:ap];
  va_end(ap);

  self = [self initWithStream:_stream reason:tmp];
  [tmp release];
  return self;
}

- (id)initWithStream:(id<NGStream>)_stream reason:(NSString *)_reason {
  NSDictionary *ui = nil;
  
  ui = [NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithInt:errno], @"errno",
                       [NSString stringWithCString:strerror(errno)], @"error",
                       [NSValue valueWithNonretainedObject:_stream], @"stream",
                       nil];
  
  self = [super initWithName:NSStringFromClass([self class])
                reason:_reason
                userInfo:ui];
  if (self) {
    self->streamPointer = 
      [[NSValue valueWithNonretainedObject:_stream] retain];
  }
  return self;
}

+ (id)exceptionWithStream:(id<NGStream>)_stream {
  return [[self alloc] initWithStream:_stream];
}
+ (id)exceptionWithStream:(id<NGStream>)_stream reason:(NSString *)_reason {
  return [[self alloc] initWithStream:_stream reason:_reason];
}
+ (void)raiseWithStream:(id<NGStream>)_stream {
  [[[self alloc] initWithStream:_stream] raise];
}
+ (void)raiseWithStream:(id<NGStream>)_stream reason:(NSString *)_reason {
  [[[self alloc] initWithStream:_stream reason:_reason] raise];
}
+ (void)raiseWithStream:(id<NGStream>)_stream format:(NSString *)_format,... {
  NSString *tmp = nil;
  va_list  ap;
  
  va_start(ap, _format);
  tmp = [[NSString alloc] initWithFormat:_format arguments:ap];
  va_end(ap);
  tmp = [tmp autorelease];

  [[[self alloc] initWithStream:_stream reason:tmp] raise];
}

- (void)dealloc {
  [self->streamPointer release];
  [super dealloc];
}

@end /* NGStreamException */

// ******************** NGEndOfStreamException ********************

@implementation NGEndOfStreamException

- (id)initWithStream:(id<NGStream>)_stream {
  return [self initWithStream:_stream
               readCount:0
               safeCount:0
               data:nil];
}

- (id)initWithStream:(id<NGStream>)_stream
  readCount:(unsigned)_readCount
  safeCount:(unsigned)_safeCount
  data:(NSData *)_data {

  NSString *tmp;

  tmp = [NSString stringWithFormat:@"reached end of stream %@", _stream];

  if ((self = [super initWithStream:_stream reason:tmp])) {
    self->readCount = _readCount;
    self->safeCount = _safeCount;
    self->data      = [_data retain];
  }
  return self;
}

- (void)dealloc {
  [self->data release];
  [super dealloc];
}

/* accessors */

- (NSData *)readBytes {
  return self->data;
}

@end /* NGEndOfStreamException */

// ******************** open state exceptions *********************

@implementation NGCouldNotOpenStreamException

- (NSString *)defaultReason {
  return @"could not open stream";
}

@end

@implementation NGCouldNotCloseStreamException

- (NSString *)defaultReason {
  return @"could not close stream";
}

@end

@implementation NGStreamNotOpenException

- (NSString *)defaultReason {
  return @"stream is not open";
}

@end

// ******************** NGStreamErrors ****************************

@implementation NGStreamErrorException

- (id)initWithStream:(id<NGStream>)_stream errorCode:(int)_code {
  NSString *tmp = nil;

  tmp = [NSString stringWithFormat:@"stream error occured, errno=%i error=%s",
                    _code, strerror(_code)];
  if ((self = [self initWithStream:_stream reason:tmp])) {
    osErrorCode = _code;
  }
  tmp = nil;
  return self;
}

+ (void)raiseWithStream:(id<NGStream>)_stream errorCode:(int)_code {
  [[[self alloc] initWithStream:_stream errorCode:_code] raise];
}

- (int)operationSystemErrorCode {
  return osErrorCode;
}
- (NSString *)operatingSystemError {
  return [NSString stringWithCString:strerror(osErrorCode)];
}

@end /* NGStreamErrorException */

@implementation NGStreamReadErrorException

- (NSString *)defaultReason {
  return @"read error on stream";
}

@end /* NGStreamReadErrorException */

@implementation NGStreamWriteErrorException

- (NSString *)defaultReason {
  return @"write error on stream";
}

@end /* NGStreamWriteErrorException */

@implementation NGStreamSeekErrorException

- (NSString *)defaultReason {
  return @"seek error on stream";
}

@end

// ******************** NGStreamModeExceptions ********************

@implementation NGStreamModeException

- (NSString *)defaultReason {
  return @"stream mode failure";
}

@end

@implementation NGUnknownStreamModeException

- (NSString *)defaultReason {
  return @"unknow stream mode";
}

- (id)initWithStream:(id<NGStream>)_stream mode:(NSString *)_streamMode {
  if ((self = [super initWithStream:_stream
                     format:@"unknown stream mode: %@", _streamMode])) {
    streamMode = [_streamMode copy];
  }
  return self;
}

- (void)dealloc {
  [self->streamMode release];
  [super dealloc];
}

@end /* NGUnknownStreamModeException */

@implementation NGReadOnlyStreamException

- (NSString *)defaultReason {
  return @"stream is read only";
}

@end /* NGReadOnlyStreamException */

@implementation NGWriteOnlyStreamException

- (NSString *)defaultReason {
  return @"stream is write only";
}

@end /* NGWriteOnlyStreamException */

// ******************** NGIOAccessException ******************

@implementation NGIOAccessException
@end

@implementation NGIOSearchAccessException
@end
