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
    
    self->laImpl = (int (*)(id, SEL, unsigned))
      [self methodForSelector: @selector (la:)];
    self->sourceReadByte = (int(*)(id, SEL))
      [_source methodForSelector: @selector (readByte)];
    self->sourceReadBytes = (int (*)(id, SEL, void *, unsigned))
      [_source methodForSelector: @selector (readBytes:count:)];

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

/* this function reads bytes from self->la *without* increasing self->headIdx */
static size_t readAllFromBuffer(NGByteBuffer *self,
                                unsigned char *dest, size_t len) {
  size_t required, lastBytesCount;
  unsigned localHeadIdx, localNextHeadIdx;

  required = self->freeIdx - self->headIdx;
  if (required > 0) {
    if (required > len) {
      required = len;
    }

    localHeadIdx = self->headIdx & self->sizeLessOne;
    localNextHeadIdx = (self->headIdx + required) & self->sizeLessOne;
    if (localHeadIdx < localNextHeadIdx) {
      memcpy(dest, self->la + localHeadIdx, required);
    }
    else {
      lastBytesCount = self->bufLen - localHeadIdx;
      memcpy(dest, self->la + localHeadIdx, lastBytesCount);
      memcpy(dest + lastBytesCount, self->la, required - lastBytesCount);
    }
  }

  return required;
}

/* this function reads *all* bytes from source, unless an exception was
   returned. In all case it does *not* increase self->headIdx nor
   self->freeIdx. */
static size_t readAllFromSource(NGByteBuffer *self,
                                unsigned char *dest, size_t len) {
  register size_t totalReadCnt = 0;
  register int readCnt;

  while (totalReadCnt < len) {
    readCnt = self->sourceReadBytes(self->source,
                                    @selector (readBytes:count:),
                                    dest + totalReadCnt,
                                    len - totalReadCnt);
    if (readCnt == NGStreamError) {
      NSException *exc = [self->source lastException];
      if ([exc isKindOfClass:[NGEndOfStreamException class]]) {
        self->wasEOF = YES;
      }
      else {
        [exc raise];
      }
      break;
    }
    else {
      totalReadCnt += readCnt;
    }
  }

  return totalReadCnt;
}

- (int)readByte {
  int byte = self->laImpl(self, @selector (la:), 0);
  [self consume];
  return byte;
}

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  size_t totalReadCnt, readCnt;

  if (self->wasEOF && self->headIdx == self->EOFIdx)
    [NGEndOfStreamException raiseWithStream:self->source];

  if (_len == 1111097) {
    printf ("coucou\n");
  }

  totalReadCnt = readAllFromBuffer(self, _buf, _len);
  self->headIdx += totalReadCnt;
  if (totalReadCnt < _len) {
    readCnt = readAllFromSource(self,
                                _buf + totalReadCnt, _len - totalReadCnt);
    totalReadCnt += readCnt;
    /* if we are here, it means that readAllFromBuffer gave headIdx the same
       value as freeIdx */
    self->headIdx += readCnt;
    self->freeIdx = self->headIdx;
    if (self->wasEOF) {
      self->EOFIdx = self->headIdx;
    }
  }

  return totalReadCnt;

}

- (int)la:(unsigned)_la {
  // TODO: huge method, should be split up
  int result;
  register unsigned idx;
  
  if (_la > self->sizeLessOne) {
    [NSException raise:NSRangeException
                 format:@"tried to look ahead too far (la=%d, max=%d)", 
                  _la, self->bufLen];
  }

  idx = self->headIdx + _la;
  if (idx < self->freeIdx) {
    result = self->la[idx & self->sizeLessOne];
  }
  else if (self->wasEOF) {
    result = -1;
  }
  else {
    unsigned max, localFreeIdx;
    register unsigned len, readCnt;

#if DEBUG
    struct timeval tv;
    double         ti = 0.0;
#endif
          
#if DEBUG
    if (ProfileByteBuffer) {
      gettimeofday(&tv, NULL);
      ti =  (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0);
    }
#endif

    max = idx - self->freeIdx + 1;

    localFreeIdx = self->freeIdx & self->sizeLessOne;
    len = self->bufLen - localFreeIdx;
    if (len > max) {
      len = max;
    }

    /* fill last bytes of buffer, from the position pointed at by freeIdx */
    readCnt = readAllFromSource(self, self->la + localFreeIdx, len);
    self->freeIdx += readCnt;
    if (self->wasEOF) {
      self->EOFIdx = self->freeIdx;
    }
    else if (readCnt < max) {
      /* if needed fill first bytes of buffer */
      len = max - readCnt;
      readCnt = readAllFromSource(self, self->la, len);
      self->freeIdx += readCnt;
      if (self->wasEOF) {
        self->EOFIdx = self->freeIdx;
      }
    }

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

    if (idx < self->freeIdx) {
      result = self->la[idx & self->sizeLessOne];
    }
    else {
      result = -1;
    }
  }

  return result;
}

- (void)consume {
  if (self->headIdx == self->freeIdx) {
    self->laImpl(self, @selector (la:), 0);
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
    self->laImpl(self, @selector (la:), needed);
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
