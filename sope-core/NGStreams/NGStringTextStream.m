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

#include "common.h"
#include "NGStringTextStream.h"
#include "NGStreamExceptions.h"

@implementation NGStringTextStream

+ (id)textStreamWithString:(NSString *)_string {
  return [[[self alloc] initWithString:_string] autorelease];
}
- (id)initWithString:(NSString *)_string {
  if ((self = [super init])) {
    self->string    = [_string retain];
    self->index     = 0;
    self->isMutable = [_string isKindOfClass:[NSMutableString class]];
  }
  return self;
}

- (void)dealloc {
  [self->string release];
  [super dealloc];
}

/* accessors */

- (NSString *)string {
  return string;
}

/* operations */

- (BOOL)close {
  // releases string
  [self->string release]; self->string = nil;
  return YES;
}

// NGTextInputStream

- (unichar)readCharacter {
  // throws
  //   NGStreamNotOpenException  when the stream is not open
  unsigned currentLength = [string length];
  unichar  result;

  if (string == nil) {
    [NGStreamNotOpenException raiseWithReason:
       @"tried to read from a string text stream which was closed"];
  }
  
  if (currentLength == index)
    [[[NGEndOfStreamException alloc] init] raise];

  result = [string characterAtIndex:index];
  index++;
  return result;
}

// NGExtendedTextInputStream

- (NSString *)readLineAsString {
  // throws
  //   NGStreamNotOpenException  when the stream is not open
  
  unsigned currentLength = [string length];
  NSRange  range;
  
  if (string == nil) {
    [NGStreamNotOpenException raiseWithReason:
            @"tried to read from a string text stream which was closed"];
  }
  
  if (currentLength == index)
    //[[[NGEndOfStreamException alloc] init] raise]
    return nil;
  
  range.location = index;
  range.length   = (currentLength - index);

  range = [string rangeOfString:@"\n" options:NSLiteralSearch range:range];
  if (range.length == 0) { // did not found newline
    NSString *result = [string substringFromIndex:index];
    index = currentLength;
    return result;
  }
  else {
    NSString *result = nil;

    range.length   = (range.location - index);
    range.location = index;

    result = [string substringWithRange:range];

    index += range.length + 1;

    return result;
  }
}

// NGTextOutputStream

- (BOOL)writeCharacter:(unichar)_character {
  // throws
  //   NGReadOnlyStreamException when the stream is not writeable
  //   NGStreamNotOpenException  when the stream is not open
  
  if (string == nil) {
    [NGStreamNotOpenException raiseWithReason:
            @"tried to write to a string text stream which was closed"];
    return NO;
  }
  if (!isMutable) {
    [[[NGReadOnlyStreamException alloc] init] raise];
    return NO;
  }
  
  [(NSMutableString *)string appendString:
    [NSString stringWithCharacters:&_character length:1]];
  return YES;
}

- (BOOL)writeString:(NSString *)_string {
  // throws
  //   NGReadOnlyStreamException when the stream is not writeable
  //   NGStreamNotOpenException  when the stream is not open
  
  if (string == nil) {
    [NGStreamNotOpenException raiseWithReason:
            @"tried to write to a string text stream which was closed"];
    return NO;
  }
  if (!isMutable) {
    [[[NGReadOnlyStreamException alloc] init] raise];
    return NO;
  }
  
  [(NSMutableString *)string appendString:_string];
  return YES;
}

- (BOOL)flush {
  return YES;
}

@end /* NGStringTextStream */
