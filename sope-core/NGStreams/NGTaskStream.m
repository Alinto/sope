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

#include "config.h"
#include "common.h"
#include "NGTaskStream.h"

@implementation NGTaskStream

- (id)initWithPath:(NSString *)_executable
  arguments:(NSArray *)_args
  environment:(NSDictionary *)_env
{
  return nil;
}

- (void)dealloc {
  [super dealloc];
}

/* state */

- (BOOL)isOpen {
  return [self->task isRunning];
}

/* primitives */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  return NGStreamError;
}
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  return NGStreamError;
}

- (BOOL)close {
  if (![self isOpen]) {
    NSLog(@"tried to close already closed stream %@", self);
    return NO;
  }
  [self->task terminate];
  return YES;
}

- (NGStreamMode)mode {
  return NGStreamMode_readWrite;
}
- (BOOL)isRootStream {
  return YES;
}

/* marking */

- (BOOL)mark {
  NSLog(@"WARNING: called mark on a stream which doesn't support marking !");
  return NO;
}
- (BOOL)rewind {
  [[[NGStreamException alloc] initWithStream:self
                              reason:@"marking not supported"] raise];
  return NO;
}
- (BOOL)markSupported {
  return -1;
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:
                     @"<%@[0x%p] task=%@ mode=%@>",
                     NSStringFromClass([self class]), (unsigned)self,
                     self->task,
                     [self modeDescription]];
}

@end /* NGTaskStream */
