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

typedef struct NGByteBufferLA {
  unsigned char byte;
  char          isEOF:1;
  char          isFetched:1;
} LA_NGByteBuffer;

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
    
    self->la = malloc(sizeof(LA_NGByteBuffer) * size + 4);
    memset(self->la, 0, sizeof(LA_NGByteBuffer) * size);

    self->bufLen      = size;
    self->sizeLessOne = self->bufLen - 1;
    self->headIdx     = 0;
    self->wasEOF      = NO;
    if ([self->source respondsToSelector:@selector(methodForSelector:)]) {
      self->readByte = (int(*)(id, SEL))
        [(NSObject *)self->source methodForSelector:@selector(readByte)];
    }
    if ([self respondsToSelector:@selector(methodForSelector:)]) {
      self->laFunction = (int(*)(id, SEL, unsigned))
        [(NSObject *)self methodForSelector:@selector(la:)];
    }
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
  int byte = (self->laFunction == NULL)
    ? [self la:0]
    : self->laFunction(self, @selector(la:), 0);
  [self consume];
  return byte;
}

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  if (_len == 0)
    return 0;

  if (!(self->la[(self->headIdx & self->sizeLessOne)].isFetched)) {
    int byte = [self readByte];

    if (byte == -1)
      [NGEndOfStreamException raiseWithStream:self->source];

    ((char *)_buf)[0] = byte;
    return 1;
  }
  else {
    unsigned      cnt    = 0;
    int           idxCnt = self->headIdx & sizeLessOne;
    unsigned char buffer[self->bufLen];
    
    while (self->la[idxCnt].isFetched && cnt < _len && cnt < bufLen) {
      buffer[cnt] = self->la[idxCnt].byte;
      cnt++;
      idxCnt = (cnt + self->headIdx) & sizeLessOne;
    }
    memcpy(_buf, buffer, cnt);
    [self consume:cnt];
    return cnt;
  }
  return 0;
}

- (int)la:(unsigned)_la {
  // TODO: huge method, should be split up
  volatile unsigned result, idx;
  unsigned i = 0;
  
  result = -1;
  *(&idx) = (_la + self->headIdx) & self->sizeLessOne;
  
  if (_la > self->sizeLessOne) {
    [NSException raise:NSRangeException
                 format:@"tried to look ahead too far (la=%d, max=%d)", 
                  _la, self->bufLen];
  }
  
  if (self->wasEOF) {
    result = (!self->la[idx].isFetched || self->la[idx].isEOF)
      ? -1 : self->la[idx].byte;
    return result;
  }
  
  if (self->la[idx].isFetched) {
    result = (self->la[idx].isEOF) ? -1 : self->la[idx].byte;
    return result;
  }

  *(&i) = 0;
  for (i = 0;
       i < _la &&
         self->la[(self->headIdx + i) & self->sizeLessOne].isFetched;
       i++);
  
  /* 
     If we should read more than 5 bytes, we take the time costs of an
     exception handler 
  */
  if ((_la - i + 1) <= 5) {
    while (i <= _la) {
#if DEBUG
      struct timeval tv;
      double         ti = 0.0;
#endif
          
      int byte = 0;

#if DEBUG
      if (ProfileByteBuffer) {
        gettimeofday(&tv, NULL);
        ti =  (double)tv.tv_sec + ((double)tv.tv_usec / 1000000.0);
      }
#endif
      byte = (self->readByte == NULL)
        ? [self->source readByte]
        : (int)self->readByte(self->source, @selector(readByte));

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
        break;
      }
      else {
        int ix = (self->headIdx + i) & self->sizeLessOne;
        self->la[ix].byte      = byte;
        self->la[ix].isFetched = 1;
      }
      i++;
    }
  }
  else {
    BOOL readStream = YES;
    NSException *exc = nil;
    
    while (readStream) {
      int  cntReadBytes  = 0;
      int  cnt           = 0;
      int  desiredBytes  = _la - i+1;
      char *tmpBuffer;

      // TODO: check whether malloc is used for sufficiently large blocks!
      tmpBuffer = malloc(desiredBytes + 2);

      cntReadBytes = (self->readBytes == NULL)
        ? [self->source readBytes:tmpBuffer count:desiredBytes]
        : self->readBytes(self->source, @selector(readBytes:count:),
                          tmpBuffer, desiredBytes);
          
      if (cntReadBytes == NGStreamError) {
        exc = [[self->source lastException] retain];
        break;
      }
      else {
        if (cntReadBytes == desiredBytes)
          readStream = NO;

        cnt = 0;
        while (cntReadBytes > 0) {
          int ix = (self->headIdx + i) & self->sizeLessOne;
          self->la[ix].byte      = tmpBuffer[cnt];
          self->la[ix].isFetched = 1;
          i++;
          cnt++;
          cntReadBytes--;
        }
      }
          
      if (tmpBuffer) free(tmpBuffer);
    }
    if (exc) {
      if (![exc isKindOfClass:[NGEndOfStreamException class]]) {
        [self setLastException:exc];
        return NGStreamError;
      }
      self->wasEOF = YES;
    }
  }
  
  if (self->wasEOF) {
    while (i <= _la) {
      self->la[(self->headIdx + i) & self->sizeLessOne].isEOF = YES;
      i++;
    }
  }
  
  result = (self->la[idx].isEOF) ? -1 : self->la[idx].byte;
  return result;
}

- (void)consume {
  int idx = self->headIdx & sizeLessOne;
  
  if (!(self->la[idx].isFetched)) {
    (self->laFunction == NULL)
      ? [self la:0]
      : self->laFunction(self, @selector(la:), 0);
  }
  self->la[idx].isFetched = 0;
  self->headIdx++;
}

- (void)consume:(unsigned)_cnt {
  while (_cnt > 0) {
    int idx = self->headIdx & sizeLessOne;
    
    if (!(self->la[idx].isFetched))
      (self->laFunction == NULL)
        ? [self la:0]
        : self->laFunction(self, @selector(la:), 0);

    self->la[idx].isFetched = 0;
    self->headIdx++;
    _cnt--;
  }
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
