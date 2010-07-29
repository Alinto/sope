/*
  Copyright (C) 2000-2008 SKYRIX Software AG
  Copyright (C) 2008      Helge Hess

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

#include <NGExtensions/NSString+Escaping.h>
#include "common.h"

@implementation NSString(Escaping)

- (NSString *)stringByApplyingCEscaping {
  // Unicode!
  unichar  *src;
  unichar  *buffer;
  int      len, pos, srcIdx;
  NSString *s;
  
  if ((len = [self length]) == 0)
    return @"";
  
  src = malloc(sizeof(unichar) * (len + 2));
  [self getCharacters:src];
  src[len] = 0; // zero-terminate
  
  buffer = malloc(sizeof(unichar) * ((len * 2) + 1));
  
  for (pos = 0, srcIdx = 0; srcIdx < len; pos++, srcIdx++) {
    switch (src[srcIdx]) {
      case '\n':
        buffer[pos] = '\\'; pos++;
        buffer[pos] = 'n';
        break;
      case '\r':
        buffer[pos] = '\\'; pos++;
        buffer[pos] = 'r';
        break;
      case '\t':
        buffer[pos] = '\\'; pos++;
        buffer[pos] = 't';
        break;
        
      default:
        buffer[pos] = src[srcIdx];
        break;
    }
  }
  buffer[pos] = '\0';
  
  s = [NSString stringWithCharacters:buffer length:pos];
  
  if (buffer != NULL) { free(buffer); buffer = NULL; }
  if (src    != NULL) { free(src);    src    = NULL; }
  return s;
}

- (NSString *)stringByEscapingCharactersFromSet:(NSCharacterSet *)_escSet
  usingStringEscaping:(<NGStringEscaping>)_esc
{
  NSMutableString *safeString;
  unsigned length;
  NSRange  prevRange, escRange;
  NSRange  todoRange;
  BOOL     needsEscaping;
  
  length    = [self length];
  prevRange = NSMakeRange(0, length);
  escRange  = [self rangeOfCharacterFromSet:_escSet options:0 range:prevRange];

  needsEscaping = escRange.length > 0 ? YES : NO;
  if (!needsEscaping)
    return self; /* cheap */
  
  safeString = [NSMutableString stringWithCapacity:length];

  do {
    NSString *s;

    prevRange.length = escRange.location - prevRange.location;
    if (prevRange.length > 0)
      [safeString appendString:[self substringWithRange:prevRange]];
    
    s = [_esc stringByEscapingString:[self substringWithRange:escRange]];
    if (s != nil)
        [safeString appendString:s];

    prevRange.location = NSMaxRange(escRange);
    todoRange.location = prevRange.location;
    todoRange.length   = length - prevRange.location;
    escRange           = [self rangeOfCharacterFromSet:_escSet
                               options:0
			                         range:todoRange];
  }
  while(escRange.length > 0);
  
  if (todoRange.length > 0)
    [safeString appendString:[self substringWithRange:todoRange]];
  
  return safeString;
}

@end /* NSString(Escaping) */
