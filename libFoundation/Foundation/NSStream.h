/* 
   NSStream.h

   Copyright (C) 2003 SKYRIX Software AG, Helge Hess.
   All rights reserved.
   
   Author: Helge Hess <helge.hess@opengroupware.org>
   
   This file is part of libFoundation.
   
   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.
   
   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

#ifndef __NSStream_H__
#define __NSStream_H__

#include <Foundation/NSObject.h>
#include <Foundation/NSArray.h>

@class NSString, NSData, NSHost, NSError, NSRunLoop;
@class NSStream, NSInputStream, NSOutputStream;

typedef enum {
    NSStreamStatusNotOpen = 0,
    NSStreamStatusOpening = 1,
    NSStreamStatusOpen    = 2,
    NSStreamStatusReading = 3,
    NSStreamStatusWriting = 4,
    NSStreamStatusAtEnd   = 5,
    NSStreamStatusClosed  = 6,
    NSStreamStatusError   = 7
} NSStreamStatus;

typedef enum {
   NSStreamEventEndEncountered    = 1 << 4,
   NSStreamEventErrorOccurred     = 1 << 3,
   NSStreamEventHasBytesAvailable = 1 << 1,
   NSStreamEventHasSpaceAvailable = 1 << 2,
   NSStreamEventNone              = 0,
   NSStreamEventOpenCompleted     = 1 << 0,
} NSStreamEvent;


@interface NSStream : NSObject
{
}

+ (void)getStreamsToHost:(NSHost *)_host port:(int)_port 
  inputStream:(NSInputStream **)_in
  outputStream:(NSOutputStream **)_out;

/* accessors */

- (void)setDelegate:(id)_delegate;
- (id)delegate;

- (NSError *)streamError;
- (NSStreamStatus)streamStatus;

/* properties */

- (BOOL)setProperty:(id)_value forKey:(NSString *)_key;
- (id)propertyForKey:(NSString *)_key;

/* operations */

- (void)open;
- (void)close;

/* runloop */

- (void)scheduleInRunLoop:(NSRunLoop *)_runloop forMode:(NSString *)_mode;
- (void)removeFromRunLoop:(NSRunLoop *)_runloop forMode:(NSString *)_mode;

@end


@interface NSInputStream : NSStream
{
}

+ (id)inputStreamWithData:(NSData *)_data;
+ (id)inputStreamWithFileAtPath:(NSString *)_path;

- (id)initWithData:(NSData *)_data;
- (id)initWithFileAtPath:(NSString *)_path;

/* operations */

- (int)read:(void *)_buf maxLength:(unsigned int)_len;
- (BOOL)getBuffer:(void **)_buf length:(unsigned int *)_len;
- (BOOL)hasBytesAvailable;

@end


@interface NSOutputStream : NSStream
{
}

+ (id)outputStreamToMemory;
+ (id)outputStreamToBuffer:(void *)_buf capacity:(unsigned int)_capacity;
+ (id)outputStreamToFileAtPath:(NSStream *)_path append:(BOOL)_append;

- (id)initToMemory;
- (id)initToBuffer:(void *)_buf capacity:(unsigned int)_capacity;
- (id)initToFileAtPath:(NSStream *)_path append:(BOOL)_append;

/* operations */

- (BOOL)hasSpaceAvailable;
- (int)write:(const void *)buffer maxLength:(unsigned int)len;

@end

/* delegate */

@interface NSObject(NSStreamDelegate)

- (void)stream:(NSStream *)_stream handleEvent:(NSStreamEvent)_event;

@end

#endif /* __NSStream_H__ */

/*
  Local Variables:
  c-basic-offset: 4
  tab-width: 8
  End:
*/
