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

#include <NGStreams/NGConcreteStreamFileHandle.h>
#include <NGStreams/NGStreamProtocols.h>
#include <NGStreams/NGStreamExceptions.h>
#include <NGStreams/NGBufferedStream.h>
#include "common.h"

@interface NGStream(FileHandleReset)

- (void)resetFileHandle;

@end

@implementation NGConcreteStreamFileHandle

- (id)initWithStream:(id<NGStream>)_stream {
  if ((self = [super init])) {
    self->stream = [_stream retain];
  }
  return self;
}

- (void)dealloc {
  if ([stream respondsToSelector:@selector(resetFileHandle)])
    [(NGStream *)self->stream resetFileHandle];
  [self->stream release];
  [super dealloc];
}

// accessors

- (id<NGStream>)stream {
  return self->stream;
}

/* NSFileHandle operations */

- (void)closeFile {
  [self->stream close];
}

- (int)fileDescriptor {
  if ([self->stream respondsToSelector:@selector(fileDescriptor)])
    return [(id)self->stream fileDescriptor];
  else {
    [self subclassResponsibility:_cmd];
    return -1;
  }
}

/* buffering */

- (void)synchronizeFile {
  [self->stream flush];
}

/* reading */

- (NSData *)readDataOfLength:(unsigned int)_length {
  char   *buffer;
  NSData *data;

  *(&buffer) = NGMallocAtomic(_length);
  *(&data)   = nil;
  
  NS_DURING {
    [stream safeReadBytes:buffer count:_length];
    data = [[NSData alloc] initWithBytes:buffer length:_length];
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
      data = [(NGEndOfStreamException *)localException readBytes];

      data = data ? [data retain] : [[NSData alloc] init];
    }
    else {
      if (buffer) {
        NGFree(buffer);
        buffer = NULL;
      }
      [localException raise];
    }
  }
  NS_ENDHANDLER;
  
  if (buffer) {
    NGFree(buffer);
    buffer = NULL;
  }

  return [data autorelease];
}

- (NSData *)readDataToEndOfFile {
  NGBufferedStream *bs;
  NSMutableData    *data;
  char buf[2048];

  *(&data) = [NSMutableData dataWithCapacity:2048];
  *(&bs) = [self->stream isKindOfClass:[NGBufferedStream class]]
    ? [self->stream retain]
    : [(NGBufferedStream *)[NGBufferedStream alloc] 
          initWithSource:self->stream];

  NS_DURING {
    while (1 == 1) {
      unsigned got = [bs readBytes:buf count:2048];
      [data appendBytes:buf length:got];
    }
  }
  NS_HANDLER {
    if (![localException isKindOfClass:[NGEndOfStreamException class]]) {
      [bs release];
      bs = nil;
      [localException raise];
    }
  }
  NS_ENDHANDLER;
  [bs release]; bs = nil;

  return data;
}

- (NSData *)availableData {
  NSLog(@"NGConcreteStreamFileHandle(availableData) not implemented");
  [self notImplemented:_cmd];
  return nil;
}

/* writing */

- (void)writeData:(NSData *)_data {
  [self->stream safeWriteBytes:[_data bytes] count:[_data length]];
}

/* seeking */

- (unsigned long long)seekToEndOfFile {
  NSLog(@"NGConcreteStreamFileHandle(seekToEndOfFile) not implemented");
  [self notImplemented:_cmd];
  return 0;
}
- (void)seekToFileOffset:(unsigned long long)_offset {
  [(id<NGPositionableStream>)stream moveToLocation:_offset];
}

- (unsigned long long)offsetInFile {
  NSLog(@"_NGConcreteFileStreamFileHandle(offsetInFile:) not implemented, abort");
  [self notImplemented:_cmd];
  return 0;
}

/* asynchronous operations */

- (void)acceptConnectionInBackgroundAndNotify {
  NSLog(@"NGConcreteStreamFileHandle(acceptConnectionInBackgroundAndNotify) "
        @"not implemented");
  [self notImplemented:_cmd];
}
- (void)acceptConnectionInBackgroundAndNotifyForModes:(NSArray *)_modes {
  NSLog(@"NGConcreteStreamFileHandle(acceptConnectionInBackgroundAndNotifyForModes:) "
        @"not implemented");
  [self notImplemented:_cmd];
}

- (void)readInBackgroundAndNotify {
  NSLog(@"NGConcreteStreamFileHandle(readInBackgroundAndNotify) not implemented");
  [self notImplemented:_cmd];
}
- (void)readInBackgroundAndNotifyForModes:(NSArray *)_modes {
  NSLog(@"NGConcreteStreamFileHandle(readInBackgroundAndNotifyForModes:) "
        @"not implemented");
  [self notImplemented:_cmd];
}
- (void)readToEndOfFileInBackgroundAndNotify {
  NSLog(@"NGConcreteStreamFileHandle(readToEndOfFileInBackgroundAndNotify)"
        @"not implemented");
  [self notImplemented:_cmd];
}
- (void)readToEndOfFileInBackgroundAndNotifyForModes:(NSArray *)_modes {
  NSLog(@"NGConcreteStreamFileHandle("
        @"readToEndOfFileInBackgroundAndNotifyForModes:)"
        @"not implemented");
  [self notImplemented:_cmd];
}

- (void)waitForDataInBackgroundAndNotify {
  NSLog(@"NGConcreteStreamFileHandle("
        @"waitForDataInBackgroundAndNotify)"
        @"not implemented");
  [self notImplemented:_cmd];
}
- (void)waitForDataInBackgroundAndNotifyForModes:(NSArray *)_modes {
  NSLog(@"NGConcreteStreamFileHandle("
        @"waitForDataInBackgroundAndNotifyForModes:)"
        @"not implemented");
  [self notImplemented:_cmd];
}

@end /* NGConcreteStreamFileHandle */
