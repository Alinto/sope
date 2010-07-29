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

#include "NGTextStream.h"
#include "common.h"

@implementation NGTextStream

+ (int)version {
  return 2;
}

- (void)dealloc {
  [self->lastException release];
  [super dealloc];
}

/* NGTextInputStream */

- (NSException *)lastException {
  return nil;
}
- (void)setLastException:(NSException *)_exception {
  ASSIGN(self->lastException, _exception);
}
- (void)resetLastException {
  [self->lastException release];
  self->lastException = nil;
}

- (unichar)readCharacter {
  [self subclassResponsibility:_cmd];
  return 0;
}

- (BOOL)isOpen {
  return YES;
}

/* NGExtendedTextInputStream */

- (NSString *)readLineAsString {
  NSMutableString *str;
  unichar c;

  *(&str) = (id)[NSMutableString string];

  NS_DURING {
    while ((c = [self readCharacter]) != '\n')
      [str appendString:[NSString stringWithCharacters:&c length:1]];
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
      if ([str length] == 0) str = nil;
    }
    else
      [localException raise];
  }
  NS_ENDHANDLER;
  
  return str;
}

- (unsigned)readCharacters:(unichar *)_chars count:(unsigned)_count {
  /*
    Read up to _count characters, but one at the minimum.
  */
  volatile unsigned pos;

  NS_DURING {
    for (pos = 0; pos < _count; pos++)
      _chars[pos] = [self readCharacter];
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
      if (pos == 0)
        [localException raise];
    }
    else
      [localException raise];
  }
  NS_ENDHANDLER;

  NSAssert1(pos > 0, @"invalid character count to be returned: %i", pos);
  return pos;
}

- (BOOL)safeReadCharacters:(unichar *)_chars count:(unsigned)_count {
  volatile unsigned pos;
  
  for (pos = 0; pos < _count; pos++)
    _chars[pos] = [self readCharacter];
  
  return YES;
}

/* NGTextOutputStream */

- (BOOL)writeCharacter:(unichar)_character {
  [self subclassResponsibility:_cmd];
  return NO;
}

- (BOOL)writeString:(NSString *)_string {
  unsigned length = [_string length], cnt = 0;
  unichar  buffer[length];
  void     (*writeChar)(id, SEL, unichar);

  writeChar = (void (*)(id,SEL,unichar))
    [self methodForSelector:@selector(writeCharacter:)];
  
  [_string getCharacters:buffer];
  for (cnt = 0; cnt < length; cnt++)
    writeChar(self, @selector(writeCharacter:), buffer[cnt]);
  
  return YES;
}

- (BOOL)flush {
  return YES;
}

/* NGExtendedTextOutputStream */

- (BOOL)writeFormat:(NSString *)_format arguments:(va_list)_ap {
  NSString *tmp;
  
  tmp = [[[NSString alloc] initWithFormat:_format arguments:_ap] autorelease];
  [self writeString:tmp];
  return YES;
}
- (BOOL)writeFormat:(NSString *)_format, ... {
  va_list ap;
  BOOL res = NO;

  va_start(ap, _format);

#if MAC_OS_X_VERSION_MAX_ALLOWED >= 1050
  /* As soon as we add an exception handler on Leopard compilation
   * breaks. Probably some GCC bug.
   */
  res = [self writeFormat:_format arguments:ap];
#else
  NS_DURING {
    res = [self writeFormat:_format arguments:ap];
  }
  NS_HANDLER {
    va_end(ap);
    [localException raise];
  }
  NS_ENDHANDLER;
#endif
  
  va_end(ap);

  return res;
}

- (BOOL)writeNewline {
  if (![self writeString:@"\n"]) return NO;
  return [self flush];
}

- (unsigned)writeCharacters:(const unichar *)_chars count:(unsigned)_count {
  /*
    Write up to _count characters, but one at the minimum.
  */
  volatile unsigned pos;

  NS_DURING {
    for (pos = 0; pos < _count; pos++)
      [self writeCharacter:_chars[pos]];
  }
  NS_HANDLER {
    if ([localException isKindOfClass:[NGEndOfStreamException class]]) {
      if (pos == 0)
        [localException raise];
    }
    else
      [localException raise];
  }
  NS_ENDHANDLER;

  NSAssert1(pos > 0, @"invalid character count to be returned: %i", pos);
  return pos;
}

- (BOOL)safeWriteCharacters:(const unichar *)_chars count:(unsigned)_count {
  unsigned pos;

  for (pos = 0; pos < _count; pos++) {
    if (![self writeCharacter:_chars[pos]])
      return NO;
  }
  
  return YES;
}

@end /* NGTextStream */
