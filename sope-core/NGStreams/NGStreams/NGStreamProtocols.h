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

#ifndef __NGStreams_NGStreamProtocols_H__
#define __NGStreams_NGStreamProtocols_H__

#import <Foundation/NSObject.h>

#if !(MAC_OS_X_VERSION_10_2 <= MAC_OS_X_VERSION_MAX_ALLOWED)
#  define USE_SERIALIZER 1
#  import <Foundation/NSSerialization.h>
#endif

@class NSException;

typedef enum {
  NGStreamMode_undefined = 0,
  NGStreamMode_readOnly  = 1,
  NGStreamMode_writeOnly = 2,
  NGStreamMode_readWrite = 4
} NGStreamMode;

/* if this value is returned by -read, -lastException is set ... */
enum {NGStreamError = 0x7fffffff};

typedef unsigned (*NGIOReadMethodType )(id, SEL, void *, unsigned);
typedef unsigned (*NGIOWriteMethodType)(id, SEL, const void *, unsigned);
typedef BOOL (*NGIOSafeReadMethodType )(id, SEL, void *, unsigned);
typedef BOOL (*NGIOSafeWriteMethodType)(id, SEL, const void *, unsigned);

@protocol NGInputStream < NSObject >

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len;
- (BOOL)safeReadBytes:(void *)_buf count:(unsigned)_len;
- (BOOL)close;

// marks

- (BOOL)mark;
- (BOOL)rewind;
- (BOOL)markSupported;

@end

@protocol NGOutputStream < NSObject >

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len;
- (BOOL)safeWriteBytes:(const void *)_buf count:(unsigned)_len;

- (BOOL)flush;
- (BOOL)close;

@end

@protocol NGPositionableStream < NSObject >

- (BOOL)moveToLocation:(unsigned)_location;
- (BOOL)moveByOffset:(int)_delta;

@end

@protocol NGStream < NGInputStream, NGOutputStream >

- (BOOL)close;
- (NGStreamMode)mode;
- (NSException *)lastException;

@end

@protocol NGByteSequenceStream < NGInputStream >

- (int)readByte; // Java semantics (-1 on EOF)
  
@end

typedef int (*NGSequenceReadByteMethod)(id<NGByteSequenceStream> self, SEL _cmd);

// push streams

@class NSData;

@protocol NGPushStream < NSObject >

- (void)pushChar:(char)_c;
- (void)pushCString:(const char *)_cstr;
- (void)pushData:(NSData *)_block;
- (void)pushBytes:(const void *)_buffer count:(unsigned)_len;
- (void)abort;

@end

// serializer

@protocol NGSerializer < NSObject >

- (void)serializeChar:(char)_value;
- (void)serializeShort:(short)_value;
- (void)serializeInt:(int)_value;
- (void)serializeLong:(long)_value;
- (void)serializeFloat:(float)_value;
- (void)serializeDouble:(double)_value;
- (void)serializeLongLong:(long long)_value;

- (char)deserializeChar;
- (short)deserializeShort;
- (int)deserializeInt;
- (long)deserializeLong;
- (float)deserializeFloat;
- (double)deserializeDouble;
- (long long)deserializeLongLong;

- (void)serializeCString:(const char *)_value;
- (char *)deserializeCString;

#if USE_SERIALIZER
- (void)serializeDataAt:(const void*)data ofObjCType:(const char*)type
  context:(id<NSObjCTypeSerializationCallBack>)_callback;
- (void)deserializeDataAt:(const void*)data ofObjCType:(const char*)type
  context:(id<NSObjCTypeSerializationCallBack>)_callback;
#endif

@end

#endif /* __NGStreams_NGStreamProtocols_H__ */
