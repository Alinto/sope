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

#include "NGStringScanEnumerator.h"
#include "common.h"
#include <ctype.h>

@implementation NGStringScanEnumerator

- (id)initWithData:(NSData *)_data maxLength:(unsigned int)_length {
  if (_data == nil) {
    [self release];
    return nil;
  }
  
  if ((self = [super init])) {
    self->data      = [_data retain];
    self->curPos    = 0;
    self->maxLength = _length;
  }
  return self;
}

+ (id)enumeratorWithData:(NSData *)_data maxLength:(unsigned int)_length {
  return [[[self alloc] initWithData:_data maxLength:_length] autorelease];
}

- (void)dealloc {
  [self->data release];
  [super dealloc];
}

- (NSString *)nextObject {
  register int i;
  const unsigned char *bytes;
  unsigned int length;
  register int startPos = -1;
  
  bytes  = [self->data bytes];
  length = [self->data length];

  if (length == 0) {
    [self->data release]; self->data = nil;
    return nil;
  }
  
  for (i = self->curPos; i < length; i++) {

    if (isprint(bytes[i])) {
      if (startPos == -1)
        startPos = i;
    }
    else {
      if (startPos != -1) {
        if ((i - startPos) >= self->maxLength) {
          self->curPos = i;
          
          return [NSString stringWithCString:(bytes + startPos)
                           length:(i - startPos)];
        }
        startPos = -1;
      }
    }
  }
  /* end reached (can release data) */
  [self->data release]; self->data = nil;
  return nil;
}

@end /* NGStringScanEnumerator */

@implementation NSData(NGStringScanEnumerator)

- (NSEnumerator *)stringScanEnumeratorWithMaxStringLength:(unsigned int)_max {
  return [NGStringScanEnumerator enumeratorWithData:self maxLength:_max];
}

- (NSEnumerator *)stringScanEnumerator {
  return [self stringScanEnumeratorWithMaxStringLength:256];
}

@end /* NSData(Strings) */
