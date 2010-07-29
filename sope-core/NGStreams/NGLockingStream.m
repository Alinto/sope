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

#include <NGStreams/NGLockingStream.h>
#include "common.h"

@implementation NGLockingStream

+ (id)filterWithSource:(id<NGStream>)_source lock:(id<NSObject,NSLocking>)_lock {
  return [[[self alloc] initWithSource:_source lock:_lock] autorelease];
}

- (id)initWithSource:(id<NGStream>)_source lock:(id<NSObject,NSLocking>)_lock {
  if ((self = [super initWithSource:_source])) {
    if (_lock == nil) {
      readLock  = [[NSRecursiveLock allocWithZone:[self zone]] init];
      writeLock = [readLock retain];
    }
    else {
      readLock  = [_lock    retain];
      writeLock = [readLock retain];
    }
  }
  return self;
}

- (id)initWithSource:(id<NGStream>)_source {
  return [self initWithSource:_source lock:nil];
}

- (void)dealloc {
  [self->readLock  release];
  [self->writeLock release];
  [super dealloc];
}

// primitives

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  volatile unsigned result = 0;

  [readLock lock];

  NS_DURING {
    result = (readBytes != NULL)
      ? (unsigned)readBytes(source, _cmd, _buf, _len)
      : [source readBytes:_buf count:_len];
  }
  NS_HANDLER {
    [readLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER;
  [readLock unlock];

  return result;
}

- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  volatile unsigned result = 0;

  [writeLock lock];

  NS_DURING {
    result = (writeBytes != NULL)
      ? (unsigned)writeBytes(source, _cmd, _buf, _len)
      : [source writeBytes:_buf count:_len];
  }
  NS_HANDLER {
    [writeLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER;
  [writeLock unlock];

  return result;
}

- (BOOL)flush {
  BOOL res = NO;
  
  [writeLock lock];

  NS_DURING {
    res = [super flush];
  }
  NS_HANDLER {
    [writeLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER;
  [writeLock unlock];
  return res;
}

- (BOOL)safeReadBytes:(void *)_buf  count:(unsigned)_len {
  BOOL res;
  
  [readLock lock];

  NS_DURING {
    *(&res) = [super safeReadBytes:_buf count:_len];
  }
  NS_HANDLER {
    [readLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER;
  [readLock unlock];

  return res;
}

- (BOOL)safeWriteBytes:(const void *)_buf count:(unsigned)_len {
  BOOL res = NO;
  
  [writeLock lock];

  NS_DURING {
    res = [super safeWriteBytes:_buf count:_len];
  }
  NS_HANDLER {
    [writeLock unlock];
    [localException raise];
  }
  NS_ENDHANDLER;
  [writeLock unlock];
  return res;
}

@end /* NGLockingStream */
