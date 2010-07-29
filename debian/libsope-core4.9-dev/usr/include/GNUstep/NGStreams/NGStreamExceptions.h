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

#ifndef __NGStreams_NGStreamExceptions_H__
#define __NGStreams_NGStreamExceptions_H__

#import <Foundation/NSException.h>
#include <NGStreams/NGStream.h>

@class NSData;

@interface NGIOException : NSException

- (id)init;
- (id)initWithReason:(NSString *)_reason;
+ (void)raiseWithReason:(NSString *)_reason;
+ (void)raiseOnStream:(id)_stream reason:(NSString *)_reason;
+ (void)raiseOnStream:(id)_stream;

@end

static inline BOOL NGIsIOException(NSException *_exception) {
  return [_exception isKindOfClass:[NGIOException class]];
}

// ******************** NGStreamException *************************

@class NSValue;

@interface NGStreamException : NGIOException
{
@protected
  NSValue *streamPointer; /* only valid if stream is not deallocated */
}

- (id)init;
- (id)initWithStream:(id<NGStream>)_stream;
- (id)initWithStream:(id<NGStream>)_stream reason:(NSString *)_reason;
- (id)initWithStream:(id<NGStream>)_stream format:(NSString *)_format,...;
+ (id)exceptionWithStream:(id<NGStream>)_stream;
+ (id)exceptionWithStream:(id<NGStream>)_stream reason:(NSString *)_reason;
+ (void)raiseWithStream:(id<NGStream>)_stream;
+ (void)raiseWithStream:(id<NGStream>)_stream format:(NSString *)_format,...;
+ (void)raiseWithStream:(id<NGStream>)_stream reason:(NSString *)_reason;

@end

static inline BOOL NGIsStreamException(NSException *_exception) {
  return [_exception isKindOfClass:[NGStreamException class]];
}

// ******************** NGEndOfStreamException ********************

@interface NGEndOfStreamException : NGStreamException
{
@protected
  unsigned readCount; // number of bytes that could be read in
  unsigned safeCount; // number of bytes that were requested
  NSData   *data;
}

- (id)initWithStream:(id<NGStream>)_stream;

- (id)initWithStream:(id<NGStream>)_stream
  readCount:(unsigned)_readCount
  safeCount:(unsigned)_safeCount
  data:(NSData *)_data;

- (NSData *)readBytes; // the bytes read before EOF

@end

static inline BOOL NGIsEndOfStreamException(NSException *_exception) {
  return [_exception isKindOfClass:[NGEndOfStreamException class]];
}

// ******************** open state exceptions *********************

@interface NGCouldNotOpenStreamException : NGStreamException
@end

@interface NGCouldNotCloseStreamException : NGStreamException
@end

@interface NGStreamNotOpenException : NGStreamException
@end

static inline BOOL NGIsCouldNotOpenStreamException(NSException *_exception) {
  return [_exception isKindOfClass:[NGCouldNotOpenStreamException class]];
}
static inline BOOL NGIsCouldNotCloseStreamException(NSException *_exception) {
  return [_exception isKindOfClass:[NGCouldNotCloseStreamException class]];
}
static inline BOOL NGIsStreamNotOpenException(NSException *_exception) {
  return [_exception isKindOfClass:[NGStreamNotOpenException class]];
}

// ******************** NGStreamErrors ****************************

@interface NGStreamErrorException : NGStreamException
{
@protected
  int osErrorCode;
}

- (id)initWithStream:(id<NGStream>)_stream errorCode:(int)_code;
+ (void)raiseWithStream:(id<NGStream>)_stream errorCode:(int)_code;

- (int)operationSystemErrorCode;
- (NSString *)operatingSystemError;

@end

static inline BOOL NGIsStreamErrorException(NSException *_exception) {
  return [_exception isKindOfClass:[NGStreamErrorException class]];
}

@interface NGStreamReadErrorException : NGStreamErrorException
@end

@interface NGStreamWriteErrorException : NGStreamErrorException
@end

@interface NGStreamSeekErrorException : NGStreamErrorException
@end

static inline BOOL NGIsStreamReadErrorException(NSException *_exception) {
  return [_exception isKindOfClass:[NGStreamReadErrorException class]];
}
static inline BOOL NGIsStreamWriteErrorException(NSException *_exception) {
  return [_exception isKindOfClass:[NGStreamWriteErrorException class]];
}
static inline BOOL NGIsStreamSeekErrorException(NSException *_exception) {
  return [_exception isKindOfClass:[NGStreamSeekErrorException class]];
}

// ******************** NGStreamModeExceptions ********************

@interface NGStreamModeException : NGStreamException
@end

@interface NGUnknownStreamModeException : NGStreamModeException
{
@protected
  NSString *streamMode;
}

- (id)initWithStream:(id<NGStream>)_stream mode:(NSString *)_streamMode;

@end

@interface NGReadOnlyStreamException : NGStreamModeException
@end

@interface NGWriteOnlyStreamException : NGStreamModeException
@end

static inline BOOL NGIsStreamModeException(NSException *_exception) {
  return [_exception isKindOfClass:[NGStreamModeException class]];
}
static inline BOOL NGIsUnknownStreamModeException(NSException *_exception) {
  return [_exception isKindOfClass:[NGUnknownStreamModeException class]];
}
static inline BOOL NGIsReadOnlyStreamException(NSException *_exception) {
  return [_exception isKindOfClass:[NGReadOnlyStreamException class]];
}
static inline BOOL NGIsWriteOnlyStreamException(NSException *_exception) {
  return [_exception isKindOfClass:[NGWriteOnlyStreamException class]];
}

// ******************** NGIOAccessException ***********************

@interface NGIOAccessException : NGIOException
@end

@interface NGIOSearchAccessException : NGIOAccessException
@end

#endif /* __NGStreams_NGStreamExceptions_H__ */
