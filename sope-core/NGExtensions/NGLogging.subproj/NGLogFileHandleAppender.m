/*
  Copyright (C) 2004-2005 SKYRIX Software AG

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

#include "NGLogFileHandleAppender.h"
#include "NGLogEvent.h"
#include "common.h"

@implementation NGLogFileHandleAppender

static NSData *nextLineData = nil;

+ (void)initialize {
  static BOOL didInit = NO;
  
  if (didInit) return;

  didInit = YES;
  nextLineData = [[@"\n" dataUsingEncoding:NSASCIIStringEncoding] retain];
}

- (id)initWithConfig:(NSDictionary *)_config {
  self = [super initWithConfig:_config];
  if (self) {
    self->flushImmediately = NO;
    self->encoding         = [NSString defaultCStringEncoding];
    [self openFileHandleWithConfig:_config];
  }
  return self;
}

- (void)dealloc {
  if ([self isFileHandleOpen])
    [self closeFileHandle];
  [self->fh release];
  [super dealloc];
}

- (BOOL)isFileHandleOpen {
  return self->fh ? YES : NO;
}

- (void)openFileHandleWithConfig:(NSDictionary *)_config {
}

- (void)closeFileHandle {
  [self->fh closeFile];
}

- (void)appendLogEvent:(NGLogEvent *)_event {
  NSString *formatted;
  NSData   *bin;

  formatted = [self formattedEvent:_event];
  bin       = [formatted dataUsingEncoding:self->encoding];
  [self->fh writeData:bin];
  [self->fh writeData:nextLineData];
  if (self->flushImmediately)
    [self->fh synchronizeFile];
}

@end /* NGLogFileHandleAppender */
