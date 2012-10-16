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

#include "NGByteBuffer.h"
#include "common.h"
#include <sys/time.h>

@implementation NGByteBuffer

static BOOL  ProfileByteBuffer = NO;
static Class DataStreamClass = Nil;

+ (void)initialize {
  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  static BOOL didInit = NO;
  if (didInit) return;
  didInit = YES;
  
  ProfileByteBuffer = [ud boolForKey:@"ProfileByteBufferEnabled"];
  DataStreamClass   = NSClassFromString(@"NGDataStream");
}

+ (int)version {
  return [super version] + 1;
}

+ (id)byteBufferWithSource:(id<NGStream>)_source la:(unsigned)_la {
  if (_source            == nil)            return nil;
  if (*(Class *)_source == DataStreamClass) return _source;
  return [[[self alloc] initWithSource:_source la:_la] autorelease];
}

- (id)initWithSource:(id<NGStream>)_source la:(unsigned)_la {
  if (_source == nil) {
    [self release];
    return nil;
  }
  if (*(Class *)_source == DataStreamClass) {
    [self release];
    return [_source retain];
  }
  if ((self = [super initWithSource:_source])) {
    unsigned size = 0;
    
    if (_la < 1) {
      [NSException raise:NSRangeException
                   format:@"lookahead depth is less than one (%d)", _la];
    }

    // Find first power of 2 >= to requested size
    for (size = 2; size < _la; size *=2);
    
    self->la = malloc(size * sizeof(unsigned char));

    self->bufLen      = size;
    self->sizeLessOne = self->bufLen - 1;
    self->headIdx     = 0;
    self->freeIdx = 0;
    self->EOFIdx = 0;
    self->wasEOF      = NO;
  }
  return self;
}

- (id)init {
  [self release];
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (id)initWithSource:(id<NGStream>)_source {
  [self release];
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (id)initWithInputSource:(id<NGInputStream>)_source {
  [self release];
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (id)initWithOutputSource:(id<NGOutputStream>)_source {
  [self release];
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (void)dealloc {
  if (self->la) free(self->la);
  [super dealloc];
}

/* operations */

- (int)readByte {
  int byte = [self la:0];
  [self consume];
  return byte;
}

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  if (_len == 0)
    return 0;

  if (self->headIdx >= self->freeIdx) {
    int byte = [self readByte];

    if (byte == -1)
      [NGEndOfStreamException raiseWithStream:self->source];

    ((char *)_buf)[0] = byte;
    return 1;
  }
  else {
    unsigned idx, localIdx, cnt, max, localMax;

    idx = self->headIdx;

    cnt = _len;
    max = self->freeIdx - idx;
    if (cnt > max)
      cnt = max;

    localIdx = idx & sizeLessOne;
    localMax = self->bufLen - localIdx;
    if (cnt > localMax)
      cnt = localMax;

    memcpy(_buf, self->la + localIdx, cnt);
    [self consume:cnt];
    return cnt;
  }
  return 0;
}

- (int)la:(unsigned)_la {
  // TODO: huge method, should be split up
  int result;
  unsigned idx, max;
  
  if (_la > self->sizeLessOne) {
    [NSException raise:NSRangeException
                 format:@"tried to look ahead too far (la=%d, max=%d)", 
                  _la, self->bufLen];
  }

  idx = self->headIdx + _la;
  if (self->wasEOF) {
    if (idx < self->freeIdx && idx < self->EOFIdx) {
      result = self->la[idx & self->sizeLessOne];
    }
    else
      result = -1;
    return result;
  }
  
  if (idx < self->freeIdx) {
    result = self->la[idx & self->sizeLessOne];
    return result;
  }

  /* 
     If we should read more than 5 bytes, we take the time costs of an
     exception handler 
  */
  max = idx - self->freeIdx + 1;
  if (max < 6) {
    /* TODO: can be optimized by removing the "&" operation */
    for (; self->freeIdx <= idx; self->freeIdx++) {
#if DEBUG
      struct timeval tv;
      double         ti = 0.0;
#endif
          
      int byte;

#if DEBUG
      if (ProfileByteBuffer) {
        gettimeofday(&tv, NULL);
        ti =  (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0);
      }
#endif
      byte = [self->source readByte];

#if DEBUG
      if (ProfileByteBuffer) {
        gettimeofday(&tv, NULL);
        ti = (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0) - ti;
        if (ti > 0.01) {
          fprintf(stderr, "[%s] <read bytes from stream> : time "
                  "needed: %4.4fs\n",
                  __PRETTY_FUNCTION__, ti < 0.0 ? -1.0 : ti);
        }
      }
#endif
    
      if (byte == -1) {  // EOF was reached
        self->wasEOF = YES;
        self->EOFIdx = self->freeIdx;
        break;
      }
      else {
        self->la[self->freeIdx & self->sizeLessOne] = byte;
      }
    }
  }
  else {
    unsigned localFreeIdx, len;
    int readCnt, totalReadCnt;
    NSException *exc = nil;
    
    localFreeIdx = self->freeIdx & self->sizeLessOne;
    len = self->bufLen - localFreeIdx;
    if (len > max) {
      len = max;
    }

    totalReadCnt = 0;
    while (len > 0) {
      readCnt = [self->source readBytes: (self->la + totalReadCnt
                                          + localFreeIdx)
                                  count: len];
      if (readCnt == NGStreamError) {
        exc = [[self->source lastException] retain];
        break;
      }

      self->freeIdx += readCnt;
      totalReadCnt += readCnt;
      len -= readCnt;
    }

    if (!exc && totalReadCnt < max) {
      len = max - totalReadCnt;
      totalReadCnt = 0;
      while (len > 0) {
        readCnt = [self->source readBytes: self->la + totalReadCnt
                                    count: len];
        if (readCnt == NGStreamError) {
          exc = [[self->source lastException] retain];
          break;
        }
      
        self->freeIdx += readCnt;
        totalReadCnt += readCnt;
        len -= readCnt;
      }
    }

    if (exc) {
      if (![exc isKindOfClass:[NGEndOfStreamException class]]) {
        [self setLastException:exc];
        return NGStreamError;
      }
      self->wasEOF = YES;
      self->EOFIdx = self->freeIdx;
    }
  }

  if (!self->wasEOF || idx < self->EOFIdx)
    result = self->la[idx & self->sizeLessOne];
  else
    result = -1;

  return result;
}

- (void)consume {
  if (self->headIdx == self->freeIdx) {
    [self la:0];
  }
  else if (self->headIdx > self->freeIdx) {
    [NSException raise: NSRangeException
                format: @"a buffer inconsistency was detected"];
  }
  self->headIdx++;
}

- (void)consume:(unsigned)_cnt {
  unsigned nextHead, needed;

  nextHead = self->headIdx + _cnt;
  if (nextHead >= self->freeIdx) {
    needed = nextHead - self->freeIdx + 1;
    [self la: needed];
  }
  self->headIdx = nextHead;
}

/* description */

- (NSString *)description {
  NSMutableString *ms;
  
  ms = [NSMutableString stringWithCapacity:128];

  [ms appendFormat:@"<0x%p[%@]:", self, NSStringFromClass([self class])];
  
  if (self->source) [ms appendFormat:@" source=%@", self->source];
  [ms appendFormat:@" mode=%@", [self modeDescription]];
  [ms appendFormat:@" la=%d", self->bufLen];
  [ms appendString:@">"];
  return ms;
}

@end /* NGByteBuffer */
