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

#include <NGStreams/NGFilterStream.h>
#include "common.h"

@implementation NGFilterStream

+ (id)filterWithInputSource:(id<NGInputStream>)_s {
  return [[(NGFilterStream *)[self alloc] initWithInputSource:_s] autorelease];
}
+ (id)filterWithOutputSource:(id<NGOutputStream>)_s {
  return [[(NGFilterStream *)[self alloc] initWithOutputSource:_s] autorelease];
}
+ (id)filterWithSource:(id<NGStream>)_s {
  return [[(NGFilterStream *)[self alloc] initWithSource:_s] autorelease];
}

- (id)init {
  return [self initWithSource:nil];
}

- (id)initWithSource:(id<NGStream>)_source {
  if ((self = [super init])) {
    self->source = [_source retain];

    if ([source isKindOfClass:[NSObject class]]) {
      self->readBytes  = (NGIOReadMethodType)
        [(NSObject *)self->source methodForSelector:@selector(readBytes:count:)];
      self->writeBytes = (NGIOWriteMethodType)
        [(NSObject *)self->source methodForSelector:@selector(writeBytes:count:)];
    }
  }
  return self;
}

- (id)initWithInputSource:(id<NGInputStream>)_source {
  if ((self = [super init])) {
    self->source = [_source retain];

    if ([source isKindOfClass:[NSObject class]]) {
      self->readBytes  = (NGIOReadMethodType)
        [(NSObject *)self->source methodForSelector:@selector(readBytes:count:)];
    }
  }
  return self;
}
- (id)initWithOutputSource:(id<NGOutputStream>)_source {
  if ((self = [super init])) {
    self->source = [_source retain];

    if ([source isKindOfClass:[NSObject class]]) {
      self->writeBytes  = (NGIOWriteMethodType)
        [(NSObject *)self->source methodForSelector:@selector(writeBytes:count:)];
    }
  }
  return self;
}

- (void)dealloc {
  [self->source release];
  self->readBytes  = NULL;
  self->writeBytes = NULL;
  [super dealloc];
}

/* accessors */

- (id<NGInputStream>)inputStream {
  return [self source];
}
- (id<NGOutputStream>)outputStream {
  return [self source];
}
- (id<NGStream>)source {
  return self->source;
}

/* primitives */

- (NSException *)lastException {
  return [self->source lastException];
}
- (void)resetLastException {
  [self->source resetLastException];
}
- (void)setLastException:(NSException *)_exception {
  [self->source setLastException:_exception];
}

- (BOOL)isOpen {
  return [self->source isOpen];
}

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  if (self->readBytes)
    return (unsigned)readBytes(self->source, _cmd, _buf, _len);
  else
    return [self->source readBytes:_buf count:_len];
}
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  if (self->writeBytes)
    return (unsigned)writeBytes(self->source, _cmd, _buf, _len);
  else
    return [self->source writeBytes:_buf count:_len];
}

- (BOOL)flush {
  return [self->source flush];
}
- (BOOL)close {
  return [((NGStream *)self->source) close];
}

- (NGStreamMode)mode {
  return [(NGStream *)self->source mode];
}
- (BOOL)isRootStream {
  return NO;
}

// all other things are forward

- (void)forwardInvocation:(NSInvocation *)_invocation {
  if ([self->source respondsToSelector:[_invocation selector]]) {
    [_invocation setTarget:self->source];
    [_invocation invoke];
  }
  else
    [self doesNotRecognizeSelector:[_invocation selector]];
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p] source=%@ mode=%@>",
                     NSStringFromClass([self class]), self,
                     self->source ? (id)self->source : (id)@"nil",
                     [self modeDescription]];
}

@end /* NGFilterStream */
