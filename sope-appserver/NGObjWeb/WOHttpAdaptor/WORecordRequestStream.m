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

#include "WORecordRequestStream.h"
#include "common.h"

#define ReadLogInitSize  1024
#define WriteLogInitSize 128*1024

@implementation WORecordRequestStream

- (id)initWithSource:(id<NGStream>)_source {
  if ((self = [super initWithSource:_source]) != nil) {
    self->readLog  = [[NSMutableData alloc] initWithCapacity:ReadLogInitSize];
    self->writeLog = [[NSMutableData alloc] initWithCapacity:WriteLogInitSize];
  }
  return self;
}

- (void)dealloc {
  [self->readLog  release];
  [self->writeLog release];
  [super dealloc];
}

/* accessors */

- (NSData *)readLog {
  return self->readLog;
}
- (NSData *)writeLog {
  return self->writeLog;
}

- (void)resetReadLog {
  [self->readLog setLength:0];
}
- (void)resetWriteLog {
  [self->writeLog setLength:0];
}
- (void)reset {
  [self resetReadLog];
  [self resetWriteLog];
}

/* implementation */

- (unsigned)readBytes:(void *)_buf count:(unsigned)_len {
  unsigned len;
  
  len = [super readBytes:_buf count:_len];
  if (len == NGStreamError)
    return NGStreamError;
  
  [self->readLog appendBytes:_buf length:len];
  return len;
}
- (unsigned)writeBytes:(const void *)_buf count:(unsigned)_len {
  unsigned len;
  
  len = [super writeBytes:_buf count:_len];
  if (len == NGStreamError)
    return NGStreamError;
  
  [self->writeLog appendBytes:_buf length:len];
  return len;
}

@end /* WORecordRequestStream */
