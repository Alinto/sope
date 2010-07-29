/*
  Copyright (C) 2000-2006 SKYRIX Software AG
  Copyright (C) 2006      Helge Hess

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

#include "NGMBoxReader.h"
#include "NGMimeMessageParser.h"
#include "common.h"
#include <string.h>

@implementation NGMBoxReader

+ (int)version {
  return 2;
}

static inline int __readByte(NGMBoxReader *self);
static inline void
__appendByte(NGMBoxReader *self, NSMutableData *_data, IMP _readBytes, int _c);

+ (id)readerForMBox:(NSString *)_path {
  NGFileStream     *fs;
  NGBufferedStream *bs;

  fs = [NGFileStream alloc]; /* to keep gcc 3.4 happy */
  fs = [[fs initWithPath:_path] autorelease];
  bs = [NGBufferedStream filterWithSource:fs];

  [fs openInMode:NGFileReadOnly];

  return [[(NGMBoxReader *)[self alloc] initWithSource:bs] autorelease];
}

+ (id)mboxWithSource:(id<NGByteSequenceStream>)_in {
  return [[(NGMBoxReader *)[self alloc] initWithSource:_in] autorelease];
}

- (id)init {
  return [self initWithSource:nil];
}

- (id)initWithSource:(id<NGByteSequenceStream>)_in {
  if ((self = [super init])) {
    self->source        = [_in retain];
    self->isEndOfStream = NO;
    self->lastDate      = nil;
    self->separator     = @"From -";

    self->readByte =
      [self->source respondsToSelector:@selector(methodForSelector:)]
      ? (int(*)(id, SEL))[(NSObject *)self->source
				      methodForSelector:@selector(readByte)]
      : NULL;
  }
  return self;
}

- (void)dealloc {
  [self->source    release];
  [self->lastDate  release];
  [self->separator release];
  self->readByte = NULL;
  [super dealloc];
}

- (id<NGMimePart>)nextMessage {

  // Macros
#define AppendBytes(_buf, _cnt) \
  appendBytes(msgData, @selector(appendBytes:length:), _buf, _cnt)

#define AppendByte(_c) \
  __appendByte(self, msgData, appendBytes, _c)

  // Method  
  NSMutableData       *msgData    = nil;
  IMP                 appendBytes = NULL;

  const int bufLen = 256;
  int       bufCnt = 0;
  int       c      = 0;
  char      buf[bufLen];  
  
  int        sepLength  = [self->separator length];
  const char *sepStrbuf = NULL;

  sepStrbuf = [self->separator cString];
  
  msgData     = [[NSMutableData allocWithZone:[self zone]]
                                initWithCapacity:4096];
  
  appendBytes = [msgData methodForSelector:@selector(appendBytes:length:)];
  //read from-line

  if (self->isEndOfStream)
    return nil;

  if (self->lastDate == nil) {
    // start of MBox from-line length < 255
    bufCnt = 0;
    while (bufCnt < sepLength) { // parse form
      c = __readByte(self);
      buf[bufCnt++] = c;
    }
    if (strncmp(buf, sepStrbuf, sepLength) != 0) {
      NSLog(@"WARNING: no %@ at begin of MBox %s", self->separator, buf);
    }
    bufCnt = 0;
    while ((c = __readByte(self)) != '\n') { // parse date < 255
      buf[bufCnt++] = c;
      if (bufCnt >= bufLen) {
        NSLog(@"WARNING: too long from-line");
        break;
      }
    }
    if (buf[bufCnt - 1] == '\r')
      self->lastDate = [[NSString allocWithZone:[self zone]] initWithCString:buf
                                                             length:bufCnt-1];
    else
      self->lastDate = [[NSString allocWithZone:[self zone]] initWithCString:buf
                                                             length:bufCnt];
    bufCnt = 0;
  }
  c = -2;
  do {
    if (c != -2) {     
      AppendBytes(buf, bufCnt); // write buffer to data
      bufCnt = 0;
      if (c != '\n') { // no end of line
        AppendByte(c);
        while ((c = __readByte(self)) != '\n') {
          buf[bufCnt++] = c;
          if (bufCnt >= bufLen) {
            AppendBytes(buf, bufCnt);
            bufCnt = 0;
          }
        }
        if (bufCnt > 0) {
          AppendBytes(buf, bufCnt);
          bufCnt = 0;
        }
        AppendByte(c);
      }
      else
        AppendByte(c);
    }
    
    while ((c = __readByte(self)) != '\n' &&
           bufCnt < sepLength) {        // read oly until seperator length    
      if (c == -1)
        break;
      buf[bufCnt++] = c;
    }
    if (c == -1)
      break;
  } while (strncmp(buf, sepStrbuf, sepLength) != 0);
    
  if (c == -1) {
    self->isEndOfStream = YES;
  } 
  else { // read from-line
    bufCnt = 0;
    while ((c = __readByte(self)) != '\n') { // from-line is not longer
                                     // than 255 ( I hope it :))
      buf[bufCnt++] = c;
      if (bufCnt >= bufLen) {
        NSLog(@"WARNING: too long from-line");
        break;
      }
    }
    [self->lastDate release];
    self->lastDate = [[NSString alloc] initWithCString:buf length:bufCnt];
    bufCnt = 0;
  }

  if ([msgData length] == 0) // end, no msg data
    return nil;
      
  {  // build result
    NGMimeMessageParser *parser = nil;
    NGDataStream        *stream = nil;
    id<NGMimePart> part;

    *(&part) = nil;
    
    parser = [[NGMimeMessageParser alloc] init];
    stream = [[NGDataStream alloc] initWithData:msgData];

    NS_DURING
      part = [parser parsePartFromStream:stream];
    NS_HANDLER {}
    NS_ENDHANDLER;

    if (part == nil) {
      fprintf(stderr, "mbox: failed to parse message:\n%s",
              [[NSString stringWithCString:[msgData bytes]
                         length:[msgData length]] cString]);
    }

    [parser  release]; parser  = nil;
    [stream  release]; stream  = nil;    
    [msgData release]; msgData = nil;
    
    return part;
  }
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p] source=%@ endOfStream=%@",
                     NSStringFromClass([self class]), self,
                     self->source, self->isEndOfStream ? @"YES" : @"NO"];
}


/* functions */

static inline int __readByte(NGMBoxReader *self) {
  return (self->readByte)
    ? self->readByte(self->source, @selector(readByte))
    : [self->source readByte];
}

static inline void __appendByte(NGMBoxReader *self, NSMutableData *_data,
                                IMP _readBytes, int _c) {
  unsigned char c = _c;
  _readBytes(_data, @selector(appendBytes:length:), &c, 1);
}

@end /* NGMBoxReader */
