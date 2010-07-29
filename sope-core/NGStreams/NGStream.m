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

#include <NGStreams/NGStreamExceptions.h>
#include <NGStreams/NGStream.h>
#include <NGStreams/NGFilterStream.h>
#include "common.h"

@implementation NGStream

/* primitives */

- (void)setLastException:(NSException *)_exception {
  [_exception raise];
}
- (NSException *)lastException {
  return nil;
}

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  [self subclassResponsibility:_cmd];
  return 0;
}
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  [self subclassResponsibility:_cmd];
  return 0;
}

- (BOOL)flush {
  return YES;
}
- (BOOL)close {
  return YES;
}

- (NGStreamMode)mode {
  [self subclassResponsibility:_cmd];
  return 0;
}
- (BOOL)isRootStream {
  [self subclassResponsibility:_cmd];
  return NO;
}

// methods method which write exactly _len bytes

- (BOOL)safeReadBytes:(void *)_buf count:(unsigned)_len {
  return NGSafeReadBytesFromStream(self, _buf, _len);
}

- (BOOL)safeWriteBytes:(const void *)_buf count:(unsigned)_len {
  return NGSafeWriteBytesToStream(self, _buf, _len);
}

/* marking */

- (BOOL)mark {
  NSLog(@"WARNING: called mark on a stream which doesn't support marking !");
  return NO;
}
- (BOOL)rewind {
  [NGStreamException raiseWithStream:self reason:@"marking not supported"];
  return NO;
}
- (BOOL)markSupported {
  return NO;
}

/* convenience methods */

- (int)readByte {
  return NGReadByteFromStream(self);
}

/* description */

- (NSString *)modeDescription {
  NSString *result = @"unknown";
  
  switch ([self mode]) {
    case NGStreamMode_undefined: result = @"undefined"; break;
    case NGStreamMode_readOnly:  result = @"r";         break;
    case NGStreamMode_writeOnly: result = @"w";         break;
    case NGStreamMode_readWrite: result = @"rw";        break;
    default:
      [NGUnknownStreamModeException raiseWithStream:self];
      break;
  }
  return result;
}

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p] mode=%@>",
                     NSStringFromClass([self class]), self,
                     [self modeDescription]];
}

@end /* NGStream */

@implementation NGStream(DataMethods)

- (NSData *)readDataOfLength:(unsigned int)_length {
  unsigned readCount;
  char buf[_length];
  
  if (_length == 0) return [NSData data];
  
  readCount = [self readBytes:buf count:_length];
  if (readCount == NGStreamError)
    return nil;
  
  return [NSData dataWithBytes:buf length:readCount];
}

- (NSData *)safeReadDataOfLength:(unsigned int)_length {
  char buf[_length];
  
  if (_length == 0) return [NSData data];
  if (![self safeReadBytes:buf count:_length])
    return nil;
  return [NSData dataWithBytes:buf length:_length];
}

- (unsigned int)writeData:(NSData *)_data {
  return [self writeBytes:[_data bytes] count:[_data length]];
}
- (BOOL)safeWriteData:(NSData *)_data {
  return [self safeWriteBytes:[_data bytes] count:[_data length]];
}

@end /* NGStream(DataMethods) */

// concrete implementations as functions

int NGReadByteFromStream(id<NGInputStream> _stream) {
  volatile int  result = -1;
  unsigned char c;

  NS_DURING {
    int l;
    l = [_stream readBytes:&c count:sizeof(unsigned char)];
    if (l == NGStreamError) {
      NSException *e = [(id)_stream lastException];
      if ([e isKindOfClass:[NGEndOfStreamException class]])
        *(&result) = -1;
      else
        [e raise];
    }
    else
      *(&result) = c;
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGEndOfStreamException class]])
      *(&result) = -1;
    else
      [localException raise];
  }
  NS_ENDHANDLER;
  
  return result;
}

BOOL NGSafeReadBytesFromStream(id<NGInputStream> _in, void *_buf, unsigned _len){
  volatile int toBeRead;
  volatile int readResult;
  volatile NGIOReadMethodType readBytes;

  *(&toBeRead) = _len;
  readBytes = (NGIOReadMethodType)
    [(NSObject *)_in methodForSelector:@selector(readBytes:count:)];

  NS_DURING {
    void *pos = _buf;
    
    while (YES) {
      *(&readResult) = (unsigned)readBytes(_in, @selector(readBytes:count:),
                                           pos, toBeRead);

      if (readResult == NGStreamError) {
	/* TODO: improve exception handling ... */
        [[(id)_in lastException] raise];
      }
      else if (readResult == toBeRead) {
        // all bytes were read successfully, return
        break;
      }
      
      if (readResult < 1) {
        [NSException raise:NSInternalInconsistencyException
                     format:@"readBytes:count: returned a value < 1"];
      }

      toBeRead -= readResult;
      pos += readResult;
    }
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
      [[[NGEndOfStreamException alloc]
                                initWithStream:(id)_in
                                readCount:(_len - toBeRead)
                                safeCount:_len
                                data:[NSData dataWithBytes:_buf
                                             length:(_len - toBeRead)]]
                                raise];
    }
    else {
      [localException raise];
    }
  }
  NS_ENDHANDLER;
  return YES;
}

BOOL NGSafeWriteBytesToStream(id<NGOutputStream> _o,const void *_b,unsigned _l) {
  int  toBeWritten = _l;
  int  writeResult;
  void *pos = (void *)_b;
  NGIOWriteMethodType writeBytes;
  
  writeBytes = (NGIOWriteMethodType)
    [(NSObject *)_o methodForSelector:@selector(writeBytes:count:)];
  
  while (YES) {
    writeResult =
      (int)writeBytes(_o, @selector(writeBytes:count:), pos, toBeWritten);
    
    if (writeResult == NGStreamError) {
      /* remember number of written bytes ??? */
      return NO;
    }
    else if (writeResult == toBeWritten) {
      // all bytes were written successfully, return
      break;
    }
    
    if (writeResult < 1) {
      [NSException raise:NSInternalInconsistencyException
                   format:@"writeBytes:count: returned a value<1 in %@", _o];
    }

    toBeWritten -= writeResult;
    pos += writeResult;
  }
  return YES;
}
