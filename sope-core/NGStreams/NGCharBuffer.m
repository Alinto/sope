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

#include "NGCharBuffer.h"
#include "common.h"

typedef struct NGCharBufferLA {
  unichar character;
  char    isEOF:1;
  char    isFetched:1;
} LA_NGCharBuffer;

@implementation NGCharBuffer

+ (id)charBufferWithSource:(id<NGTextStream>)_source la:(int)_la {
  return [[[self alloc] initWithSource:_source la:_la] autorelease];
}

- (id)initWithSource:(id<NGTextStream>)_source la:(int)_la {
  if ((self = [super initWithSource:_source])) {
    int size = 0;

    if (_la < 1) {
      [NSException raise:NSRangeException
                   format:@"lookahead depth is less than one (%d)", _la];
    }

    // Find first power of 2 >= to requested size
    for (size = 2; size < _la; size *=2);
    
#if LIB_FOUNDATION_LIBRARY
    self->la = NSZoneMallocAtomic([self zone],
                                  sizeof(LA_NGCharBuffer) * size);
#else
    self->la = NSZoneMalloc([self zone], sizeof(LA_NGCharBuffer) * size);
#endif
    memset(self->la, 0, sizeof(LA_NGCharBuffer) * size);

    self->bufLen      = size;
    self->sizeLessOne = self->bufLen - 1;
    self->headIdx     = 0;
    self->wasEOF      = NO;

    if ([self->source respondsToSelector:@selector(methodForSelector:)]) {
      self->readCharacter = (unichar (*)(id, SEL))
        [(NSObject *)self->source methodForSelector:@selector(readCharacter)];
    }
  }
  return self;
}

- (id)initWithSource:(id<NGTextStream>)_source {
  [self release];
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

- (id)init {
  [self release];
  [self doesNotRecognizeSelector:_cmd];
  return nil;
}

#if !LIB_FOUNDATION_BOEHM_GC
- (void)dealloc {
  NSZoneFree([self zone], self->la);
  self->readCharacter = NULL;
  [super dealloc];
}
#endif

- (unichar)readCharacter {
  int character = [self la:0];
  if (character < 1)
      [[[NGEndOfStreamException alloc] init] raise];
  [self consume];
  return character;
}

/* LA */

- (int)la:(int)_la {
  int result = -1;
  int idx    = (_la + self->headIdx) & self->sizeLessOne;

  idx = *(&idx);
  
  if (_la > self->sizeLessOne) {
    [NSException raise:NSRangeException
                 format:@"tried to look ahead too far (la=%d, max=%d)", 
                  _la, self->bufLen];
  }
  
  if (self->wasEOF) {
    result = (!self->la[idx].isFetched || self->la[idx].isEOF)
      ? -1
      : self->la[idx].character;
  }
  else {
    if (!self->la[idx].isFetched) {
      int i;

      *(&i) = 0;
      while ((i < _la) &&
             (self->la[(self->headIdx + i) & self->sizeLessOne].isFetched))
        i++;

      NS_DURING {
        while (i <= _la) {
          int     ix        = 0;
          unichar character = 0;

          if (self->readCharacter == NULL) 
            character = [self->source readCharacter];
          else {
            character = self->readCharacter(self->source,
					    @selector(readCharacter));
	  }
          ix = (self->headIdx + i) & self->sizeLessOne;      
          self->la[ix].character = character;
          self->la[ix].isFetched = 1;
          i++;
        }
      }
      NS_HANDLER {
        if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
          while (i <= _la) {
            self->la[(self->headIdx + i) & self->sizeLessOne].isEOF = YES;
            i++;
            self->wasEOF = YES;        
          }
        }
        else {
          [localException raise];
        }
      }
      NS_ENDHANDLER;
    }
    result = (self->la[idx].isEOF) ? -1 : self->la[idx].character;
  }
  return result;
}

- (void)consume {
  int idx = self->headIdx & sizeLessOne;
  
  if (!(self->la[idx].isFetched))
    [self la:0];

  self->la[idx].isFetched = 0;
  self->headIdx++;
}

- (void)consume:(int)_cnt {
  while (_cnt > 0) {
    int idx = self->headIdx & sizeLessOne;
    
    if (!(self->la[idx].isFetched))
      [self la:0];

    self->la[idx].isFetched = 0;
    self->headIdx++;
    _cnt--;
  }
}

/* description */

- (NSString *)description {
  return [NSString stringWithFormat:@"<%@[0x%p] source=%@ la=%d",
		     NSStringFromClass([self class]), self,
                     self->source, self->bufLen];
}

@end /* NGCharBuffer */
